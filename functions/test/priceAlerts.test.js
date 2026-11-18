'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const pa = require('../src/priceAlerts');

const alert = (extra) => ({
  id: 'a1',
  uid: 'u1',
  commodityId: 'maize',
  commodityName: 'Maize',
  unit: 'bag (100 kg)',
  active: true,
  ...extra,
});

test('a rise past an "above" target fires; staying below does not', () => {
  const up = alert({ direction: 'above', targetNgn: 30000 });
  assert.deepEqual(pa.crossedAlerts(28000, 30000, [up]), [up]);
  assert.deepEqual(pa.crossedAlerts(28000, 31000, [up]), [up]);
  assert.deepEqual(pa.crossedAlerts(28000, 29999, [up]), []);
  // Already above before the change: it fired (or was set) earlier.
  assert.deepEqual(pa.crossedAlerts(30500, 31000, [up]), []);
});

test('a fall past a "below" target fires; a rise does not', () => {
  const down = alert({ direction: 'below', targetNgn: 25000 });
  assert.deepEqual(pa.crossedAlerts(28000, 25000, [down]), [down]);
  assert.deepEqual(pa.crossedAlerts(28000, 26000, [down]), []);
  assert.deepEqual(pa.crossedAlerts(24000, 23000, [down]), []);
});

test('used-up alerts and unchanged prices never fire', () => {
  const used = alert({ direction: 'above', targetNgn: 30000, active: false });
  assert.deepEqual(pa.crossedAlerts(28000, 31000, [used]), []);
  const up = alert({ direction: 'above', targetNgn: 30000 });
  assert.deepEqual(pa.crossedAlerts(28000, 28000, [up]), []);
});

test('the notification names the commodity, price and target', () => {
  const n = pa.alertNotification(
    alert({ direction: 'above', targetNgn: 30000 }),
    { name: 'Maize', unit: 'bag (100 kg)' },
    31500,
  );
  assert.equal(n.recipientId, 'u1');
  assert.equal(n.title, 'Maize is now ₦31,500 per bag (100 kg)');
  assert.equal(n.body, 'The price rose above your alert of ₦30,000.');
  assert.equal(n.route, '/main/market/commodity/maize');
  assert.equal(n.type, 'price_alert');
  assert.ok(n.saveToInbox);
});
