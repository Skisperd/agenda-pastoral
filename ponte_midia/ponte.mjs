// Ponte de mídia da Pedras Vivas: rode no computador da igreja (node ponte.mjs).
// Lê config.json nesta pasta (copie de config.exemplo.json).
import { readFileSync } from 'node:fs';
import { OBSWebSocket } from 'obs-websocket-js/json';

import { conectarFirebase } from './src/firebase.mjs';
import { LigacaoObs } from './src/obs.mjs';
import { Ponte } from './src/ponte.mjs';

const cfg = JSON.parse(readFileSync(new URL('./config.json', import.meta.url), 'utf8'));
const log = (m) => console.log(`[${new Date().toLocaleTimeString('pt-PT')}] ${m}`);

let fb;
for (;;) {
  try {
    fb = await conectarFirebase(cfg.firebase);
    log('Firebase conectado.');
    break;
  } catch (e) {
    log(`Não foi possível entrar no Firebase (${e.code ?? e.message}). Nova tentativa em 30 s.`);
    await new Promise((r) => setTimeout(r, 30000));
  }
}

const obs = new LigacaoObs(new OBSWebSocket(), cfg.obs, () => {}, log);
const ponte = new Ponte({ obs, fb, telaoUrl: cfg.telao?.url ?? 'http://localhost:8765', previa: cfg.previa, log });
ponte.iniciar();
log('Ponte de mídia a correr. Ctrl+C para parar.');

process.on('SIGINT', async () => {
  await ponte.parar();
  process.exit(0);
});
