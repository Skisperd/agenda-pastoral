import assert from 'node:assert/strict';
import { test } from 'node:test';

import { fontesVisiveis, pedidoTelao, pedidosObs, resumoTelao, tally, validarComando } from '../src/estado.mjs';
import { ObsFalso } from './falsos.mjs';

test('câmera no ar, na prévia ou livre', () => {
  const t = tally(
    [
      { nome: 'Câmera 1', fonte: 'Câmera 1' },
      { nome: 'Câmera 2', fonte: 'Câmera 2' },
      { nome: 'PTZ', fonte: 'PTZ' },
      { nome: 'Sem fonte' },
    ],
    { fontesPrograma: ['Culto', 'Câmera 1'], fontesPrevia: ['Pregação', 'Câmera 2'] },
  );
  assert.deepEqual(t, { 'Câmera 1': 'programa', 'Câmera 2': 'previa', PTZ: 'livre' });
});

test('fontes visíveis entram em cenas aninhadas e ignoram as desligadas', async () => {
  const obs = new ObsFalso();
  const listar = async (c) => (await obs.call('GetSceneItemList', { sceneName: c })).sceneItems;
  assert.deepEqual(await fontesVisiveis('Culto', listar), ['Culto', 'Câmera 1', 'Letras']);
  assert.deepEqual(await fontesVisiveis('Pregação', listar), ['Pregação', 'Pregador', 'Câmera 2']);
});

test('valida comandos', () => {
  assert.equal(validarComando({ tipo: 'obs.programa', valor: 'Culto' }), null);
  assert.match(validarComando({ tipo: 'obs.programa' }), /valor/);
  assert.match(validarComando({ tipo: 'apagar.tudo' }), /desconhecido/);
});

test('troca de cena: na prévia em modo estúdio, direto no ar sem ele', () => {
  assert.deepEqual(pedidosObs({ tipo: 'obs.previa', valor: 'X' }, { modoEstudio: true }), [
    ['SetCurrentPreviewScene', { sceneName: 'X' }],
  ]);
  assert.deepEqual(pedidosObs({ tipo: 'obs.previa', valor: 'X' }, { modoEstudio: false }), [
    ['SetCurrentProgramScene', { sceneName: 'X' }],
  ]);
  assert.throws(() => pedidosObs({ tipo: 'obs.transicao' }, { modoEstudio: false }), /estúdio/);
});

test('comandos do telão', () => {
  assert.deepEqual(pedidoTelao({ tipo: 'telao.cena', valor: 'pregacao' }), ['POST', '/api/cena/pregacao']);
  assert.deepEqual(pedidoTelao({ tipo: 'holyrics.proximo' }), ['POST', '/api/holyrics/proximo']);
});

test('resumo do telão', () => {
  const r = resumoTelao({
    status: { status: { ligado: true, no_ar: { tipo: 'musica', descricao: 'Grande é o Senhor' } } },
    estado: { tipo: 'musica', texto: 'Grande é o Senhor', rodape: '' },
    cenas: { ativa: 'culto', cenas: [{ id: 'culto', nome: 'Culto', x: 1 }] },
  });
  assert.equal(r.descricao, 'Grande é o Senhor');
  assert.equal(r.cena, 'culto');
  assert.deepEqual(r.cenas, [{ id: 'culto', nome: 'Culto' }]);
});
