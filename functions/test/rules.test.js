'use strict';

/**
 * Firestore security-rules tests. Run against the local emulator:
 *   cd functions && npm run test:rules
 */

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-smartagro',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
    },
  });
});

test.after(async () => {
  await env.cleanup();
});

test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), { name: 'Alice', role: 'farmer', verified: false });
    await setDoc(doc(db, 'users/vera'), { name: 'Vera', role: 'farmer', verified: true });
    await setDoc(doc(db, 'users/admin'), { name: 'Admin', role: 'admin' });
    await setDoc(doc(db, 'users/bob'), { name: 'Bob', role: 'buyer' });
    await setDoc(doc(db, 'products/p1'), {
      title: 'Maize', priceNgn: 500, quantityKg: 40, sellerId: 'alice',
      verified: false, status: 'active', availability: 'in_stock',
    });
    await setDoc(doc(db, 'payments/ref1'), {
      buyerId: 'bob', sellerId: 'alice', amountKobo: 2000000, status: 'pending',
    });
    await setDoc(doc(db, 'orders/ref1'), { buyerId: 'bob', sellerId: 'alice', status: 'paid' });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const listing = (sellerId, extra = {}) => ({
  title: 'Yam', priceNgn: 800, quantityKg: 10, sellerId, verified: false, ...extra,
});

// ── Users ─────────────────────────────────────────────────────────────────

test('a new user can create their own farmer/buyer profile', async () => {
  await assertSucceeds(setDoc(doc(as('carol'), 'users/carol'), { name: 'Carol', role: 'buyer' }));
});

test('a new user cannot register as admin', async () => {
  await assertFails(setDoc(doc(as('mallory'), 'users/mallory'), { name: 'M', role: 'admin' }));
});

test('a new user cannot pre-verify themselves', async () => {
  await assertFails(setDoc(doc(as('mallory'), 'users/mallory'), { name: 'M', role: 'farmer', verified: true }));
});

test('a user cannot promote themselves to admin', async () => {
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { role: 'admin' }));
});

test('a user cannot verify, unban or re-rate themselves', async () => {
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { verified: true }));
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { banned: false }));
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { rating: 5 }));
});

test('a user can edit their own name, phone and FCM token', async () => {
  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), { name: 'Alice A', phone: '080', fcmToken: 't' }));
});

test("a user cannot edit someone else's profile", async () => {
  await assertFails(updateDoc(doc(as('bob'), 'users/alice'), { name: 'hacked' }));
});

test('an admin can verify a user', async () => {
  await assertSucceeds(updateDoc(doc(as('admin'), 'users/alice'), { verified: true }));
});

test('signed-out visitors cannot read profiles', async () => {
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/alice')));
});

// ── Products ──────────────────────────────────────────────────────────────

test('a seller can create a valid listing for themselves', async () => {
  await assertSucceeds(setDoc(doc(as('alice'), 'products/new'), listing('alice')));
});

test('a seller cannot list on behalf of someone else', async () => {
  await assertFails(setDoc(doc(as('alice'), 'products/new'), listing('bob')));
});

test('an unverified seller cannot claim the verified badge', async () => {
  await assertFails(setDoc(doc(as('alice'), 'products/new'), listing('alice', { verified: true })));
});

test('a verified seller can show the verified badge', async () => {
  await assertSucceeds(setDoc(doc(as('vera'), 'products/new'), listing('vera', { verified: true })));
});

test('zero, negative or fractional prices are rejected', async () => {
  await assertFails(setDoc(doc(as('alice'), 'products/a'), listing('alice', { priceNgn: 0 })));
  await assertFails(setDoc(doc(as('alice'), 'products/b'), listing('alice', { priceNgn: -1 })));
  await assertFails(setDoc(doc(as('alice'), 'products/c'), listing('alice', { priceNgn: 1.5 })));
});

test('a seller can update their price but not transfer the listing', async () => {
  await assertSucceeds(updateDoc(doc(as('alice'), 'products/p1'), { priceNgn: 450 }));
  await assertFails(updateDoc(doc(as('alice'), 'products/p1'), { sellerId: 'bob' }));
  await assertFails(updateDoc(doc(as('alice'), 'products/p1'), { verified: true }));
});

test("another user cannot edit or delete someone's listing", async () => {
  await assertFails(updateDoc(doc(as('bob'), 'products/p1'), { priceNgn: 1 }));
  await assertFails(deleteDoc(doc(as('bob'), 'products/p1')));
});

// ── Payments & orders ─────────────────────────────────────────────────────

test('buyer and seller can read their payment; others cannot', async () => {
  await assertSucceeds(getDoc(doc(as('bob'), 'payments/ref1')));
  await assertSucceeds(getDoc(doc(as('alice'), 'payments/ref1')));
  await assertFails(getDoc(doc(as('vera'), 'payments/ref1')));
});

test('no app client can create or mark a payment as successful', async () => {
  await assertFails(updateDoc(doc(as('bob'), 'payments/ref1'), { status: 'success' }));
  await assertFails(setDoc(doc(as('bob'), 'payments/fake'), { buyerId: 'bob', status: 'success' }));
  await assertFails(updateDoc(doc(as('admin'), 'payments/ref1'), { status: 'success' }));
});

test('no app client can create an order', async () => {
  await assertFails(setDoc(doc(as('bob'), 'orders/fake'), { buyerId: 'bob', status: 'paid' }));
  await assertSucceeds(getDoc(doc(as('bob'), 'orders/ref1')));
  await assertFails(getDoc(doc(as('vera'), 'orders/ref1')));
});

// ── Chats ─────────────────────────────────────────────────────────────────

test('chat participants cannot add a third person', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chats/alice_bob'), { participants: ['alice', 'bob'], lastMessage: 'hi' });
  });
  await assertSucceeds(updateDoc(doc(as('bob'), 'chats/alice_bob'), { lastMessage: 'hello' }));
  await assertFails(updateDoc(doc(as('bob'), 'chats/alice_bob'), { participants: ['alice', 'bob', 'vera'] }));
  await assertFails(getDoc(doc(as('vera'), 'chats/alice_bob')));
});
