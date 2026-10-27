import '../../core/roles.dart';

/// Conta de acesso ao app.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.memberId,
    this.unavailable = const [],
  });

  final String uid;
  final String name;
  final String email;
  final AppRole role;

  /// Cadastro de membro vinculado a esta conta ("meu cadastro", "minha escala").
  final String? memberId;

  /// Datas (yyyy-MM-dd) em que a pessoa avisou que não pode servir na escala.
  final List<String> unavailable;

  String get firstName => name.trim().split(' ').first;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
    uid: uid,
    name: m['name'] as String? ?? '',
    email: m['email'] as String? ?? '',
    role: AppRole.parse(m['role'] as String?),
    memberId: m['memberId'] as String?,
    unavailable: List<String>.from(m['unavailable'] as List? ?? const [])..sort(),
  );
}

/// Cadastro de uma pessoa no rol da igreja (pode ou não ter conta no app).
class Membro {
  const Membro({
    required this.id,
    required this.name,
    this.situacao = Situacao.comungante,
    this.oficio,
    this.birthDate,
    this.phone,
    this.email,
    this.address,
    this.neighborhood,
    this.lat,
    this.lng,
    this.maritalStatus,
    this.weddingDate,
    this.family,
    this.baptismDate,
    this.professionDate,
    this.admissionDate,
    this.admissionMode,
    this.ministries = const [],
    this.funcoes = const [],
    this.selfRegistered = false,
    this.updatedAt,
  });

  final String id;
  final String name;
  final Situacao situacao;
  final Oficio? oficio;

  /// yyyy-MM-dd
  final String? birthDate;
  final String? phone;
  final String? email;
  final String? address;

  /// Bairro/região, mostrado na agenda pastoral.
  final String? neighborhood;

  /// Coordenadas do endereço (para calcular o deslocamento do pastor).
  final double? lat;
  final double? lng;
  final String? maritalStatus;
  final String? weddingDate;

  /// Nome da família, para agrupar ("Família Oliveira").
  final String? family;
  final String? baptismDate;
  final String? professionDate;
  final String? admissionDate;

  /// Batismo, profissão de fé, transferência, jurisdição…
  final String? admissionMode;

  /// Ministérios em que serve (louvor, EBD, diaconia, mídia…).
  final List<String> ministries;

  /// Funções da escala diaconal que a pessoa prefere/sabe fazer (vazio = todas).
  final List<FuncaoDiaconal> funcoes;

  /// Criado pela própria pessoa (ainda não conferido pela secretaria).
  final bool selfRegistered;
  final String? updatedAt;

  bool get hasLocation => lat != null && lng != null;

  /// Pode entrar na escala diaconal: diácono ou auxiliar da diaconia.
  bool get servesDiaconia => oficio == Oficio.diacono || ministries.any((m) => m.toLowerCase().startsWith('diacon'));

  factory Membro.fromMap(String id, Map<String, dynamic> m) => Membro(
    id: id,
    name: m['name'] as String? ?? '',
    situacao: Situacao.parse(m['situacao'] as String?),
    oficio: Oficio.tryParse(m['oficio'] as String?),
    birthDate: m['birthDate'] as String?,
    phone: m['phone'] as String?,
    email: m['email'] as String?,
    address: m['address'] as String?,
    neighborhood: m['neighborhood'] as String?,
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
    maritalStatus: m['maritalStatus'] as String?,
    weddingDate: m['weddingDate'] as String?,
    family: m['family'] as String?,
    baptismDate: m['baptismDate'] as String?,
    professionDate: m['professionDate'] as String?,
    admissionDate: m['admissionDate'] as String?,
    admissionMode: m['admissionMode'] as String?,
    ministries: List<String>.from(m['ministries'] as List? ?? const []),
    funcoes: [for (final f in (m['funcoes'] as List? ?? const [])) ?FuncaoDiaconal.tryParse(f as String)],
    selfRegistered: m['selfRegistered'] == true,
    updatedAt: m['updatedAt'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'situacao': situacao.name,
    'oficio': oficio?.name,
    'birthDate': birthDate,
    'phone': phone,
    'email': email,
    'address': address,
    'neighborhood': neighborhood,
    'lat': lat,
    'lng': lng,
    'maritalStatus': maritalStatus,
    'weddingDate': weddingDate,
    'family': family,
    'baptismDate': baptismDate,
    'professionDate': professionDate,
    'admissionDate': admissionDate,
    'admissionMode': admissionMode,
    'ministries': ministries,
    'funcoes': [for (final f in funcoes) f.name],
    'selfRegistered': selfRegistered,
    // Índice para a coordenação da escala achar quem serve na diaconia.
    'diaconia': servesDiaconia,
  };

  /// Campos que a própria pessoa pode alterar no cadastro dela.
  static const selfFields = [
    'name',
    'phone',
    'email',
    'address',
    'neighborhood',
    'lat',
    'lng',
    'birthDate',
    'maritalStatus',
    'weddingDate',
    'updatedAt',
  ];
}

const estadosCivis = ['Solteiro(a)', 'Casado(a)', 'Viúvo(a)', 'Divorciado(a)'];
const modosAdmissao = ['Batismo', 'Profissão de fé', 'Batismo e profissão de fé', 'Transferência', 'Jurisdição'];
const ministeriosSugeridos = [
  'Diaconia',
  'Louvor',
  'EBD',
  'Mídia',
  'Som',
  'Infantil',
  'Recepção',
  'SAF',
  'UPH',
  'UMP',
  'UPA',
  'UCP',
  'Intercessão',
];
