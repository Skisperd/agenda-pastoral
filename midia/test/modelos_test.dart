import 'package:flutter_test/flutter_test.dart';
import 'package:midia_pedras_vivas/core/roles.dart';
import 'package:midia_pedras_vivas/data/modelos.dart';
import 'package:midia_pedras_vivas/features/comum.dart';

void main() {
  test('acesso e comando conforme o perfil', () {
    Usuario u(String role, [String? midia]) => Usuario.fromMap('x', {'name': 'A', 'role': role, 'midia': ?midia});
    expect(u('membro').acesso, isFalse);
    expect(u('membro', 'operador').acesso, isTrue);
    expect(u('membro', 'operador').comanda, isFalse);
    expect(u('membro', 'lider').comanda, isTrue);
    expect(u('presbitero').acesso, isTrue);
    expect(u('presbitero').comanda, isFalse);
    expect(u('admin').comanda, isTrue);
    expect(u('pending', 'lider').acesso, isFalse);
    expect(u('membro', 'lider').midia, NivelMidia.lider);
  });

  test('tally da câmera pelas fontes do programa e da prévia', () {
    final o = EstadoObs.fromMap({
      'programa': 'Pregação',
      'previa': 'Louvor',
      'modoEstudio': true,
      'fontesPrograma': ['Pregação', 'Câmera 2'],
      'fontesPrevia': ['Louvor', 'Câmera 1', 'Câmera 3'],
    });
    expect(const Camera('C2', 'Câmera 2').tally(o), Tally.programa);
    expect(const Camera('C1', 'Câmera 1').tally(o), Tally.previa);
    expect(const Camera('C4', 'Câmera 4').tally(o), Tally.livre);
    // Sem modo estúdio a prévia não existe.
    final simples = EstadoObs.fromMap({
      'fontesPrograma': ['Câmera 2'],
      'fontesPrevia': ['Câmera 1'],
    });
    expect(const Camera('C1', 'Câmera 1').tally(simples), Tally.livre);
  });

  test('ponte online só com sinal recente', () {
    final agora = DateTime.utc(2026, 11, 1, 10);
    EstadoMidia e(Duration d) => EstadoMidia.fromMap({'ponteEm': agora.subtract(d).toIso8601String()});
    expect(e(const Duration(seconds: 20)).ponteOnline(agora), isTrue);
    expect(e(const Duration(minutes: 2)).ponteOnline(agora), isFalse);
    expect(const EstadoMidia().ponteOnline(agora), isFalse);
  });

  test('telão, config e comandos', () {
    final t = EstadoTelao.fromMap({
      'tipo': 'biblia',
      'cena': 'p',
      'cenas': [
        {'id': 'p', 'nome': 'Pregação'},
      ],
    });
    expect(t.rotulo, 'Bíblia');
    expect(t.nomeCena, 'Pregação');
    final c = ConfigMidia.fromMap({
      'cameras': [
        {'nome': 'Púlpito', 'fonte': 'Câmera 2'},
        {'nome': ''},
      ],
    });
    expect(c.cameras.single.nome, 'Púlpito');
    expect(c.rapidas, ConfigMidia.rapidasPadrao);
    expect(ConfigMidia.fromMap(c.toMap()).cameras.single.fonte, 'Câmera 2');
    expect(
      Comando.fromMap('1', {'tipo': 'obs.programa', 'valor': 'Louvor', 'status': 'feito'}).descricao,
      'No ar: Louvor',
    );
    expect(Comando.fromMap('1', {'status': 'xx'}).status, StatusComando.pendente);
    expect(duracao(3725000), '1:02:05');
    expect(duracao(65000), '1:05');
  });
}
