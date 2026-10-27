/// Tipos da regra de horários das visitas, independentes do banco.
library;

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;
}

/// Uma visita ocupando a agenda do pastor (de qualquer membro). Para o membro
/// só chegam o horário, o bairro e uma coordenada aproximada.
class Stop {
  const Stop({required this.start, required this.end, required this.neighborhood, required this.location});

  final DateTime start;
  final DateTime end;
  final String neighborhood;
  final GeoPoint location;
}

/// Janela de atendimento que o pastor libera (ex.: 06/10, das 17h às 22h).
class Window {
  const Window({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
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

  factory ScheduleSettings.fromMap(Map<String, dynamic>? m) => ScheduleSettings(
    visitDuration: Duration(minutes: (m?['visitMinutes'] as num?)?.toInt() ?? 60),
    buffer: Duration(minutes: (m?['bufferMinutes'] as num?)?.toInt() ?? 10),
    slotStep: Duration(minutes: (m?['stepMinutes'] as num?)?.toInt() ?? 30),
    maxVisitsPerDay: (m?['maxPerDay'] as num?)?.toInt() ?? 4,
  );

  Map<String, dynamic> toMap() => {
    'visitMinutes': visitDuration.inMinutes,
    'bufferMinutes': buffer.inMinutes,
    'stepMinutes': slotStep.inMinutes,
    'maxPerDay': maxVisitsPerDay,
  };
}
