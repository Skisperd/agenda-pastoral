/// Pequeno grupo (grupos/{id}).
class Grupo {
  const Grupo({
    required this.id,
    required this.local,
    required this.weekday,
    required this.time,
    this.lider,
    this.telefone,
    this.descricao,
    this.ativo = true,
  });

  final String id;

  /// Onde se reúne ("São Mamede", "Porto"): só a zona, não a morada da casa.
  final String local;

  /// 1 = segunda … 7 = domingo.
  final int weekday;

  /// "19:30"
  final String time;

  /// Quem conduz ("Marco", "Pr. Léo").
  final String? lider;

  /// Contacto do líder (opcional).
  final String? telefone;
  final String? descricao;
  final bool ativo;

  /// "19h30"
  String get hora => time.replaceAll(':', 'h').replaceAll('h00', 'h');

  factory Grupo.fromMap(String id, Map<String, dynamic> m) => Grupo(
    id: id,
    local: m['local'] as String? ?? '',
    weekday: (m['weekday'] as num?)?.toInt() ?? 4,
    time: m['time'] as String? ?? '20:00',
    lider: m['lider'] as String?,
    telefone: m['telefone'] as String?,
    descricao: m['descricao'] as String?,
    ativo: m['ativo'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'local': local.trim(),
    'weekday': weekday,
    'time': time,
    'lider': lider,
    'telefone': telefone,
    'descricao': descricao,
    'ativo': ativo,
  };
}

/// Configuração dos pequenos grupos (config/pg).
class PgConfig {
  const PgConfig({
    this.titulo = 'A comunhão continua durante a semana',
    this.texto =
        'Pequenos Grupos: espaços de comunhão, discipulado e cuidado mútuo. Os encontros proporcionam um ambiente '
        'de convivência e estudo da Palavra, fortalecendo os vínculos entre os irmãos.',
    this.contatoNome,
    this.contatoTelefone,
    this.estudoAtual,
  });

  final String titulo;
  final String texto;

  /// Quem atende quem quer participar ("presbítero Roberto").
  final String? contatoNome;
  final String? contatoTelefone;

  /// Estudo desta semana (id em estudos/).
  final String? estudoAtual;

  factory PgConfig.fromMap(Map<String, dynamic>? m) => m == null
      ? const PgConfig()
      : PgConfig(
          titulo: (m['titulo'] as String?)?.trim().isNotEmpty == true ? m['titulo'] as String : const PgConfig().titulo,
          texto: (m['texto'] as String?)?.trim().isNotEmpty == true ? m['texto'] as String : const PgConfig().texto,
          contatoNome: m['contatoNome'] as String?,
          contatoTelefone: m['contatoTelefone'] as String?,
          estudoAtual: m['estudoAtual'] as String?,
        );

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'texto': texto,
    'contatoNome': contatoNome,
    'contatoTelefone': contatoTelefone,
    'estudoAtual': estudoAtual,
  };
}

/// Pergunta de um estudo bíblico indutivo, com orientação para quem conduz.
class Pergunta {
  const Pergunta({required this.texto, this.tipo, this.guia});
  final String texto;

  /// Observação, Interpretação, Aplicação, Transmissão.
  final String? tipo;
  final String? guia;

  factory Pergunta.fromMap(Map<String, dynamic> m) =>
      Pergunta(texto: m['texto'] as String? ?? '', tipo: m['tipo'] as String?, guia: m['guia'] as String?);

  Map<String, dynamic> toMap() => {'texto': texto, 'tipo': tipo, 'guia': guia};
}

/// Estudo bíblico indutivo (EBI) dos pequenos grupos (estudos/{id}).
class Estudo {
  const Estudo({
    required this.id,
    required this.referencia,
    this.titulo = '',
    this.livro,
    this.ordem = 0,
    this.resumo,
    this.frase,
    this.perguntas = const [],
    this.fontes = const [],
  });

  final String id;

  /// "Atos 13:1–12"
  final String referencia;
  final String titulo;
  final String? livro;
  final int ordem;
  final String? resumo;

  /// Resumo em uma frase, para transmitir.
  final String? frase;
  final List<Pergunta> perguntas;
  final List<String> fontes;

  factory Estudo.fromMap(String id, Map<String, dynamic> m) => Estudo(
    id: id,
    referencia: m['referencia'] as String? ?? '',
    titulo: m['titulo'] as String? ?? '',
    livro: m['livro'] as String?,
    ordem: (m['ordem'] as num?)?.toInt() ?? 0,
    resumo: m['resumo'] as String?,
    frase: m['frase'] as String?,
    perguntas: [
      for (final p in (m['perguntas'] as List? ?? const []))
        if (p is Map) Pergunta.fromMap(Map<String, dynamic>.from(p)),
    ],
    fontes: List<String>.from(m['fontes'] as List? ?? const []),
  );

  Map<String, dynamic> toMap() => {
    'referencia': referencia.trim(),
    'titulo': titulo.trim(),
    'livro': livro,
    'ordem': ordem,
    'resumo': resumo,
    'frase': frase,
    'perguntas': [for (final p in perguntas) p.toMap()],
    'fontes': fontes,
  };

  /// Perguntas em texto para colar no grupo do WhatsApp.
  String get textoWhatsApp {
    final b = StringBuffer('*Estudo Bíblico Indutivo · $referencia*\n');
    if (titulo.isNotEmpty) b.write('_${titulo}_\n');
    for (final (i, p) in perguntas.indexed) {
      b.write('\n${i + 1}. ${p.texto}\n');
    }
    return b.toString().trim();
  }
}
