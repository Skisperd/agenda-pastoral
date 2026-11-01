import 'dart:io';

import 'package:agenda_pastoral/domain/ebi_parser.dart';
import 'package:flutter_test/flutter_test.dart';

late String _fonte;

/// Texto extraído pelo pdftotext ou pelo pdf.js (o que o site usa).
EbiExtraido ler(String nome) => extrairEbi(File('test/fixtures/$nome$_fonte').readAsStringSync());

void main() {
  for (final fonte in ['.txt', '.pdfjs.txt']) {
    group(fonte == '.txt' ? 'pdftotext' : 'pdf.js', () {
      setUp(() => _fonte = fonte);
      _casos();
    });
  }
}

void _casos() {
  test('Atos 13:1–12: passagem, título, 10 perguntas e 3 fontes', () {
    final e = ler('EBI_-_Atos_13_1-12');
    expect(e.referencia, 'Atos 13:1–12');
    expect(e.titulo, 'Comissão e Missão em Chipre');
    expect(e.perguntas, hasLength(10));
    expect(e.perguntas.first, startsWith('Qual é a frequência com que o Espírito Santo aparece'));
    expect(e.perguntas.first, isNot(contains('[1]')));
    expect(e.perguntas.last, endsWith('sensível ao chamado de Deus?'));
    expect(e.fontes, hasLength(3));
    expect(e.fontes.first, startsWith('Josh Wilson and John Lee, Discovering Acts'));
    expect(e.fontes.first, isNot(contains('See here')));
  });

  test('Atos 13:13–52: 16 perguntas, inclusive as numeradas na mesma linha', () {
    final e = ler('EBI_-_Atos_13_13-52');
    expect(e.referencia, 'Atos 13:13–52');
    expect(e.perguntas, hasLength(16));
    expect(e.perguntas[9], startsWith('Qual o conteúdo do discurso de Paulo?'));
    expect(e.perguntas[13], contains('Considere At 1:8 e Rm 10:17'));
    expect(e.perguntas[4], anyOf(contains('(vv.49-50)'), contains('(vv.4950)')));
    expect(e.fontes.single, contains('Iain M. Duguid'));
  });

  test('Atos 14:1–7: 9 perguntas e nenhuma fonte', () {
    final e = ler('EBI_-_Atos_14_1-7');
    expect(e.referencia, 'Atos 14:1–7');
    expect(e.perguntas, hasLength(9));
    expect(
      e.perguntas.first,
      'Qual local Paulo e Barnabé procuram em Icônio? Quem estava presente? O que Paulo e '
      'Barnabé fizeram lá? Qual o resultado (v.1)?',
    );
    expect(e.fontes, isEmpty);
  });

  test('texto sem perguntas numeradas devolve lista vazia', () {
    expect(extrairEbi('Apenas um texto qualquer\nsem perguntas').perguntas, isEmpty);
  });
}
