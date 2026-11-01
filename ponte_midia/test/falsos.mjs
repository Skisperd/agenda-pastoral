// OBS falso: responde às requisições usadas pela ponte e guarda as chamadas.
export class ObsFalso {
  constructor() {
    this.handlers = {};
    this.chamadas = [];
    this.programa = 'Culto';
    this.previa = 'Pregação';
    this.estudio = true;
    this.cenas = {
      Culto: [
        { sourceName: 'Câmera 1', sceneItemEnabled: true, sourceType: 'OBS_SOURCE_TYPE_INPUT' },
        { sourceName: 'Letras', sceneItemEnabled: true, sourceType: 'OBS_SOURCE_TYPE_INPUT' },
        { sourceName: 'Câmera 3', sceneItemEnabled: false, sourceType: 'OBS_SOURCE_TYPE_INPUT' },
      ],
      Pregação: [{ sourceName: 'Pregador', sceneItemEnabled: true, sourceType: 'OBS_SOURCE_TYPE_SCENE' }],
      Pregador: [{ sourceName: 'Câmera 2', sceneItemEnabled: true, sourceType: 'OBS_SOURCE_TYPE_INPUT' }],
    };
    this.transmitindo = false;
  }
  on(evento, fn) {
    this.handlers[evento] = fn;
  }
  emitir(evento, dados) {
    this.handlers[evento]?.(dados);
  }
  async connect(url) {
    if (url.includes('falha')) throw new Error('recusado');
  }
  async disconnect() {}
  async call(req, dados = {}) {
    this.chamadas.push([req, dados]);
    switch (req) {
      case 'GetSceneList':
        return {
          currentProgramSceneName: this.programa,
          currentPreviewSceneName: this.previa,
          scenes: Object.keys(this.cenas).map((n, i) => ({ sceneName: n, sceneIndex: i })),
        };
      case 'GetStudioModeEnabled':
        return { studioModeEnabled: this.estudio };
      case 'GetStreamStatus':
        return { outputActive: this.transmitindo, outputDuration: this.transmitindo ? 61000 : 0 };
      case 'GetRecordStatus':
        return { outputActive: false, outputDuration: 0 };
      case 'GetSceneItemList':
        if (!this.cenas[dados.sceneName]) throw new Error('cena não existe');
        return { sceneItems: this.cenas[dados.sceneName] };
      case 'GetGroupSceneItemList':
        throw new Error('não é grupo');
      case 'SetCurrentProgramScene':
        this.programa = dados.sceneName;
        return {};
      case 'SetCurrentPreviewScene':
        this.previa = dados.sceneName;
        return {};
      case 'TriggerStudioModeTransition':
        [this.programa, this.previa] = [this.previa, this.programa];
        return {};
      case 'StartStream':
        this.transmitindo = true;
        return {};
      case 'GetSourceScreenshot':
        return { imageData: `data:image/jpg;base64,${this.programa}` };
      default:
        return {};
    }
  }
}

/** Firebase falso: guarda o que a ponte gravaria. */
export class FbFalso {
  constructor() {
    this.estado = {};
    this.gravacoes = 0;
    this.previas = [];
    this.respostas = [];
  }
  async gravarEstado(d) {
    this.gravacoes++;
    Object.assign(this.estado, d);
  }
  async gravarPrevia(img) {
    this.previas.push(img);
  }
  ouvirComandos(fn) {
    this.enviar = fn;
    return () => {};
  }
  async responder(id, status, resultado) {
    this.respostas.push({ id, status, resultado });
  }
}
