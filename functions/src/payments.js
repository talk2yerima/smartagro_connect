'use strict';

/**
 * Server-side payment logic for SmartAgro Connect.
 *
 * Every decision that involves money is made here, never on the phone:
 *   - the amount is computed from the product document in Firestore,
 *   - the Paystack secret key only exists in this backend,
 *   - a payment is only marked "success" after Paystack confirms it AND the
 *     confirmed amount/currency match what we asked for.
 *
 * All Firestore and Paystack access is injected so the logic can be unit
 * tested without the emulator or the network (see test/payments.test.js).
 */

const crypto = require('node:crypto');

const CURRENCY = 'NGN';

/** Statuses that will never change again once written. */
const FINAL_STATUSES = new Set(['success', 'failed', 'reversed', 'amount_mismatch']);

/** Error carrying a Firebase HttpsError code (mapped in index.js). */
class PaymentError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PaymentError';
    this.code = code;
  }
}

// ── Pure helpers ─────────────────────────────────────────────────────────────

/**
 * Price of buying the whole lot, in kobo. Throws if the listing data is not
 * a sane positive integer price/quantity.
 */
function computeAmountKobo(product) {
  const price = product && product.priceNgn;
  const qty = product && product.quantityKg;
  if (!Number.isInteger(price) || price <= 0) {
    throw new PaymentError('failed-precondition', 'Listing has an invalid price.');
  }
  if (!Number.isInteger(qty) || qty <= 0) {
    throw new PaymentError('failed-precondition', 'Listing has an invalid quantity.');
  }
  const kobo = price * qty * 100;
  if (!Number.isSafeInteger(kobo)) {
    throw new PaymentError('failed-precondition', 'Order amount is too large.');
  }
  return kobo;
}

/** Constant-time check of Paystack's `x-paystack-signature` header. */
function isValidWebhookSignature(rawBody, signature, secret) {
  if (!rawBody || typeof signature !== 'string' || !signature || !secret) return false;
  const expected = crypto.createHmac('sha512', secret).update(rawBody).digest('hex');
  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(signature, 'utf8');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/**
 * Maps a Paystack transaction (from /transaction/verify) onto our status,
 * checking that the money received is exactly what we charged.
 */
function resolveStatus(record, tx) {
  if (!tx || tx.reference !== record.reference) return 'pending';
  switch (tx.status) {
    case 'success':
      return tx.amount === record.amountKobo && tx.currency === record.currency
        ? 'success'
        : 'amount_mismatch';
    case 'failed':
    case 'reversed':
    case 'abandoned':
      return tx.status;
    default:
      // ongoing, pending, processing, queued, …
      return 'pending';
  }
}

function newReference() {
  return `SA-${crypto.randomUUID().replace(/-/g, '')}`;
}

function isEmail(value) {
  return typeof value === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

// ── Paystack HTTP client ─────────────────────────────────────────────────────

function createPaystackClient({ secretKey, fetchImpl = globalThis.fetch, baseUrl = 'https://api.paystack.co' }) {
  if (!secretKey) throw new Error('PAYSTACK_SECRET_KEY is not configured.');

  async function call(method, path, body) {
    let res;
    try {
      res = await fetchImpl(`${baseUrl}${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${secretKey}`,
          'Content-Type': 'application/json',
        },
        body: body ? JSON.stringify(body) : undefined,
      });
    } catch (_) {
      throw new PaymentError('unavailable', 'Could not reach the payment provider.');
    }
    let json = null;
    try {
      json = await res.json();
    } catch (_) {
      // fall through to the generic error below
    }
    if (!res.ok || !json || json.status !== true) {
      throw new PaymentError(
        'unavailable',
        (json && json.message) || `Payment provider error (${res.status}).`,
      );
    }
    return json.data;
  }

  return {
    async initialize({ email, amountKobo, reference, metadata }) {
      const data = await call('POST', '/transaction/initialize', {
        email,
        amount: amountKobo,
        currency: CURRENCY,
        reference,
        metadata,
      });
      return {
        authorizationUrl: data.authorization_url,
        accessCode: data.access_code,
        reference: data.reference,
      };
    },
    async verify(reference) {
      return call('GET', `/transaction/verify/${encodeURIComponent(reference)}`);
    },
  };
}

// ── Use cases ────────────────────────────────────────────────────────────────

/**
 * Starts a payment for a whole product lot and returns the Paystack
 * checkout URL. The client only sends the product id.
 */
async function initializePayment({ db, paystack, uid, tokenEmail, email, productId, now = () => new Date(), makeReference = newReference }) {
  if (!uid) throw new PaymentError('unauthenticated', 'Sign in to pay.');
  if (typeof productId !== 'string' || !productId || productId.includes('/')) {
    throw new PaymentError('invalid-argument', 'A valid productId is required.');
  }
  const receiptEmail = isEmail(email) ? email.trim() : tokenEmail;
  if (!isEmail(receiptEmail)) {
    throw new PaymentError('invalid-argument', 'A valid receipt email is required.');
  }

  const productSnap = await db.collection('products').doc(productId).get();
  if (!productSnap.exists) throw new PaymentError('not-found', 'Listing not found.');
  const product = productSnap.data();

  if (product.status && product.status !== 'active') {
    throw new PaymentError('failed-precondition', 'This listing is no longer available.');
  }
  if (product.availability === 'sold_out') {
    throw new PaymentError('failed-precondition', 'This listing is sold out.');
  }
  if (product.sellerId === uid) {
    throw new PaymentError('failed-precondition', 'You cannot buy your own listing.');
  }

  const amountKobo = computeAmountKobo(product);
  const reference = makeReference();
  const description = `${product.quantityKg} kg of ${product.title || 'produce'}`;
  const paymentRef = db.collection('payments').doc(reference);

  await paymentRef.set({
    reference,
    buyerId: uid,
    buyerEmail: receiptEmail,
    sellerId: product.sellerId || null,
    productId,
    description,
    amountKobo,
    currency: CURRENCY,
    status: 'initializing',
    createdAt: now(),
    updatedAt: now(),
  });

  let init;
  try {
    init = await paystack.initialize({
      email: receiptEmail,
      amountKobo,
      reference,
      metadata: { productId, buyerId: uid },
    });
  } catch (err) {
    await paymentRef.update({ status: 'init_failed', updatedAt: now() });
    throw err instanceof PaymentError
      ? err
      : new PaymentError('unavailable', 'Could not start the payment.');
  }

  await paymentRef.update({ status: 'pending', updatedAt: now() });

  return {
    reference,
    authorizationUrl: init.authorizationUrl,
    amountKobo,
    currency: CURRENCY,
    description,
  };
}

/**
 * Writes a verified status. Idempotent: a payment that already reached a
 * final status is never changed, and the order is only created once.
 */
async function applyStatus({ db, reference, status, tx, now = () => new Date() }) {
  const paymentRef = db.collection('payments').doc(reference);
  return db.runTransaction(async (t) => {
    const snap = await t.get(paymentRef);
    if (!snap.exists) throw new PaymentError('not-found', 'Payment not found.');
    const record = snap.data();
    if (FINAL_STATUSES.has(record.status)) return record.status;

    const update = { status, updatedAt: now() };
    if (tx) {
      update.gatewayAmount = tx.amount === undefined ? null : tx.amount;
      update.gatewayCurrency = tx.currency || null;
      update.channel = tx.channel || null;
      update.paidAt = tx.paid_at || null;
    }
    t.update(paymentRef, update);

    if (status === 'success') {
      t.set(db.collection('orders').doc(reference), {
        reference,
        buyerId: record.buyerId,
        sellerId: record.sellerId,
        productId: record.productId,
        description: record.description,
        amountKobo: record.amountKobo,
        currency: record.currency,
        status: 'paid',
        createdAt: now(),
      });
      if (record.productId) {
        t.update(db.collection('products').doc(record.productId), {
          availability: 'sold_out',
          updatedAt: now(),
        });
      }
    }
    return status;
  });
}

/** Buyer (or admin) asks the server to confirm a payment with Paystack. */
async function verifyPayment({ db, paystack, uid, isAdmin = false, reference, now }) {
  if (!uid) throw new PaymentError('unauthenticated', 'Sign in to verify a payment.');
  if (typeof reference !== 'string' || !reference || reference.includes('/')) {
    throw new PaymentError('invalid-argument', 'A valid reference is required.');
  }
  const snap = await db.collection('payments').doc(reference).get();
  if (!snap.exists) throw new PaymentError('not-found', 'Payment not found.');
  const record = snap.data();
  if (record.buyerId !== uid && !isAdmin) {
    throw new PaymentError('permission-denied', 'Not your payment.');
  }
  if (FINAL_STATUSES.has(record.status)) {
    return { reference, status: record.status, amountKobo: record.amountKobo };
  }
  const tx = await paystack.verify(reference);
  const status = resolveStatus(record, tx);
  const finalStatus = await applyStatus({ db, reference, status, tx, now });
  return { reference, status: finalStatus, amountKobo: record.amountKobo };
}

/**
 * Paystack webhook. Returns the HTTP status code to send back.
 * The payload is only trusted after the HMAC signature checks out, and the
 * transaction is re-verified against the Paystack API before it counts.
 */
async function handleWebhook({ db, paystack, rawBody, signature, secret, now }) {
  if (!isValidWebhookSignature(rawBody, signature, secret)) return 401;

  let event;
  try {
    event = JSON.parse(Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : rawBody);
  } catch (_) {
    return 400;
  }
  const reference = event && event.data && event.data.reference;
  if (!reference || typeof reference !== 'string' || reference.includes('/')) return 200;
  if (event.event !== 'charge.success') return 200;

  const snap = await db.collection('payments').doc(reference).get();
  if (!snap.exists) return 200; // not one of ours — acknowledge and ignore

  const tx = await paystack.verify(reference);
  const status = resolveStatus(snap.data(), tx);
  await applyStatus({ db, reference, status, tx, now });
  return 200;
}

module.exports = {
  CURRENCY,
  FINAL_STATUSES,
  PaymentError,
  applyStatus,
  computeAmountKobo,
  createPaystackClient,
  handleWebhook,
  initializePayment,
  isValidWebhookSignature,
  newReference,
  resolveStatus,
  verifyPayment,
};
