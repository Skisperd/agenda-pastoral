/// Lê o texto de uma apostila de Estudo Bíblico Indutivo (PDF convertido em texto)
/// e separa a passagem, o título, as perguntas numeradas e as fontes das notas.
class EbiExtraido {
  const EbiExtraido({required this.referencia, this.titulo = '', this.perguntas = const [], this.fontes = const []});

  /// "Atos 13:13–52" (vazio se não achou).
  final String referencia;
  final String titulo;
  final List<String> perguntas;
  final List<String> fontes;
}

const _livros = {'atos dos apóstolos': 'Atos', 'atos dos apostolos': 'Atos'};

EbiExtraido extrairEbi(String texto) {
  final linhas = texto
      .replaceAll('\f', '\n')
      .replaceAll('\r', '')
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
      .toList();

  // Passagem: "Atos dos Apóstolos 13:13-52" ou "Primeira Seção (Atos 13:1–12): Título".
  var referencia = '';
  var titulo = '';
  var inicio = 0;
  final refRe = RegExp(
    r'((?:[1-3]\s?)?[A-ZÁÉÍÓÚÂÊÔÃÕ][a-záéíóúâêôãõç]+(?: d[aeo]s? [A-ZÁÉÍÓÚ][a-záéíóúâêôãõç]+)?)\s+(\d{1,3}):(\d{1,3})\s*[-–—]\s*(\d{1,3})',
  );
  for (final (i, l) in linhas.indexed) {
    final m = refRe.firstMatch(l);
    if (m == null) continue;
    inicio = i + 1;
    final livro = _livros[m[1]!.toLowerCase()] ?? m[1]!;
    referencia = '$livro ${m[2]}:${m[3]}–${m[4]}';
    final depois = l.substring(m.end).replaceFirst(RegExp(r'^\)?\s*[:–—-]\s*'), '').trim();
    if (depois.isNotEmpty) titulo = depois;
    break;
  }

  final perguntas = <String>[];
  final fontes = <String>[];
  StringBuffer? atual;
  var esperado = 1;
  var nasNotas = false;
  final numRe = RegExp(r'^(\d{1,2})\s*[.)]\s*(.*)$');
  final notaRe = RegExp(r'^\[(\d+)\]\s*(.*)$');

  void fecha() {
    if (atual == null) return;
    final t = atual
        .toString()
        .replaceAll(RegExp(r'\[\d+\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' ?', '?')
        .trim();
    if (t.isNotEmpty) perguntas.add(t);
    atual = null;
  }

  // As perguntas começam depois da passagem (antes dela vêm o método e os princípios, também numerados).
  for (final bruta in linhas.skip(inicio)) {
    if (bruta.isEmpty) continue;
    // Separador das notas ("---"), às vezes colado à primeira nota ("--[1] ...").
    final l = bruta.replaceFirst(RegExp(r'^-{2,}\s*'), '');
    if (l != bruta || (notaRe.hasMatch(l) && atual != null && !l.contains('?'))) nasNotas = true;
    if (l.isEmpty) continue;
    if (nasNotas) {
      final n = notaRe.firstMatch(l);
      if (n != null) {
        fecha();
        fontes.add(n[2]!);
      } else if (fontes.isNotEmpty) {
        fontes[fontes.length - 1] = '${fontes.last} $l';
      }
      continue;
    }
    final m = numRe.firstMatch(l);
    if (m != null && int.parse(m[1]!) == esperado) {
      fecha();
      atual = StringBuffer(m[2]!);
      esperado++;
      continue;
    }
    // Linhas antes da 1ª pergunta (cabeçalho, método) são ignoradas. Palavra ou
    // intervalo quebrado com hífen no fim da linha ("vv.49-" + "50") é emendado.
    if (atual != null) {
      final t = atual.toString();
      atual!.write(t.endsWith('-') && RegExp(r'^[\da-záéíóúâêôãõç]').hasMatch(l) ? l : ' $l');
    }
  }
  fecha();

  return EbiExtraido(
    referencia: referencia,
    titulo: titulo,
    perguntas: perguntas,
    fontes: [
      for (final f in fontes)
        f.replaceAll(RegExp(r'\s*\[See here[^\]]*\]\.?'), '').replaceAll(RegExp(r'\s+'), ' ').trim(),
    ],
  );
}
