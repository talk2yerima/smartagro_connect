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

// ── Deliveries (haulage jobs) ─────────────────────────────────────────────

const { deleteField } = require('firebase/firestore');

const place = (label, lat, lng) => ({ label, state: 'Yobe', lat, lng });
const newJob = (requesterId, extra = {}) => ({
  orderId: 'd1', description: '50 kg of Maize', weightKg: 50,
  requesterId, sellerId: 'alice', buyerId: 'bob',
  pickup: place('Gashua market', 12.87, 11.04),
  dropoff: place('Potiskum', 11.71, 11.08),
  distanceKm: 168.5, offerNgn: 20000, notes: 'Call on arrival',
  status: 'open', createdAt: serverTimestamp(), ...extra,
});
const accept = (uid) => ({
  status: 'accepted', transporterId: uid, transporterName: 'Tunde', acceptedAt: serverTimestamp(),
});
const here = (lat = 12.5, lng = 11.0) => ({ lat, lng, speedKmh: 40, updatedAt: serverTimestamp() });

async function seedDrivers() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/tunde'), { name: 'Tunde', role: 'transporter' });
    await setDoc(doc(ctx.firestore(), 'users/tola'), { name: 'Tola', role: 'transporter' });
  });
}

async function seedJob(extra = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'haulageJobs/d1'), {
      ...newJob('alice'), createdAt: new Date(), ...extra,
    });
  });
}

test('the buyer or seller of a paid order can ask for transport', async () => {
  await seedOrder();
  await assertSucceeds(setDoc(doc(as('bob'), 'haulageJobs/d1'), newJob('bob')));
  await env.clearFirestore();
  await seedOrder();
  await assertSucceeds(setDoc(doc(as('alice'), 'haulageJobs/d1'), newJob('alice')));
});

test('strangers, bad numbers and unpaid orders cannot post a job', async () => {
  await seedOrder();
  await assertFails(setDoc(doc(as('vera'), 'haulageJobs/d1'), newJob('vera')));
  await assertFails(setDoc(doc(as('bob'), 'haulageJobs/d1'), newJob('bob', { buyerId: 'vera' })));
  await assertFails(setDoc(doc(as('bob'), 'haulageJobs/d1'), newJob('bob', { weightKg: 0 })));
  await assertFails(setDoc(doc(as('bob'), 'haulageJobs/d1'), newJob('bob', { status: 'accepted' })));
  await assertFails(setDoc(doc(as('bob'), 'haulageJobs/d1'), newJob('bob', { transporterId: 'bob' })));
  await assertFails(setDoc(doc(as('bob'), 'haulageJobs/d1'), newJob('bob', { pickup: place('X', 200, 0) })));
  await seedOrder({ status: 'received' });
  await assertFails(setDoc(doc(as('bob'), 'haulageJobs/d1'), newJob('bob')));
});

test('transporters see open jobs; others do not', async () => {
  await seedDrivers();
  await seedJob();
  const openJobs = (db) =>
    getDocs(query(collection(db, 'haulageJobs'), where('status', '==', 'open'), orderBy('createdAt', 'desc')));
  await assertSucceeds(openJobs(as('tunde')));
  await assertFails(openJobs(as('vera')));
  await assertSucceeds(getDoc(doc(as('bob'), 'haulageJobs/d1')));
  await assertSucceeds(getDoc(doc(as('bob'), 'haulageJobs/none')));
  await assertFails(getDoc(doc(as('vera'), 'haulageJobs/d1')));
});

test('a transporter accepts an open job; only one gets it', async () => {
  await seedDrivers();
  await seedJob();
  await assertFails(updateDoc(doc(as('vera'), 'haulageJobs/d1'), accept('vera')));
  await assertFails(updateDoc(doc(as('tola'), 'haulageJobs/d1'), accept('tunde')));
  await assertSucceeds(updateDoc(doc(as('tunde'), 'haulageJobs/d1'), accept('tunde')));
  await assertFails(updateDoc(doc(as('tola'), 'haulageJobs/d1'), accept('tola')));
  // Once taken, the job leaves other transporters' view.
  await assertFails(getDoc(doc(as('tola'), 'haulageJobs/d1')));
  await assertSucceeds(getDocs(query(collection(as('tunde'), 'haulageJobs'), where('transporterId', '==', 'tunde'))));
});

test('only the assigned transporter shares location and moves the job on, in order', async () => {
  await seedDrivers();
  await seedJob({ status: 'accepted', transporterId: 'tunde', transporterName: 'Tunde', acceptedAt: new Date() });
  const ref = (uid) => doc(as(uid), 'haulageJobs/d1');
  await assertFails(updateDoc(ref('tola'), { driverLocation: here() }));
  await assertFails(updateDoc(ref('bob'), { driverLocation: here() }));
  await assertSucceeds(updateDoc(ref('tunde'), { driverLocation: here() }));
  await assertFails(updateDoc(ref('tunde'), { driverLocation: { lat: 1, lng: 2, updatedAt: new Date(2000, 1, 1) } }));
  await assertFails(updateDoc(ref('tunde'), { status: 'delivered', deliveredAt: serverTimestamp() }));
  await assertFails(updateDoc(ref('tunde'), { status: 'picked_up', pickedUpAt: serverTimestamp(), offerNgn: 90000 }));
  await assertSucceeds(updateDoc(ref('tunde'), { status: 'picked_up', pickedUpAt: serverTimestamp(), driverLocation: here() }));
  await assertSucceeds(updateDoc(ref('tunde'), { status: 'delivered', deliveredAt: serverTimestamp() }));
  await assertFails(updateDoc(ref('tunde'), { driverLocation: here() }));
  await assertSucceeds(getDoc(ref('bob')));
  await assertFails(getDoc(ref('tola')));
});

test('a transporter can hand a job back before pickup; parties can cancel and repost', async () => {
  await seedOrder();
  await seedDrivers();
  await seedJob({ status: 'accepted', transporterId: 'tunde', transporterName: 'Tunde', acceptedAt: new Date() });
  const handBack = {
    status: 'open', transporterId: deleteField(), transporterName: deleteField(),
    acceptedAt: deleteField(), driverLocation: deleteField(),
  };
  await assertFails(updateDoc(doc(as('tunde'), 'haulageJobs/d1'), { status: 'open' }));
  await assertSucceeds(updateDoc(doc(as('tunde'), 'haulageJobs/d1'), handBack));
  const cancel = { status: 'cancelled', cancelledAt: serverTimestamp() };
  await assertFails(updateDoc(doc(as('vera'), 'haulageJobs/d1'), cancel));
  await assertSucceeds(updateDoc(doc(as('bob'), 'haulageJobs/d1'), cancel));
  await assertSucceeds(setDoc(doc(as('bob'), 'haulageJobs/d1'), newJob('bob', { offerNgn: 25000 })));
  await assertFails(setDoc(doc(as('vera'), 'haulageJobs/d1'), newJob('vera')));
  await assertFails(deleteDoc(doc(as('bob'), 'haulageJobs/d1')));
});

// ── Reviews and rating totals ─────────────────────────────────────────────

test('anyone signed in can read reviews; nobody can write them from the app', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'reviews/r1'), { sellerId: 'alice', rating: 5 });
  });
  await assertSucceeds(getDoc(doc(as('vera'), 'reviews/r1')));
  await assertFails(setDoc(doc(as('alice'), 'reviews/fake'), { sellerId: 'alice', rating: 5 }));
  await assertFails(updateDoc(doc(as('alice'), 'reviews/r1'), { rating: 5 }));
});

test('a seller cannot inflate their own rating totals', async () => {
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { ratingSum: 500 }));
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { ratingCount: 100 }));
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { ratingCounts: { 5: 100 } }));
  await assertFails(setDoc(doc(as('newbie'), 'users/newbie'), { name: 'N', role: 'farmer', ratingCount: 9 }));
  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), { about: 'Mixed farm in Gashua' }));
});

test('review tags must come from the list, at most six', async () => {
  const rate = (tags) => ({ rating: 5, reviewTags: tags, ratedAt: serverTimestamp() });
  await seedOrder({ status: 'received' });
  await assertFails(updateDoc(doc(as('bob'), 'orders/d1'), rate(['Paid me to say this'])));
  await assertFails(updateDoc(doc(as('bob'), 'orders/d1'), rate('Fresh produce')));
  await assertSucceeds(updateDoc(doc(as('bob'), 'orders/d1'), rate(['Fresh produce', 'Fast delivery'])));
});

test('sellers cannot give their listings a higher star rating than they have', async () => {
  // alice has no rating yet.
  await assertFails(setDoc(doc(as('alice'), 'products/fake5'), listing('alice', { sellerRating: 5 })));
  await assertSucceeds(setDoc(doc(as('alice'), 'products/honest'), listing('alice', { sellerRating: 0 })));
  await assertFails(updateDoc(doc(as('alice'), 'products/p1'), { sellerRating: 5 }));
  await assertSucceeds(updateDoc(doc(as('admin'), 'products/p1'), { sellerRating: 4.2 }));
});

test('a cancelled delivery cannot be reposted once the order is received', async () => {
  await seedOrder({ status: 'received' });
  await seedJob({ status: 'cancelled', cancelledAt: new Date() });
  await assertFails(setDoc(doc(as('bob'), 'haulageJobs/d1'), newJob('bob')));
});
