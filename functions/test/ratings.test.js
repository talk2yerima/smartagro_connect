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
  assert.deepEqual(ratings.averageAfter({}, 4), { ratingSum: 4, ratingCount: 1, rating: 4 });
  assert.deepEqual(ratings.averageAfter({ ratingSum: 9, ratingCount: 2 }, 3), {
    ratingSum: 12,
    ratingCount: 3,
    rating: 4,
  });
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
