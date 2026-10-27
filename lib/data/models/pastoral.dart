import '../../core/format.dart';
import '../../domain/models.dart';

/// Janela de atendimento liberada pelo pastor.
class Janela {
  const Janela({required this.id, required this.start, required this.end});

  final String id;
  final DateTime start;
  final DateTime end;

  Window get window => Window(start: start, end: end);

  factory Janela.fromMap(String id, Map<String, dynamic> m) =>
      Janela(id: id, start: parseLocal(m['start'] as String), end: parseLocal(m['end'] as String));

  Map<String, dynamic> toMap() => {'start': localIso(start), 'end': localIso(end)};
}

enum VisitaStatus {
  pendente('Aguardando confirmação'),
  confirmada('Confirmada'),
  realizada('Realizada'),
  cancelada('Cancelada');

  const VisitaStatus(this.label);
  final String label;

  static VisitaStatus parse(String? v) =>
      VisitaStatus.values.firstWhere((s) => s.name == v, orElse: () => VisitaStatus.pendente);

  bool get active => this != cancelada;
}

/// Visita pastoral. Só o pastor e quem marcou leem este documento.
class Visita {
  const Visita({
    required this.id,
    required this.memberId,
    required this.uid,
    required this.memberName,
    required this.start,
    required this.end,
    this.phone,
    this.address,
    this.neighborhood = '',
    this.lat = 0,
    this.lng = 0,
    this.reason,
    this.status = VisitaStatus.pendente,
    this.createdAt = '',
  });

  final String id;
  final String memberId;

  /// Conta que marcou (o próprio membro ou o pastor).
  final String uid;
  final String memberName;
  final String? phone;
  final String? address;
  final String neighborhood;
  final double lat;
  final double lng;
  final DateTime start;
  final DateTime end;

  /// Motivo informado (aconselhamento, enfermidade, bênção do lar…).
  final String? reason;
  final VisitaStatus status;
  final String createdAt;

  String get day => ymd(start);
  Stop get stop => Stop(start: start, end: end, neighborhood: neighborhood, location: GeoPoint(lat, lng));

  factory Visita.fromMap(String id, Map<String, dynamic> m) => Visita(
    id: id,
    memberId: m['memberId'] as String? ?? '',
    uid: m['uid'] as String? ?? '',
    memberName: m['memberName'] as String? ?? '',
    phone: m['phone'] as String?,
    address: m['address'] as String?,
    neighborhood: m['neighborhood'] as String? ?? '',
    lat: (m['lat'] as num?)?.toDouble() ?? 0,
    lng: (m['lng'] as num?)?.toDouble() ?? 0,
    start: parseLocal(m['start'] as String),
    end: parseLocal(m['end'] as String),
    reason: m['reason'] as String?,
    status: VisitaStatus.parse(m['status'] as String?),
    createdAt: m['createdAt'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    'uid': uid,
    'memberName': memberName,
    'phone': phone,
    'address': address,
    'neighborhood': neighborhood,
    'lat': lat,
    'lng': lng,
    'start': localIso(start),
    'end': localIso(end),
    'reason': reason,
    'status': status.name,
    'createdAt': createdAt,
  };
}

/// Ocupação de um dia (agenda/{yyyy-MM-dd}), sem nome nem endereço: é o que os
/// membros enxergam para calcular se o pastor chega a tempo. A coordenada é
/// arredondada (~1 km).
class SlotOcupado {
  const SlotOcupado({required this.visitId, required this.stop});

  final String visitId;
  final Stop stop;

  static double round(double v) => (v * 100).roundToDouble() / 100;

  factory SlotOcupado.fromMap(Map<String, dynamic> m) => SlotOcupado(
    visitId: m['visitId'] as String? ?? '',
    stop: Stop(
      start: parseLocal(m['start'] as String),
      end: parseLocal(m['end'] as String),
      neighborhood: m['neighborhood'] as String? ?? '',
      location: GeoPoint((m['lat'] as num?)?.toDouble() ?? 0, (m['lng'] as num?)?.toDouble() ?? 0),
    ),
  );

  Map<String, dynamic> toMap() => {
    'visitId': visitId,
    'start': localIso(stop.start),
    'end': localIso(stop.end),
    'neighborhood': stop.neighborhood,
    'lat': round(stop.location.lat),
    'lng': round(stop.location.lng),
  };
}

/// Aviso para o pastor (visita nova, cancelamento, pedido de oração reservado).
class Notificacao {
  const Notificacao({required this.id, required this.message, required this.createdAt, this.read = false, this.route});

  final String id;
  final String message;
  final String createdAt;
  final bool read;
  final String? route;

  factory Notificacao.fromMap(String id, Map<String, dynamic> m) => Notificacao(
    id: id,
    message: m['message'] as String? ?? '',
    createdAt: m['createdAt'] as String? ?? '',
    read: m['read'] == true,
    route: m['route'] as String?,
  );
}
