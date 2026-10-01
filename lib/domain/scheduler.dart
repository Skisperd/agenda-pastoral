import 'models.dart';
import 'travel_time.dart';

/// Um horário candidato para um membro, com o motivo caso esteja bloqueado.
class SlotOption {
  const SlotOption({required this.start, required this.end, this.blockedReason});

  final DateTime start;
  final DateTime end;
  final String? blockedReason;

  bool get available => blockedReason == null;
}

/// Regra central: quais horários cabem para ESTE membro, considerando as
/// janelas do pastor, as visitas já marcadas e o deslocamento entre elas.
class Scheduler {
  const Scheduler({
    this.settings = const ScheduleSettings(),
    this.travel = const StraightLineTravelEstimator(),
  });

  final ScheduleSettings settings;
  final TravelTimeEstimator travel;

  /// Todos os horários do [day] para [member], disponíveis ou não.
  List<SlotOption> slotsFor({
    required Member member,
    required DateTime day,
    required List<AvailabilityWindow> windows,
    required List<Visit> visits,
  }) {
    final slots = <SlotOption>[];
    final dayWindows = windows.where((w) => _sameDay(w.start, day)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    for (final window in dayWindows) {
      var start = window.start;
      while (!start.add(settings.visitDuration).isAfter(window.end)) {
        final end = start.add(settings.visitDuration);
        slots.add(
          SlotOption(
            start: start,
            end: end,
            blockedReason: blockedReason(member: member, start: start, end: end, visits: visits),
          ),
        );
        start = start.add(settings.slotStep);
      }
    }
    return slots;
  }

  /// Motivo pelo qual [member] não pode marcar de [start] a [end], ou `null`
  /// se pode. Também é usado para revalidar no momento da reserva.
  String? blockedReason({
    required Member member,
    required DateTime start,
    required DateTime end,
    required List<Visit> visits,
  }) {
    final sameDay = visits.where((v) => v.isActive && _sameDay(v.start, start)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final v in sameDay) {
      if (v.start.isBefore(end) && start.isBefore(v.end)) {
        return 'Horário já reservado';
      }
    }

    if (sameDay.length >= settings.maxVisitsPerDay) {
      return 'Limite de ${settings.maxVisitsPerDay} visitas no dia atingido';
    }

    final previous = sameDay.where((v) => !v.end.isAfter(start)).lastOrNull;
    if (previous != null) {
      final trip = travel.estimate(previous.member.location, member.location);
      final arrival = previous.end.add(trip).add(settings.buffer);
      if (arrival.isAfter(start)) {
        return 'O pastor sai de ${previous.member.neighborhood} às '
            '${_hhmm(previous.end)} e leva ~${trip.inMinutes} min até você';
      }
    }

    final next = sameDay.where((v) => !v.start.isBefore(end)).firstOrNull;
    if (next != null) {
      final trip = travel.estimate(member.location, next.member.location);
      final arrival = end.add(trip).add(settings.buffer);
      if (arrival.isAfter(next.start)) {
        return 'Não daria tempo de chegar à visita das ${_hhmm(next.start)} '
            'em ${next.member.neighborhood} (~${trip.inMinutes} min)';
      }
    }

    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
