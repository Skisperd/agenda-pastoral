import '../core/format.dart';
import '../core/roles.dart';
import 'auth/auth_service.dart';
import 'models/igreja.dart';
import 'repository.dart';
import 'store/doc_store.dart';

/// Dados de exemplo do modo demonstração (nomes fictícios).
Future<void> seedDemo(DocStore store, DateTime now) async {
  final today = dateOnly(now);
  final writes = <DocWrite>[
    DocWrite('config/app', {'bootstrappedAt': nowIso()}),
    const DocWrite('config/igreja', {
      'name': 'Igreja Cristã Presbiteriana Pedras Vivas',
      'shortName': 'Pedras Vivas',
      'address': 'Rua Exemplo, 100 · São Paulo',
      'phone': '11999990000',
      'email': 'secretaria@exemplo.org',
      'youtube': 'https://www.youtube.com/@exemplo',
    }),
  ];

  // (id, nome, situação, ofício, nascimento, telefone, bairro, lat, lng, ministérios)
  const pessoas = [
    (
      'm-pastor',
      'Rev. André Lima',
      'comungante',
      'pastor',
      '1978-03-12',
      '11990000001',
      'Vila Mariana',
      -23.589,
      -46.634,
      <String>[],
    ),
    (
      'm-presb1',
      'Carlos Menezes',
      'comungante',
      'presbitero',
      '1965-07-02',
      '11990000002',
      'Moema',
      -23.601,
      -46.665,
      <String>[],
    ),
    (
      'm-presb2',
      'Paulo Ribeiro',
      'comungante',
      'presbitero',
      '1970-11-20',
      '11990000003',
      'Saúde',
      -23.618,
      -46.639,
      <String>[],
    ),
    (
      'm-diac1',
      'João Batista Souza',
      'comungante',
      'diacono',
      '1982-01-15',
      '11990000004',
      'Santo Amaro',
      -23.654,
      -46.709,
      <String>[],
    ),
    (
      'm-diac2',
      'Pedro Almeida',
      'comungante',
      'diacono',
      '1988-05-30',
      '11990000005',
      'Campo Belo',
      -23.623,
      -46.668,
      <String>[],
    ),
    (
      'm-diac3',
      'Marcos Oliveira',
      'comungante',
      'diacono',
      '1975-09-09',
      '11990000006',
      'Jabaquara',
      -23.646,
      -46.641,
      <String>[],
    ),
    (
      'm-diac4',
      'Lucas Ferreira',
      'comungante',
      'diacono',
      '1990-12-01',
      '11990000007',
      'Ipiranga',
      -23.587,
      -46.606,
      <String>[],
    ),
    (
      'm-diac5',
      'Tiago Nascimento',
      'comungante',
      'diacono',
      '1985-04-18',
      '11990000008',
      'Cursino',
      -23.616,
      -46.617,
      <String>[],
    ),
    (
      'm-aux1',
      'Daniel Costa',
      'comungante',
      null,
      '1995-08-08',
      '11990000009',
      'Vila Clementino',
      -23.598,
      -46.645,
      ['Diaconia'],
    ),
    (
      'm-aux2',
      'Rafael Martins',
      'comungante',
      null,
      '1993-02-25',
      '11990000010',
      'Brooklin',
      -23.611,
      -46.689,
      ['Diaconia', 'Som'],
    ),
    (
      'm-maria',
      'Maria Aparecida Santos',
      'comungante',
      null,
      '1958-06-14',
      '11990000011',
      'Santana',
      -23.502,
      -46.625,
      ['SAF', 'Intercessão'],
    ),
    (
      'm-ana',
      'Ana Paula Rocha',
      'comungante',
      null,
      '1992-10-03',
      '11990000012',
      'Pinheiros',
      -23.567,
      -46.693,
      ['Louvor', 'EBD'],
    ),
    ('m-julia', 'Júlia Carvalho', 'naoComungante', null, '2014-03-21', null, 'Moema', -23.601, -46.665, ['Infantil']),
    (
      'm-renato',
      'Renato Gomes',
      'congregado',
      null,
      '1987-07-29',
      '11990000014',
      'Tatuapé',
      -23.540,
      -46.576,
      <String>[],
    ),
    ('m-sara', 'Sara Lopes', 'visitante', null, '1999-11-11', '11990000015', 'Liberdade', -23.558, -46.635, <String>[]),
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
        'email': phone == null ? null : '${id.substring(2)}@exemplo.org',
        'address': 'Rua de Exemplo, ${pessoas.indexWhere((p) => p.$1 == id) * 10 + 15} · $bairro, São Paulo',
        'neighborhood': '$bairro · São Paulo',
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

  // Programação semanal.
  const semana = [
    (7, '09:00', '10:15', 'Escola Bíblica Dominical', 'ebd', 'Salas de EBD'),
    (7, '10:30', '12:00', 'Culto de adoração (manhã)', 'culto', 'Templo'),
    (7, '18:00', '19:30', 'Culto de adoração (noite)', 'culto', 'Templo'),
    (3, '20:00', '21:15', 'Culto de oração e estudo bíblico', 'oracao', 'Templo'),
    (5, '20:00', '21:30', 'Ensaio do louvor', 'ensaio', 'Templo'),
    (6, '17:00', '19:00', 'UMP · Mocidade', 'sociedade', 'Salão social'),
  ];
  for (final (i, (wd, t, end, title, cat, place)) in semana.indexed) {
    writes.add(
      DocWrite('${Col.weekly}/w$i', {
        'weekday': wd,
        'time': t,
        'endTime': end,
        'title': title,
        'categoria': cat,
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
        'place': 'Sítio de exemplo · Atibaia',
        'categoria': Categoria.retiro.name,
        'status': EventoStatus.planejamento.name,
        'published': true,
        'registration': true,
        'capacity': 40,
        'deadline': ymd(addDays(today, 14)),
        'price': r'R$ 350 por casal',
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
