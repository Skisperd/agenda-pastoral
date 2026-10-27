// Testes das regras de segurança no emulador do Firestore (grátis, local).
// Rode com: npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, updateDoc, where, writeBatch,
} from 'firebase/firestore';

let env;
const user = (role, extra = {}) => ({ name: role, email: `${role}@x`, role, ...extra });
const visit = (uid, memberId, extra = {}) => ({
  uid, memberId, memberName: memberId, neighborhood: 'y', lat: 0, lng: 0,
  start: '2026-10-06T17:00', end: '2026-10-06T18:00', status: 'pendente', createdAt: 'x', ...extra,
});
const slot = (visitId) => ({ visitId, start: '2026-10-06T17:00', end: '2026-10-06T18:00', neighborhood: 'y', lat: 0, lng: 0 });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-agenda',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const docs = {
      'config/app': { bootstrappedAt: 'x' },
      'users/admin': user('admin'),
      'users/pastor': user('pastor', { memberId: 'm-pastor' }),
      'users/presb': user('presbitero'),
      'users/lider': user('liderDiaconia', { memberId: 'm-lider' }),
      'users/diac': user('diacono', { memberId: 'm-diac' }),
      'users/joao': user('membro', { memberId: 'm-joao' }),
      'users/maria': user('membro', { memberId: 'm-maria' }),
      'users/novo': user('pending'),
      'members/m-pastor': { name: 'Pastor', oficio: 'pastor', phone: '1' },
      'members/m-lider': { name: 'Líder', oficio: 'diacono', diaconia: true },
      'members/m-diac': { name: 'Diácono', oficio: 'diacono', diaconia: true },
      'members/m-aux': { name: 'Auxiliar', diaconia: true, address: 'rua secreta' },
      'members/m-joao': { name: 'João', situacao: 'comungante', address: 'rua 1' },
      'members/m-maria': { name: 'Maria', situacao: 'comungante', address: 'rua 2' },
      'pastoralNotes/m-joao': { text: 'reservado' },
      'visits/v-joao': visit('joao', 'm-joao'),
      'agenda/2026-10-06': { slots: [slot('v-joao')] },
      'notifications/n1': { message: 'Nova visita', createdAt: 'x', read: false },
      'events/pub': { title: 'Retiro', published: true, registration: true },
      'events/draft': { title: 'Rascunho', published: false },
      'events/pub/tasks/t1': { title: 'Reservar sítio' },
      'diaconia/e1': { date: '2026-11-01', published: true, assignments: { ofertorio: ['m-diac'] }, confirmations: {} },
      'diaconia/e2': { date: '2026-11-08', published: false, assignments: {} },
      'oracao/pub': { text: 'Pela família', authorUid: 'maria', private: false, answered: false, praying: [] },
      'oracao/priv': { text: 'Reservado', authorUid: 'maria', private: true, answered: false, praying: [] },
    };
    for (const [path, data] of Object.entries(docs)) await setDoc(doc(db, path), data);
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('contas', () => {
  test('nova conta entra aguardando aprovação', () =>
    assertSucceeds(setDoc(doc(as('x'), 'users/x'), user('pending'))));
  test('ninguém se cria como admin depois do início', () =>
    assertFails(setDoc(doc(as('x'), 'users/x'), user('admin'))));
  test('membro não muda o próprio perfil', () =>
    assertFails(updateDoc(doc(as('joao'), 'users/joao'), { role: 'pastor' })));
  test('membro não se vincula ao cadastro de outra pessoa', () =>
    assertFails(updateDoc(doc(as('joao'), 'users/joao'), { memberId: 'm-pastor' })));
  test('membro marca as datas em que não pode servir', () =>
    assertSucceeds(updateDoc(doc(as('diac'), 'users/diac'), { unavailable: ['2026-11-01'] })));
  test('membro não lê a conta de outro', () => assertFails(getDoc(doc(as('joao'), 'users/maria'))));
  test('coordenação da escala lê as contas (indisponibilidades)', () =>
    assertSucceeds(getDocs(collection(as('lider'), 'users'))));
  test('secretaria aprova e define o perfil', () =>
    assertSucceeds(updateDoc(doc(as('admin'), 'users/novo'), { role: 'membro' })));
  test('quem aguarda aprovação não lê nada da igreja', () =>
    assertFails(getDocs(collection(as('novo'), 'weekly'))));
  test('sem login não lê nada', () => assertFails(getDoc(doc(anon(), 'events/pub'))));
});

describe('membros', () => {
  test('membro vê os contatos da liderança', () =>
    assertSucceeds(getDocs(query(collection(as('joao'), 'members'), where('oficio', 'in', ['pastor', 'presbitero', 'diacono'])))));
  test('membro não lê o rol completo', () => assertFails(getDocs(collection(as('joao'), 'members'))));
  test('membro não lê o cadastro de outro membro', () => assertFails(getDoc(doc(as('joao'), 'members/m-maria'))));
  test('membro lê e edita o próprio contato', async () => {
    await assertSucceeds(getDoc(doc(as('joao'), 'members/m-joao')));
    await assertSucceeds(updateDoc(doc(as('joao'), 'members/m-joao'), { phone: '11999', address: 'rua nova' }));
  });
  test('membro não muda a própria situação nem o ofício', () =>
    assertFails(updateDoc(doc(as('joao'), 'members/m-joao'), { oficio: 'presbitero' })));
  test('presbítero lê e edita o rol', async () => {
    await assertSucceeds(getDocs(collection(as('presb'), 'members')));
    await assertSucceeds(updateDoc(doc(as('presb'), 'members/m-joao'), { situacao: 'inativo' }));
  });
  test('coordenação da escala lê quem serve na diaconia, mas não o resto', async () => {
    await assertSucceeds(getDocs(query(collection(as('lider'), 'members'), where('diaconia', 'in', [true]))));
    await assertFails(getDoc(doc(as('lider'), 'members/m-joao')));
  });
  test('sem cadastro, a pessoa cria o próprio como visitante e se vincula', async () => {
    const db = as('semcad');
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users/semcad'), user('membro')));
    const b = writeBatch(db);
    b.set(doc(db, 'members/semcad'), { name: 'Sem', situacao: 'visitante', oficio: null, diaconia: false, selfRegistered: true, ministries: [] });
    b.set(doc(db, 'users/semcad'), { memberId: 'semcad' }, { merge: true });
    await assertSucceeds(b.commit());
  });
  test('ninguém se cadastra sozinho como membro ou oficial', () =>
    assertFails(setDoc(doc(as('joao'), 'members/joao'), { name: 'J', situacao: 'comungante', oficio: 'pastor', selfRegistered: true, ministries: [] })));
  test('anotações pastorais: só pastor e secretaria', async () => {
    await assertSucceeds(getDoc(doc(as('pastor'), 'pastoralNotes/m-joao')));
    await assertFails(getDoc(doc(as('presb'), 'pastoralNotes/m-joao')));
    await assertFails(getDoc(doc(as('joao'), 'pastoralNotes/m-joao')));
  });
});

describe('agenda pastoral', () => {
  test('membro vê só as próprias visitas', async () => {
    await assertSucceeds(getDocs(query(collection(as('joao'), 'visits'), where('uid', 'in', ['joao']))));
    await assertFails(getDoc(doc(as('maria'), 'visits/v-joao')));
  });
  test('membro marca visita para o próprio cadastro, aguardando confirmação', () =>
    assertSucceeds(setDoc(doc(as('maria'), 'visits/v-maria'), visit('maria', 'm-maria'))));
  test('membro não marca visita em nome de outro', () =>
    assertFails(setDoc(doc(as('maria'), 'visits/v2'), visit('maria', 'm-joao'))));
  test('membro não marca visita já confirmada', () =>
    assertFails(setDoc(doc(as('maria'), 'visits/v3'), visit('maria', 'm-maria', { status: 'confirmada' }))));
  test('membro só cancela a própria visita', async () => {
    await assertSucceeds(updateDoc(doc(as('joao'), 'visits/v-joao'), { status: 'cancelada' }));
    await assertFails(updateDoc(doc(as('maria'), 'visits/v-joao'), { status: 'cancelada' }));
  });
  test('membro não confirma a visita', () =>
    assertFails(updateDoc(doc(as('joao'), 'visits/v-joao'), { status: 'confirmada' })));
  test('ocupação: acrescenta um horário por vez', async () => {
    await assertSucceeds(setDoc(doc(as('maria'), 'agenda/2026-10-06'), { slots: [slot('v-joao'), slot('v-maria')] }));
    await assertFails(setDoc(doc(as('maria'), 'agenda/2026-10-06'), { slots: [slot('a'), slot('b'), slot('c'), slot('d')] }));
  });
  test('ocupação não aceita dados pessoais', () =>
    assertFails(setDoc(doc(as('maria'), 'agenda/2026-10-07'), { slots: [slot('x')], memberName: 'Maria' })));
  test('somente o pastor libera horários', async () => {
    await assertSucceeds(setDoc(doc(as('pastor'), 'availability/a1'), { start: '2026-10-06T17:00', end: '2026-10-06T21:00' }));
    await assertFails(setDoc(doc(as('presb'), 'availability/a2'), { start: '2026-10-06T17:00', end: '2026-10-06T21:00' }));
  });
  test('membro avisa o pastor, mas não lê os avisos', async () => {
    await assertSucceeds(setDoc(doc(as('joao'), 'notifications/n2'), { message: 'oi', createdAt: 'x', read: false }));
    await assertFails(getDoc(doc(as('joao'), 'notifications/n1')));
  });
});

describe('eventos', () => {
  test('membro vê só eventos publicados', async () => {
    await assertSucceeds(getDocs(query(collection(as('joao'), 'events'), where('published', 'in', [true]))));
    await assertFails(getDoc(doc(as('joao'), 'events/draft')));
  });
  test('liderança vê rascunhos e cria eventos', async () => {
    await assertSucceeds(getDoc(doc(as('presb'), 'events/draft')));
    await assertSucceeds(setDoc(doc(as('presb'), 'events/novo'), { title: 'Culto', published: false }));
    await assertFails(setDoc(doc(as('joao'), 'events/x'), { title: 'Meu', published: true }));
  });
  test('membro se inscreve só em nome próprio e sem marcar presença', async () => {
    await assertSucceeds(setDoc(doc(as('joao'), 'events/pub/registrations/joao'), { name: 'João', guests: 1, createdAt: 'x', checkedIn: false }));
    await assertFails(setDoc(doc(as('joao'), 'events/pub/registrations/maria'), { name: 'Maria', guests: 0, createdAt: 'x' }));
    await assertFails(setDoc(doc(as('maria'), 'events/pub/registrations/maria'), { name: 'Maria', guests: 0, createdAt: 'x', checkedIn: true }));
  });
  test('não há inscrição em rascunho', () =>
    assertFails(setDoc(doc(as('joao'), 'events/draft/registrations/joao'), { name: 'João', guests: 0, createdAt: 'x' })));
  test('tarefas e orçamento: só a liderança', async () => {
    await assertSucceeds(getDocs(collection(as('presb'), 'events/pub/tasks')));
    await assertFails(getDocs(collection(as('joao'), 'events/pub/tasks')));
    await assertFails(getDocs(collection(as('joao'), 'events/pub/budget')));
  });
});

describe('escala diaconal', () => {
  test('diácono vê só escalas publicadas', async () => {
    await assertSucceeds(getDocs(query(collection(as('diac'), 'diaconia'), where('published', 'in', [true]))));
    await assertFails(getDoc(doc(as('diac'), 'diaconia/e2')));
  });
  test('diácono confirma a própria presença', () =>
    assertSucceeds(setDoc(doc(as('diac'), 'diaconia/e1'), { confirmations: { 'm-diac': { status: 'confirmado' } } }, { merge: true })));
  test('diácono não responde por outro nem muda a escala', async () => {
    await assertFails(setDoc(doc(as('diac'), 'diaconia/e1'), { confirmations: { 'm-lider': { status: 'confirmado' } } }, { merge: true }));
    await assertFails(updateDoc(doc(as('diac'), 'diaconia/e1'), { assignments: { ofertorio: ['m-lider'] } }));
  });
  test('coordenação cria, edita e publica', async () => {
    await assertSucceeds(setDoc(doc(as('lider'), 'diaconia/e3'), { date: '2026-11-15', published: true, assignments: {} }));
    await assertSucceeds(updateDoc(doc(as('lider'), 'diaconia/e2'), { published: true }));
  });
});

describe('oração', () => {
  test('pedidos reservados: só conselho e autor', async () => {
    await assertFails(getDoc(doc(as('joao'), 'oracao/priv')));
    await assertSucceeds(getDoc(doc(as('maria'), 'oracao/priv')));
    await assertSucceeds(getDoc(doc(as('presb'), 'oracao/priv')));
  });
  test('qualquer membro lê os públicos', () =>
    assertSucceeds(getDocs(query(collection(as('joao'), 'oracao'), where('private', 'in', [false])))));
  test('"vou orar": cada um marca só a si mesmo', async () => {
    await assertSucceeds(updateDoc(doc(as('joao'), 'oracao/pub'), { praying: ['joao'] }));
    await assertFails(updateDoc(doc(as('joao'), 'oracao/pub'), { praying: ['joao', 'maria'] }));
  });
  test('não se publica pedido em nome de outro', () =>
    assertFails(setDoc(doc(as('joao'), 'oracao/x'), { text: 'a', authorUid: 'maria', private: false, answered: false, praying: [] })));
  test('autor apaga o próprio pedido; outro membro não', async () => {
    await assertFails(deleteDoc(doc(as('joao'), 'oracao/pub')));
    await assertSucceeds(deleteDoc(doc(as('maria'), 'oracao/pub')));
  });
});

describe('primeiro acesso', () => {
  test('projeto vazio: a primeira conta vira admin junto com a marca', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'config/app')));
    const db = as('primeiro');
    const b = writeBatch(db);
    b.set(doc(db, 'users/primeiro'), user('admin'));
    b.set(doc(db, 'config/app'), { bootstrappedAt: 'x' });
    await assertSucceeds(b.commit());
  });
  test('pastor da versão anterior marca o início', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'config/app')));
    await assertSucceeds(setDoc(doc(as('pastor'), 'config/app'), { bootstrappedAt: 'x' }));
  });
  test('membro não marca o início', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'config/app')));
    await assertFails(setDoc(doc(as('joao'), 'config/app'), { bootstrappedAt: 'x' }));
  });
});
