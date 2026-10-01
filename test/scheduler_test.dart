import 'package:agenda_pastoral/data/seed.dart';
import 'package:agenda_pastoral/domain/models.dart';
import 'package:agenda_pastoral/domain/scheduler.dart';
import 'package:agenda_pastoral/domain/travel_time.dart';
import 'package:flutter_test/flutter_test.dart';

final joaoSul = demoMembers[0];
final mariaNorte = demoMembers[1];
final pedroSul = demoMembers[2];
final ana = demoMembers[3];

DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 6, h, m);

void main() {
  const scheduler = Scheduler();
  final windows = [AvailabilityWindow(id: 'w', start: at(17), end: at(22))];
  final visitaSul = Visit(id: 'v', member: joaoSul, start: at(17), end: at(18));

  bool livre(Member m, int h, [int min = 0]) => scheduler
      .slotsFor(member: m, day: at(0), windows: windows, visits: [visitaSul])
      .firstWhere((s) => s.start == at(h, min))
      .available;

  test('estimativa Zona Sul → Zona Norte fica em torno de 1 hora', () {
    final t = const StraightLineTravelEstimator().estimate(joaoSul.location, mariaNorte.location);
    expect(t.inMinutes, inInclusiveRange(55, 75));
  });

  test('gera horários de 30 em 30 min dentro da janela, sem passar do fim', () {
    final slots = scheduler.slotsFor(member: ana, day: at(0), windows: windows, visits: const []);
    expect(slots.first.start, at(17));
    expect(slots.last.end, at(22));
    expect(slots, hasLength(9)); // 17:00 ... 21:00
  });

  test('irmã da Zona Norte não pode marcar logo depois da visita na Zona Sul', () {
    expect(livre(mariaNorte, 18), isFalse);
    expect(livre(mariaNorte, 18, 30), isFalse);
    expect(livre(mariaNorte, 19), isFalse);
    expect(livre(mariaNorte, 19, 30), isTrue);
  });

  test('irmão vizinho na Zona Sul consegue marcar mais cedo', () {
    expect(livre(pedroSul, 18), isFalse); // 18 min de trajeto + 10 de folga
    expect(livre(pedroSul, 18, 30), isTrue);
  });

  test('horário sobreposto é bloqueado para todos', () {
    expect(livre(pedroSul, 17), isFalse);
    expect(livre(pedroSul, 17, 30), isFalse);
  });

  test('bloqueia quando não daria tempo de ir para a visita SEGUINTE', () {
    final visitaNorte = Visit(id: 'n', member: mariaNorte, start: at(20), end: at(21));
    final reason = scheduler.blockedReason(
      member: joaoSul,
      start: at(18, 30),
      end: at(19, 30),
      visits: [visitaNorte],
    );
    expect(reason, contains('visita das 20:00'));
    expect(
      scheduler.blockedReason(member: joaoSul, start: at(17), end: at(18), visits: [visitaNorte]),
      isNull,
    );
  });

  test('visitas canceladas não bloqueiam nada', () {
    final cancelada = visitaSul.copyWith(status: VisitStatus.cancelled);
    expect(
      scheduler.blockedReason(member: mariaNorte, start: at(18), end: at(19), visits: [cancelada]),
      isNull,
    );
  });

  test('respeita o limite de visitas por dia', () {
    const s = Scheduler(settings: ScheduleSettings(maxVisitsPerDay: 1));
    expect(
      s.blockedReason(member: pedroSul, start: at(21), end: at(22), visits: [visitaSul]),
      contains('Limite'),
    );
  });

  test('store recusa reserva que ficou inválida (dois irmãos ao mesmo tempo)', () async {
    final store = demoStore(clock: () => DateTime(2026, 10, 5, 8));
    final day = store.openDays.first;
    final slot = store.slotsFor(pedroSul, day).firstWhere((s) => s.available);
    await store.book(pedroSul, slot);
    await expectLater(store.book(ana, slot), throwsStateError);
    expect(store.unreadCount, 1);
  });

  test('pastor copia as janelas da semana para a seguinte', () async {
    final store = demoStore(clock: () => DateTime(2026, 10, 5, 8));
    final antes = store.windows.length;
    final copiadas = await store.copyWeekToNext(DateTime(2026, 10, 5));
    expect(copiadas, 2);
    expect(store.windows.length, antes + 2);
  });
}
