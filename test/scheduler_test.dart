import 'package:agenda_pastoral/domain/models.dart';
import 'package:agenda_pastoral/domain/scheduler.dart';
import 'package:agenda_pastoral/domain/travel_time.dart';
import 'package:flutter_test/flutter_test.dart';

// Coordenadas aproximadas de bairros de São Paulo.
const santoAmaro = GeoPoint(-23.6544, -46.7095);
const santana = GeoPoint(-23.5025, -46.6253);
const campoBelo = GeoPoint(-23.6260, -46.6700);
const tatuape = GeoPoint(-23.5400, -46.5760);

DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 6, h, m);

void main() {
  const scheduler = Scheduler();
  final windows = [Window(start: at(17), end: at(22))];
  final visitaSul = Stop(start: at(17), end: at(18), neighborhood: 'Santo Amaro', location: santoAmaro);

  bool livre(GeoPoint p, int h, [int min = 0]) => scheduler
      .slotsFor(location: p, day: at(0), windows: windows, visits: [visitaSul])
      .firstWhere((s) => s.start == at(h, min))
      .available;

  test('estimativa Zona Sul → Zona Norte fica em torno de 1 hora', () {
    final t = const StraightLineTravelEstimator().estimate(santoAmaro, santana);
    expect(t.inMinutes, inInclusiveRange(55, 75));
  });

  test('gera horários de 30 em 30 min dentro da janela, sem passar do fim', () {
    final slots = scheduler.slotsFor(location: tatuape, day: at(0), windows: windows, visits: const []);
    expect(slots.first.start, at(17));
    expect(slots.last.end, at(22));
    expect(slots, hasLength(9)); // 17:00 ... 21:00
  });

  test('irmã da Zona Norte não pode marcar logo depois da visita na Zona Sul', () {
    expect(livre(santana, 18), isFalse);
    expect(livre(santana, 19), isFalse);
    expect(livre(santana, 19, 30), isTrue);
  });

  test('irmão vizinho na Zona Sul consegue marcar mais cedo', () {
    expect(livre(campoBelo, 18), isFalse); // trajeto + 10 min de folga
    expect(livre(campoBelo, 18, 30), isTrue);
  });

  test('horário sobreposto é bloqueado para todos', () {
    expect(livre(campoBelo, 17), isFalse);
    expect(livre(campoBelo, 17, 30), isFalse);
  });

  test('bloqueia quando não daria tempo de ir para a visita SEGUINTE', () {
    final visitaNorte = Stop(start: at(20), end: at(21), neighborhood: 'Santana', location: santana);
    final reason = scheduler.blockedReason(
      location: santoAmaro,
      start: at(18, 30),
      end: at(19, 30),
      visits: [visitaNorte],
    );
    expect(reason, contains('visita das 20:00'));
    expect(scheduler.blockedReason(location: santoAmaro, start: at(17), end: at(18), visits: [visitaNorte]), isNull);
  });

  test('respeita o limite de visitas por dia', () {
    const s = Scheduler(settings: ScheduleSettings(maxVisitsPerDay: 1));
    expect(s.blockedReason(location: campoBelo, start: at(21), end: at(22), visits: [visitaSul]), contains('Limite'));
  });

  test('horários que já passaram aparecem bloqueados', () {
    final slots = scheduler.slotsFor(
      location: tatuape,
      day: at(0),
      windows: windows,
      visits: const [],
      now: at(18, 10),
    );
    expect(slots.where((s) => s.start.isBefore(at(18, 10))).every((s) => !s.available), isTrue);
    expect(slots.firstWhere((s) => s.start == at(18, 30)).available, isTrue);
  });

  test('ajustes do pastor são lidos e gravados', () {
    final s = ScheduleSettings.fromMap(
      const ScheduleSettings(maxVisitsPerDay: 2, buffer: Duration(minutes: 20)).toMap(),
    );
    expect(s.maxVisitsPerDay, 2);
    expect(s.buffer.inMinutes, 20);
    expect(ScheduleSettings.fromMap(null).visitDuration, const Duration(hours: 1));
  });
}
