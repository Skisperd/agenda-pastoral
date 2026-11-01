// Grava os estudos de assets/estudos/atos.json direto no Firestore do projeto
// (usado pelo workflow "Importar estudos", com a chave FIREBASE_SERVICE_ACCOUNT).
// Mesmo formato do app: o estudo em estudos/{id} e as orientações, só para quem
// conduz, em estudos/{id}/lider/guias. Não apaga respostas nem materiais.
import { readFileSync } from 'node:fs';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault(), projectId: 'agenda-pastoral-15bff' });
const db = getFirestore();
const serie = JSON.parse(readFileSync(new URL('../../assets/estudos/atos.json', import.meta.url), 'utf8'));

const batch = db.batch();
for (const e of serie.estudos) {
  const perguntas = e.perguntas.map((p) => ({ texto: p.texto, tipo: p.tipo ?? null }));
  batch.set(db.doc(`estudos/${e.id}`), {
    referencia: e.referencia, titulo: e.titulo ?? '', livro: e.livro ?? null, ordem: e.ordem ?? 0,
    resumo: e.resumo ?? null, frase: e.frase ?? null, perguntas, fontes: e.fontes ?? [],
  });
  const guias = {};
  e.perguntas.forEach((p, i) => { if (p.guia) guias[String(i)] = p.guia; });
  batch.set(db.doc(`estudos/${e.id}/lider/guias`), { guias });
  console.log(`${e.referencia}: ${perguntas.length} perguntas`);
}
const pg = await db.doc('config/pg').get();
if (!pg.exists || !pg.data().estudoAtual) {
  batch.set(db.doc('config/pg'), { estudoAtual: 'atos-14-01' }, { merge: true });
  console.log('Estudo da semana: Atos 14:1–7');
}
await batch.commit();
console.log('Pronto.');
