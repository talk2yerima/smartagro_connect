'use strict';

/**
 * Firebase Cloud Functions entry point.
 *
 * Deploy:
 *   firebase functions:secrets:set PAYSTACK_SECRET_KEY   # sk_test_… or sk_live_…
 *   firebase deploy --only functions,firestore:rules
 *
 * Then set the Paystack dashboard webhook URL to the deployed
 * `paystackWebhook` URL (Settings → API Keys & Webhooks).
 */

const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { defineSecret, defineInt } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const payments = require('./src/payments');
const notifications = require('./src/notifications');
const payouts = require('./src/payouts');
const ratings = require('./src/ratings');

initializeApp();

const PAYSTACK_SECRET_KEY = defineSecret('PAYSTACK_SECRET_KEY');
// SmartAgro's share of each sale, in percent. Set in functions/.env;
// the seller receives the rest. SmartAgro pays Paystack's fee from its share.
const PLATFORM_FEE_PERCENT = defineInt('PLATFORM_FEE_PERCENT', { default: 5 });
const REGION = 'us-central1';

function paystackClient() {
  return payments.createPaystackClient({ secretKey: PAYSTACK_SECRET_KEY.value() });
}

function toHttpsError(err) {
  if (err instanceof HttpsError) return err;
  if (err instanceof payments.PaymentError) return new HttpsError(err.code, err.message);
  logger.error('Unexpected payment error', err);
  return new HttpsError('internal', 'Something went wrong. Please try again.');
}

async function isAdmin(db, uid) {
  const snap = await db.collection('users').doc(uid).get();
  return snap.exists && snap.get('role') === 'admin';
}

exports.initializePayment = onCall(
  { region: REGION, secrets: [PAYSTACK_SECRET_KEY] },
  async (request) => {
    try {
      const data = request.data || {};
      return await payments.initializePayment({
        db: getFirestore(),
        paystack: paystackClient(),
        uid: request.auth && request.auth.uid,
        tokenEmail: request.auth && request.auth.token && request.auth.token.email,
        email: data.email,
        productId: data.productId,
        feePercent: PLATFORM_FEE_PERCENT.value(),
      });
    } catch (err) {
      throw toHttpsError(err);
    }
  },
);

exports.verifyPayment = onCall(
  { region: REGION, secrets: [PAYSTACK_SECRET_KEY] },
  async (request) => {
    try {
      const db = getFirestore();
      const uid = request.auth && request.auth.uid;
      return await payments.verifyPayment({
        db,
        paystack: paystackClient(),
        uid,
        isAdmin: uid ? await isAdmin(db, uid) : false,
        reference: (request.data || {}).reference,
      });
    } catch (err) {
      throw toHttpsError(err);
    }
  },
);

exports.paystackWebhook = onRequest(
  { region: REGION, secrets: [PAYSTACK_SECRET_KEY] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }
    try {
      const code = await payments.handleWebhook({
        db: getFirestore(),
        paystack: paystackClient(),
        rawBody: req.rawBody,
        signature: req.get('x-paystack-signature'),
        secret: PAYSTACK_SECRET_KEY.value(),
      });
      res.sendStatus(code);
    } catch (err) {
      // 500 makes Paystack retry the webhook later.
      logger.error('paystackWebhook failed', err);
      res.sendStatus(500);
    }
  },
);

// ── Notifications ───────────────────────────────────────────────────────────
// Firestore triggers must run in the database's location. us-central1 suits
// the default (nam5 / us-central1) database; change REGION if yours differs.

function notificationDeps() {
  const db = getFirestore();
  return {
    getUser: async (uid) => (await db.collection('users').doc(uid).get()).data(),
    addNotification: (uid, doc) =>
      db.collection('users').doc(uid).collection('notifications').add({
        ...doc,
        createdAt: FieldValue.serverTimestamp(),
      }),
    send: (message) => getMessaging().send(message),
    clearToken: (uid) =>
      db.collection('users').doc(uid).update({ fcmToken: FieldValue.delete() }),
    log: logger,
  };
}

/** Push the other person in a chat when a message arrives. */
exports.notifyOnChatMessage = onDocumentCreated(
  { document: 'chats/{threadId}/messages/{messageId}', region: REGION },
  async (event) => {
    const message = event.data && event.data.data();
    if (!message) return;
    const { threadId } = event.params;
    const thread = (await getFirestore().collection('chats').doc(threadId).get()).data();
    const note = notifications.messageNotification({ threadId, message, thread });
    if (note) await notifications.deliver(note, notificationDeps());
  },
);

/** Tell the seller (new order) and the buyer (payment confirmed). */
exports.notifyOnOrder = onDocumentCreated(
  { document: 'orders/{orderId}', region: REGION },
  async (event) => {
    const order = event.data && event.data.data();
    const deps = notificationDeps();
    for (const note of notifications.orderNotifications(order)) {
      await notifications.deliver(note, deps);
    }
  },
);

// ── Farmer payouts (Paystack split) ─────────────────────────────────────────

let bankCache = null; // { banks, fetchedAt } per warm instance
const BANK_CACHE_MS = 12 * 60 * 60 * 1000;

/** Banks for the "Get paid" screen, plus the fee so the app can explain it. */
exports.listBanks = onCall(
  { region: REGION, secrets: [PAYSTACK_SECRET_KEY] },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
    try {
      if (!bankCache || Date.now() - bankCache.fetchedAt > BANK_CACHE_MS) {
        bankCache = { banks: await paystackClient().listBanks(), fetchedAt: Date.now() };
      }
      return { banks: bankCache.banks, feePercent: PLATFORM_FEE_PERCENT.value() };
    } catch (err) {
      throw toHttpsError(err);
    }
  },
);

/** "Check account": returns the account name the bank has on file. */
exports.resolveBankAccount = onCall(
  { region: REGION, secrets: [PAYSTACK_SECRET_KEY] },
  async (request) => {
    try {
      const data = request.data || {};
      return await payouts.resolveBankAccount({
        paystack: paystackClient(),
        uid: request.auth && request.auth.uid,
        accountNumber: data.accountNumber,
        bankCode: data.bankCode,
      });
    } catch (err) {
      throw toHttpsError(err);
    }
  },
);

/** Saves the seller's bank account as their Paystack subaccount. */
exports.savePayoutAccount = onCall(
  { region: REGION, secrets: [PAYSTACK_SECRET_KEY] },
  async (request) => {
    try {
      const data = request.data || {};
      return await payouts.savePayoutAccount({
        db: getFirestore(),
        paystack: paystackClient(),
        uid: request.auth && request.auth.uid,
        accountNumber: data.accountNumber,
        bankCode: data.bankCode,
        bankName: data.bankName,
        feePercent: PLATFORM_FEE_PERCENT.value(),
      });
    } catch (err) {
      throw toHttpsError(err);
    }
  },
);

// ── Delivery tracking ───────────────────────────────────────────────────────

/**
 * Order updated by the seller (dispatched) or buyer (received, rated):
 * notify the other person, and add any new rating to the seller's average
 * (profile and their listings' seller rating).
 */
exports.onOrderUpdated = onDocumentUpdated(
  { document: 'orders/{orderId}', region: REGION },
  async (event) => {
    const before = event.data && event.data.before.data();
    const after = event.data && event.data.after.data();
    if (!before || !after) return;

    const deps = notificationDeps();
    for (const note of notifications.orderStatusNotifications(before, after)) {
      await notifications.deliver(note, deps);
    }

    const added = ratings.newRating(before, after);
    if (!added) return;
    const db = getFirestore();
    const result = await ratings.applyRating({ db, ...added });
    if (!result) return;
    // Listings carry a copy of the seller's rating for the marketplace cards.
    const listings = await db.collection('products')
      .where('sellerId', '==', added.sellerId).limit(200).get();
    const batch = db.batch();
    listings.forEach((d) => batch.update(d.ref, { sellerRating: result.rating }));
    if (!listings.empty) await batch.commit();
  },
);
