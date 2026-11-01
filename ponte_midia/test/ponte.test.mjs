import assert from 'node:assert/strict';
import http from 'node:http';
import { test } from 'node:test';

import { LigacaoObs } from '../src/obs.mjs';
import { Ponte } from '../src/ponte.mjs';
import { executarTelao, lerTelao } from '../src/telao.mjs';
import { FbFalso, ObsFalso } from './falsos.mjs';

const silencio = () => {};

async function montar() {
  const obsFalso = new ObsFalso();
  const fb = new FbFalso();
  const telao = [];
  const obs = new LigacaoObs(obsFalso, { url: 'ws://obs:4455' }, silencio, silencio);
  const ponte = new Ponte({
    obs,
    fb,
    telaoUrl: 'http://telao',
    ler: async () => ({ conectado: true, cena: 'culto' }),
    executar: async (_url, c) => telao.push(c),
    log: silencio,
  });
  obs.aoMudar = (e) => ponte.publicar('obs', e);
  await obs.ligar();
  return { obsFalso, fb, telao, obs, ponte };
}

test('publica o estado do OBS com cenas, prévia e fontes', async () => {
  const { fb } = await montar();
  assert.equal(fb.estado.obs.programa, 'Culto');
  assert.equal(fb.estado.obs.previa, 'Pregação');
  assert.ok(fb.estado.obs.fontesPrevia.includes('Câmera 2'));
  assert.deepEqual(fb.estado.obs.cenas, ['Pregador', 'Pregação', 'Culto']);
});

test('não grava de novo quando nada mudou', async () => {
  const { fb, ponte } = await montar();
  const antes = fb.gravacoes;
  await ponte.ciclo();
  await ponte.ciclo();
  assert.equal(fb.gravacoes, antes + 1);
});

test('comandos do app chegam ao OBS e ao telão, e são respondidos', async () => {
  const { obsFalso, fb, telao, ponte } = await montar();
  await ponte.comando('c1', { tipo: 'obs.transicao', uid: 'u' });
  assert.equal(obsFalso.programa, 'Pregação');
  assert.equal(fb.estado.obs.programa, 'Pregação', 'estado atualizado após o comando');
  await ponte.comando('c2', { tipo: 'telao.cena', valor: 'pregacao', uid: 'u' });
  assert.deepEqual(telao.at(-1), { tipo: 'telao.cena', valor: 'pregacao', uid: 'u' });
  await ponte.comando('c3', { tipo: 'rm -rf', uid: 'u' });
  assert.deepEqual(
    fb.respostas.map((r) => [r.id, r.status]),
    [
      ['c1', 'feito'],
      ['c2', 'feito'],
      ['c3', 'erro'],
    ],
  );
});

test('prévia só é enviada quando a imagem muda', async () => {
  const { obsFalso, fb, ponte } = await montar();
  await ponte.enviarPrevia();
  await ponte.enviarPrevia();
  obsFalso.programa = 'Pregador';
  await ponte.obs.atualizar();
  await ponte.enviarPrevia();
  assert.equal(fb.previas.length, 2);
});

test('OBS fora do ar: estado desconectado e comando com erro', async () => {
  const fb = new FbFalso();
  const obs = new LigacaoObs(new ObsFalso(), { url: 'ws://falha:4455' }, silencio, silencio);
  const ponte = new Ponte({ obs, fb, telaoUrl: 'x', ler: async () => ({}), log: silencio });
  obs.aoMudar = (e) => ponte.publicar('obs', e);
  await obs.ligar();
  obs.parar();
  assert.equal(fb.estado.obs.conectado, false);
  await ponte.comando('c1', { tipo: 'obs.programa', valor: 'Culto' });
  assert.equal(fb.respostas[0].status, 'erro');
});

test('lê o servidor do telão e envia comandos (HTTP real)', async () => {
  const pedidos = [];
  const srv = http.createServer((req, res) => {
    pedidos.push(`${req.method} ${req.url}`);
    const corpo = {
      '/api/status': { ok: true, status: { ligado: true, no_ar: { tipo: 'biblia', descricao: 'Atos 14:3' } } },
      '/estado': { tipo: 'biblia', texto: 'Por isso permaneceram bastante tempo' },
      '/api/cenas': { ok: true, ativa: 'culto', cenas: [{ id: 'culto', nome: 'Culto' }] },
      '/api/cena/pregacao': { ok: true, ativa: 'pregacao' },
      '/api/cena/xx': { ok: false, erro: 'cena não encontrada: xx' },
    }[req.url];
    res.writeHead(corpo?.ok === false ? 404 : 200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(corpo ?? {}));
  });
  await new Promise((r) => srv.listen(0, r));
  const base = `http://127.0.0.1:${srv.address().port}`;
  try {
    const t = await lerTelao(base);
    assert.equal(t.descricao, 'Atos 14:3');
    assert.equal(t.cena, 'culto');
    await executarTelao(base, { tipo: 'telao.cena', valor: 'pregacao' });
    assert.ok(pedidos.includes('POST /api/cena/pregacao'));
    await assert.rejects(executarTelao(base, { tipo: 'telao.cena', valor: 'xx' }), /cena não encontrada/);
    assert.equal((await lerTelao('http://127.0.0.1:1')).conectado, false);
  } finally {
    srv.close();
  }
});
