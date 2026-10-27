import 'dart:math';

import '../core/format.dart';
import '../core/roles.dart';
import '../domain/models.dart';
import '../domain/scheduler.dart';
import 'auth/auth_service.dart';
import 'models/conteudo.dart';
import 'models/escala.dart';
import 'models/igreja.dart';
import 'models/pastoral.dart';
import 'models/people.dart';
import 'store/doc_store.dart';

/// Coleções do banco.
abstract final class Col {
  static const users = 'users';
  static const config = 'config';
  static const members = 'members';
  static const pastoralNotes = 'pastoralNotes';
  static const availability = 'availability';
  static const visits = 'visits';
  static const agenda = 'agenda';
  static const notifications = 'notifications';
  static const weekly = 'weekly';
  static const events = 'events';
  static const diaconia = 'diaconia';
  static const videos = 'videos';
  static const avisos = 'avisos';
  static const oracao = 'oracao';
  static String registrations(String eventId) => '$events/$eventId/registrations';
  static String tasks(String eventId) => '$events/$eventId/tasks';
  static String budget(String eventId) => '$events/$eventId/budget';
}

/// Ofícios que aparecem em Contatos (lidos por todos os membros).
final contactOficios = [for (final o in Oficio.values) o.name];

/// Acesso tipado a todas as coleções do app.
class Repository {
  Repository(this.store);
  final DocStore store;

  static final _rand = Random.secure();

  /// Id novo de documento (para gravar dentro de transações).
  static String newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(20, (_) => chars[_rand.nextInt(chars.length)]).join();
  }

  List<T> _map<T>(List<Doc> docs, T Function(String, Map<String, dynamic>) f) => [
    for (final d in docs) f(d.id, d.data),
  ];

  // ---- Contas ---------------------------------------------------------------
  Stream<AppUser?> watchUser(String uid) =>
      store.watchDoc('${Col.users}/$uid').map((d) => d == null ? null : AppUser.fromMap(d.id, d.data));

  Stream<List<AppUser>> watchUsers() => store
      .watchCollection(Col.users)
      .map((docs) => _map(docs, AppUser.fromMap)..sort((a, b) => fold(a.name).compareTo(fold(b.name))));

  /// Cria o perfil no primeiro login. A primeira conta do projeto vira
  /// administradora; as demais aguardam aprovação. Se o projeto já tinha um
  /// pastor (versão anterior do app), é ele quem marca o projeto como iniciado.
  Future<void> ensureUser(AuthUser auth) async {
    final path = '${Col.users}/${auth.uid}';
    final existing = await store.getDoc(path);
    final bootstrapped = await store.getDoc('${Col.config}/app') != null;
    if (existing != null) {
      if (!bootstrapped && const {'pastor', 'admin'}.contains(existing.data['role'])) {
        await store.set('${Col.config}/app', {'bootstrappedAt': nowIso(), 'bootstrappedBy': auth.uid});
      }
      return;
    }
    final base = {'name': auth.name, 'email': auth.email, 'createdAt': nowIso()};
    if (bootstrapped) {
      await store.set(path, {...base, 'role': AppRole.pending.name});
    } else {
      await store.batch([
        DocWrite(path, {...base, 'role': AppRole.admin.name}, merge: false),
        DocWrite('${Col.config}/app', {'bootstrappedAt': nowIso(), 'bootstrappedBy': auth.uid}, merge: false),
      ]);
    }
  }

  Future<void> updateUser(String uid, {AppRole? role, String? memberId, bool clearMember = false}) => store.set(
    '${Col.users}/$uid',
    {if (role != null) 'role': role.name, if (memberId != null || clearMember) 'memberId': memberId},
    merge: true,
  );

  Future<void> deleteUser(String uid) => store.delete('${Col.users}/$uid');

  Future<void> setUnavailable(String uid, List<String> dates) =>
      store.set('${Col.users}/$uid', {'unavailable': dates.toSet().toList()..sort()}, merge: true);

  Future<void> renameSelf(String uid, String name) =>
      store.set('${Col.users}/$uid', {'name': name.trim()}, merge: true);

  // ---- Igreja ---------------------------------------------------------------
  Stream<IgrejaConfig> watchIgreja() =>
      store.watchDoc('${Col.config}/igreja').map((d) => IgrejaConfig.fromMap(d?.data));

  Future<void> saveIgreja(IgrejaConfig c) => store.set('${Col.config}/igreja', c.toMap());

  // ---- Membros --------------------------------------------------------------
  Stream<List<Membro>> watchMembers() => store
      .watchSynced(Col.members)
      .map((docs) => _map(docs, Membro.fromMap)..sort((a, b) => fold(a.name).compareTo(fold(b.name))));

  /// Pastores, presbíteros e diáconos: o que qualquer membro pode ver.
  Stream<List<Membro>> watchOfficers() => store
      .watchWhere(Col.members, 'oficio', contactOficios)
      .map((docs) => _map(_alive(docs), Membro.fromMap)..sort((a, b) => fold(a.name).compareTo(fold(b.name))));

  /// Quem serve na diaconia (diáconos e auxiliares): o que a coordenação da escala lê.
  Stream<List<Membro>> watchDiaconia() => store
      .watchWhere(Col.members, 'diaconia', [true])
      .map((docs) => _map(_alive(docs), Membro.fromMap)..sort((a, b) => fold(a.name).compareTo(fold(b.name))));

  Stream<Membro?> watchMember(String id) => store
      .watchDoc('${Col.members}/$id')
      .map((d) => d == null || d.data['deleted'] == true ? null : Membro.fromMap(d.id, d.data));

  /// Sem os cadastros removidos (exclusão lógica).
  static List<Doc> _alive(List<Doc> docs) => [
    for (final d in docs)
      if (d.data['deleted'] != true) d,
  ];

  Future<String> saveMember(Membro m, {required String byUid}) async {
    final data = {...m.toMap(), 'updatedAt': nowIso(), 'updatedBy': byUid};
    if (m.id.isEmpty) return store.add(Col.members, data);
    await store.set('${Col.members}/${m.id}', data, merge: true);
    return m.id;
  }

  /// Exclusão lógica (some das listas e de todos os aparelhos).
  Future<void> deleteMember(String id) =>
      store.set('${Col.members}/$id', {'deleted': true, 'updatedAt': nowIso()}, merge: true);

  /// A própria pessoa atualiza contato e endereço.
  Future<void> saveOwnMember(String id, Map<String, dynamic> fields) => store.set('${Col.members}/$id', {
    for (final e in fields.entries)
      if (Membro.selfFields.contains(e.key)) e.key: e.value,
    'updatedAt': nowIso(),
  }, merge: true);

  /// Quem ainda não tem cadastro cria o próprio (id = uid) e vincula à conta.
  Future<void> createOwnMember(String uid, Membro m) => store.batch([
    DocWrite('${Col.members}/$uid', {
      ...m.toMap(),
      'situacao': Situacao.visitante.name,
      'oficio': null,
      'ministries': const <String>[],
      'funcoes': const <String>[],
      'selfRegistered': true,
      'updatedAt': nowIso(),
      'updatedBy': uid,
    }, merge: false),
    DocWrite('${Col.users}/$uid', {'memberId': uid}),
  ]);

  Stream<String> watchPastoralNote(String memberId) =>
      store.watchDoc('${Col.pastoralNotes}/$memberId').map((d) => d?.data['text'] as String? ?? '');

  Future<void> savePastoralNote(String memberId, String text) =>
      store.set('${Col.pastoralNotes}/$memberId', {'text': text, 'updatedAt': nowIso()});

  // ---- Agenda pastoral -------------------------------------------------------
  Stream<ScheduleSettings> watchScheduleSettings() =>
      store.watchDoc('${Col.config}/agenda').map((d) => ScheduleSettings.fromMap(d?.data));

  Future<void> saveScheduleSettings(ScheduleSettings s) => store.set('${Col.config}/agenda', s.toMap());

  Stream<List<Janela>> watchWindows() => store
      .watchCollection(Col.availability)
      .map((docs) => _map(docs, Janela.fromMap)..sort((a, b) => a.start.compareTo(b.start)));

  Future<void> addWindow(DateTime start, DateTime end) {
    if (!end.isAfter(start)) throw ArgumentError('O fim precisa ser depois do início.');
    if (ymd(start) != ymd(end)) throw ArgumentError('A janela precisa começar e terminar no mesmo dia.');
    return store.add(Col.availability, Janela(id: '', start: start, end: end).toMap());
  }

  Future<void> removeWindow(String id) => store.delete('${Col.availability}/$id');

  /// Repete na semana seguinte as janelas da semana de [monday]. Devolve quantas.
  Future<int> copyWeek(List<Janela> all, DateTime monday) async {
    final next = addDays(monday, 7), after = addDays(monday, 14);
    final source = [
      for (final w in all)
        if (!w.start.isBefore(monday) && w.start.isBefore(next)) w,
    ];
    final existing = {
      for (final w in all)
        if (!w.start.isBefore(next) && w.start.isBefore(after)) localIso(w.start),
    };
    final writes = [
      for (final w in source)
        if (!existing.contains(localIso(addDaysKeepTime(w.start, 7))))
          DocWrite(
            '${Col.availability}/${newId()}',
            Janela(id: '', start: addDaysKeepTime(w.start, 7), end: addDaysKeepTime(w.end, 7)).toMap(),
            merge: false,
          ),
    ];
    if (writes.isNotEmpty) await store.batch(writes);
    return writes.length;
  }

  /// Todas as visitas (pastor) ou só as de quem marcou.
  Stream<List<Visita>> watchVisits({String? uid}) =>
      (uid == null ? store.watchCollection(Col.visits) : store.watchWhere(Col.visits, 'uid', [uid])).map(
        (docs) => _map(docs, Visita.fromMap)..sort((a, b) => a.start.compareTo(b.start)),
      );

  /// Ocupação de todos os dias (sem dados pessoais).
  Stream<List<SlotOcupado>> watchBusy() => store
      .watchCollection(Col.agenda)
      .map(
        (docs) => [
          for (final d in docs)
            for (final s in (d.data['slots'] as List? ?? const []))
              SlotOcupado.fromMap(Map<String, dynamic>.from(s as Map)),
        ],
      );

  Stream<List<Notificacao>> watchNotifications() => store
      .watchCollection(Col.notifications)
      .map((docs) => _map(docs, Notificacao.fromMap)..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Future<void> markNotificationsRead(List<Notificacao> ns) => store.batch([
    for (final n in ns)
      if (!n.read) DocWrite('${Col.notifications}/${n.id}', {'read': true}),
  ]);

  /// Marca uma visita. Em transação: relê a ocupação do dia e refaz a conta do
  /// deslocamento, então dois membros nunca ficam com horários incompatíveis.
  /// Lança [StateError] com o motivo quando o horário não cabe mais.
  Future<String> bookVisit({
    required Membro member,
    required String uid,
    required DateTime start,
    required Scheduler scheduler,
    String? reason,
    bool byPastor = false,
  }) async {
    if (!member.hasLocation) throw StateError('Cadastre o endereço antes de marcar a visita.');
    final end = start.add(scheduler.settings.visitDuration);
    final day = ymd(start);
    final dayPath = '${Col.agenda}/$day';
    final id = newId();
    final location = GeoPoint(member.lat!, member.lng!);
    final visit = Visita(
      id: id,
      memberId: member.id,
      uid: uid,
      memberName: member.name,
      phone: member.phone,
      address: member.address,
      neighborhood: member.neighborhood ?? '',
      lat: member.lat!,
      lng: member.lng!,
      start: start,
      end: end,
      reason: reason,
      status: byPastor ? VisitaStatus.confirmada : VisitaStatus.pendente,
      createdAt: nowIso(),
    );
    await store.transact([dayPath], (current) {
      final slots = [
        for (final s in (current[dayPath]?['slots'] as List? ?? const []))
          SlotOcupado.fromMap(Map<String, dynamic>.from(s as Map)),
      ];
      final blocked = scheduler.blockedReason(
        location: location,
        start: start,
        end: end,
        visits: [for (final s in slots) s.stop],
      );
      if (blocked != null) throw StateError(blocked);
      return [
        DocWrite('${Col.visits}/$id', visit.toMap(), merge: false),
        DocWrite(dayPath, {
          'slots': [for (final s in slots) s.toMap(), SlotOcupado(visitId: id, stop: visit.stop).toMap()],
        }, merge: false),
        if (!byPastor)
          DocWrite('${Col.notifications}/${newId()}', {
            'message': '${member.name} marcou visita para ${fmtShortDate(day)} às ${fmtHour(start)}',
            'createdAt': nowIso(),
            'read': false,
            'route': '/pastoral',
          }, merge: false),
      ];
    });
    return id;
  }

  /// Cancela uma visita e libera o horário. O pastor recebe aviso quando é o
  /// membro quem cancela.
  Future<void> cancelVisit(Visita v, {required bool byPastor}) async {
    final dayPath = '${Col.agenda}/${v.day}';
    await store.transact([dayPath], (current) {
      final slots = [
        for (final s in (current[dayPath]?['slots'] as List? ?? const []))
          if ((s as Map)['visitId'] != v.id) Map<String, dynamic>.from(s),
      ];
      return [
        DocWrite('${Col.visits}/${v.id}', {'status': VisitaStatus.cancelada.name}),
        if (current[dayPath] != null) DocWrite(dayPath, {'slots': slots}, merge: false),
        if (!byPastor)
          DocWrite('${Col.notifications}/${newId()}', {
            'message': '${v.memberName} cancelou a visita de ${fmtShortDate(v.day)} às ${fmtHour(v.start)}',
            'createdAt': nowIso(),
            'read': false,
            'route': '/pastoral',
          }, merge: false),
      ];
    });
  }

  Future<void> setVisitStatus(String id, VisitaStatus status) =>
      store.set('${Col.visits}/$id', {'status': status.name}, merge: true);

  // ---- Programação semanal e eventos -----------------------------------------
  Stream<List<Programacao>> watchWeekly() => store
      .watchCollection(Col.weekly)
      .map(
        (docs) =>
            _map(docs, Programacao.fromMap)
              ..sort((a, b) => a.weekday != b.weekday ? a.weekday.compareTo(b.weekday) : a.time.compareTo(b.time)),
      );

  Future<void> saveWeekly(Programacao p) =>
      p.id.isEmpty ? store.add(Col.weekly, p.toMap()) : store.set('${Col.weekly}/${p.id}', p.toMap());

  Future<void> deleteWeekly(String id) => store.delete('${Col.weekly}/$id');

  Stream<List<Evento>> watchEvents({required bool all}) =>
      (all ? store.watchCollection(Col.events) : store.watchWhere(Col.events, 'published', [true])).map(
        (docs) => _map(docs, Evento.fromMap)..sort((a, b) => a.start.compareTo(b.start)),
      );

  Future<String> saveEvent(Evento e) async {
    if (e.id.isEmpty) return store.add(Col.events, {...e.toMap(), 'createdAt': nowIso()});
    await store.set('${Col.events}/${e.id}', e.toMap(), merge: true);
    return e.id;
  }

  Future<void> deleteEvent(String id) => store.delete('${Col.events}/$id');

  Stream<List<Inscricao>> watchRegistrations(String eventId) =>
      store.watchCollection(Col.registrations(eventId)).map((docs) => _map(docs, Inscricao.fromMap));

  Stream<Inscricao?> watchMyRegistration(String eventId, String uid) => store
      .watchDoc('${Col.registrations(eventId)}/$uid')
      .map((d) => d == null ? null : Inscricao.fromMap(d.id, d.data));

  Future<void> register(String eventId, Inscricao i) => store.set('${Col.registrations(eventId)}/${i.uid}', i.toMap());

  Future<void> unregister(String eventId, String uid) => store.delete('${Col.registrations(eventId)}/$uid');

  Future<void> checkIn(String eventId, String uid, bool value) =>
      store.set('${Col.registrations(eventId)}/$uid', {'checkedIn': value}, merge: true);

  Stream<List<Tarefa>> watchTasks(String eventId) => store
      .watchCollection(Col.tasks(eventId))
      .map(
        (docs) => _map(docs, Tarefa.fromMap)
          ..sort((a, b) {
            if (a.done != b.done) return a.done ? 1 : -1;
            return (a.due ?? '9999').compareTo(b.due ?? '9999');
          }),
      );

  Future<void> saveTask(String eventId, Tarefa t) =>
      t.id.isEmpty ? store.add(Col.tasks(eventId), t.toMap()) : store.set('${Col.tasks(eventId)}/${t.id}', t.toMap());

  Future<void> deleteTask(String eventId, String id) => store.delete('${Col.tasks(eventId)}/$id');

  Stream<List<Lancamento>> watchBudget(String eventId) =>
      store.watchCollection(Col.budget(eventId)).map((docs) => _map(docs, Lancamento.fromMap));

  Future<void> saveBudgetItem(String eventId, Lancamento l) =>
      l.id.isEmpty ? store.add(Col.budget(eventId), l.toMap()) : store.set('${Col.budget(eventId)}/${l.id}', l.toMap());

  Future<void> deleteBudgetItem(String eventId, String id) => store.delete('${Col.budget(eventId)}/$id');

  // ---- Escala diaconal --------------------------------------------------------
  Stream<List<EscalaDiaconal>> watchEscalas({required bool all}) =>
      (all ? store.watchCollection(Col.diaconia) : store.watchWhere(Col.diaconia, 'published', [true])).map(
        (docs) =>
            _map(docs, EscalaDiaconal.fromMap)
              ..sort((a, b) => a.date != b.date ? a.date.compareTo(b.date) : (a.time ?? '').compareTo(b.time ?? '')),
      );

  Future<String> saveEscala(EscalaDiaconal e) async {
    if (e.id.isEmpty) return store.add(Col.diaconia, e.toMap());
    await store.set('${Col.diaconia}/${e.id}', e.toMap(), merge: true);
    return e.id;
  }

  Future<void> saveEscalas(List<EscalaDiaconal> list) =>
      store.batch([for (final e in list) DocWrite('${Col.diaconia}/${e.id.isEmpty ? newId() : e.id}', e.toMap())]);

  Future<void> deleteEscala(String id) => store.delete('${Col.diaconia}/$id');

  /// O próprio diácono confirma ou recusa.
  Future<void> respondEscala(String escalaId, String memberId, Resposta r, {String? note}) =>
      store.set('${Col.diaconia}/$escalaId', {
        'confirmations': {
          memberId: {'status': r.name, 'note': note, 'at': nowIso()},
        },
      }, merge: true);

  // ---- Vídeos, avisos e oração ------------------------------------------------
  Stream<List<Video>> watchVideos() => store
      .watchCollection(Col.videos)
      .map((docs) => _map(docs, Video.fromMap)..sort((a, b) => b.date.compareTo(a.date)));

  Future<void> saveVideo(Video v) => v.id.isEmpty
      ? store.add(Col.videos, {...v.toMap(), 'createdAt': nowIso()})
      : store.set('${Col.videos}/${v.id}', v.toMap(), merge: true);

  Future<void> deleteVideo(String id) => store.delete('${Col.videos}/$id');

  Stream<List<Aviso>> watchAvisos() => store
      .watchCollection(Col.avisos)
      .map((docs) => _map(docs, Aviso.fromMap)..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Future<void> saveAviso(Aviso a) => a.id.isEmpty
      ? store.add(Col.avisos, {...a.toMap(), 'createdAt': nowIso()})
      : store.set('${Col.avisos}/${a.id}', a.toMap());

  Future<void> deleteAviso(String id) => store.delete('${Col.avisos}/$id');

  /// Pedidos públicos; quem vê os reservados recebe todos.
  Stream<List<PedidoOracao>> watchPrayers({required bool all}) =>
      (all ? store.watchCollection(Col.oracao) : store.watchWhere(Col.oracao, 'private', [false])).map(
        (docs) => _map(docs, PedidoOracao.fromMap)..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  /// Pedidos da própria pessoa (inclusive reservados).
  Stream<List<PedidoOracao>> watchMyPrayers(String uid) =>
      store.watchWhere(Col.oracao, 'authorUid', [uid]).map((docs) => _map(docs, PedidoOracao.fromMap));

  Future<void> addPrayer({
    required String uid,
    required String name,
    required String text,
    required bool anonymous,
    required bool private,
  }) => store.batch([
    DocWrite('${Col.oracao}/${newId()}', {
      'text': text.trim(),
      'authorUid': uid,
      'authorName': name,
      'anonymous': anonymous,
      'private': private,
      'answered': false,
      'praying': const <String>[],
      'createdAt': nowIso(),
    }, merge: false),
    if (private)
      DocWrite('${Col.notifications}/${newId()}', {
        'message': 'Novo pedido de oração reservado de $name',
        'createdAt': nowIso(),
        'read': false,
        'route': '/mais/oracao',
      }, merge: false),
  ]);

  Future<void> togglePraying(PedidoOracao p, String uid) => store.set('${Col.oracao}/${p.id}', {
    'praying': p.praying.contains(uid) ? [...p.praying.where((u) => u != uid)] : [...p.praying, uid],
  }, merge: true);

  Future<void> setAnswered(String id, bool v) => store.set('${Col.oracao}/$id', {'answered': v}, merge: true);

  Future<void> deletePrayer(String id) => store.delete('${Col.oracao}/$id');
}

/// Soma dias mantendo o horário (sem pular por causa de horário de verão).
DateTime addDaysKeepTime(DateTime d, int days) => DateTime(d.year, d.month, d.day + days, d.hour, d.minute);
