import '../core/roles.dart';

/// Quem pode servir na escala diaconal.
class Candidato {
  const Candidato({required this.id, required this.name, this.funcoes = const [], this.unavailable = const {}});

  final String id;
  final String name;

  /// Funções que a pessoa faz (vazio = qualquer uma).
  final List<FuncaoDiaconal> funcoes;

  /// Datas (yyyy-MM-dd) em que avisou que não pode.
  final Set<String> unavailable;

  bool can(FuncaoDiaconal f) => funcoes.isEmpty || funcoes.contains(f);
}

/// Resultado da geração: escala por data e as vagas que ficaram sem ninguém.
class EscalaGerada {
  const EscalaGerada(this.porData, this.vagas);

  /// data -> função -> ids
  final Map<String, Map<FuncaoDiaconal, List<String>>> porData;

  /// "dom, 03/11 · Ofertório: faltou 1"
  final List<(String, FuncaoDiaconal, int)> vagas;
}

/// Monta a escala distribuindo o serviço de forma equilibrada, como o
/// "auto-schedule" dos sistemas de escala de voluntários:
///
/// 1. respeita as datas em que cada pessoa avisou que não pode;
/// 2. ninguém faz duas funções no mesmo culto;
/// 3. respeita as funções que cada um faz;
/// 4. escolhe primeiro quem serviu menos (somando o histórico recente),
///    evita escalar a mesma pessoa em cultos seguidos e alterna as funções.
class EscalaGenerator {
  const EscalaGenerator();

  EscalaGerada gerar({
    required List<String> datas,
    required Map<FuncaoDiaconal, int> vagasPorFuncao,
    required List<Candidato> candidatos,
    Map<String, int> historico = const {},
    Map<String, Map<FuncaoDiaconal, List<String>>> fixos = const {},
  }) {
    final carga = {for (final c in candidatos) c.id: historico[c.id] ?? 0};
    final cargaFuncao = <(String, FuncaoDiaconal), int>{};
    final porData = <String, Map<FuncaoDiaconal, List<String>>>{};
    final vagas = <(String, FuncaoDiaconal, int)>[];
    Set<String> anterior = {};

    for (final data in [...datas]..sort()) {
      final escala = <FuncaoDiaconal, List<String>>{
        for (final e in (fixos[data] ?? const <FuncaoDiaconal, List<String>>{}).entries) e.key: [...e.value],
      };
      final usados = {for (final ids in escala.values) ...ids};
      for (final id in usados) {
        carga[id] = (carga[id] ?? 0) + 1;
      }
      // Funções com menos gente apta primeiro, para não "gastar" quem só faz aquela.
      final funcoes = [
        for (final f in FuncaoDiaconal.values)
          if ((vagasPorFuncao[f] ?? 0) > 0) f,
      ]..sort((a, b) => candidatos.where((c) => c.can(a)).length.compareTo(candidatos.where((c) => c.can(b)).length));

      for (final f in funcoes) {
        final lista = escala.putIfAbsent(f, () => []);
        final faltam = (vagasPorFuncao[f] ?? 0) - lista.length;
        final aptos = sugerir(
          data: data,
          funcao: f,
          candidatos: candidatos,
          ocupados: usados,
          carga: carga,
          cargaFuncao: cargaFuncao,
          anterior: anterior,
        );
        for (final c in aptos.take(faltam < 0 ? 0 : faltam)) {
          lista.add(c.id);
          usados.add(c.id);
          carga[c.id] = (carga[c.id] ?? 0) + 1;
          cargaFuncao[(c.id, f)] = (cargaFuncao[(c.id, f)] ?? 0) + 1;
        }
        final sobra = (vagasPorFuncao[f] ?? 0) - lista.length;
        if (sobra > 0) vagas.add((data, f, sobra));
      }
      escala.removeWhere((_, ids) => ids.isEmpty);
      porData[data] = escala;
      anterior = usados;
    }
    return EscalaGerada(porData, vagas);
  }

  /// Pessoas aptas para [funcao] em [data], da mais indicada para a menos.
  /// Também usado para sugerir um substituto quando alguém recusa.
  List<Candidato> sugerir({
    required String data,
    required FuncaoDiaconal funcao,
    required List<Candidato> candidatos,
    Set<String> ocupados = const {},
    Map<String, int> carga = const {},
    Map<(String, FuncaoDiaconal), int> cargaFuncao = const {},
    Set<String> anterior = const {},
  }) {
    final aptos = [
      for (final c in candidatos)
        if (c.can(funcao) && !c.unavailable.contains(data) && !ocupados.contains(c.id)) c,
    ];
    int peso(Candidato c) =>
        (carga[c.id] ?? 0) * 100 + (anterior.contains(c.id) ? 50 : 0) + (cargaFuncao[(c.id, funcao)] ?? 0) * 10;
    // Desempate estável que muda a cada data, para não favorecer sempre os mesmos nomes.
    int giro(Candidato c) => _fnv('${c.id}|$data');
    return aptos..sort((a, b) {
      final p = peso(a).compareTo(peso(b));
      return p != 0 ? p : giro(a).compareTo(giro(b));
    });
  }

  /// Hash FNV-1a: igual em todas as execuções (o `hashCode` do Dart não garante isso).
  static int _fnv(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}
