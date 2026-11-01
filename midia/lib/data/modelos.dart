import '../core/roles.dart';

/// Conta (a mesma do app da igreja) com o lugar na equipa de mídia.
class Usuario {
  const Usuario({required this.uid, required this.nome, required this.role, this.midia, this.ponte = false});

  final String uid;
  final String nome;
  final AppRole role;
  final NivelMidia? midia;

  /// Conta usada pela ponte no computador da igreja.
  final bool ponte;

  /// Vê o app de mídia: equipa de mídia, secretaria, pastores e presbíteros.
  bool get acesso => role.isApproved && (midia != null || role.isLeader);

  /// Comanda o OBS e o telão: liderança de mídia e secretaria.
  bool get comanda => role.isApproved && (midia == NivelMidia.lider || role == AppRole.admin);

  String get primeiroNome => nome.trim().split(' ').first;

  factory Usuario.fromMap(String uid, Map<String, dynamic> m) => Usuario(
    uid: uid,
    nome: m['name'] as String? ?? '',
    role: AppRole.parse(m['role'] as String?),
    midia: NivelMidia.tryParse(m['midia'] as String?),
    ponte: m['ponte'] == true,
  );
}

/// O que o OBS está a fazer (gravado pela ponte em midia/estado.obs).
class EstadoObs {
  const EstadoObs({
    this.conectado = false,
    this.erro,
    this.programa,
    this.previa,
    this.modoEstudio = false,
    this.cenas = const [],
    this.fontesPrograma = const [],
    this.fontesPrevia = const [],
    this.transmitindo = false,
    this.transmissaoMs = 0,
    this.gravando = false,
    this.gravacaoMs = 0,
  });

  final bool conectado;
  final String? erro;
  final String? programa;
  final String? previa;
  final bool modoEstudio;
  final List<String> cenas;
  final List<String> fontesPrograma;
  final List<String> fontesPrevia;
  final bool transmitindo;
  final int transmissaoMs;
  final bool gravando;
  final int gravacaoMs;

  static List<String> _l(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];

  factory EstadoObs.fromMap(Map<String, dynamic>? m) => m == null
      ? const EstadoObs()
      : EstadoObs(
          conectado: m['conectado'] == true,
          erro: m['erro'] as String?,
          programa: m['programa'] as String?,
          previa: m['previa'] as String?,
          modoEstudio: m['modoEstudio'] == true,
          cenas: _l(m['cenas']),
          fontesPrograma: _l(m['fontesPrograma']),
          fontesPrevia: _l(m['fontesPrevia']),
          transmitindo: m['transmitindo'] == true,
          transmissaoMs: (m['transmissaoMs'] as num?)?.toInt() ?? 0,
          gravando: m['gravando'] == true,
          gravacaoMs: (m['gravacaoMs'] as num?)?.toInt() ?? 0,
        );
}

class CenaTelao {
  const CenaTelao(this.id, this.nome);
  final String id;
  final String nome;
}

/// O que o telão mostra (servidor do Holyrics, gravado pela ponte em midia/estado.telao).
class EstadoTelao {
  const EstadoTelao({
    this.conectado = false,
    this.holyrics = false,
    this.erro,
    this.tipo = 'vazio',
    this.descricao = '',
    this.leitor,
    this.texto = '',
    this.cena,
    this.cenas = const [],
  });

  final bool conectado;
  final bool holyrics;
  final String? erro;

  /// musica, biblia, midia, vazio
  final String tipo;
  final String descricao;
  final String? leitor;
  final String texto;
  final String? cena;
  final List<CenaTelao> cenas;

  String get rotulo => switch (tipo) {
    'musica' => 'Música',
    'biblia' => 'Bíblia',
    'midia' => 'Mídia',
    _ => 'Nada no ar',
  };

  String? get nomeCena => cenas.where((c) => c.id == cena).firstOrNull?.nome ?? cena;

  factory EstadoTelao.fromMap(Map<String, dynamic>? m) => m == null
      ? const EstadoTelao()
      : EstadoTelao(
          conectado: m['conectado'] == true,
          holyrics: m['holyrics'] == true,
          erro: m['erro'] as String?,
          tipo: m['tipo'] as String? ?? 'vazio',
          descricao: m['descricao'] as String? ?? '',
          leitor: m['leitor'] as String?,
          texto: m['texto'] as String? ?? '',
          cena: m['cena'] as String?,
          cenas: [
            for (final c in (m['cenas'] as List? ?? const []))
              if (c is Map) CenaTelao('${c['id']}', '${c['nome'] ?? c['id']}'),
          ],
        );
}

/// midia/estado inteiro.
class EstadoMidia {
  const EstadoMidia({this.obs = const EstadoObs(), this.telao = const EstadoTelao(), this.ponteEm});

  final EstadoObs obs;
  final EstadoTelao telao;

  /// Último sinal da ponte (ISO, UTC).
  final String? ponteEm;

  /// A ponte manda sinal a cada 30 s e a cada mudança.
  bool ponteOnline(DateTime agora) {
    final t = ponteEm == null ? null : DateTime.tryParse(ponteEm!);
    return t != null && agora.toUtc().difference(t.toUtc()).inSeconds < 75;
  }

  factory EstadoMidia.fromMap(Map<String, dynamic>? m) => EstadoMidia(
    obs: EstadoObs.fromMap(m?['obs'] == null ? null : Map<String, dynamic>.from(m!['obs'] as Map)),
    telao: EstadoTelao.fromMap(m?['telao'] == null ? null : Map<String, dynamic>.from(m!['telao'] as Map)),
    ponteEm: m?['ponteEm'] as String?,
  );
}

enum Tally {
  programa('NO AR'),
  previa('PRÉVIA'),
  livre('LIVRE');

  const Tally(this.label);
  final String label;
}

/// Câmera ligada a uma fonte (ou cena) do OBS.
class Camera {
  const Camera(this.nome, this.fonte);
  final String nome;
  final String fonte;

  Tally tally(EstadoObs o) => o.fontesPrograma.contains(fonte)
      ? Tally.programa
      : o.modoEstudio && o.fontesPrevia.contains(fonte)
      ? Tally.previa
      : Tally.livre;
}

/// midia/config: câmeras e mensagens rápidas (liderança de mídia edita).
class ConfigMidia {
  const ConfigMidia({this.cameras = const [], this.rapidas = rapidasPadrao});

  final List<Camera> cameras;
  final List<String> rapidas;

  static const rapidasPadrao = [
    'Próxima música',
    'Câmera no pregador',
    'Plano aberto',
    'Volta ao culto',
    'Letra atrasada',
    'Sem som na transmissão',
    'Preparar a Bíblia',
    'Tudo certo 👍',
  ];

  factory ConfigMidia.fromMap(Map<String, dynamic>? m) => m == null
      ? const ConfigMidia()
      : ConfigMidia(
          cameras: [
            for (final c in (m['cameras'] as List? ?? const []))
              if (c is Map && '${c['nome'] ?? ''}'.isNotEmpty) Camera('${c['nome']}', '${c['fonte'] ?? ''}'),
          ],
          rapidas: (m['rapidas'] as List?)?.map((e) => '$e').toList() ?? rapidasPadrao,
        );

  Map<String, dynamic> toMap() => {
    'cameras': [
      for (final c in cameras) {'nome': c.nome, 'fonte': c.fonte},
    ],
    'rapidas': rapidas,
  };
}

/// Para quem vai a mensagem.
enum Destino {
  todos('Todos'),
  cameras('Câmeras'),
  holyrics('Holyrics'),
  transmissao('Transmissão'),
  som('Som');

  const Destino(this.label);
  final String label;

  static Destino parse(String? v) => Destino.values.firstWhere((d) => d.name == v, orElse: () => Destino.todos);
}

class Mensagem {
  const Mensagem({
    required this.id,
    required this.texto,
    required this.uid,
    required this.nome,
    required this.createdAt,
    this.para = Destino.todos,
  });

  final String id;
  final String texto;
  final String uid;
  final String nome;
  final String createdAt;
  final Destino para;

  factory Mensagem.fromMap(String id, Map<String, dynamic> m) => Mensagem(
    id: id,
    texto: m['texto'] as String? ?? '',
    uid: m['uid'] as String? ?? '',
    nome: m['nome'] as String? ?? '',
    createdAt: m['createdAt'] as String? ?? '',
    para: Destino.parse(m['para'] as String?),
  );
}

enum StatusComando { pendente, feito, erro }

/// Pedido do app para a ponte (midiaComandos/{id}).
class Comando {
  const Comando({
    required this.id,
    required this.tipo,
    this.valor,
    this.uid = '',
    this.nome = '',
    this.status = StatusComando.pendente,
    this.resultado,
    this.createdAt = '',
  });

  final String id;
  final String tipo;
  final String? valor;
  final String uid;
  final String nome;
  final StatusComando status;
  final String? resultado;
  final String createdAt;

  String get descricao => switch (tipo) {
    'obs.programa' => 'No ar: $valor',
    'obs.previa' => 'Prévia: $valor',
    'obs.transicao' => 'Transição',
    'obs.transmissao.iniciar' => 'Iniciar transmissão',
    'obs.transmissao.parar' => 'Parar transmissão',
    'obs.gravacao.iniciar' => 'Iniciar gravação',
    'obs.gravacao.parar' => 'Parar gravação',
    'telao.cena' => 'Telão: $valor',
    'holyrics.proximo' => 'Holyrics: próximo',
    'holyrics.anterior' => 'Holyrics: anterior',
    _ => tipo,
  };

  factory Comando.fromMap(String id, Map<String, dynamic> m) => Comando(
    id: id,
    tipo: m['tipo'] as String? ?? '',
    valor: m['valor'] as String?,
    uid: m['uid'] as String? ?? '',
    nome: m['nome'] as String? ?? '',
    status: StatusComando.values.firstWhere((s) => s.name == m['status'], orElse: () => StatusComando.pendente),
    resultado: m['resultado'] as String?,
    createdAt: m['createdAt'] as String? ?? '',
  );
}
