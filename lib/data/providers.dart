import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/roles.dart';
import '../domain/models.dart';
import '../domain/scheduler.dart';
import 'auth/auth_service.dart';
import 'geocoder.dart';
import 'models/conteudo.dart';
import 'models/escala.dart';
import 'models/igreja.dart';
import 'models/pastoral.dart';
import 'models/people.dart';
import 'repository.dart';
import 'store/doc_store.dart';

// Sobrescritos em main.dart conforme o modo (Firebase ou demonstração).
final isDemoProvider = Provider<bool>((_) => false);
final docStoreProvider = Provider<DocStore>((_) => throw UnimplementedError());
final authServiceProvider = Provider<AuthService>((_) => throw UnimplementedError());
final geocoderProvider = Provider<Geocoder>((_) => NominatimGeocoder());

final repoProvider = Provider<Repository>((ref) => Repository(ref.watch(docStoreProvider)));

final authStateProvider = StreamProvider<AuthUser?>((ref) => ref.watch(authServiceProvider).authStateChanges());

/// Usuário logado com seu perfil. `null` quando deslogado.
final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final auth = await ref.watch(authStateProvider.future);
  if (auth == null) {
    yield null;
    return;
  }
  final repo = ref.watch(repoProvider);
  await repo.ensureUser(auth);
  yield* repo.watchUser(auth.uid);
});

final roleProvider = Provider<AppRole>((ref) => ref.watch(currentUserProvider).value?.role ?? AppRole.pending);
final uidProvider = Provider<String?>((ref) => ref.watch(currentUserProvider).value?.uid);

/// Os streams abaixo dependem do perfil: as regras do servidor só liberam a
/// cada perfil o que ele pode ver, então a consulta precisa pedir só isso.
final igrejaProvider = StreamProvider<IgrejaConfig>((ref) => ref.watch(repoProvider).watchIgreja());

final membersProvider = StreamProvider<List<Membro>>((ref) {
  final role = ref.watch(roleProvider);
  final repo = ref.watch(repoProvider);
  return role.canManageMembers ? repo.watchMembers() : repo.watchOfficers();
});

final officersProvider = Provider<AsyncValue<List<Membro>>>(
  (ref) => ref
      .watch(membersProvider)
      .whenData(
        (all) => [
          for (final m in all)
            if (m.oficio != null) m,
        ],
      ),
);

final memberMapProvider = Provider<Map<String, Membro>>(
  (ref) => {for (final m in ref.watch(membersProvider).value ?? const <Membro>[]) m.id: m},
);

final memberProvider = StreamProvider.family<Membro?, String>((ref, id) => ref.watch(repoProvider).watchMember(id));

/// Cadastro vinculado à conta logada.
final myMemberProvider = StreamProvider<Membro?>((ref) {
  final id = ref.watch(currentUserProvider).value?.memberId;
  if (id == null) return Stream.value(null);
  return ref.watch(repoProvider).watchMember(id);
});

final usersProvider = StreamProvider<List<AppUser>>((ref) => ref.watch(repoProvider).watchUsers());

final todayProvider = Provider<DateTime>((_) => dateOnly(DateTime.now()));

// ---- Agenda pastoral ----------------------------------------------------------
final scheduleSettingsProvider = StreamProvider<ScheduleSettings>(
  (ref) => ref.watch(repoProvider).watchScheduleSettings(),
);
final schedulerProvider = Provider<Scheduler>(
  (ref) => Scheduler(settings: ref.watch(scheduleSettingsProvider).value ?? const ScheduleSettings()),
);
final windowsProvider = StreamProvider<List<Janela>>((ref) => ref.watch(repoProvider).watchWindows());

/// Pastor: todas as visitas. Membro: só as que ele marcou.
final visitsProvider = StreamProvider<List<Visita>>((ref) {
  final role = ref.watch(roleProvider);
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(repoProvider).watchVisits(uid: role.isPastoral ? null : uid);
});
final busyProvider = StreamProvider<List<SlotOcupado>>((ref) => ref.watch(repoProvider).watchBusy());
final notificationsProvider = StreamProvider<List<Notificacao>>((ref) {
  if (!ref.watch(roleProvider).isPastoral) return Stream.value(const []);
  return ref.watch(repoProvider).watchNotifications();
});

/// O que ocupa a agenda do pastor: as visitas completas (pastor) ou a ocupação
/// anônima (membro).
final pastorStopsProvider = Provider<List<Stop>>((ref) {
  if (ref.watch(roleProvider).isPastoral) {
    return [
      for (final v in ref.watch(visitsProvider).value ?? const <Visita>[])
        if (v.status.active) v.stop,
    ];
  }
  return [for (final s in ref.watch(busyProvider).value ?? const <SlotOcupado>[]) s.stop];
});

// ---- Igreja --------------------------------------------------------------------
final weeklyProvider = StreamProvider<List<Programacao>>((ref) => ref.watch(repoProvider).watchWeekly());
final eventsProvider = StreamProvider<List<Evento>>(
  (ref) => ref.watch(repoProvider).watchEvents(all: ref.watch(roleProvider).canManageEvents),
);
final eventProvider = Provider.family<Evento?, String>((ref, id) {
  for (final e in ref.watch(eventsProvider).value ?? const <Evento>[]) {
    if (e.id == id) return e;
  }
  return null;
});
final registrationsProvider = StreamProvider.family<List<Inscricao>, String>(
  (ref, id) => ref.watch(repoProvider).watchRegistrations(id),
);
final myRegistrationProvider = StreamProvider.family<Inscricao?, String>((ref, id) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(repoProvider).watchMyRegistration(id, uid);
});
final tasksProvider = StreamProvider.family<List<Tarefa>, String>((ref, id) => ref.watch(repoProvider).watchTasks(id));
final budgetProvider = StreamProvider.family<List<Lancamento>, String>(
  (ref, id) => ref.watch(repoProvider).watchBudget(id),
);

/// Um item da agenda da semana: atividade fixa ou evento.
class ItemAgenda {
  const ItemAgenda({required this.start, required this.title, this.end, this.place, this.categoria, this.eventId});
  final DateTime start;
  final DateTime? end;
  final String title;
  final String? place;
  final Categoria? categoria;
  final String? eventId;
}

/// Agenda da semana que começa em [monday]: programação fixa + eventos publicados.
final weekAgendaProvider = Provider.family<List<ItemAgenda>, DateTime>((ref, monday) {
  final next = addDays(monday, 7);
  final items = [
    for (final p in ref.watch(weeklyProvider).value ?? const <Programacao>[])
      if (p.active)
        ItemAgenda(start: p.on(monday), title: p.title, place: p.place, categoria: p.categoria, end: _endOf(p, monday)),
    for (final e in ref.watch(eventsProvider).value ?? const <Evento>[])
      if (e.published && e.status != EventoStatus.cancelado && !e.start.isBefore(monday) && e.start.isBefore(next))
        ItemAgenda(start: e.start, end: e.end, title: e.title, place: e.place, categoria: e.categoria, eventId: e.id),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return items;
});

DateTime? _endOf(Programacao p, DateTime monday) {
  final hm = parseHhmm(p.endTime);
  if (hm == null) return null;
  final s = p.on(monday);
  return DateTime(s.year, s.month, s.day, hm.$1, hm.$2);
}

// ---- Escala diaconal -------------------------------------------------------------
final escalasProvider = StreamProvider<List<EscalaDiaconal>>(
  (ref) => ref.watch(repoProvider).watchEscalas(all: ref.watch(roleProvider).canManageEscala),
);
final escalaProvider = Provider.family<EscalaDiaconal?, String>((ref, id) {
  for (final e in ref.watch(escalasProvider).value ?? const <EscalaDiaconal>[]) {
    if (e.id == id) return e;
  }
  return null;
});

/// Quem pode ser escalado na diaconia.
final diaconiaMembersProvider = StreamProvider<List<Membro>>((ref) {
  final role = ref.watch(roleProvider);
  final repo = ref.watch(repoProvider);
  if (role.canManageMembers) {
    return repo.watchMembers().map(
      (all) => [
        for (final m in all)
          if (m.servesDiaconia && m.situacao != Situacao.inativo) m,
      ],
    );
  }
  return repo.watchDiaconia();
});

/// Datas indisponíveis de cada membro (pelas contas vinculadas).
final unavailableByMemberProvider = Provider<Map<String, Set<String>>>((ref) {
  if (!ref.watch(roleProvider).canManageEscala) return const {};
  return {
    for (final u in ref.watch(usersProvider).value ?? const <AppUser>[])
      if (u.memberId != null) u.memberId!: u.unavailable.toSet(),
  };
});

/// Próximas escalas em que a pessoa logada está.
final myEscalasProvider = Provider<List<EscalaDiaconal>>((ref) {
  final memberId = ref.watch(currentUserProvider).value?.memberId;
  if (memberId == null) return const [];
  final today = ymd(ref.watch(todayProvider));
  return [
    for (final e in ref.watch(escalasProvider).value ?? const <EscalaDiaconal>[])
      if (e.published && e.date.compareTo(today) >= 0 && e.people.contains(memberId)) e,
  ];
});

// ---- Conteúdo ----------------------------------------------------------------------
final videosProvider = StreamProvider<List<Video>>((ref) => ref.watch(repoProvider).watchVideos());

/// Vídeos dos últimos 7 dias (ou os 3 mais recentes, se a semana estiver vazia).
final weekVideosProvider = Provider<List<Video>>((ref) {
  final all = ref.watch(videosProvider).value ?? const <Video>[];
  final since = ymd(addDays(ref.watch(todayProvider), -7));
  final week = [
    for (final v in all)
      if (v.date.compareTo(since) >= 0) v,
  ];
  return week.isNotEmpty ? week : all.take(3).toList();
});

final avisosProvider = StreamProvider<List<Aviso>>((ref) => ref.watch(repoProvider).watchAvisos());

final prayersProvider = StreamProvider<List<PedidoOracao>>((ref) {
  final repo = ref.watch(repoProvider);
  final role = ref.watch(roleProvider);
  final uid = ref.watch(uidProvider);
  if (role.seesPrivatePrayers || uid == null) return repo.watchPrayers(all: role.seesPrivatePrayers);
  // Públicos + os reservados da própria pessoa.
  final mine = <String, PedidoOracao>{};
  var public = <PedidoOracao>[];
  late final StreamController<List<PedidoOracao>> ctrl;
  void emit() {
    final ids = {for (final p in public) p.id};
    ctrl.add(
      [...public, ...mine.values.where((p) => !ids.contains(p.id))]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  final subs = <StreamSubscription<List<PedidoOracao>>>[];
  ctrl = StreamController<List<PedidoOracao>>(
    onListen: () {
      subs
        ..add(
          repo.watchPrayers(all: false).listen((l) {
            public = l;
            emit();
          }, onError: ctrl.addError),
        )
        ..add(
          repo.watchMyPrayers(uid).listen((l) {
            mine
              ..clear()
              ..addEntries(l.map((p) => MapEntry(p.id, p)));
            emit();
          }, onError: ctrl.addError),
        );
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
      await ctrl.close();
    },
  );
  return ctrl.stream;
});

/// Aniversariantes dos próximos [days] dias (só para quem vê o cadastro completo).
final birthdaysProvider = Provider.family<List<(Membro, DateTime)>, int>((ref, days) {
  if (!ref.watch(roleProvider).canManageMembers) return const [];
  final today = ref.watch(todayProvider);
  final out = <(Membro, DateTime)>[];
  for (final m in ref.watch(membersProvider).value ?? const <Membro>[]) {
    final b = m.birthDate == null ? null : DateTime.tryParse(m.birthDate!);
    if (b == null || m.situacao == Situacao.transferido || m.situacao == Situacao.inativo) continue;
    var next = DateTime(today.year, b.month, b.day);
    if (next.isBefore(today)) next = DateTime(today.year + 1, b.month, b.day);
    if (next.difference(today).inDays < days) out.add((m, next));
  }
  return out..sort((a, b) => a.$2.compareTo(b.$2));
});
