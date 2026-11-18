'use strict';

/**
 * Farmer payouts: each seller's bank account becomes a Paystack
 * subaccount, so every sale is split at Paystack and the seller is paid at
 * settlement without anyone moving money by hand.
 *
 * Bank details are checked with the bank (Paystack /bank/resolve) on the
 * server, never trusted from the phone. Only a masked account number is
 * stored in Firestore; Paystack holds the full details.
 */

const { PaymentError } = require('./payments');

/** Roles that sell produce and therefore need a payout account. */
const SELLER_ROLES = new Set(['farmer', 'admin']);

/** Nigerian NUBAN: exactly 10 digits. Returns null when invalid. */
function normalizeAccountNumber(value) {
  const digits = String(value || '').replace(/\D/g, '');
  return /^\d{10}$/.test(digits) ? digits : null;
}

function normalizeBankCode(value) {
  const code = String(value || '').trim();
  return /^[0-9A-Za-z-]{2,20}$/.test(code) ? code : null;
}

function maskAccountNumber(nuban) {
  return `******${nuban.slice(-4)}`;
}

function requireValidAccount({ accountNumber, bankCode }) {
  const nuban = normalizeAccountNumber(accountNumber);
  if (!nuban) {
    throw new PaymentError('invalid-argument', 'Enter your 10-digit account number.');
  }
  const code = normalizeBankCode(bankCode);
  if (!code) throw new PaymentError('invalid-argument', 'Choose your bank.');
  return { nuban, code };
}

/** "Check account": the name the bank has on file for this account. */
async function resolveBankAccount({ paystack, uid, accountNumber, bankCode }) {
  if (!uid) throw new PaymentError('unauthenticated', 'Sign in to add a bank account.');
  const { nuban, code } = requireValidAccount({ accountNumber, bankCode });
  try {
    const { accountName } = await paystack.resolveAccount({ accountNumber: nuban, bankCode: code });
    if (!accountName) throw new Error('no name');
    return { accountName, accountNumberMasked: maskAccountNumber(nuban) };
  } catch (_) {
    throw new PaymentError(
      'not-found',
      "We couldn't find that account. Check the bank and the 10-digit number.",
    );
  }
}

/**
 * Saves (or replaces) the seller's payout account: verifies it with the
 * bank, creates/updates their Paystack subaccount, and records it.
 */
async function savePayoutAccount({
  db,
  paystack,
  uid,
  accountNumber,
  bankCode,
  bankName,
  feePercent,
  now = () => new Date(),
}) {
  if (!uid) throw new PaymentError('unauthenticated', 'Sign in to add a bank account.');
  const { nuban, code } = requireValidAccount({ accountNumber, bankCode });

  const userSnap = await db.collection('users').doc(uid).get();
  const user = userSnap.exists ? userSnap.data() : null;
  if (!user || !SELLER_ROLES.has(user.role)) {
    throw new PaymentError('permission-denied', 'Only sellers can add a payout account.');
  }
  if (user.banned) {
    throw new PaymentError('permission-denied', 'This account has been suspended.');
  }

  const { accountName } = await resolveBankAccount({
    paystack,
    uid,
    accountNumber: nuban,
    bankCode: code,
  });

  const businessName = `SmartAgro: ${user.name || accountName}`.slice(0, 100);
  const accountRef = db.collection('payoutAccounts').doc(uid);
  const existingSnap = await accountRef.get();
  const existing = existingSnap.exists ? existingSnap.data() : null;

  const details = {
    businessName,
    bankCode: code,
    accountNumber: nuban,
    percentageCharge: Number(feePercent),
    email: user.email || undefined,
  };
  let subaccountCode;
  try {
    ({ subaccountCode } = existing && existing.subaccountCode
      ? await paystack.updateSubaccount(existing.subaccountCode, details)
      : await paystack.createSubaccount(details));
  } catch (err) {
    throw err instanceof PaymentError
      ? err
      : new PaymentError('unavailable', 'Could not save your bank account. Try again.');
  }

  const record = {
    subaccountCode,
    bankCode: code,
    bankName: String(bankName || '').slice(0, 100) || code,
    accountName,
    accountNumberMasked: maskAccountNumber(nuban),
    updatedAt: now(),
  };
  if (!existing) record.createdAt = now();
  await accountRef.set(existing ? { ...existing, ...record } : record);
  // Public flag so buyers can see the seller can be paid. Only this backend
  // can set it (protected in firestore.rules).
  await db.collection('users').doc(uid).update({ payoutReady: true });

  return {
    bankName: record.bankName,
    accountName,
    accountNumberMasked: record.accountNumberMasked,
  };
}

module.exports = {
  SELLER_ROLES,
  normalizeAccountNumber,
  maskAccountNumber,
  resolveBankAccount,
  savePayoutAccount,
};
