import 'package:agenda_pastoral/core/roles.dart';
import 'package:agenda_pastoral/domain/escala_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gen = EscalaGenerator();
  final pessoas = [
    for (final n in ['Ana', 'Bruno', 'Caio', 'Davi', 'Eli', 'Fabio']) Candidato(id: n.toLowerCase(), name: n),
  ];
  const domingos = ['2026-11-01', '2026-11-08', '2026-11-15', '2026-11-22', '2026-11-29'];
  const vagas = {FuncaoDiaconal.recepcao: 2, FuncaoDiaconal.ofertorio: 1};

  test('preenche todas as vagas e ninguém faz duas funções no mesmo culto', () {
    final g = gen.gerar(datas: domingos, vagasPorFuncao: vagas, candidatos: pessoas);
    expect(g.vagas, isEmpty);
    for (final d in domingos) {
      final ids = [for (final l in g.porData[d]!.values) ...l];
      expect(ids, hasLength(3));
      expect(ids.toSet(), hasLength(3), reason: 'pessoa repetida em $d');
    }
  });

  test('distribui de forma equilibrada (diferença de no máximo 1 entre quem mais e menos serviu)', () {
    final g = gen.gerar(datas: domingos, vagasPorFuncao: vagas, candidatos: pessoas);
    final conta = <String, int>{};
    for (final d in domingos) {
      for (final id in g.porData[d]!.values.expand((x) => x)) {
        conta[id] = (conta[id] ?? 0) + 1;
      }
    }
    final valores = [for (final p in pessoas) conta[p.id] ?? 0];
    expect(valores.reduce((a, b) => a > b ? a : b) - valores.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(1));
  });

  test('respeita as datas em que a pessoa avisou que não pode', () {
    final comBloqueio = [
      for (final p in pessoas)
        p.id == 'ana' ? const Candidato(id: 'ana', name: 'Ana', unavailable: {'2026-11-01', '2026-11-08'}) : p,
    ];
    final g = gen.gerar(datas: domingos, vagasPorFuncao: vagas, candidatos: comBloqueio);
    for (final d in ['2026-11-01', '2026-11-08']) {
      expect(g.porData[d]!.values.expand((x) => x), isNot(contains('ana')));
    }
  });

  test('respeita as funções que cada um faz', () {
    final g = gen.gerar(
      datas: domingos,
      vagasPorFuncao: const {FuncaoDiaconal.ofertorio: 1, FuncaoDiaconal.estacionamento: 1},
      candidatos: [
        const Candidato(id: 'x', name: 'X', funcoes: [FuncaoDiaconal.estacionamento]),
        const Candidato(id: 'y', name: 'Y', funcoes: [FuncaoDiaconal.ofertorio]),
      ],
    );
    for (final d in domingos) {
      expect(g.porData[d]![FuncaoDiaconal.estacionamento], ['x']);
      expect(g.porData[d]![FuncaoDiaconal.ofertorio], ['y']);
    }
  });

  test('avisa as vagas que ficaram sem ninguém', () {
    final g = gen.gerar(
      datas: const ['2026-11-01'],
      vagasPorFuncao: const {FuncaoDiaconal.recepcao: 3},
      candidatos: [pessoas.first],
    );
    expect(g.vagas.single.$3, 2);
  });

  test('evita escalar a mesma pessoa em cultos seguidos quando há gente livre', () {
    final g = gen.gerar(
      datas: domingos,
      vagasPorFuncao: const {FuncaoDiaconal.recepcao: 2},
      candidatos: pessoas.take(4).toList(),
    );
    for (var i = 1; i < domingos.length; i++) {
      final antes = g.porData[domingos[i - 1]]!.values.expand((x) => x).toSet();
      final agora = g.porData[domingos[i]]!.values.expand((x) => x).toSet();
      expect(antes.intersection(agora), isEmpty, reason: '${domingos[i]} repetiu ${antes.intersection(agora)}');
    }
  });

  test('sugere substituto livre e que serviu menos', () {
    final s = gen.sugerir(
      data: '2026-11-01',
      funcao: FuncaoDiaconal.recepcao,
      candidatos: pessoas,
      ocupados: {'ana', 'bruno'},
      carga: {'caio': 3, 'davi': 0, 'eli': 1, 'fabio': 2},
    );
    expect(s.first.id, 'davi');
    expect(s.map((c) => c.id), isNot(contains('ana')));
  });

  test('a mesma entrada gera sempre a mesma escala', () {
    final a = gen.gerar(datas: domingos, vagasPorFuncao: vagas, candidatos: pessoas);
    final b = gen.gerar(datas: domingos, vagasPorFuncao: vagas, candidatos: pessoas);
    expect(a.porData.toString(), b.porData.toString());
  });
}
