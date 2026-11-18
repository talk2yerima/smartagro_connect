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
const { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, orderBy, getDocs } = require('firebase/firestore');

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

// ── Farmer payouts ────────────────────────────────────────────────────────

test('only the seller (and admins) can see their payout account', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'payoutAccounts/alice'), {
      subaccountCode: 'ACCT_1',
      accountNumberMasked: '******6789',
    });
  });
  await assertSucceeds(getDoc(doc(as('alice'), 'payoutAccounts/alice')));
  await assertSucceeds(getDoc(doc(as('admin'), 'payoutAccounts/alice')));
  await assertFails(getDoc(doc(as('bob'), 'payoutAccounts/alice')));
});

test('nobody can write payout accounts or fake payoutReady from the app', async () => {
  await assertFails(setDoc(doc(as('alice'), 'payoutAccounts/alice'), { subaccountCode: 'ACCT_fake' }));
  await assertFails(setDoc(doc(as('bob'), 'payoutAccounts/alice'), { subaccountCode: 'ACCT_steal' }));
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { payoutReady: true }));
  await assertFails(setDoc(doc(as('mallory'), 'users/mallory'), { name: 'M', role: 'farmer', payoutReady: true }));
});

// ── Orders screen queries ─────────────────────────────────────────────────

test('buyers and sellers can list only their own orders', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'orders/o1'), {
      buyerId: 'bob', sellerId: 'alice', status: 'paid', createdAt: new Date(),
    });
  });
  const mine = (db, field, uid) =>
    getDocs(query(collection(db, 'orders'), where(field, '==', uid), orderBy('createdAt', 'desc')));
  await assertSucceeds(mine(as('bob'), 'buyerId', 'bob'));
  await assertSucceeds(mine(as('alice'), 'sellerId', 'alice'));
});

test('nobody can list other people\'s orders', async () => {
  const db = as('vera');
  await assertFails(getDocs(query(collection(db, 'orders'), where('buyerId', '==', 'bob'))));
  await assertFails(getDocs(collection(db, 'orders')));
});

// ── Delivery tracking ─────────────────────────────────────────────────────

const { serverTimestamp } = require('firebase/firestore');

async function seedOrder(extra = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'orders/d1'), {
      buyerId: 'bob', sellerId: 'alice', status: 'paid',
      amountKobo: 5000000, sellerShareKobo: 4750000, createdAt: new Date(), ...extra,
    });
  });
}

test('only the seller can mark an order dispatched', async () => {
  await seedOrder();
  const dispatch = { status: 'dispatched', dispatchedAt: serverTimestamp() };
  await assertFails(updateDoc(doc(as('bob'), 'orders/d1'), dispatch));
  await assertFails(updateDoc(doc(as('vera'), 'orders/d1'), dispatch));
  await assertSucceeds(updateDoc(doc(as('alice'), 'orders/d1'), dispatch));
});

test('only the buyer can confirm receipt, from paid or dispatched', async () => {
  await seedOrder({ status: 'dispatched' });
  const received = { status: 'received', receivedAt: serverTimestamp() };
  await assertFails(updateDoc(doc(as('alice'), 'orders/d1'), received));
  await assertSucceeds(updateDoc(doc(as('bob'), 'orders/d1'), received));
  await seedOrder({ status: 'paid' });
  await assertSucceeds(updateDoc(doc(as('bob'), 'orders/d1'), received));
});

test('nobody can change the money or skip steps backwards', async () => {
  await seedOrder();
  await assertFails(updateDoc(doc(as('alice'), 'orders/d1'), {
    status: 'dispatched', dispatchedAt: serverTimestamp(), sellerShareKobo: 5000000,
  }));
  await assertFails(updateDoc(doc(as('bob'), 'orders/d1'), { amountKobo: 1 }));
  await seedOrder({ status: 'received' });
  await assertFails(updateDoc(doc(as('alice'), 'orders/d1'), {
    status: 'dispatched', dispatchedAt: serverTimestamp(),
  }));
});

test('the buyer can rate once, 1 to 5, only after receipt', async () => {
  const rate = (r) => ({ rating: r, review: 'Fresh and on time', ratedAt: serverTimestamp() });
  await seedOrder({ status: 'dispatched' });
  await assertFails(updateDoc(doc(as('bob'), 'orders/d1'), rate(5)));
  await seedOrder({ status: 'received' });
  await assertFails(updateDoc(doc(as('alice'), 'orders/d1'), rate(5)));
  await assertFails(updateDoc(doc(as('bob'), 'orders/d1'), rate(6)));
  await assertFails(updateDoc(doc(as('bob'), 'orders/d1'), rate(0)));
  await assertSucceeds(updateDoc(doc(as('bob'), 'orders/d1'), rate(4)));
  await assertFails(updateDoc(doc(as('bob'), 'orders/d1'), rate(1)));
});

// ── Price alerts ──────────────────────────────────────────────────────────

const goodAlert = (uid) => ({
  uid, commodityId: 'maize', commodityName: 'Maize', unit: 'bag',
  targetNgn: 30000, direction: 'above', active: true, createdAt: serverTimestamp(),
});

test('people can create and remove only their own price alerts', async () => {
  await assertSucceeds(setDoc(doc(as('bob'), 'priceAlerts/b1'), goodAlert('bob')));
  await assertFails(setDoc(doc(as('bob'), 'priceAlerts/x1'), goodAlert('alice')));
  await assertSucceeds(getDoc(doc(as('bob'), 'priceAlerts/b1')));
  await assertFails(getDoc(doc(as('vera'), 'priceAlerts/b1')));
  await assertFails(deleteDoc(doc(as('vera'), 'priceAlerts/b1')));
  await assertSucceeds(deleteDoc(doc(as('bob'), 'priceAlerts/b1')));
});

test('price alerts must be sensible and cannot be edited from the app', async () => {
  await assertFails(setDoc(doc(as('bob'), 'priceAlerts/b2'), { ...goodAlert('bob'), targetNgn: 0 }));
  await assertFails(setDoc(doc(as('bob'), 'priceAlerts/b3'), { ...goodAlert('bob'), direction: 'sideways' }));
  await assertFails(setDoc(doc(as('bob'), 'priceAlerts/b4'), { ...goodAlert('bob'), active: false }));
  await assertFails(setDoc(doc(as('bob'), 'priceAlerts/b5'), { ...goodAlert('bob'), extra: 1 }));
  await assertSucceeds(setDoc(doc(as('bob'), 'priceAlerts/b6'), goodAlert('bob')));
  await assertFails(updateDoc(doc(as('bob'), 'priceAlerts/b6'), { targetNgn: 1 }));
});
