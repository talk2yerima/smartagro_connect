'use strict';

/**
 * Seller ratings from delivered orders.
 *
 * A buyer can rate an order once, after confirming receipt (enforced by
 * firestore.rules). This keeps the seller's average on their profile:
 * users/{sellerId}.rating (1 decimal), ratingCount and ratingSum. Only this
 * backend can write those fields (rating is protected in the rules).
 */

/** The new rating on an order update, or null if this update isn't one. */
function newRating(before, after) {
  if (!after || !after.sellerId) return null;
  const was = before && before.rating;
  const now = after.rating;
  if (was || !Number.isInteger(now) || now < 1 || now > 5) return null;
  return { sellerId: after.sellerId, rating: now };
}

/** Running average, rounded to one decimal. */
function averageAfter({ ratingSum = 0, ratingCount = 0 }, rating) {
  const sum = Number(ratingSum) + rating;
  const count = Number(ratingCount) + 1;
  return { ratingSum: sum, ratingCount: count, rating: Math.round((sum / count) * 10) / 10 };
}

/** Adds one rating to the seller's profile, safely under concurrency. */
async function applyRating({ db, sellerId, rating }) {
  const userRef = db.collection('users').doc(sellerId);
  return db.runTransaction(async (t) => {
    const snap = await t.get(userRef);
    if (!snap.exists) return null;
    const next = averageAfter(snap.data(), rating);
    t.update(userRef, next);
    return next;
  });
}

module.exports = { newRating, averageAfter, applyRating };
