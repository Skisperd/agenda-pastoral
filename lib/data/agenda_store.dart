import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../domain/scheduler.dart';

/// Estado da agenda visto pelas telas.
///
/// Há duas implementações: [MemoryAgendaStore] (demonstração, sem internet)
/// e `FirestoreAgendaStore` (dados reais no Firebase).
abstract class AgendaStore extends ChangeNotifier {
  AgendaStore({this.scheduler = const Scheduler(), DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final Scheduler scheduler;
  final DateTime Function() clock;

  /// Membros que aparecem no seletor de "login" do modo demonstração.
  /// Vazio no modo Firebase, onde o membro é quem fez login.
  List<Member> get members => const [];

  List<AvailabilityWindow> get windows;

  /// Visitas que o usuário atual pode ver (todas para o pastor, as próprias para o membro).
  List<Visit> get visits;

  /// Ocupação da agenda usada no cálculo de deslocamento. Para o membro, contém
  /// só horário, bairro e coordenada aproximada das visitas dos outros.
  List<Visit> get busy;

  List<PastorNotification> get notifications;

  int get unreadCount => notifications.where((n) => !n.read).length;

  /// Dias (a partir de hoje) em que o pastor liberou atendimento.
  List<DateTime> get openDays {
    final today = dateOnly(clock());
    final days = <DateTime>{};
    for (final w in windows) {
      final d = dateOnly(w.start);
      if (!d.isBefore(today)) days.add(d);
    }
    return days.toList()..sort();
  }

  List<SlotOption> slotsFor(Member member, DateTime day) {
    final now = clock();
    return scheduler
        .slotsFor(member: member, day: day, windows: windows, visits: busy)
        .where((s) => s.start.isAfter(now))
        .toList();
  }

  List<Visit> visitsOf(Member member) =>
      visits.where((v) => v.member.id == member.id && v.isActive).toList();

  // ---- Pastor ----
  Future<void> addWindow(DateTime start, DateTime end);
  Future<void> removeWindow(String id);

  /// Copia as janelas da semana de [weekStart] para a semana seguinte.
  Future<int> copyWeekToNext(DateTime weekStart);
  Future<void> setVisitStatus(String visitId, VisitStatus status);
  Future<void> markNotificationsRead();

  // ---- Membro ----

  /// Reserva o horário. Revalida a regra de deslocamento antes de gravar e
  /// lança [StateError] com o motivo se o horário não couber mais.
  Future<Visit> book(Member member, SlotOption slot);
  Future<void> cancel(Visit visit);

  /// Janelas que caem na semana iniciada em [weekStart].
  @protected
  List<AvailabilityWindow> windowsOfWeek(DateTime weekStart) {
    final from = dateOnly(weekStart);
    final to = from.add(const Duration(days: 7));
    return windows.where((w) => !w.start.isBefore(from) && w.start.isBefore(to)).toList();
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static void checkWindow(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      throw ArgumentError('O horário final precisa ser depois do inicial.');
    }
  }
}

/// Implementação em memória, usada no modo demonstração e nos testes.
class MemoryAgendaStore extends AgendaStore {
  MemoryAgendaStore({
    required this.members,
    List<AvailabilityWindow> windows = const [],
    List<Visit> visits = const [],
    super.scheduler,
    super.clock,
  }) : _windows = [...windows],
       _visits = [...visits];

  @override
  final List<Member> members;

  final List<AvailabilityWindow> _windows;
  final List<Visit> _visits;
  final List<PastorNotification> _notifications = [];
  int _nextId = 1000;

  @override
  List<AvailabilityWindow> get windows =>
      List.unmodifiable(_windows..sort((a, b) => a.start.compareTo(b.start)));

  @override
  List<Visit> get visits => List.unmodifiable(_visits..sort((a, b) => a.start.compareTo(b.start)));

  @override
  List<Visit> get busy => visits;

  @override
  List<PastorNotification> get notifications => List.unmodifiable(_notifications.reversed);

  @override
  Future<void> addWindow(DateTime start, DateTime end) async {
    AgendaStore.checkWindow(start, end);
    _windows.add(AvailabilityWindow(id: _newId(), start: start, end: end));
    notifyListeners();
  }

  @override
  Future<void> removeWindow(String id) async {
    _windows.removeWhere((w) => w.id == id);
    notifyListeners();
  }

  @override
  Future<int> copyWeekToNext(DateTime weekStart) async {
    final source = windowsOfWeek(weekStart);
    for (final w in source) {
      _windows.add(
        AvailabilityWindow(
          id: _newId(),
          start: w.start.add(const Duration(days: 7)),
          end: w.end.add(const Duration(days: 7)),
        ),
      );
    }
    notifyListeners();
    return source.length;
  }

  @override
  Future<void> setVisitStatus(String visitId, VisitStatus status) async {
    final i = _visits.indexWhere((v) => v.id == visitId);
    if (i < 0) return;
    _visits[i] = _visits[i].copyWith(status: status);
    notifyListeners();
  }

  @override
  Future<void> markNotificationsRead() async {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  @override
  Future<Visit> book(Member member, SlotOption slot) async {
    final reason = scheduler.blockedReason(
      member: member,
      start: slot.start,
      end: slot.end,
      visits: _visits,
    );
    if (reason != null) throw StateError(reason);
    final visit = Visit(id: _newId(), member: member, start: slot.start, end: slot.end);
    _visits.add(visit);
    _notifications.add(
      PastorNotification(
        id: _newId(),
        message: 'Nova visita: ${member.name} (${member.neighborhood})',
        createdAt: clock(),
      ),
    );
    notifyListeners();
    return visit;
  }

  @override
  Future<void> cancel(Visit visit) async {
    await setVisitStatus(visit.id, VisitStatus.cancelled);
    _notifications.add(
      PastorNotification(
        id: _newId(),
        message: '${visit.member.name} cancelou a visita',
        createdAt: clock(),
      ),
    );
    notifyListeners();
  }

  String _newId() => '${_nextId++}';
}
