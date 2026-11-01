// A ponte entra no Firebase com uma conta comum, marcada como "ponte de mídia"
// pela liderança no app da igreja. As regras só deixam essa conta gravar o
// estado e responder aos comandos.
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import {
  collection,
  doc,
  getFirestore,
  onSnapshot,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

// Mesmo projeto do app da igreja (os dados não são segredo; a proteção é das regras).
const PROJETO = {
  apiKey: 'AIzaSyAkQXbqKT_eyWumMXNKgA10HATZCWw-7m0',
  authDomain: 'agenda-pastoral-15bff.firebaseapp.com',
  projectId: 'agenda-pastoral-15bff',
  appId: '1:41433198968:web:6461637d861b1c0cc8988d',
};

export async function conectarFirebase({ email, senha }) {
  const app = initializeApp(PROJETO);
  const cred = await signInWithEmailAndPassword(getAuth(app), email, senha);
  const db = getFirestore(app);
  return {
    uid: cred.user.uid,
    // mergeFields troca cada parte (obs, telao) inteira: nada de campos antigos presos
    // (ex.: "transmitindo" depois de o OBS desligar), sem apagar a outra parte.
    gravarEstado: (dados) =>
      setDoc(
        doc(db, 'midia/estado'),
        { ...dados, ponteEm: new Date().toISOString() },
        { mergeFields: [...Object.keys(dados), 'ponteEm'] },
      ),
    gravarPrevia: (imagem) => setDoc(doc(db, 'midia/previa'), { programa: imagem, em: new Date().toISOString() }),
    ouvirComandos: (aoChegar) =>
      onSnapshot(query(collection(db, 'midiaComandos'), where('status', '==', 'pendente')), (snap) => {
        for (const ch of snap.docChanges()) {
          if (ch.type === 'added') aoChegar(ch.doc.id, ch.doc.data());
        }
      }),
    responder: (id, status, resultado) =>
      updateDoc(doc(db, 'midiaComandos', id), { status, resultado: resultado ?? null, executadoEm: serverTimestamp() }),
  };
}
