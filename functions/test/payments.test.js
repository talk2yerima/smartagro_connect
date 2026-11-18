'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const p = require('../src/payments');
const { createFakeFirestore } = require('./fake-firestore');

const SECRET = 'sk_test_unit_only';
const NOW = () => new Date('2026-11-14T10:00:00Z');

function seedProduct(overrides = {}, { payout = true } = {}) {
  return {
    'products/p1': {
      title: 'Maize',
      priceNgn: 500,
      quantityKg: 40,
      sellerId: 'seller-1',
      status: 'active',
      availability: 'in_stock',
      ...overrides,
    },
    // The seller's Paystack subaccount (bank account on file).
    ...(payout ? { 'payoutAccounts/seller-1': { subaccountCode: 'ACCT_seller1' } } : {}),
  };
}

function fakePaystack({ verifyResult, initError } = {}) {
  const calls = { initialize: [], verify: [] };
  return {
    calls,
    async initialize(args) {
      calls.initialize.push(args);
      if (initError) throw initError;
      return {
        authorizationUrl: `https://checkout.paystack.com/${args.reference}`,
        accessCode: 'ac_1',
        reference: args.reference,
      };
    },
    async verify(reference) {
      calls.verify.push(reference);
      return { reference, ...verifyResult };
    },
  };
}

async function startPayment(db, paystack, extra = {}) {
  return p.initializePayment({
    db,
    paystack,
    uid: 'buyer-1',
    tokenEmail: 'buyer@farm.ng',
    productId: 'p1',
    now: NOW,
    makeReference: () => 'SA-ref1',
    ...extra,
  });
}

// ── computeAmountKobo ──────────────────────────────────────────────────────

test('computeAmountKobo multiplies price × quantity × 100', () => {
  assert.equal(p.computeAmountKobo({ priceNgn: 500, quantityKg: 40 }), 2_000_000);
});

test('computeAmountKobo rejects zero, negative, fractional and string values', () => {
  for (const bad of [
    { priceNgn: 0, quantityKg: 1 },
    { priceNgn: -5, quantityKg: 1 },
    { priceNgn: 1.5, quantityKg: 1 },
    { priceNgn: '500', quantityKg: 1 },
    { priceNgn: 500, quantityKg: 0 },
  ]) {
    assert.throws(() => p.computeAmountKobo(bad), { code: 'failed-precondition' });
  }
});

// ── Webhook signature ─────────────────────────────────────────────────────

test('isValidWebhookSignature accepts the correct HMAC and rejects others', () => {
  const body = JSON.stringify({ event: 'charge.success' });
  const sig = crypto.createHmac('sha512', SECRET).update(body).digest('hex');
  assert.equal(p.isValidWebhookSignature(body, sig, SECRET), true);
  assert.equal(p.isValidWebhookSignature(body, sig, 'other-secret'), false);
  assert.equal(p.isValidWebhookSignature(body, 'deadbeef', SECRET), false);
  assert.equal(p.isValidWebhookSignature(body, undefined, SECRET), false);
});

// ── resolveStatus ─────────────────────────────────────────────────────────

test('resolveStatus only reports success when amount and currency match', () => {
  const record = { reference: 'r', amountKobo: 1000, currency: 'NGN' };
  assert.equal(p.resolveStatus(record, { reference: 'r', status: 'success', amount: 1000, currency: 'NGN' }), 'success');
  assert.equal(p.resolveStatus(record, { reference: 'r', status: 'success', amount: 100, currency: 'NGN' }), 'amount_mismatch');
  assert.equal(p.resolveStatus(record, { reference: 'r', status: 'success', amount: 1000, currency: 'USD' }), 'amount_mismatch');
  assert.equal(p.resolveStatus(record, { reference: 'r', status: 'failed' }), 'failed');
  assert.equal(p.resolveStatus(record, { reference: 'r', status: 'ongoing' }), 'pending');
  assert.equal(p.resolveStatus(record, { reference: 'other', status: 'success', amount: 1000, currency: 'NGN' }), 'pending');
});

// ── initializePayment ─────────────────────────────────────────────────────

test('initializePayment charges the server-side price, not a client amount', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack();
  const result = await startPayment(db, paystack, { amountKobo: 1 });

  assert.equal(result.amountKobo, 2_000_000);
  assert.equal(paystack.calls.initialize[0].amountKobo, 2_000_000);
  assert.equal(result.authorizationUrl, 'https://checkout.paystack.com/SA-ref1');
  const record = db.store.get('payments/SA-ref1');
  assert.equal(record.status, 'pending');
  assert.equal(record.buyerId, 'buyer-1');
  assert.equal(record.sellerId, 'seller-1');
});

test('initializePayment requires sign-in', async () => {
  const db = createFakeFirestore(seedProduct());
  await assert.rejects(startPayment(db, fakePaystack(), { uid: undefined }), { code: 'unauthenticated' });
});

test('initializePayment rejects missing, sold-out and own listings', async () => {
  await assert.rejects(
    startPayment(createFakeFirestore({}), fakePaystack()),
    { code: 'not-found' },
  );
  await assert.rejects(
    startPayment(createFakeFirestore(seedProduct({ availability: 'sold_out' })), fakePaystack()),
    { code: 'failed-precondition' },
  );
  await assert.rejects(
    startPayment(createFakeFirestore(seedProduct({ sellerId: 'buyer-1' })), fakePaystack()),
    { code: 'failed-precondition' },
  );
  await assert.rejects(
    startPayment(createFakeFirestore(seedProduct()), fakePaystack(), { productId: '../users/x' }),
    { code: 'invalid-argument' },
  );
});

test('initializePayment marks the record init_failed when Paystack is down', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ initError: new p.PaymentError('unavailable', 'down') });
  await assert.rejects(startPayment(db, paystack), { code: 'unavailable' });
  assert.equal(db.store.get('payments/SA-ref1').status, 'init_failed');
});

// ── verifyPayment ─────────────────────────────────────────────────────────

test('verifyPayment success creates an order and marks the lot sold out', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ verifyResult: { status: 'success', amount: 2_000_000, currency: 'NGN', channel: 'card' } });
  await startPayment(db, paystack);

  const result = await p.verifyPayment({ db, paystack, uid: 'buyer-1', reference: 'SA-ref1', now: NOW });

  assert.equal(result.status, 'success');
  assert.equal(db.store.get('payments/SA-ref1').status, 'success');
  assert.equal(db.store.get('orders/SA-ref1').status, 'paid');
  assert.equal(db.store.get('products/p1').availability, 'sold_out');
});

test('verifyPayment flags underpayment instead of accepting it', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ verifyResult: { status: 'success', amount: 100, currency: 'NGN' } });
  await startPayment(db, paystack);

  const result = await p.verifyPayment({ db, paystack, uid: 'buyer-1', reference: 'SA-ref1', now: NOW });

  assert.equal(result.status, 'amount_mismatch');
  assert.equal(db.store.has('orders/SA-ref1'), false);
  assert.equal(db.store.get('products/p1').availability, 'in_stock');
});

test('verifyPayment refuses other users but allows admins', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ verifyResult: { status: 'ongoing' } });
  await startPayment(db, paystack);

  await assert.rejects(
    p.verifyPayment({ db, paystack, uid: 'someone-else', reference: 'SA-ref1', now: NOW }),
    { code: 'permission-denied' },
  );
  const asAdmin = await p.verifyPayment({ db, paystack, uid: 'admin-1', isAdmin: true, reference: 'SA-ref1', now: NOW });
  assert.equal(asAdmin.status, 'pending');
});

test('verifyPayment is idempotent once a final status is reached', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ verifyResult: { status: 'success', amount: 2_000_000, currency: 'NGN' } });
  await startPayment(db, paystack);
  await p.verifyPayment({ db, paystack, uid: 'buyer-1', reference: 'SA-ref1', now: NOW });

  const again = await p.verifyPayment({ db, paystack, uid: 'buyer-1', reference: 'SA-ref1', now: NOW });

  assert.equal(again.status, 'success');
  assert.equal(paystack.calls.verify.length, 1, 'Paystack is not called again for a final payment');
});

// ── handleWebhook ─────────────────────────────────────────────────────────

function signed(body) {
  return { rawBody: Buffer.from(body), signature: crypto.createHmac('sha512', SECRET).update(body).digest('hex') };
}

test('webhook rejects an unsigned or forged request', async () => {
  const db = createFakeFirestore(seedProduct());
  const body = JSON.stringify({ event: 'charge.success', data: { reference: 'SA-ref1' } });
  const code = await p.handleWebhook({ db, paystack: fakePaystack(), rawBody: body, signature: 'forged', secret: SECRET });
  assert.equal(code, 401);
});

test('webhook charge.success completes the payment after re-verifying', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ verifyResult: { status: 'success', amount: 2_000_000, currency: 'NGN' } });
  await startPayment(db, paystack);

  const body = JSON.stringify({ event: 'charge.success', data: { reference: 'SA-ref1', amount: 2_000_000 } });
  const code = await p.handleWebhook({ db, paystack, ...signed(body), secret: SECRET, now: NOW });

  assert.equal(code, 200);
  assert.deepEqual(paystack.calls.verify, ['SA-ref1']);
  assert.equal(db.store.get('payments/SA-ref1').status, 'success');
  assert.equal(db.store.get('orders/SA-ref1').status, 'paid');
});

test('webhook ignores unknown references and other events', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ verifyResult: { status: 'success', amount: 1, currency: 'NGN' } });
  const unknown = JSON.stringify({ event: 'charge.success', data: { reference: 'not-ours' } });
  assert.equal(await p.handleWebhook({ db, paystack, ...signed(unknown), secret: SECRET }), 200);
  const other = JSON.stringify({ event: 'transfer.success', data: { reference: 'SA-ref1' } });
  assert.equal(await p.handleWebhook({ db, paystack, ...signed(other), secret: SECRET }), 200);
  assert.equal(paystack.calls.verify.length, 0);
});

// ── Paystack client ───────────────────────────────────────────────────────

test('Paystack client sends the secret only in the Authorization header', async () => {
  const requests = [];
  const client = p.createPaystackClient({
    secretKey: SECRET,
    fetchImpl: async (url, init) => {
      requests.push({ url, init });
      return {
        ok: true,
        status: 200,
        json: async () => ({ status: true, data: { authorization_url: 'u', access_code: 'a', reference: 'r' } }),
      };
    },
  });
  const res = await client.initialize({ email: 'b@f.ng', amountKobo: 100, reference: 'r' });
  assert.equal(res.authorizationUrl, 'u');
  assert.equal(requests[0].init.headers.Authorization, `Bearer ${SECRET}`);
  assert.equal(requests[0].init.body.includes(SECRET), false);
  assert.equal(JSON.parse(requests[0].init.body).currency, 'NGN');
});

test('Paystack client turns provider errors into PaymentError', async () => {
  const client = p.createPaystackClient({
    secretKey: SECRET,
    fetchImpl: async () => ({ ok: false, status: 400, json: async () => ({ status: false, message: 'Invalid key' }) }),
  });
  await assert.rejects(client.verify('r'), { code: 'unavailable', message: 'Invalid key' });
});

// ── Farmer payouts (Paystack split) ────────────────────────────────────────

test('computeSplit keeps the platform fee and gives the seller the rest', () => {
  assert.deepEqual(p.computeSplit(2_000_000, 5), {
    platformFeeKobo: 100_000,
    sellerShareKobo: 1_900_000,
  });
  assert.deepEqual(p.computeSplit(1_000, 0), { platformFeeKobo: 0, sellerShareKobo: 1_000 });
  for (const bad of [-1, 51, Number.NaN, 'x']) {
    assert.throws(() => p.computeSplit(1_000, bad), /fee is misconfigured/);
  }
});

test('a seller without a bank account cannot be paid', async () => {
  const db = createFakeFirestore(seedProduct({}, { payout: false }));
  const paystack = fakePaystack();
  await assert.rejects(startPayment(db, paystack), (err) => {
    assert.equal(err.code, 'failed-precondition');
    assert.match(err.message, /can't receive payments yet/);
    return true;
  });
  assert.equal(paystack.calls.initialize.length, 0);
  assert.equal(db.store.has('payments/SA-ref1'), false);
});

test('checkout is split to the seller subaccount with the platform fee', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack();
  const res = await startPayment(db, paystack, { feePercent: 5 });

  const init = paystack.calls.initialize[0];
  assert.equal(init.amountKobo, 2_000_000);
  assert.equal(init.subaccount, 'ACCT_seller1');
  assert.equal(init.transactionChargeKobo, 100_000);
  assert.equal(res.sellerShareKobo, 1_900_000);

  const record = db.store.get('payments/SA-ref1');
  assert.equal(record.platformFeeKobo, 100_000);
  assert.equal(record.sellerShareKobo, 1_900_000);
  assert.equal(record.subaccountCode, 'ACCT_seller1');
});

test('the paid order records what the seller receives', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({
    verifyResult: { status: 'success', amount: 2_000_000, currency: 'NGN' },
  });
  await startPayment(db, paystack, { feePercent: 5 });
  await p.verifyPayment({ db, paystack, uid: 'buyer-1', reference: 'SA-ref1', now: NOW });
  const order = db.store.get('orders/SA-ref1');
  assert.equal(order.sellerShareKobo, 1_900_000);
  assert.equal(order.platformFeeKobo, 100_000);
});

function recordingFetch(responses) {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    const body = responses.shift();
    return { ok: true, status: 200, json: async () => body };
  };
  return { calls, fetchImpl };
}

test('Paystack client sends subaccount, flat charge and bearer on split', async () => {
  const { calls, fetchImpl } = recordingFetch([
    { status: true, data: { authorization_url: 'u', access_code: 'a', reference: 'r' } },
  ]);
  const client = p.createPaystackClient({ secretKey: SECRET, fetchImpl });
  await client.initialize({
    email: 'b@farm.ng',
    amountKobo: 2_000_000,
    reference: 'r',
    subaccount: 'ACCT_x',
    transactionChargeKobo: 100_000,
  });
  const body = JSON.parse(calls[0].init.body);
  assert.equal(body.subaccount, 'ACCT_x');
  assert.equal(body.transaction_charge, 100_000);
  assert.equal(body.bearer, 'account');
});

test('Paystack client lists active banks across pages, sorted', async () => {
  const { calls, fetchImpl } = recordingFetch([
    {
      status: true,
      data: [
        { name: 'Zenith Bank', code: '057', active: true },
        { name: 'Old Bank', code: '999', active: false },
      ],
      meta: { next: 'cursor2' },
    },
    { status: true, data: [{ name: 'Access Bank', code: '044', active: true }], meta: {} },
  ]);
  const client = p.createPaystackClient({ secretKey: SECRET, fetchImpl });
  const banks = await client.listBanks();
  assert.deepEqual(banks, [
    { name: 'Access Bank', code: '044' },
    { name: 'Zenith Bank', code: '057' },
  ]);
  assert.match(calls[1].url, /next=cursor2/);
});

// ── Buying part of a lot ───────────────────────────────────────────────────

test('a buyer can pay for part of a lot', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack();
  const res = await startPayment(db, paystack, { quantityKg: 10, feePercent: 5 });
  // 10 kg × ₦500 = ₦5,000
  assert.equal(paystack.calls.initialize[0].amountKobo, 500_000);
  assert.equal(paystack.calls.initialize[0].transactionChargeKobo, 25_000);
  assert.equal(res.quantityKg, 10);
  assert.equal(res.description, '10 kg of Maize');
  assert.equal(db.store.get('payments/SA-ref1').quantityKg, 10);
});

test('the quantity must be a whole number of kg within what is available', async () => {
  for (const bad of [0, -1, 2.5, 41, '10']) {
    const db = createFakeFirestore(seedProduct());
    await assert.rejects(startPayment(db, fakePaystack(), { quantityKg: bad }), (err) => {
      assert.equal(err.code, 'invalid-argument');
      assert.match(err.message, /between 1 and 40 kg/);
      return true;
    });
  }
});

test('a partial purchase reduces stock but keeps the listing on sale', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ verifyResult: { status: 'success', amount: 500_000, currency: 'NGN' } });
  await startPayment(db, paystack, { quantityKg: 10 });
  await p.verifyPayment({ db, paystack, uid: 'buyer-1', reference: 'SA-ref1', now: NOW });

  const product = db.store.get('products/p1');
  assert.equal(product.quantityKg, 30);
  assert.equal(product.availability, 'in_stock');
  assert.equal(db.store.get('orders/SA-ref1').quantityKg, 10);
  assert.equal(db.store.get('orders/SA-ref1').shortfallKg, undefined);
});

test('buying the last kilos marks the listing sold out', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ verifyResult: { status: 'success', amount: 2_000_000, currency: 'NGN' } });
  await startPayment(db, paystack, { quantityKg: 40 });
  await p.verifyPayment({ db, paystack, uid: 'buyer-1', reference: 'SA-ref1', now: NOW });
  assert.equal(db.store.get('products/p1').quantityKg, 0);
  assert.equal(db.store.get('products/p1').availability, 'sold_out');
});

test('when two buyers race for the last kilos, the late order is flagged', async () => {
  const db = createFakeFirestore(seedProduct());
  const paystack = fakePaystack({ verifyResult: { status: 'success', amount: 1_500_000, currency: 'NGN' } });
  await startPayment(db, paystack, { quantityKg: 30 });
  // Someone else bought 20 kg in the meantime: only 20 left.
  db.store.set('products/p1', { ...db.store.get('products/p1'), quantityKg: 20 });
  await p.verifyPayment({ db, paystack, uid: 'buyer-1', reference: 'SA-ref1', now: NOW });

  const order = db.store.get('orders/SA-ref1');
  assert.equal(order.quantityKg, 30);
  assert.equal(order.shortfallKg, 10);
  assert.equal(db.store.get('products/p1').quantityKg, 0);
  assert.equal(db.store.get('products/p1').availability, 'sold_out');
});
