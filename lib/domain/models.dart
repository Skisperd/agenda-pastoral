/// Modelos de domínio da agenda pastoral.
library;

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;
}

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.neighborhood,
    required this.location,
  });

  final String id;
  final String name;
  final String phone;

  /// Bairro/região exibido para o pastor (ex.: "Santana · Zona Norte").
  final String neighborhood;

  /// Coordenadas do endereço. No app real vêm da geocodificação do endereço.
  final GeoPoint location;
}

/// Janela de atendimento que o pastor libera (ex.: 06/10, das 17h às 22h).
class AvailabilityWindow {
  const AvailabilityWindow({required this.id, required this.start, required this.end});

  final String id;
  final DateTime start;
  final DateTime end;
}

enum VisitStatus { pending, confirmed, cancelled }

/// Perfil de quem fez login (modo Firebase).
class UserProfile {
  const UserProfile({required this.member, required this.isPastor});

  final Member member;
  final bool isPastor;
}

class Visit {
  const Visit({
    required this.id,
    required this.member,
    required this.start,
    required this.end,
    this.status = VisitStatus.pending,
  });

  final String id;
  final Member member;
  final DateTime start;
  final DateTime end;
  final VisitStatus status;

  bool get isActive => status != VisitStatus.cancelled;

  Visit copyWith({VisitStatus? status}) =>
      Visit(id: id, member: member, start: start, end: end, status: status ?? this.status);
}

/// Parâmetros que o pastor ajusta.
class ScheduleSettings {
  const ScheduleSettings({
    this.visitDuration = const Duration(hours: 1),
    this.buffer = const Duration(minutes: 10),
    this.slotStep = const Duration(minutes: 30),
    this.maxVisitsPerDay = 4,
  });

  /// Duração de cada visita.
  final Duration visitDuration;

  /// Folga somada ao deslocamento (trânsito, estacionar, atrasos).
  final Duration buffer;

  /// De quanto em quanto tempo os horários são oferecidos (17:00, 17:30...).
  final Duration slotStep;

  final int maxVisitsPerDay;
}

class PastorNotification {
  PastorNotification({
    required this.id,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  bool read;
}
