import '../../core/format.dart';

/// Item de lista do boletim (aviso ou motivo de oração).
class ItemBoletim {
  const ItemBoletim({required this.titulo, this.texto = '', this.destaque = false});

  final String titulo;
  final String texto;

  /// Aviso em destaque (sino vermelho).
  final bool destaque;

  factory ItemBoletim.fromMap(Map<String, dynamic> m) => ItemBoletim(
    titulo: m['titulo'] as String? ?? '',
    texto: m['texto'] as String? ?? '',
    destaque: m['destaque'] == true,
  );

  Map<String, dynamic> toMap() => {'titulo': titulo, 'texto': texto, 'destaque': destaque};

  /// "Título — texto"
  String get linha => texto.isEmpty ? titulo : '$titulo — $texto';
}

/// O que a igreja está estudando em cada frente ("Culto solene" → "1 Pedro").
class EstudoFrente {
  const EstudoFrente(this.area, this.tema);
  final String area;
  final String tema;
}

/// Boletim da semana (boletins/{domingo yyyy-MM-dd}).
class Boletim {
  const Boletim({
    required this.id,
    required this.inicio,
    this.avisos = const [],
    this.oracao = const [],
    this.estudos = const [],
    this.publicado = false,
    this.atualizadoEm = '',
  });

  final String id;

  /// Domingo que abre a semana (yyyy-MM-dd).
  final String inicio;
  final List<ItemBoletim> avisos;
  final List<ItemBoletim> oracao;
  final List<EstudoFrente> estudos;
  final bool publicado;
  final String atualizadoEm;

  DateTime get domingo => DateTime.parse(inicio);
  DateTime get sabado => addDays(domingo, 6);

  /// "25 a 31 de outubro / 2026"
  String get periodo {
    final a = domingo, b = sabado;
    final mes = fmtMonth(b).split(' de ').first;
    if (a.month == b.month) return '${a.day} a ${b.day} de $mes / ${b.year}';
    return '${a.day} de ${fmtMonth(a).split(' de ').first} a ${b.day} de $mes / ${b.year}';
  }

  static const frentesPadrao = ['Escola Dominical', 'Culto solene', 'Curso de Teologia', 'Pequenos grupos'];

  factory Boletim.fromMap(String id, Map<String, dynamic> m) => Boletim(
    id: id,
    inicio: m['inicio'] as String? ?? id,
    avisos: [
      for (final a in (m['avisos'] as List? ?? const []))
        if (a is Map) ItemBoletim.fromMap(Map<String, dynamic>.from(a)),
    ],
    oracao: [
      for (final a in (m['oracao'] as List? ?? const []))
        if (a is Map) ItemBoletim.fromMap(Map<String, dynamic>.from(a)),
    ],
    estudos: [
      for (final e in (m['estudos'] as List? ?? const []))
        if (e is Map) EstudoFrente(e['area'] as String? ?? '', e['tema'] as String? ?? ''),
    ],
    publicado: m['publicado'] == true,
    atualizadoEm: m['atualizadoEm'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'inicio': inicio,
    'avisos': [for (final a in avisos) a.toMap()],
    'oracao': [for (final a in oracao) a.toMap()],
    'estudos': [
      for (final e in estudos) {'area': e.area, 'tema': e.tema},
    ],
    'publicado': publicado,
  };

  /// Cópia para outra semana (o editor parte da anterior), ainda não publicada.
  Boletim paraSemana(String domingo) =>
      Boletim(id: domingo, inicio: domingo, avisos: avisos, oracao: oracao, estudos: estudos);
}

/// Domingo da semana de [d] (o boletim vai de domingo a sábado).
DateTime domingoDe(DateTime d) => addDays(dateOnly(d), -(d.weekday % 7));
