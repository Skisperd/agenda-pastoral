import 'dart:async';

import 'store/doc_store.dart';

/// Contas do modo demonstração: (uid, nome, role, nível na mídia).
const contasDemo = [
  ('demo-admin', 'Demo · Liderança de mídia', 'membro', 'lider'),
  ('demo-membro', 'Demo · Operador de câmera', 'membro', 'operador'),
  ('demo-pastor', 'Demo · Pastor', 'pastor', null),
];

const _cenasObs = ['Abertura', 'Culto · plano aberto', 'Pregação', 'Louvor', 'Avisos', 'Encerramento'];
const _fontes = {
  'Abertura': ['Vídeo de abertura'],
  'Culto · plano aberto': ['Câmera 1'],
  'Pregação': ['Câmera 2', 'Letras'],
  'Louvor': ['Câmera 1', 'Câmera 3', 'Letras'],
  'Avisos': ['Slides'],
  'Encerramento': ['Câmera 1'],
};
const _letras = [
  ('musica', 'Grande é o Senhor', 'Grande é o Senhor\ne mui digno de louvor'),
  ('musica', 'Grande é o Senhor', 'Na cidade do nosso Deus,\nseu santo monte'),
  ('biblia', 'Atos 14:3', 'Por isso permaneceram ali bastante tempo, falando ousadamente no Senhor'),
];

Future<void> seedDemo(DocStore store) async {
  final agora = DateTime.now().toUtc();
  await store.batch([
    for (final (uid, nome, role, midia) in contasDemo)
      DocWrite('users/$uid', {'name': nome, 'role': role, 'midia': ?midia}, merge: false),
    const DocWrite('midia/config', {
      'cameras': [
        {'nome': 'Câmera 1', 'fonte': 'Câmera 1'},
        {'nome': 'Câmera 2', 'fonte': 'Câmera 2'},
        {'nome': 'Câmera 3', 'fonte': 'Câmera 3'},
      ],
    }, merge: false),
    DocWrite('midia/estado', {
      'ponteEm': agora.toIso8601String(),
      'obs': _obs('Pregação', 'Louvor', transmitindo: true),
      'telao': _telao(2, 'pregacao'),
    }, merge: false),
    DocWrite('midiaMensagens/m1', {
      'texto': 'Câmera 2 fecha no pregador',
      'uid': 'demo-admin',
      'nome': 'Demo · Liderança de mídia',
      'para': 'cameras',
      'createdAt': agora.subtract(const Duration(minutes: 3)).toIso8601String(),
    }, merge: false),
    DocWrite('midiaMensagens/m2', {
      'texto': 'Tudo certo 👍',
      'uid': 'demo-membro',
      'nome': 'Demo · Operador de câmera',
      'para': 'todos',
      'createdAt': agora.subtract(const Duration(minutes: 2)).toIso8601String(),
    }, merge: false),
  ]);
}

Map<String, dynamic> _obs(String programa, String? previa, {bool transmitindo = false, bool gravando = false}) => {
  'conectado': true,
  'programa': programa,
  'previa': previa,
  'modoEstudio': true,
  'cenas': _cenasObs,
  'fontesPrograma': [programa, ...?_fontes[programa]],
  'fontesPrevia': previa == null ? <String>[] : [previa, ...?_fontes[previa]],
  'transmitindo': transmitindo,
  'transmissaoMs': transmitindo ? 1834000 : 0,
  'gravando': gravando,
  'gravacaoMs': 0,
};

Map<String, dynamic> _telao(int i, String cena) {
  final (tipo, desc, texto) = _letras[i % _letras.length];
  return {
    'conectado': true,
    'holyrics': true,
    'tipo': tipo,
    'descricao': desc,
    'texto': texto,
    'cena': cena,
    'cenas': [
      {'id': 'culto', 'nome': 'Culto'},
      {'id': 'pregacao', 'nome': 'Pregação (câmera + tradução)'},
      {'id': 'avisos', 'nome': 'Avisos (pré-culto)'},
    ],
  };
}

/// Ponte simulada: executa os comandos do app sobre o estado em memória.
class PonteDemo {
  PonteDemo(this.store);
  final DocStore store;
  StreamSubscription<List<Doc>>? _sub;
  var _slide = 2;

  void iniciar() {
    _sub = store.watchWhere('midiaComandos', 'status', ['pendente']).listen((docs) async {
      for (final d in docs) {
        await _executar(d.id, d.data);
      }
    });
  }

  Future<void> parar() async => _sub?.cancel();

  Future<void> _executar(String id, Map<String, dynamic> c) async {
    final atual = (await store.getDoc('midia/estado'))?.data ?? {};
    final obs = Map<String, dynamic>.from(atual['obs'] as Map? ?? {});
    final telao = Map<String, dynamic>.from(atual['telao'] as Map? ?? {});
    var prog = obs['programa'] as String? ?? 'Culto · plano aberto';
    String? prev = obs['previa'] as String?;
    var tx = obs['transmitindo'] == true, rec = obs['gravando'] == true;
    var cena = telao['cena'] as String? ?? 'culto';
    final valor = c['valor'] as String?;
    switch (c['tipo']) {
      case 'obs.programa':
        prog = valor!;
      case 'obs.previa':
        prev = valor;
      case 'obs.transicao':
        (prog, prev) = (prev ?? prog, prog);
      case 'obs.transmissao.iniciar' || 'obs.transmissao.parar':
        tx = c['tipo'] == 'obs.transmissao.iniciar';
      case 'obs.gravacao.iniciar' || 'obs.gravacao.parar':
        rec = c['tipo'] == 'obs.gravacao.iniciar';
      case 'telao.cena':
        cena = valor!;
      case 'holyrics.proximo':
        _slide++;
      case 'holyrics.anterior':
        _slide = (_slide - 1).clamp(0, 99);
    }
    await store.batch([
      DocWrite('midia/estado', {
        'ponteEm': DateTime.now().toUtc().toIso8601String(),
        'obs': _obs(prog, prev, transmitindo: tx, gravando: rec),
        'telao': _telao(_slide, cena),
      }, merge: false),
      DocWrite('midiaComandos/$id', {'status': 'feito'}),
    ]);
  }
}
