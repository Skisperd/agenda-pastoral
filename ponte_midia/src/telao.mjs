// Leitura e comandos do servidor do telão (system-web-holyrics, porta 8765).
import { pedidoTelao, resumoTelao } from './estado.mjs';

async function json(url, opts = {}) {
  const r = await fetch(url, { ...opts, signal: AbortSignal.timeout(3000) });
  if (!r.ok) {
    let msg = `${r.status} em ${url}`;
    try {
      msg = (await r.json()).erro || msg;
    } catch {}
    throw new Error(msg);
  }
  return r.json();
}

/** Estado atual do telão; `{conectado: false}` se o servidor não responder. */
export async function lerTelao(base) {
  try {
    const [status, estado, cenas] = await Promise.all([
      json(`${base}/api/status`),
      json(`${base}/estado`),
      json(`${base}/api/cenas`),
    ]);
    return resumoTelao({ status, estado, cenas });
  } catch (e) {
    return { conectado: false, erro: `servidor do telão não respondeu (${e.message})` };
  }
}

export async function executarTelao(base, comando) {
  const [metodo, caminho] = pedidoTelao(comando);
  const r = await json(`${base}${caminho}`, { method: metodo, headers: { 'Content-Type': 'application/json' }, body: '{}' });
  if (r && r.ok === false) throw new Error(r.erro || 'o telão recusou o comando');
  return r;
}
