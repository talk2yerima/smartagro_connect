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

/** Running average (one decimal) and how many ratings of each star. */
function averageAfter({ ratingSum = 0, ratingCount = 0, ratingCounts = {} }, rating) {
  const sum = Number(ratingSum) + rating;
  const count = Number(ratingCount) + 1;
  const counts = {};
  for (const star of ['1', '2', '3', '4', '5']) counts[star] = Number(ratingCounts[star] || 0);
  counts[String(rating)] += 1;
  return {
    ratingSum: sum,
    ratingCount: count,
    ratingCounts: counts,
    rating: Math.round((sum / count) * 10) / 10,
  };
}

/**
 * The public review shown on the farmer's profile (reviews/{orderRef}).
 * Only the buyer's first name is shown; never their contact details.
 */
/** Quick tags a buyer may add (same list as the app and the rules). */
const REVIEW_TAGS = ['Fresh produce', 'Well packed', 'Fast delivery', 'As described', 'Fair price', 'Friendly seller', 'Late delivery', 'Poor quality', 'Short weight'];

function reviewDoc(orderRef, order, buyerName) {
  const first = String(buyerName || '').trim().split(/\s+/)[0] || 'Buyer';
  const text = String(order.review || '').trim().slice(0, 500);
  const tags = Array.isArray(order.reviewTags)
    ? REVIEW_TAGS.filter((t) => order.reviewTags.includes(t)).slice(0, 6)
    : [];
  return {
    orderRef,
    sellerId: order.sellerId,
    buyerId: order.buyerId,
    buyerName: first.slice(0, 40),
    rating: order.rating,
    ...(text ? { review: text } : {}),
    ...(tags.length ? { tags } : {}),
    product: String(order.description || '').slice(0, 120),
  };
}

/**
 * Adds one rating to the seller's profile and publishes the review, in one
 * transaction. Safe to run twice for the same order (a retried trigger):
 * if the review already exists, nothing is counted again.
 */
async function applyRating({ db, sellerId, rating, review, now }) {
  const userRef = db.collection('users').doc(sellerId);
  const reviewRef = review ? db.collection('reviews').doc(review.orderRef) : null;
  return db.runTransaction(async (t) => {
    if (reviewRef) {
      const existing = await t.get(reviewRef);
      if (existing.exists) return null;
    }
    const snap = await t.get(userRef);
    if (!snap.exists) return null;
    const next = averageAfter(snap.data(), rating);
    t.update(userRef, next);
    if (reviewRef) t.set(reviewRef, { ...review, createdAt: now || new Date() });
    return next;
  });
}

module.exports = { newRating, averageAfter, reviewDoc, applyRating, REVIEW_TAGS };
