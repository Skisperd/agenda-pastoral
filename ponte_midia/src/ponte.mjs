// Junta tudo: OBS + telão → Firebase (estado e prévia) e comandos do app → OBS/telão.
import { igual, validarComando } from './estado.mjs';
import { executarTelao, lerTelao } from './telao.mjs';

export class Ponte {
  /**
   * @param {object} deps
   * @param {import('./obs.mjs').LigacaoObs} deps.obs
   * @param {object} deps.fb  adaptador do Firebase (ver firebase.mjs)
   * @param {string} deps.telaoUrl
   * @param {object} [deps.previa] {intervaloSegundos, largura, qualidade}
   */
  constructor({ obs, fb, telaoUrl, previa = {}, ler = lerTelao, executar = executarTelao, log = console.log }) {
    this.obs = obs;
    this.fb = fb;
    this.telaoUrl = telaoUrl;
    this.previa = { intervaloSegundos: 4, largura: 480, qualidade: 55, ...previa };
    this.ler = ler;
    this.executarTelao = executar;
    this.log = log;
    this.ultimo = {};
    this.timers = [];
    this.ultimaPrevia = null;
  }

  /** Grava só o que mudou (e um sinal de vida a cada 30 s). */
  async publicar(parte, valor, forcar = false) {
    if (!forcar && igual(this.ultimo[parte], valor)) return;
    this.ultimo[parte] = valor;
    try {
      await this.fb.gravarEstado({ [parte]: valor });
    } catch (e) {
      this.log(`Falha ao gravar ${parte}: ${e.message}`);
    }
  }

  async ciclo() {
    await this.publicar('telao', await this.ler(this.telaoUrl));
  }

  async enviarPrevia() {
    try {
      const img = await this.obs.previaPrograma(this.previa);
      if (img && img !== this.ultimaPrevia) {
        this.ultimaPrevia = img;
        await this.fb.gravarPrevia(img);
      }
    } catch (e) {
      this.log(`Prévia: ${e.message}`);
    }
  }

  /** Executa um comando do app e responde no próprio documento. */
  async comando(id, c) {
    const erro = validarComando(c);
    if (erro) return this.fb.responder(id, 'erro', erro);
    try {
      if (c.tipo.startsWith('obs.')) await this.obs.executar(c);
      else await this.executarTelao(this.telaoUrl, c);
      this.log(`Comando ${c.tipo}${c.valor ? ` (${c.valor})` : ''} de ${c.nome ?? c.uid}.`);
      await this.fb.responder(id, 'feito');
      if (!c.tipo.startsWith('obs.')) await this.ciclo();
    } catch (e) {
      this.log(`Comando ${c.tipo} falhou: ${e.message}`);
      await this.fb.responder(id, 'erro', e.message);
    }
  }

  iniciar() {
    this.obs.aoMudar = (estado) => this.publicar('obs', estado);
    this.pararComandos = this.fb.ouvirComandos((id, c) => this.comando(id, c));
    this.obs.ligar();
    this.timers.push(setInterval(() => this.ciclo(), 1500));
    this.timers.push(setInterval(() => this.enviarPrevia(), this.previa.intervaloSegundos * 1000));
    this.timers.push(setInterval(() => this.fb.gravarEstado({ versao: '1.0.0' }).catch(() => {}), 30000));
    this.ciclo();
  }

  parar() {
    for (const t of this.timers) clearInterval(t);
    this.pararComandos?.();
    return this.obs.parar();
  }
}
