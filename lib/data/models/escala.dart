import '../../core/roles.dart';

enum Resposta {
  confirmado('Confirmado'),
  recusado('Não posso');

  const Resposta(this.label);
  final String label;

  static Resposta? tryParse(String? v) {
    for (final r in Resposta.values) {
      if (r.name == v) return r;
    }
    return null;
  }
}

class Confirmacao {
  const Confirmacao(this.status, {this.note, this.at});
  final Resposta status;
  final String? note;
  final String? at;
}

/// Escala diaconal de um culto (diaconia/{id}).
class EscalaDiaconal {
  const EscalaDiaconal({
    required this.id,
    required this.date,
    this.title = 'Culto',
    this.time,
    this.assignments = const {},
    this.confirmations = const {},
    this.notes,
    this.published = false,
    this.names = const {},
  });

  /// Nome de cada pessoa escalada no momento em que a escala foi salva (quem não
  /// é da liderança não lê o cadastro completo de membros).
  final Map<String, String> names;

  final String id;

  /// yyyy-MM-dd
  final String date;
  final String title;

  /// "18:00"
  final String? time;

  /// função -> ids dos membros
  final Map<FuncaoDiaconal, List<String>> assignments;

  /// id do membro -> resposta
  final Map<String, Confirmacao> confirmations;
  final String? notes;

  /// Rascunho só a coordenação vê; publicada, todos os diáconos veem.
  final bool published;

  Set<String> get people => {for (final ids in assignments.values) ...ids};

  EscalaDiaconal copyWith({
    String? title,
    String? time,
    Map<FuncaoDiaconal, List<String>>? assignments,
    String? notes,
    bool? published,
    Map<String, String>? names,
  }) => EscalaDiaconal(
    id: id,
    date: date,
    title: title ?? this.title,
    time: time ?? this.time,
    assignments: assignments ?? this.assignments,
    confirmations: confirmations,
    notes: notes ?? this.notes,
    published: published ?? this.published,
    names: names ?? this.names,
  );

  FuncaoDiaconal? funcaoOf(String memberId) {
    for (final e in assignments.entries) {
      if (e.value.contains(memberId)) return e.key;
    }
    return null;
  }

  factory EscalaDiaconal.fromMap(String id, Map<String, dynamic> m) => EscalaDiaconal(
    id: id,
    date: m['date'] as String? ?? '',
    title: m['title'] as String? ?? 'Culto',
    time: m['time'] as String?,
    assignments: {
      for (final e in Map<String, dynamic>.from(m['assignments'] as Map? ?? const {}).entries)
        ?FuncaoDiaconal.tryParse(e.key): List<String>.from(e.value as List? ?? const []),
    },
    confirmations: {
      for (final e in Map<String, dynamic>.from(m['confirmations'] as Map? ?? const {}).entries)
        if (e.value is Map)
          if (Resposta.tryParse((e.value as Map)['status'] as String?) case final r?)
            e.key: Confirmacao(r, note: (e.value as Map)['note'] as String?, at: (e.value as Map)['at'] as String?),
    },
    notes: m['notes'] as String?,
    published: m['published'] == true,
    names: Map<String, String>.from(m['names'] as Map? ?? const {}),
  );

  Map<String, dynamic> toMap() => {
    'date': date,
    'title': title,
    'time': time,
    'assignments': {for (final e in assignments.entries) e.key.name: e.value},
    'notes': notes,
    'published': published,
    'names': names,
  };
}
