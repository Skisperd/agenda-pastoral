import 'package:agenda_pastoral/core/format.dart';
import 'package:agenda_pastoral/core/roles.dart';
import 'package:agenda_pastoral/data/auth/auth_service.dart';
import 'package:agenda_pastoral/data/demo_seed.dart';
import 'package:agenda_pastoral/data/models/escala.dart';
import 'package:agenda_pastoral/data/models/igreja.dart';
import 'package:agenda_pastoral/data/models/pastoral.dart';
import 'package:agenda_pastoral/data/models/people.dart';
import 'package:agenda_pastoral/data/repository.dart';
import 'package:agenda_pastoral/data/store/memory_doc_store.dart';
import 'package:agenda_pastoral/domain/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const pedro = Membro(id: 'p', name: 'Pedro', neighborhood: 'Campo Belo', lat: -23.6260, lng: -46.6700);
const maria = Membro(id: 'm', name: 'Maria', neighborhood: 'Santana', lat: -23.5025, lng: -46.6253);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('cadastro de membros', () {
    test('ida e volta pelo banco preserva os campos', () {
      const m = Membro(
        id: 'x',
        name: 'João',
        oficio: Oficio.diacono,
        birthDate: '1980-02-03',
        ministries: ['Louvor'],
        funcoes: [FuncaoDiaconal.ofertorio],
      );
      final back = Membro.fromMap('x', m.toMap());
      expect(back.oficio, Oficio.diacono);
      expect(back.funcoes, [FuncaoDiaconal.ofertorio]);
      expect(back.servesDiaconia, isTrue);
      expect(m.toMap()['diaconia'], isTrue);
    });

    test('auxiliar com ministério Diaconia entra na escala; os outros não', () {
      expect(const Membro(id: 'a', name: 'A', ministries: ['Diaconia']).servesDiaconia, isTrue);
      expect(const Membro(id: 'b', name: 'B', ministries: ['Louvor']).servesDiaconia, isFalse);
    });

    test('a própria pessoa só altera campos de contato', () async {
      final store = MemoryDocStore();
      final repo = Repository(store);
      await store.set('members/x', {'name': 'X', 'situacao': 'comungante'});
      await repo.saveOwnMember('x', {'phone': '11999', 'situacao': 'pastor', 'oficio': 'pastor'});
      final d = (await store.getDoc('members/x'))!.data;
      expect(d['phone'], '11999');
      expect(d['situacao'], 'comungante');
      expect(d.containsKey('oficio'), isFalse);
    });

    test('quem se cadastra sozinho entra como visitante e fica vinculado', () async {
      final store = MemoryDocStore();
      await Repository(store).createOwnMember('uid1', const Membro(id: '', name: 'Nova', oficio: Oficio.pastor));
      final d = (await store.getDoc('members/uid1'))!.data;
      expect(d['situacao'], 'visitante');
      expect(d['oficio'], isNull);
      expect(d['selfRegistered'], isTrue);
      expect((await store.getDoc('users/uid1'))!.data['memberId'], 'uid1');
    });
  });

  group('contas', () {
    test('a primeira conta vira administradora; as seguintes aguardam', () async {
      final store = MemoryDocStore();
      final repo = Repository(store);
      await repo.ensureUser(const AuthUser(uid: 'a', email: 'a@x', name: 'A'));
      await repo.ensureUser(const AuthUser(uid: 'b', email: 'b@x', name: 'B'));
      expect((await store.getDoc('users/a'))!.data['role'], 'admin');
      expect((await store.getDoc('users/b'))!.data['role'], 'pending');
    });

    test('projeto da versão anterior: o pastor existente marca o início e ninguém novo vira admin', () async {
      final store = MemoryDocStore();
      await store.set('users/pastor', {'name': 'P', 'role': 'pastor'});
      final repo = Repository(store);
      await repo.ensureUser(const AuthUser(uid: 'pastor', email: 'p@x', name: 'P'));
      await repo.ensureUser(const AuthUser(uid: 'novo', email: 'n@x', name: 'N'));
      expect((await store.getDoc('users/novo'))!.data['role'], 'pending');
    });
  });

  group('agenda pastoral', () {
    final dia = DateTime(2026, 10, 6);
    DateTime at(int h, [int m = 0]) => DateTime(dia.year, dia.month, dia.day, h, m);

    test('reserva grava a visita, a ocupação anônima e avisa o pastor', () async {
      final store = MemoryDocStore();
      final repo = Repository(store);
      final id = await repo.bookVisit(
        member: pedro,
        uid: 'u-p',
        start: at(17),
        scheduler: const Scheduler(),
        reason: 'Aconselhamento',
      );
      final v = Visita.fromMap(id, (await store.getDoc('visits/$id'))!.data);
      expect(v.status, VisitaStatus.pendente);
      expect(v.end, at(18));
      final slot = ((await store.getDoc('agenda/2026-10-06'))!.data['slots'] as List).single as Map;
      expect(slot.containsKey('memberName'), isFalse, reason: 'ocupação não leva nome');
      expect(slot['lat'], -23.63, reason: 'coordenada arredondada');
      expect(await store.watchCollection('notifications').first, hasLength(1));
    });

    test('segunda reserva incompatível é recusada com o motivo', () async {
      final store = MemoryDocStore();
      final repo = Repository(store);
      await repo.bookVisit(member: pedro, uid: 'u-p', start: at(17), scheduler: const Scheduler());
      await expectLater(
        repo.bookVisit(member: maria, uid: 'u-m', start: at(18), scheduler: const Scheduler()),
        throwsA(isA<StateError>().having((e) => e.message, 'motivo', contains('Campo Belo'))),
      );
      expect(await store.watchCollection('visits').first, hasLength(1));
    });

    test('cancelar libera o horário', () async {
      final store = MemoryDocStore();
      final repo = Repository(store);
      final id = await repo.bookVisit(member: pedro, uid: 'u-p', start: at(17), scheduler: const Scheduler());
      final v = Visita.fromMap(id, (await store.getDoc('visits/$id'))!.data);
      await repo.cancelVisit(v, byPastor: false);
      expect((await store.getDoc('agenda/2026-10-06'))!.data['slots'], isEmpty);
      await repo.bookVisit(member: maria, uid: 'u-m', start: at(18), scheduler: const Scheduler());
    });

    test('sem endereço não marca', () async {
      final repo = Repository(MemoryDocStore());
      await expectLater(
        repo.bookVisit(
          member: const Membro(id: 'z', name: 'Z'),
          uid: 'z',
          start: at(17),
          scheduler: const Scheduler(),
        ),
        throwsStateError,
      );
    });

    test('repete as janelas na semana seguinte sem duplicar', () async {
      final store = MemoryDocStore();
      final repo = Repository(store);
      final seg = DateTime(2026, 10, 5);
      await repo.addWindow(at(17), at(21));
      await repo.addWindow(DateTime(2026, 10, 8, 17), DateTime(2026, 10, 8, 21));
      var all = await repo.watchWindows().first;
      expect(await repo.copyWeek(all, seg), 2);
      all = await repo.watchWindows().first;
      expect(all, hasLength(4));
      expect(await repo.copyWeek(all, seg), 0);
    });

    test('janela inválida é recusada', () {
      final repo = Repository(MemoryDocStore());
      expect(() => repo.addWindow(at(20), at(18)), throwsArgumentError);
    });
  });

  group('eventos', () {
    Inscricao i(String id, int guests, String at) => Inscricao(uid: id, name: id, guests: guests, createdAt: at);

    test('inscrições além das vagas vão para a lista de espera, por ordem de chegada', () {
      final (ok, wait) = splitWaitlist([i('c', 0, '3'), i('a', 1, '1'), i('b', 1, '2')], 4);
      expect(ok.map((x) => x.uid), ['a', 'b']);
      expect(wait.map((x) => x.uid), ['c']);
      final (all, none) = splitWaitlist([i('a', 5, '1')], null);
      expect((all.length, none.length), (1, 0));
    });

    test('orçamento soma previsto e realizado', () {
      final o = Orcamento(const [
        Lancamento(id: '1', description: 'Sítio', planned: 1000, actual: 500),
        Lancamento(id: '2', description: 'Inscrições', receita: true, planned: 1500, actual: 300),
      ]);
      expect(o.saldoPrevisto, 500);
      expect(o.saldoRealizado, -200);
    });

    test('atividade semanal cai no dia certo da semana', () {
      const p = Programacao(id: 'p', weekday: 7, time: '18:30', title: 'Culto');
      expect(p.on(DateTime(2026, 10, 26)), DateTime(2026, 11, 1, 18, 30));
    });

    test('inscrições abertas só até o prazo e para eventos publicados', () {
      final e = Evento(
        id: 'e',
        title: 'Retiro',
        start: DateTime(2026, 11, 20, 8),
        published: true,
        registration: true,
        deadline: '2026-11-10',
      );
      expect(e.registrationOpen(DateTime(2026, 11, 10)), isTrue);
      expect(e.registrationOpen(DateTime(2026, 11, 11)), isFalse);
    });
  });

  group('escala diaconal', () {
    test('lê e grava funções, nomes e respostas', () async {
      final store = MemoryDocStore();
      final repo = Repository(store);
      final id = await repo.saveEscala(
        const EscalaDiaconal(
          id: '',
          date: '2026-11-01',
          assignments: {
            FuncaoDiaconal.ofertorio: ['a'],
          },
          names: {'a': 'Ana'},
          published: true,
        ),
      );
      await repo.respondEscala(id, 'a', Resposta.recusado, note: 'viagem');
      final e = EscalaDiaconal.fromMap(id, (await store.getDoc('diaconia/$id'))!.data);
      expect(e.funcaoOf('a'), FuncaoDiaconal.ofertorio);
      expect(e.confirmations['a']!.status, Resposta.recusado);
      expect(e.names['a'], 'Ana');
    });
  });

  group('formatos', () {
    test('telefone, dinheiro e idade', () {
      expect(phoneDigits('(11) 98765-4321'), '5511987654321');
      expect(fmtPhone('11987654321'), '(11) 98765-4321');
      expect(parseMoney('1.234,50'), 1234.5);
      expect(ageOn('2000-10-28', DateTime(2026, 10, 27)), 25);
      expect(parseHhmm('19h30'), (19, 30));
      expect(localIso(DateTime(2026, 1, 2, 3, 4)), '2026-01-02T03:04');
    });
  });

  test('dados de demonstração carregam sem erro', () async {
    final store = MemoryDocStore();
    await seedDemo(store, DateTime(2026, 10, 27));
    expect(await store.watchCollection('members').first, hasLength(15));
    expect((await store.getDoc('users/${DemoAuthService.uidFor(AppRole.pastor)}'))!.data['memberId'], 'm-pastor');
  });
}
