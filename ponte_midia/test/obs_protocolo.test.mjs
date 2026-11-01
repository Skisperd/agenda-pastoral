// A ponte com a biblioteca real (obs-websocket-js) contra um servidor que fala
// o protocolo do obs-websocket v5 (Hello → Identify → Identified → requisições).
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { OBSWebSocket } from 'obs-websocket-js/json';
import { WebSocketServer } from 'ws';

import { LigacaoObs } from '../src/obs.mjs';
import { ObsFalso } from './falsos.mjs';

test('conecta, lê o estado e troca de cena pelo protocolo real', async () => {
  const falso = new ObsFalso();
  const wss = new WebSocketServer({ port: 0 });
  wss.on('connection', (ws) => {
    ws.send(JSON.stringify({ op: 0, d: { obsWebSocketVersion: '5.5.0', rpcVersion: 1 } }));
    ws.on('message', async (raw) => {
      const m = JSON.parse(raw.toString());
      if (m.op === 1) ws.send(JSON.stringify({ op: 2, d: { negotiatedRpcVersion: 1 } }));
      if (m.op === 6) {
        const { requestType, requestId, requestData } = m.d;
        try {
          const responseData = await falso.call(requestType, requestData ?? {});
          ws.send(JSON.stringify({ op: 7, d: { requestType, requestId, requestStatus: { result: true, code: 100 }, responseData } }));
        } catch (e) {
          ws.send(JSON.stringify({ op: 7, d: { requestType, requestId, requestStatus: { result: false, code: 600, comment: e.message } } }));
        }
      }
    });
  });
  await new Promise((r) => wss.on('listening', r));
  const estados = [];
  const obs = new LigacaoObs(new OBSWebSocket(), { url: `ws://127.0.0.1:${wss.address().port}` }, (e) => estados.push(e), () => {});
  try {
    await obs.ligar();
    assert.equal(obs.estado.conectado, true);
    assert.equal(obs.estado.programa, 'Culto');
    assert.ok(obs.estado.fontesPrevia.includes('Câmera 2'));
    await obs.executar({ tipo: 'obs.transicao' });
    assert.equal(obs.estado.programa, 'Pregação');
    assert.match(await obs.previaPrograma(), /^data:image\/jpg;base64,/);
  } finally {
    await obs.parar();
    wss.close();
  }
});

test('autentica com a senha do OBS e recusa senha errada', async () => {
  const { createHash } = await import('node:crypto');
  const b64sha = (s) => createHash('sha256').update(s).digest('base64');
  const salt = 'sal123', challenge = 'desafio456', senha = 'segredo';
  const esperado = b64sha(b64sha(senha + salt) + challenge);
  const falso = new ObsFalso();
  const wss = new WebSocketServer({ port: 0 });
  wss.on('connection', (ws) => {
    ws.send(JSON.stringify({ op: 0, d: { obsWebSocketVersion: '5.5.0', rpcVersion: 1, authentication: { challenge, salt } } }));
    ws.on('message', async (raw) => {
      const m = JSON.parse(raw.toString());
      if (m.op === 1) {
        if (m.d.authentication !== esperado) return ws.close(4009, 'Authentication failed.');
        ws.send(JSON.stringify({ op: 2, d: { negotiatedRpcVersion: 1 } }));
      }
      if (m.op === 6) {
        const { requestType, requestId, requestData } = m.d;
        const responseData = await falso.call(requestType, requestData ?? {});
        ws.send(JSON.stringify({ op: 7, d: { requestType, requestId, requestStatus: { result: true, code: 100 }, responseData } }));
      }
    });
  });
  await new Promise((r) => wss.on('listening', r));
  const url = `ws://127.0.0.1:${wss.address().port}`;
  const certa = new LigacaoObs(new OBSWebSocket(), { url, senha }, () => {}, () => {});
  const errada = new LigacaoObs(new OBSWebSocket(), { url, senha: 'x' }, () => {}, () => {});
  try {
    await certa.ligar();
    assert.equal(certa.estado.conectado, true);
    await errada.ligar();
    assert.equal(errada.estado.conectado, false);
    assert.match(errada.estado.erro, /OBS/);
  } finally {
    await certa.parar();
    await errada.parar();
    wss.close();
  }
});
