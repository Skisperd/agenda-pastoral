import '../core/format.dart';
import '../core/roles.dart';
import 'auth/auth_service.dart';
import 'dados_iniciais.dart';
import 'models/boletim.dart';
import 'models/igreja.dart';
import 'repository.dart';
import 'store/doc_store.dart';

/// Dados de exemplo do modo demonstração (nomes fictícios).
Future<void> seedDemo(DocStore store, DateTime now) async {
  final today = dateOnly(now);
  final writes = <DocWrite>[
    DocWrite('config/app', {'bootstrappedAt': nowIso()}),
    DocWrite('config/igreja', {
      ...DadosIniciais.igreja.toMap(),
      'phone': '912000000',
      'email': 'secretaria@exemplo.pt',
    }),
    DocWrite('config/pg', {...DadosIniciais.pg.toMap(), 'contatoTelefone': '912000003'}),
    for (final g in DadosIniciais.grupos) DocWrite('grupos/${g.id}', g.toMap(), merge: false),
    DocWrite('boletins/${ymd(domingoDe(today))}', {...boletimDemo(today).toMap(), 'publicado': true}, merge: false),
  ];

  // (id, nome, situação, ofício, nascimento, telefone, bairro, lat, lng, ministérios)
  const pessoas = [
    (
      'm-pastor',
      'Rev. André Lima',
      'comungante',
      'pastor',
      '1978-03-12',
      '912000001',
      'Rio Tinto',
      41.178,
      -8.559,
      <String>[],
    ),
    (
      'm-presb1',
      'Carlos Menezes',
      'comungante',
      'presbitero',
      '1965-07-02',
      '912000002',
      'Gondomar',
      41.144,
      -8.532,
      <String>[],
    ),
    (
      'm-presb2',
      'Paulo Ribeiro',
      'comungante',
      'presbitero',
      '1970-11-20',
      '912000003',
      'Paranhos',
      41.172,
      -8.601,
      <String>[],
    ),
    (
      'm-diac1',
      'João Batista Souza',
      'comungante',
      'diacono',
      '1982-01-15',
      '912000004',
      'Vila Nova de Gaia',
      41.124,
      -8.611,
      <String>[],
    ),
    (
      'm-diac2',
      'Pedro Almeida',
      'comungante',
      'diacono',
      '1988-05-30',
      '912000005',
      'Maia',
      41.235,
      -8.620,
      <String>[],
    ),
    (
      'm-diac3',
      'Marcos Oliveira',
      'comungante',
      'diacono',
      '1975-09-09',
      '912000006',
      'Valongo',
      41.189,
      -8.498,
      <String>[],
    ),
    (
      'm-diac4',
      'Lucas Ferreira',
      'comungante',
      'diacono',
      '1990-12-01',
      '912000007',
      'Ermesinde',
      41.217,
      -8.553,
      <String>[],
    ),
    (
      'm-diac5',
      'Tiago Nascimento',
      'comungante',
      'diacono',
      '1985-04-18',
      '912000008',
      'Campanhã',
      41.150,
      -8.585,
      <String>[],
    ),
    (
      'm-aux1',
      'Daniel Costa',
      'comungante',
      null,
      '1995-08-08',
      '912000009',
      'Matosinhos',
      41.182,
      -8.689,
      ['Diaconia'],
    ),
    (
      'm-aux2',
      'Rafael Martins',
      'comungante',
      null,
      '1993-02-25',
      '912000010',
      'São Mamede de Infesta',
      41.198,
      -8.611,
      ['Diaconia', 'Som'],
    ),
    (
      'm-maria',
      'Maria Aparecida Santos',
      'comungante',
      null,
      '1958-06-14',
      '912000011',
      'Baixa do Porto',
      41.149,
      -8.611,
      ['SAF', 'Intercessão'],
    ),
    (
      'm-ana',
      'Ana Paula Rocha',
      'comungante',
      null,
      '1992-10-03',
      '912000012',
      'Rio Tinto',
      41.181,
      -8.552,
      ['Louvor', 'EBD'],
    ),
    ('m-julia', 'Júlia Carvalho', 'naoComungante', null, '2014-03-21', null, 'Gondomar', 41.144, -8.532, ['Infantil']),
    ('m-renato', 'Renato Gomes', 'congregado', null, '1987-07-29', '912000014', 'Fânzeres', 41.170, -8.528, <String>[]),
    ('m-sara', 'Sara Lopes', 'visitante', null, '1999-11-11', '912000015', 'Bonfim', 41.147, -8.596, <String>[]),
  ];
  for (final (id, name, sit, ofi, birth, phone, bairro, lat, lng, mins) in pessoas) {
    // Aniversário de alguém nesta semana, para aparecer no Início.
    final b = id == 'm-maria' ? '1958-${ymd(addDays(today, 2)).substring(5)}' : birth;
    writes.add(
      DocWrite('${Col.members}/$id', {
        'name': name,
        'situacao': sit,
        'oficio': ofi,
        'birthDate': b,
        'phone': phone,
        'email': phone == null ? null : '${id.substring(2)}@exemplo.pt',
        'address': 'Rua de Exemplo, ${pessoas.indexWhere((p) => p.$1 == id) * 10 + 15} · $bairro, Porto',
        'neighborhood': '$bairro · Porto',
        'lat': lat,
        'lng': lng,
        'ministries': mins,
        'diaconia': ofi == 'diacono' || mins.contains('Diaconia'),
        'family': name.split(' ').last == 'Santos' ? 'Família Santos' : null,
        'maritalStatus': ofi != null ? 'Casado(a)' : null,
        'admissionMode': sit == 'comungante' ? 'Profissão de fé' : null,
        'updatedAt': nowIso(),
      }, merge: false),
    );
  }

  // Contas de demonstração, uma por perfil, ligadas a um cadastro.
  const contas = {
    AppRole.admin: null,
    AppRole.pastor: 'm-pastor',
    AppRole.presbitero: 'm-presb1',
    AppRole.liderDiaconia: 'm-diac1',
    AppRole.diacono: 'm-diac2',
    AppRole.membro: 'm-maria',
  };
  for (final e in contas.entries) {
    writes.add(
      DocWrite('${Col.users}/${DemoAuthService.uidFor(e.key)}', {
        'name': 'Demo · ${e.key.label}',
        'email': '${e.key.name}@demo.icppv',
        'role': e.key.name,
        'memberId': e.value,
      }, merge: false),
    );
  }

  // Programação semanal (a mesma da configuração inicial) + atividades de exemplo.
  final semana = [
    ...DadosIniciais.programacao,
    (3, '20:30', '21:30', 'Estudo bíblico online', Categoria.estudo, 'Zoom'),
    (6, '17:00', '19:00', 'Mocidade', Categoria.sociedade, 'Salão'),
  ];
  for (final (i, (wd, t, end, title, cat, place)) in semana.indexed) {
    writes.add(
      DocWrite('${Col.weekly}/w$i', {
        'weekday': wd,
        'time': t,
        'endTime': end,
        'title': title,
        'categoria': cat.name,
        'place': place,
        'active': true,
      }, merge: false),
    );
  }

  // Eventos: um nesta semana, um daqui a três semanas (com inscrições e organização).
  final sabado = addDays(weekStart(today), 5);
  final retiro = addDays(today, 21);
  writes
    ..add(
      DocWrite('${Col.events}/e-ceia', {
        'title': 'Almoço de comunhão',
        'start': localIso(DateTime(sabado.year, sabado.month, sabado.day, 12)),
        'end': localIso(DateTime(sabado.year, sabado.month, sabado.day, 15)),
        'place': 'Salão social',
        'categoria': Categoria.social.name,
        'status': EventoStatus.confirmado.name,
        'published': true,
        'registration': true,
        'capacity': 80,
        'price': 'Cada família traz um prato',
        'responsible': 'SAF',
        'createdAt': nowIso(),
      }, merge: false),
    )
    ..add(
      DocWrite('${Col.events}/e-retiro', {
        'title': 'Retiro de casais',
        'description': 'Fim de semana de comunhão e estudo sobre a família cristã.',
        'start': localIso(DateTime(retiro.year, retiro.month, retiro.day, 8)),
        'end': localIso(DateTime(retiro.year, retiro.month, retiro.day + 1, 17)),
        'place': 'Quinta de exemplo · Gerês',
        'categoria': Categoria.retiro.name,
        'status': EventoStatus.planejamento.name,
        'published': true,
        'registration': true,
        'capacity': 40,
        'deadline': ymd(addDays(today, 14)),
        'price': '350 € por casal',
        'responsible': 'Presb. Carlos Menezes',
        'createdAt': nowIso(),
      }, merge: false),
    )
    ..addAll([
      for (final (i, (t, who, d, done)) in [
        ('Reservar o sítio', 'Carlos', -3, true),
        ('Definir preletor e tema', 'Rev. André', 2, false),
        ('Abrir inscrições no app', 'Secretaria', 0, true),
        ('Comprar materiais e lembranças', 'Ana Paula', 10, false),
        ('Organizar transporte (caronas)', 'Pedro', 15, false),
      ].indexed)
        DocWrite('${Col.tasks('e-retiro')}/t$i', {
          'title': t,
          'assignee': who,
          'due': ymd(addDays(today, d)),
          'done': done,
        }, merge: false),
      for (final (i, (desc, rec, plan, act)) in [
        ('Aluguel do sítio', false, 6000.0, 3000.0),
        ('Alimentação', false, 4200.0, null),
        ('Materiais', false, 600.0, null),
        ('Inscrições (20 casais)', true, 7000.0, 2450.0),
        ('Oferta da igreja', true, 3000.0, null),
      ].indexed)
        DocWrite('${Col.budget('e-retiro')}/b$i', {
          'description': desc,
          'receita': rec,
          'planned': plan,
          'actual': act,
        }, merge: false),
      for (final (i, n) in ['Carlos Menezes', 'Pedro Almeida', 'Ana Paula Rocha'].indexed)
        DocWrite('${Col.registrations('e-retiro')}/demo-r$i', {
          'name': n,
          'guests': 1,
          'createdAt': nowIso(),
        }, merge: false),
    ]);

  // Horários do pastor nesta semana e na próxima (terça e quinta, 17h às 21h).
  for (final w in [0, 7]) {
    for (final wd in [2, 4]) {
      final d = addDays(weekStart(today), w + wd - 1);
      writes.add(
        DocWrite('${Col.availability}/a$w$wd', {
          'start': localIso(DateTime(d.year, d.month, d.day, 17)),
          'end': localIso(DateTime(d.year, d.month, d.day, 21)),
        }, merge: false),
      );
    }
  }

  // Vídeos da semana e avisos.
  final domingo = addDays(weekStart(today), -1);
  writes
    ..add(
      DocWrite('${Col.videos}/v1', {
        'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'title': 'Culto de domingo · exemplo',
        'date': ymd(domingo),
        'tipo': 'culto',
        'speaker': 'Rev. André Lima',
        'bibleText': 'Atos 13.1-12',
      }, merge: false),
    )
    ..add(
      DocWrite('${Col.videos}/v2', {
        'url': 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
        'title': 'Estudo bíblico de quarta · exemplo',
        'date': ymd(addDays(domingo, -4)),
        'tipo': 'estudo',
        'bibleText': 'Atos 12',
      }, merge: false),
    )
    ..add(
      DocWrite('${Col.avisos}/av1', {
        'title': 'Santa Ceia no próximo domingo',
        'body': 'Prepare o coração. Membros comungantes participam; visitantes são bem-vindos ao culto.',
        'pinned': true,
        'author': 'Conselho',
        'createdAt': nowIso(),
      }, merge: false),
    )
    ..add(
      DocWrite('${Col.oracao}/o1', {
        'text': 'Pela saúde da irmã Maria, que fará uma cirurgia na quinta.',
        'authorUid': DemoAuthService.uidFor(AppRole.membro),
        'authorName': 'Maria Aparecida Santos',
        'anonymous': false,
        'private': false,
        'answered': false,
        'praying': const <String>[],
        'createdAt': nowIso(),
      }, merge: false),
    );

  await store.batch(writes);
}
