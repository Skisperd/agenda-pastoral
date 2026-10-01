import 'package:agenda_pastoral/data/seed.dart';
import 'package:agenda_pastoral/domain/models.dart';
import 'package:agenda_pastoral/firebase/firestore_agenda_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final joaoSul = demoMembers[0];
final mariaNorte = demoMembers[1];
final pedroSul = demoMembers[2];
final ana = demoMembers[3];
const pastor = Member(
  id: 'pastor',
  name: 'Pastor',
  phone: '',
  neighborhood: 'Igreja',
  location: GeoPoint(-23.55, -46.63),
);

DateTime clock() => DateTime(2026, 10, 5, 8);
DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 6, h, m);

void main() {
  late FakeFirebaseFirestore db;
  final stores = <FirestoreAgendaStore>[];

  FirestoreAgendaStore storeFor(Member m, {bool isPastor = false}) {
    final s = FirestoreAgendaStore(
      firestore: db,
      profile: UserProfile(member: m, isPastor: isPastor),
      clock: clock,
    );
    stores.add(s);
    return s;
  }

  setUp(() => db = FakeFirebaseFirestore());
  tearDown(() {
    for (final s in stores) {
      s.dispose();
    }
    stores.clear();
  });

  Future<void> bookAt(FirestoreAgendaStore store, Member m, int hour) async {
    await pumpEventQueue();
    final slot = store.slotsFor(m, at(0)).firstWhere((s) => s.start == at(hour));
    await store.book(m, slot);
    await pumpEventQueue();
  }

  test('janela criada pelo pastor aparece para o membro', () async {
    final p = storeFor(pastor, isPastor: true);
    final maria = storeFor(mariaNorte);
    await p.addWindow(at(17), at(22));
    await pumpEventQueue();
    expect(maria.openDays, [DateTime(2026, 10, 6)]);
    expect(maria.slotsFor(mariaNorte, at(0)), hasLength(9));
  });

  test('membro da Zona Norte vê o bloqueio causado pela visita na Zona Sul', () async {
    await storeFor(pastor, isPastor: true).addWindow(at(17), at(22));
    await bookAt(storeFor(joaoSul), joaoSul, 17);

    final maria = storeFor(mariaNorte);
    await pumpEventQueue();
    final slots = {
      for (final s in maria.slotsFor(mariaNorte, at(0))) s.start.hour * 60 + s.start.minute: s,
    };
    expect(slots[18 * 60]!.blockedReason, contains('Santo Amaro'));
    expect(slots[19 * 60]!.available, isFalse);
    expect(slots[19 * 60 + 30]!.available, isTrue);
  });

  test('agenda pública não expõe nome, telefone nem endereço exato', () async {
    await storeFor(pastor, isPastor: true).addWindow(at(17), at(22));
    await bookAt(storeFor(joaoSul), joaoSul, 17);

    final day = await db.collection('agenda').doc('2026-10-06').get();
    final slot = (day['slots'] as List).single as Map;
    expect(slot.keys, unorderedEquals(['visitId', 'start', 'end', 'neighborhood', 'area']));
    expect(slot['area'].latitude, -23.65);
    expect(slot['area'].longitude, -46.71);
  });

  test('segundo membro não consegue pegar o mesmo horário', () async {
    await storeFor(pastor, isPastor: true).addWindow(at(17), at(22));
    final pedro = storeFor(pedroSul);
    final anaStore = storeFor(ana);
    await pumpEventQueue();
    // Os dois carregaram a agenda quando 18h ainda estava livre.
    final slotPedro = pedro.slotsFor(pedroSul, at(0)).firstWhere((s) => s.start == at(18));
    final slotAna = anaStore.slotsFor(ana, at(0)).firstWhere((s) => s.start == at(18));

    await pedro.book(pedroSul, slotPedro);
    await expectLater(anaStore.book(ana, slotAna), throwsStateError);
    expect((await db.collection('visits').get()).docs, hasLength(1));
  });

  test('pastor recebe a notificação, marca como lida e confirma', () async {
    final p = storeFor(pastor, isPastor: true);
    await p.addWindow(at(17), at(22));
    await bookAt(storeFor(pedroSul), pedroSul, 18);

    expect(p.unreadCount, 1);
    expect(p.notifications.single.message, contains('Irmão Pedro'));
    await p.markNotificationsRead();
    await pumpEventQueue();
    expect(p.unreadCount, 0);

    final visit = p.visits.single;
    expect(visit.member.phone, pedroSul.phone);
    await p.setVisitStatus(visit.id, VisitStatus.confirmed);
    await pumpEventQueue();
    expect(p.visits.single.status, VisitStatus.confirmed);
  });

  test('membro só enxerga as próprias visitas', () async {
    await storeFor(pastor, isPastor: true).addWindow(at(17), at(22));
    await bookAt(storeFor(joaoSul), joaoSul, 17);
    final maria = storeFor(mariaNorte);
    await bookAt(maria, mariaNorte, 20);
    expect(maria.visits.map((v) => v.member.id), [mariaNorte.id]);
  });

  test('cancelar libera o horário e avisa o pastor', () async {
    final p = storeFor(pastor, isPastor: true);
    await p.addWindow(at(17), at(22));
    final joao = storeFor(joaoSul);
    await bookAt(joao, joaoSul, 17);

    await joao.cancel(joao.visits.single);
    await pumpEventQueue();
    expect(joao.visitsOf(joaoSul), isEmpty);

    final maria = storeFor(mariaNorte);
    await pumpEventQueue();
    expect(maria.slotsFor(mariaNorte, at(0)).every((s) => s.available), isTrue);
    expect(p.notifications.first.message, contains('cancelou'));
  });

  test('pastor recusar também libera o horário', () async {
    final p = storeFor(pastor, isPastor: true);
    await p.addWindow(at(17), at(22));
    await bookAt(storeFor(joaoSul), joaoSul, 17);

    await p.setVisitStatus(p.visits.single.id, VisitStatus.cancelled);
    final day = await db.collection('agenda').doc('2026-10-06').get();
    expect(day['slots'], isEmpty);
  });

  test('repetir a semana copia as janelas para 7 dias depois', () async {
    final p = storeFor(pastor, isPastor: true);
    await p.addWindow(at(17), at(22));
    await pumpEventQueue();
    expect(await p.copyWeekToNext(DateTime(2026, 10, 5)), 1);
    await pumpEventQueue();
    expect(p.openDays, [DateTime(2026, 10, 6), DateTime(2026, 10, 13)]);
  });
}
