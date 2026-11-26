'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const h = require('../src/haulage');

const job = (extra = {}) => ({
  orderId: 'SA-1', description: '50 kg of Maize', buyerId: 'bob', sellerId: 'alice',
  requesterId: 'alice', status: 'open', distanceKm: 168.4, offerNgn: 20000,
  pickup: { label: 'Gashua market', state: 'Yobe', lat: 12.87, lng: 11.04 },
  dropoff: { label: 'Kano', state: 'Kano', lat: 12, lng: 8.59 },
  ...extra,
});
const to = (notes) => notes.map((n) => `${n.recipientId}:${n.title}`).sort();

test('a new job tells the other party, not the one who asked', () => {
  assert.deepEqual(to(h.jobNotifications('SA-1', null, job())), ['bob:Transport requested']);
  assert.deepEqual(
    to(h.jobNotifications('SA-1', job({ status: 'cancelled' }), job({ requesterId: 'bob' }))),
    ['alice:Transport requested']);
});

test('each step tells the right people', () => {
  const accepted = job({ status: 'accepted', transporterId: 't1', transporterName: 'Tunde' });
  assert.deepEqual(to(h.jobNotifications('SA-1', job(), accepted)),
    ['alice:Transporter found', 'bob:Transporter found']);
  const picked = { ...accepted, status: 'picked_up' };
  assert.deepEqual(to(h.jobNotifications('SA-1', accepted, picked)), ['alice:Produce collected']);
  const delivered = { ...accepted, status: 'delivered' };
  assert.deepEqual(to(h.jobNotifications('SA-1', picked, delivered)), ['alice:Delivered', 'bob:Delivered']);
  assert.deepEqual(to(h.jobNotifications('SA-1', accepted, job())),
    ['alice:Transporter dropped out', 'bob:Transporter dropped out']);
  assert.deepEqual(to(h.jobNotifications('SA-1', accepted, { ...accepted, status: 'cancelled' })),
    ['t1:Job cancelled']);
  assert.equal(h.jobNotifications('SA-1', job(), { ...job(), status: 'cancelled' }).length, 0);
});

test('location updates alone send nothing', () => {
  const a = job({ status: 'picked_up', transporterId: 't1' });
  assert.deepEqual(h.jobNotifications('SA-1', a, { ...a, driverLocation: { lat: 1, lng: 2 } }), []);
});

test('delivery notifications open the live delivery screen', () => {
  const [n] = h.jobNotifications('SA-1', null, job());
  assert.equal(n.route, '/delivery/SA-1');
  assert.equal(n.type, 'delivery');
});

test('new jobs alert transporters in the pickup state, else everyone', () => {
  const ts = [
    { id: 't1', location: 'Damaturu, Yobe' },
    { id: 't2', location: 'Kano' },
    { id: 't3', location: 'yobe state', banned: true },
    { id: 'alice', location: 'Yobe' },
  ];
  assert.deepEqual(h.transportersToAlert(job(), ts).map((t) => t.id), ['t1']);
  const elsewhere = job({ pickup: { label: 'Jos', state: 'Plateau', lat: 9.9, lng: 8.9 } });
  assert.deepEqual(h.transportersToAlert(elsewhere, ts).map((t) => t.id), ['t1', 't2']);
  // The transporter who handed the job back isn't alerted about it again.
  assert.deepEqual(h.transportersToAlert(job(), ts, { exclude: 't1' }).map((t) => t.id), ['t2']);
  const many = Array.from({ length: 150 }, (_, i) => ({ id: `t${i}`, location: 'Yobe' }));
  assert.equal(h.transportersToAlert(job(), many).length, h.MAX_TRANSPORTER_ALERTS);
});

test('the job alert reads like a job card', () => {
  const n = h.newJobAlert('SA-1', job(), 't1');
  assert.equal(n.title, 'New job: Yobe → Kano');
  assert.equal(n.body, '50 kg of Maize · about 168 km · ₦20,000');
  assert.equal(n.saveToInbox, false);
});

test('collection marks a paid order as dispatched, once', () => {
  const a = job({ status: 'accepted' });
  const p = job({ status: 'picked_up' });
  assert.equal(h.shouldMarkOrderDispatched(a, p, { status: 'paid' }), true);
  assert.equal(h.shouldMarkOrderDispatched(a, p, { status: 'dispatched' }), false);
  assert.equal(h.shouldMarkOrderDispatched(p, { ...p, driverLocation: {} }, { status: 'paid' }), false);
});
