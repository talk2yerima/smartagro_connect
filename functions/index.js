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
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const payments = require('./src/payments');

initializeApp();

const PAYSTACK_SECRET_KEY = defineSecret('PAYSTACK_SECRET_KEY');
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
