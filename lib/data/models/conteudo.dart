import '../../core/links.dart';

enum VideoTipo {
  culto('Culto'),
  estudo('Estudo'),
  ebd('EBD'),
  devocional('Devocional'),
  aviso('Aviso'),
  louvor('Louvor');

  const VideoTipo(this.label);
  final String label;

  static VideoTipo parse(String? v) => VideoTipo.values.firstWhere((t) => t.name == v, orElse: () => VideoTipo.culto);
}

/// Vídeo do canal da igreja no YouTube.
class Video {
  const Video({
    required this.id,
    required this.url,
    required this.title,
    required this.date,
    this.tipo = VideoTipo.culto,
    this.speaker,
    this.bibleText,
  });

  final String id;
  final String url;
  final String title;

  /// Data do culto/estudo (yyyy-MM-dd).
  final String date;
  final VideoTipo tipo;
  final String? speaker;
  final String? bibleText;

  String? get youtubeId => youtubeVideoId(url);
  String? get thumb => youtubeId == null ? null : 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';

  factory Video.fromMap(String id, Map<String, dynamic> m) => Video(
    id: id,
    url: m['url'] as String? ?? '',
    title: m['title'] as String? ?? '',
    date: m['date'] as String? ?? '',
    tipo: VideoTipo.parse(m['tipo'] as String?),
    speaker: m['speaker'] as String?,
    bibleText: m['bibleText'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'url': url.trim(),
    'title': title.trim(),
    'date': date,
    'tipo': tipo.name,
    'speaker': speaker,
    'bibleText': bibleText,
  };
}

/// Aviso do mural.
class Aviso {
  const Aviso({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.author,
    this.pinned = false,
    this.until,
    this.link,
  });

  final String id;
  final String title;
  final String body;
  final String createdAt;
  final String? author;

  /// Fixado no topo do Início.
  final bool pinned;

  /// Some do mural depois deste dia (yyyy-MM-dd).
  final String? until;
  final String? link;

  bool visibleOn(String today) => until == null || until!.compareTo(today) >= 0;

  factory Aviso.fromMap(String id, Map<String, dynamic> m) => Aviso(
    id: id,
    title: m['title'] as String? ?? '',
    body: m['body'] as String? ?? '',
    createdAt: m['createdAt'] as String? ?? '',
    author: m['author'] as String?,
    pinned: m['pinned'] == true,
    until: m['until'] as String?,
    link: m['link'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'body': body.trim(),
    'createdAt': createdAt,
    'author': author,
    'pinned': pinned,
    'until': until,
    'link': link,
  };
}

/// Pedido de oração.
class PedidoOracao {
  const PedidoOracao({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    this.anonymous = false,
    this.private = false,
    this.answered = false,
    this.praying = const [],
  });

  final String id;
  final String text;
  final String authorUid;
  final String authorName;
  final String createdAt;

  /// Mostra "Anônimo" para os irmãos (o pastor vê o nome).
  final bool anonymous;

  /// Só o pastor e o conselho veem.
  final bool private;

  /// Marcado como respondido (testemunho).
  final bool answered;

  /// Contas que marcaram "estou orando".
  final List<String> praying;

  String displayName(bool canSeeNames) => anonymous && !canSeeNames ? 'Anônimo' : authorName;

  factory PedidoOracao.fromMap(String id, Map<String, dynamic> m) => PedidoOracao(
    id: id,
    text: m['text'] as String? ?? '',
    authorUid: m['authorUid'] as String? ?? '',
    authorName: m['authorName'] as String? ?? '',
    createdAt: m['createdAt'] as String? ?? '',
    anonymous: m['anonymous'] == true,
    private: m['private'] == true,
    answered: m['answered'] == true,
    praying: List<String>.from(m['praying'] as List? ?? const []),
  );
}

/// Dados gerais da igreja (config/igreja).
class IgrejaConfig {
  const IgrejaConfig({
    this.name = 'Igreja Cristã Presbiteriana Pedras Vivas',
    this.shortName = 'Pedras Vivas',
    this.slogan = 'Conhecer a Cristo e fazê-lo conhecido',
    this.address,
    this.phone,
    this.email,
    this.youtube,
    this.instagram,
    this.site,
    this.pix,
    this.banco,
    this.iban,
    this.swift,
    this.ofertas = const [],
  });

  final String name;
  final String shortName;
  final String slogan;
  final String? address;

  /// Telefone/WhatsApp da secretaria.
  final String? phone;
  final String? email;

  /// Link do canal no YouTube.
  final String? youtube;
  final String? instagram;
  final String? site;

  /// MB WAY ou outra chave para ofertas rápidas.
  final String? pix;

  /// Conta para dízimos e ofertas.
  final String? banco;
  final String? iban;
  final String? swift;

  /// Identificação das ofertas pelos cêntimos: ("Dízimo", "+ 0,01 €").
  final List<(String, String)> ofertas;

  static String? _s(Object? v) => (v as String?)?.trim().isEmpty ?? true ? null : (v as String).trim();

  factory IgrejaConfig.fromMap(Map<String, dynamic>? m) => m == null
      ? const IgrejaConfig()
      : IgrejaConfig(
          name: _s(m['name']) ?? const IgrejaConfig().name,
          shortName: _s(m['shortName']) ?? const IgrejaConfig().shortName,
          slogan: _s(m['slogan']) ?? const IgrejaConfig().slogan,
          address: _s(m['address']),
          phone: _s(m['phone']),
          email: _s(m['email']),
          youtube: _s(m['youtube']),
          instagram: _s(m['instagram']),
          site: _s(m['site']),
          pix: _s(m['pix']),
          banco: _s(m['banco']),
          iban: _s(m['iban']),
          swift: _s(m['swift']),
          ofertas: [
            for (final o in (m['ofertas'] as List? ?? const []))
              if (o is Map) ((o['tipo'] as String?) ?? '', (o['valor'] as String?) ?? ''),
          ],
        );

  Map<String, dynamic> toMap() => {
    'name': name,
    'shortName': shortName,
    'slogan': slogan,
    'address': address,
    'phone': phone,
    'email': email,
    'youtube': youtube,
    'instagram': instagram,
    'site': site,
    'pix': pix,
    'banco': banco,
    'iban': iban,
    'swift': swift,
    'ofertas': [
      for (final (t, v) in ofertas) {'tipo': t, 'valor': v},
    ],
  };
}
