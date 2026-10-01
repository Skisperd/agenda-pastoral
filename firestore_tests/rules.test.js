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
  addDoc, collection, deleteDoc, doc, GeoPoint, getDoc, getDocs, query,
  serverTimestamp, setDoc, Timestamp, updateDoc, where,
} from 'firebase/firestore';

let env;
const at = (h) => Timestamp.fromDate(new Date(2026, 9, 6, h));
const member = (name) => ({ name, phone: '1', address: 'x', neighborhood: 'y', location: new GeoPoint(0, 0) });
const visit = (memberId, extra = {}) => ({
  memberId, memberName: memberId, memberPhone: '1', neighborhood: 'y',
  location: new GeoPoint(0, 0), start: at(17), end: at(18), status: 'pending',
  createdAt: serverTimestamp(), ...extra,
});
const slot = (visitId) => ({ visitId, start: at(17), end: at(18), neighborhood: 'y', area: new GeoPoint(0, 0) });

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
    await setDoc(doc(db, 'users/pastor'), { ...member('Pastor'), role: 'pastor' });
    await setDoc(doc(db, 'users/joao'), { ...member('João'), role: 'member' });
    await setDoc(doc(db, 'users/maria'), { ...member('Maria'), role: 'member' });
    await setDoc(doc(db, 'visits/v-joao'), visit('joao'));
    await setDoc(doc(db, 'agenda/2026-10-06'), { slots: [slot('v-joao')] });
    await setDoc(doc(db, 'notifications/n1'), { message: 'Nova visita', createdAt: at(8), read: false });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

describe('cadastro', () => {
  test('membro cria o próprio cadastro como member', () =>
    assertSucceeds(setDoc(doc(as('novo'), 'users/novo'), { ...member('Novo'), role: 'member' })));
  test('ninguém se cadastra como pastor', () =>
    assertFails(setDoc(doc(as('novo'), 'users/novo'), { ...member('Novo'), role: 'pastor' })));
  test('membro não se promove a pastor', () =>
    assertFails(updateDoc(doc(as('joao'), 'users/joao'), { role: 'pastor' })));
  test('membro edita o próprio endereço', () =>
    assertSucceeds(updateDoc(doc(as('joao'), 'users/joao'), { address: 'nova rua' })));
  test('membro não lê o cadastro de outro', () =>
    assertFails(getDoc(doc(as('maria'), 'users/joao'))));
  test('pastor lê qualquer cadastro', () =>
    assertSucceeds(getDoc(doc(as('pastor'), 'users/joao'))));
  test('visitante sem login não lê nada', () =>
    assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'agenda/2026-10-06'))));
});

describe('disponibilidade', () => {
  test('membro vê as janelas', () => assertSucceeds(getDocs(collection(as('joao'), 'availability'))));
  test('membro não cria janela', () =>
    assertFails(addDoc(collection(as('joao'), 'availability'), { start: at(17), end: at(22) })));
  test('pastor cria janela', () =>
    assertSucceeds(addDoc(collection(as('pastor'), 'availability'), { start: at(17), end: at(22) })));
});

describe('visitas', () => {
  test('membro lê as próprias visitas', () =>
    assertSucceeds(getDocs(query(collection(as('joao'), 'visits'), where('memberId', '==', 'joao')))));
  test('membro não lê visitas dos outros', () => assertFails(getDoc(doc(as('maria'), 'visits/v-joao'))));
  test('membro não lista todas as visitas', () => assertFails(getDocs(collection(as('maria'), 'visits'))));
  test('pastor lista todas as visitas', () =>
    assertSucceeds(getDocs(query(collection(as('pastor'), 'visits'), where('start', '>=', at(0))))));
  test('membro cria visita pendente para si', () =>
    assertSucceeds(setDoc(doc(as('maria'), 'visits/v2'), visit('maria'))));
  test('membro não cria visita em nome de outro', () =>
    assertFails(setDoc(doc(as('maria'), 'visits/v2'), visit('joao'))));
  test('membro não cria visita já confirmada', () =>
    assertFails(setDoc(doc(as('maria'), 'visits/v2'), visit('maria', { status: 'confirmed' }))));
  test('membro cancela a própria visita', () =>
    assertSucceeds(updateDoc(doc(as('joao'), 'visits/v-joao'), { status: 'cancelled' })));
  test('membro não confirma a própria visita', () =>
    assertFails(updateDoc(doc(as('joao'), 'visits/v-joao'), { status: 'confirmed' })));
  test('membro não muda o horário da visita', () =>
    assertFails(updateDoc(doc(as('joao'), 'visits/v-joao'), { start: at(19) })));
  test('pastor confirma a visita', () =>
    assertSucceeds(updateDoc(doc(as('pastor'), 'visits/v-joao'), { status: 'confirmed' })));
});

describe('agenda pública', () => {
  test('membro lê a ocupação do dia', () => assertSucceeds(getDoc(doc(as('maria'), 'agenda/2026-10-06'))));
  test('membro acrescenta um horário', () =>
    assertSucceeds(setDoc(doc(as('maria'), 'agenda/2026-10-06'), { slots: [slot('v-joao'), slot('v2')] })));
  test('membro não apaga a agenda inteira de uma vez', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'agenda/2026-10-06'), { slots: [slot('a'), slot('b'), slot('c')] }));
    await assertFails(setDoc(doc(as('maria'), 'agenda/2026-10-06'), { slots: [] }));
  });
  test('membro não grava campos extras', () =>
    assertFails(setDoc(doc(as('maria'), 'agenda/2026-10-06'), { slots: [slot('v-joao')], nome: 'x' })));
});

describe('notificações', () => {
  test('membro cria aviso para o pastor', () =>
    assertSucceeds(addDoc(collection(as('maria'), 'notifications'), {
      message: 'Nova visita', createdAt: serverTimestamp(), read: false,
    })));
  test('membro não lê os avisos', () => assertFails(getDocs(collection(as('maria'), 'notifications'))));
  test('pastor lê e marca como lido', async () => {
    await assertSucceeds(getDocs(collection(as('pastor'), 'notifications')));
    await assertSucceeds(updateDoc(doc(as('pastor'), 'notifications/n1'), { read: true }));
  });
  test('membro não apaga avisos', () => assertFails(deleteDoc(doc(as('maria'), 'notifications/n1'))));
});
