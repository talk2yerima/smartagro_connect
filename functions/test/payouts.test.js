'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const payouts = require('../src/payouts');
const { createFakeFirestore } = require('./fake-firestore');

const NOW = () => new Date('2026-11-18T09:00:00Z');

function fakePaystack({ accountName = 'ABUBAKAR YERIMA', resolveFails = false } = {}) {
  const calls = { resolve: [], create: [], update: [] };
  return {
    calls,
    async resolveAccount(args) {
      calls.resolve.push(args);
      if (resolveFails) throw new Error('not found');
      return { accountName, accountNumber: args.accountNumber };
    },
    async createSubaccount(details) {
      calls.create.push(details);
      return { subaccountCode: 'ACCT_new' };
    },
    async updateSubaccount(code, details) {
      calls.update.push({ code, details });
      return { subaccountCode: code };
    },
  };
}

function farmer(extra = {}) {
  return { 'users/f1': { name: 'Abubakar', role: 'farmer', email: 'a@farm.ng', ...extra } };
}

function save(db, paystack, extra = {}) {
  return payouts.savePayoutAccount({
    db,
    paystack,
    uid: 'f1',
    accountNumber: '0123456789',
    bankCode: '057',
    bankName: 'Zenith Bank',
    feePercent: 5,
    now: NOW,
    ...extra,
  });
}

test('account numbers must be 10 digits; spaces are ignored', () => {
  assert.equal(payouts.normalizeAccountNumber('0123 456 789'), '0123456789');
  assert.equal(payouts.normalizeAccountNumber('123456789'), null);
  assert.equal(payouts.normalizeAccountNumber('01234567890'), null);
  assert.equal(payouts.maskAccountNumber('0123456789'), '******6789');
});

test('checking an account returns the name the bank has on file', async () => {
  const paystack = fakePaystack();
  const res = await payouts.resolveBankAccount({
    paystack,
    uid: 'f1',
    accountNumber: '0123456789',
    bankCode: '057',
  });
  assert.deepEqual(res, { accountName: 'ABUBAKAR YERIMA', accountNumberMasked: '******6789' });
});

test('an unknown account gets a plain message', async () => {
  await assert.rejects(
    payouts.resolveBankAccount({
      paystack: fakePaystack({ resolveFails: true }),
      uid: 'f1',
      accountNumber: '0123456789',
      bankCode: '057',
    }),
    /couldn't find that account/,
  );
});

test('first save creates a subaccount and stores only a masked number', async () => {
  const db = createFakeFirestore(farmer());
  const paystack = fakePaystack();
  const res = await save(db, paystack);

  assert.equal(paystack.calls.create.length, 1);
  assert.equal(paystack.calls.create[0].percentageCharge, 5);
  assert.equal(paystack.calls.create[0].accountNumber, '0123456789');
  const stored = db.store.get('payoutAccounts/f1');
  assert.equal(stored.subaccountCode, 'ACCT_new');
  assert.equal(stored.accountNumberMasked, '******6789');
  assert.equal(stored.accountName, 'ABUBAKAR YERIMA');
  assert.ok(!JSON.stringify(stored).includes('0123456789'), 'full number not stored');
  assert.equal(db.store.get('users/f1').payoutReady, true);
  assert.equal(res.bankName, 'Zenith Bank');
});

test('changing the account updates the same subaccount', async () => {
  const db = createFakeFirestore({
    ...farmer(),
    'payoutAccounts/f1': { subaccountCode: 'ACCT_old', createdAt: 'then' },
  });
  const paystack = fakePaystack();
  await save(db, paystack, { accountNumber: '9876543210' });
  assert.equal(paystack.calls.create.length, 0);
  assert.equal(paystack.calls.update[0].code, 'ACCT_old');
  assert.equal(db.store.get('payoutAccounts/f1').subaccountCode, 'ACCT_old');
  assert.equal(db.store.get('payoutAccounts/f1').createdAt, 'then');
});

test('buyers and transporters cannot add payout accounts', async () => {
  for (const role of ['buyer', 'transporter']) {
    const db = createFakeFirestore(farmer({ role }));
    await assert.rejects(save(db, fakePaystack()), /Only sellers/);
  }
});

test('a suspended seller cannot add an account', async () => {
  const db = createFakeFirestore(farmer({ banned: true }));
  await assert.rejects(save(db, fakePaystack()), /suspended/);
});

test('nothing is created when the bank cannot confirm the account', async () => {
  const db = createFakeFirestore(farmer());
  const paystack = fakePaystack({ resolveFails: true });
  await assert.rejects(save(db, paystack), /couldn't find that account/);
  assert.equal(paystack.calls.create.length, 0);
  assert.equal(db.store.has('payoutAccounts/f1'), false);
});
