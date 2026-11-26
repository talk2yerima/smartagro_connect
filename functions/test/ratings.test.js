'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const ratings = require('../src/ratings');
const n = require('../src/notifications');
const { createFakeFirestore } = require('./fake-firestore');

const order = (extra = {}) => ({
  reference: 'SA-1',
  buyerId: 'b1',
  sellerId: 's1',
  description: '50 kg of Fresh Tomato',
  status: 'paid',
  ...extra,
});

test('a first rating on an order is picked up; later edits are not', () => {
  assert.deepEqual(
    ratings.newRating(order({ status: 'received' }), order({ status: 'received', rating: 4 })),
    { sellerId: 's1', rating: 4 },
  );
  assert.equal(ratings.newRating(order({ rating: 4 }), order({ rating: 5 })), null);
  assert.equal(ratings.newRating(order(), order({ status: 'dispatched' })), null);
  assert.equal(ratings.newRating(order(), order({ rating: 9 })), null);
});

test('the seller average is a running mean to one decimal', () => {
  const first = ratings.averageAfter({}, 4);
  assert.equal(first.rating, 4);
  assert.equal(first.ratingCount, 1);
  assert.deepEqual(first.ratingCounts, { 1: 0, 2: 0, 3: 0, 4: 1, 5: 0 });
  const third = ratings.averageAfter(
    { ratingSum: 9, ratingCount: 2, ratingCounts: { 4: 1, 5: 1 } }, 3);
  assert.equal(third.ratingSum, 12);
  assert.equal(third.rating, 4);
  assert.deepEqual(third.ratingCounts, { 1: 0, 2: 0, 3: 1, 4: 1, 5: 1 });
  assert.equal(ratings.averageAfter({ ratingSum: 5, ratingCount: 1 }, 4).rating, 4.5);
  assert.equal(ratings.averageAfter({ ratingSum: 14, ratingCount: 3 }, 5).rating, 4.8);
});

test('applying a rating updates the seller profile', async () => {
  const db = createFakeFirestore({ 'users/s1': { name: 'Abubakar', rating: 5 } });
  const res = await ratings.applyRating({ db, sellerId: 's1', rating: 3 });
  assert.equal(res.rating, 3);
  assert.equal(db.store.get('users/s1').ratingCount, 1);
  assert.equal(db.store.get('users/s1').name, 'Abubakar');
});

test('a rating publishes one review, with the first name only, once', async () => {
  const db = createFakeFirestore({ 'users/s1': { name: 'Abubakar' } });
  const o = order({ status: 'received', rating: 5, review: '  Very fresh  ' });
  const review = ratings.reviewDoc('SA-1', o, 'Bola Ahmed Tinubu');
  assert.equal(review.buyerName, 'Bola');
  assert.equal(review.review, 'Very fresh');
  assert.equal(review.product, '50 kg of Fresh Tomato');
  const first = await ratings.applyRating({ db, sellerId: 's1', rating: 5, review });
  assert.equal(first.ratingCount, 1);
  assert.equal(db.store.get('reviews/SA-1').rating, 5);
  // A retried trigger must not count the same rating twice.
  const again = await ratings.applyRating({ db, sellerId: 's1', rating: 5, review });
  assert.equal(again, null);
  assert.equal(db.store.get('users/s1').ratingCount, 1);
  assert.equal(ratings.reviewDoc('SA-2', order({ rating: 3 }), '').buyerName, 'Buyer');
  // Never publish an email or a phone number typed into the name field.
  assert.equal(ratings.reviewDoc('SA-5', order({ rating: 3 }), 'testbuyer@gmail.com').buyerName, 'Buyer');
  assert.equal(ratings.reviewDoc('SA-6', order({ rating: 3 }), '+2348012345678').buyerName, 'Buyer');
  assert.equal(ratings.reviewDoc('SA-7', order({ rating: 3 }), '08012345678 Musa').buyerName, 'Buyer');
  assert.equal('review' in ratings.reviewDoc('SA-2', order({ rating: 3 }), 'Ada'), false);
  const tagged = ratings.reviewDoc('SA-3',
    order({ rating: 4, reviewTags: ['Fast delivery', 'made up', 'Fresh produce'] }), 'Ada');
  assert.deepEqual(tagged.tags, ['Fresh produce', 'Fast delivery']);
  assert.equal('tags' in ratings.reviewDoc('SA-4', order({ rating: 4 }), 'Ada'), false);
});

test('dispatch tells the buyer the order is on the way', () => {
  const [note] = n.orderStatusNotifications(order(), order({ status: 'dispatched' }));
  assert.equal(note.recipientId, 'b1');
  assert.equal(note.title, 'Your order is on the way');
  assert.equal(note.route, '/orders');
  assert.ok(note.saveToInbox);
});

test('receipt tells the seller delivery is confirmed', () => {
  const [note] = n.orderStatusNotifications(
    order({ status: 'dispatched' }),
    order({ status: 'received' }),
  );
  assert.equal(note.recipientId, 's1');
  assert.equal(note.title, 'Delivery confirmed');
});

test('a rating tells the seller, with the stars and review', () => {
  const [note] = n.orderStatusNotifications(
    order({ status: 'received' }),
    order({ status: 'received', rating: 4, review: 'Fresh and on time' }),
  );
  assert.equal(note.recipientId, 's1');
  assert.equal(note.title, 'New rating: ★★★★☆');
  assert.equal(note.body, '"Fresh and on time"');
});

test('other order updates send nothing', () => {
  assert.deepEqual(n.orderStatusNotifications(order(), order()), []);
  assert.deepEqual(
    n.orderStatusNotifications(order({ status: 'received' }), order({ status: 'received' })),
    [],
  );
});
