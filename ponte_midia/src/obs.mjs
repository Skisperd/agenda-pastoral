// Ligação ao OBS (obs-websocket v5, embutido no OBS 28+). O OBS fica noutro PC:
// a ponte reconecta sozinha se ele for fechado ou a rede cair.
import { fontesVisiveis, pedidosObs } from './estado.mjs';

const EVENTOS = [
  'CurrentProgramSceneChanged',
  'CurrentPreviewSceneChanged',
  'SceneListChanged',
  'StudioModeStateChanged',
  'StreamStateChanged',
  'RecordStateChanged',
  'SceneItemEnableStateChanged',
  'SceneItemListReindexed',
];

export class LigacaoObs {
  /**
   * @param {object} obs instância do OBSWebSocket (ou um falso, nos testes)
   * @param {{url: string, senha?: string}} cfg
   * @param {(estado: object) => void} aoMudar
   */
  constructor(obs, cfg, aoMudar, log = console.log) {
    this.obs = obs;
    this.cfg = cfg;
    this.aoMudar = aoMudar;
    this.log = log;
    this.conectado = false;
    this.estado = { conectado: false };
    this._parar = false;
    for (const e of EVENTOS) obs.on(e, () => this.atualizar());
    obs.on('ConnectionClosed', (err) => {
      if (this.conectado) this.log(`OBS desconectado (${err?.message ?? 'sem motivo'}).`);
      this.conectado = false;
      this.estado = { conectado: false, erro: err?.message ?? null };
      this.aoMudar(this.estado);
      this._tentarDeNovo();
    });
  }

  async ligar() {
    if (this._parar) return;
    try {
      await this.obs.connect(this.cfg.url, this.cfg.senha || undefined);
      this.conectado = true;
      this.log(`OBS conectado em ${this.cfg.url}.`);
      await this.atualizar();
    } catch (e) {
      this.conectado = false;
      this.estado = { conectado: false, erro: `não foi possível conectar ao OBS (${e.message})` };
      this.aoMudar(this.estado);
      this._tentarDeNovo();
    }
  }

  _tentarDeNovo() {
    if (this._parar || this._timer) return;
    this._timer = setTimeout(() => {
      this._timer = null;
      this.ligar();
    }, 5000);
  }

  parar() {
    this._parar = true;
    clearTimeout(this._timer);
    return this.obs.disconnect?.();
  }

  /** Relê tudo o que o app mostra. Chamado a cada evento do OBS. */
  async atualizar() {
    if (!this.conectado) return this.estado;
    try {
      const [cenas, estudio, stream, rec] = await Promise.all([
        this.obs.call('GetSceneList'),
        this.obs.call('GetStudioModeEnabled'),
        this.obs.call('GetStreamStatus'),
        this.obs.call('GetRecordStatus'),
      ]);
      const listar = async (cena) => {
        try {
          return (await this.obs.call('GetSceneItemList', { sceneName: cena })).sceneItems;
        } catch {
          return (await this.obs.call('GetGroupSceneItemList', { sceneName: cena })).sceneItems;
        }
      };
      const programa = cenas.currentProgramSceneName;
      const previa = estudio.studioModeEnabled ? cenas.currentPreviewSceneName : null;
      this.estado = {
        conectado: true,
        erro: null,
        programa,
        previa,
        modoEstudio: estudio.studioModeEnabled,
        // O OBS lista de baixo para cima; o app mostra na ordem do OBS.
        cenas: [...cenas.scenes].sort((a, b) => b.sceneIndex - a.sceneIndex).map((s) => s.sceneName),
        fontesPrograma: await fontesVisiveis(programa, listar),
        fontesPrevia: previa ? await fontesVisiveis(previa, listar) : [],
        transmitindo: stream.outputActive,
        transmissaoMs: stream.outputDuration ?? 0,
        gravando: rec.outputActive,
        gravacaoMs: rec.outputDuration ?? 0,
      };
    } catch (e) {
      this.estado = { ...this.estado, erro: e.message };
    }
    this.aoMudar(this.estado);
    return this.estado;
  }

  /** Executa um comando "obs.*" do app. */
  async executar(comando) {
    if (!this.conectado) throw new Error('OBS desconectado');
    for (const [req, dados] of pedidosObs(comando, { modoEstudio: Boolean(this.estado.modoEstudio) })) {
      await this.obs.call(req, dados);
    }
    await this.atualizar();
  }

  /** Imagem do programa (JPEG em data URL), ou null. */
  async previaPrograma({ largura = 480, qualidade = 55 } = {}) {
    if (!this.conectado || !this.estado.programa) return null;
    const r = await this.obs.call('GetSourceScreenshot', {
      sourceName: this.estado.programa,
      imageFormat: 'jpg',
      imageWidth: largura,
      imageCompressionQuality: qualidade,
    });
    return r.imageData;
  }
}
