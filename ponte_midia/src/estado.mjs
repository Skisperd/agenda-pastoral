// Regras puras da ponte (sem rede): montar o estado, calcular quem está no ar
// e traduzir os comandos do app em pedidos ao OBS e ao telão.

/** Comandos aceitos do app. Qualquer outro é recusado. */
export const COMANDOS = {
  'obs.programa': { precisaValor: true },
  'obs.previa': { precisaValor: true },
  'obs.transicao': {},
  'obs.transmissao.iniciar': {},
  'obs.transmissao.parar': {},
  'obs.gravacao.iniciar': {},
  'obs.gravacao.parar': {},
  'telao.cena': { precisaValor: true },
  'holyrics.proximo': {},
  'holyrics.anterior': {},
};

/** Valida um comando vindo do Firestore. Devolve a mensagem de erro ou null. */
export function validarComando(c) {
  const def = COMANDOS[c?.tipo];
  if (!def) return `comando desconhecido: ${c?.tipo}`;
  if (def.precisaValor && !(typeof c.valor === 'string' && c.valor.trim())) return 'falta o valor do comando';
  return null;
}

/** Pedido(s) ao OBS para um comando "obs.*": [[requisição, dados], ...]. */
export function pedidosObs(c, { modoEstudio }) {
  switch (c.tipo) {
    case 'obs.programa':
      return [['SetCurrentProgramScene', { sceneName: c.valor }]];
    case 'obs.previa':
      return modoEstudio ? [['SetCurrentPreviewScene', { sceneName: c.valor }]] : [['SetCurrentProgramScene', { sceneName: c.valor }]];
    case 'obs.transicao':
      if (!modoEstudio) throw new Error('o OBS não está em modo estúdio');
      return [['TriggerStudioModeTransition', {}]];
    case 'obs.transmissao.iniciar':
      return [['StartStream', {}]];
    case 'obs.transmissao.parar':
      return [['StopStream', {}]];
    case 'obs.gravacao.iniciar':
      return [['StartRecord', {}]];
    case 'obs.gravacao.parar':
      return [['StopRecord', {}]];
    default:
      throw new Error(`não é comando do OBS: ${c.tipo}`);
  }
}

/** Caminho e método no servidor do telão para um comando "telao.*" / "holyrics.*". */
export function pedidoTelao(c) {
  switch (c.tipo) {
    case 'telao.cena':
      return ['POST', `/api/cena/${encodeURIComponent(c.valor)}`];
    case 'holyrics.proximo':
      return ['POST', '/api/holyrics/proximo'];
    case 'holyrics.anterior':
      return ['POST', '/api/holyrics/anterior'];
    default:
      throw new Error(`não é comando do telão: ${c.tipo}`);
  }
}

/**
 * Situação de cada câmera: "programa" (no ar), "previa" (na prévia do modo
 * estúdio) ou "livre". Uma câmera é a fonte do OBS ligada a ela (ou uma cena).
 */
export function tally(cameras, { fontesPrograma = [], fontesPrevia = [] } = {}) {
  const prog = new Set(fontesPrograma);
  const prev = new Set(fontesPrevia);
  const out = {};
  for (const c of cameras ?? []) {
    if (!c?.nome || !c?.fonte) continue;
    out[c.nome] = prog.has(c.fonte) ? 'programa' : prev.has(c.fonte) ? 'previa' : 'livre';
  }
  return out;
}

/**
 * Fontes visíveis de uma cena, incluindo cenas e grupos aninhados (uma câmera
 * pode estar dentro de uma cena "Pregação" usada noutra cena). [listar] devolve
 * os itens de uma cena/grupo como o OBS (GetSceneItemList).
 */
export async function fontesVisiveis(cena, listar, profundidade = 0, vistos = new Set()) {
  if (!cena || profundidade > 6 || vistos.has(cena)) return [];
  vistos.add(cena);
  const nomes = [cena];
  let itens = [];
  try {
    itens = await listar(cena);
  } catch {
    return nomes;
  }
  for (const i of itens) {
    if (!i.sceneItemEnabled) continue;
    nomes.push(i.sourceName);
    if (i.sourceType === 'OBS_SOURCE_TYPE_SCENE' || i.isGroup) {
      for (const n of await fontesVisiveis(i.sourceName, listar, profundidade + 1, vistos)) nomes.push(n);
    }
  }
  return [...new Set(nomes)];
}

/** Resumo do servidor do telão para o app. */
export function resumoTelao({ status, estado, cenas }) {
  const s = status?.status ?? {};
  return {
    conectado: true,
    holyrics: Boolean(s.ligado),
    erro: s.erro ?? null,
    tipo: s.no_ar?.tipo ?? estado?.tipo ?? 'vazio',
    descricao: s.no_ar?.descricao ?? '',
    leitor: s.no_ar?.leitor ?? null,
    texto: String(estado?.texto ?? '').slice(0, 400),
    rodape: String(estado?.rodape ?? '').slice(0, 200),
    cena: cenas?.ativa ?? null,
    cenas: (cenas?.cenas ?? []).map((c) => ({ id: c.id, nome: c.nome })),
  };
}

/** Igualdade estrutural, para só gravar no Firebase quando algo mudou. */
export function igual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}
