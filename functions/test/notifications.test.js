'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const n = require('../src/notifications');

function fakeDeps(users = {}) {
  const calls = { added: [], sent: [], cleared: [] };
  return {
    calls,
    getUser: async (uid) => users[uid],
    addNotification: async (uid, doc) => calls.added.push({ uid, doc }),
    send: async (msg) => {
      if (msg.token === 'dead') {
        const e = new Error('gone');
        e.code = 'messaging/registration-token-not-registered';
        throw e;
      }
      if (msg.token === 'flaky') {
        const e = new Error('later');
        e.code = 'messaging/internal-error';
        throw e;
      }
      calls.sent.push(msg);
    },
    clearToken: async (uid) => calls.cleared.push(uid),
    log: { warn: () => {} },
  };
}

test('formats naira from kobo with thousands separators', () => {
  assert.equal(n.formatNaira(5000000), '₦50,000');
  assert.equal(n.formatNaira(253000000), '₦2,530,000');
  assert.equal(n.formatNaira(0), '₦0');
});

test('message previews: text, photo, voice, long text', () => {
  assert.equal(n.preview({ text: '  Is it  still available? ' }), 'Is it still available?');
  assert.equal(n.preview({ kind: 'image', imageUrl: 'x' }), '📷 Photo');
  assert.equal(n.preview({ kind: 'voice', audioUrl: 'x' }), '🎤 Voice note');
  const long = n.preview({ text: 'a'.repeat(300) });
  assert.equal(long.length, 100);
  assert.ok(long.endsWith('…'));
});

test('a chat message notifies the other person and opens the chat', () => {
  const out = n.messageNotification({
    threadId: 'buyer1_farmer2',
    message: { fromId: 'farmer2', text: 'Yes, 50 kg left' },
    thread: { names: { farmer2: 'Abubakar', buyer1: 'Test Buyer' } },
  });
  assert.equal(out.recipientId, 'buyer1');
  assert.equal(out.title, 'Abubakar');
  assert.equal(out.body, 'Yes, 50 kg left');
  assert.equal(out.route, '/chat/buyer1_farmer2?name=Abubakar&peerId=farmer2');
  assert.equal(out.saveToInbox, false);
});

test('no notification for a malformed chat id or missing sender', () => {
  assert.equal(n.messageNotification({ threadId: 'solo', message: { fromId: 'solo' } }), null);
  assert.equal(n.messageNotification({ threadId: 'a_b', message: { text: 'x' } }), null);
});

test('a paid order notifies seller and buyer with the amount', () => {
  const [seller, buyer] = n.orderNotifications({
    reference: 'ref1',
    sellerId: 'farmer2',
    buyerId: 'buyer1',
    description: '50 kg of Fresh Tomato',
    amountKobo: 5000000,
  });
  assert.equal(seller.recipientId, 'farmer2');
  assert.match(seller.body, /50 kg of Fresh Tomato, ₦50,000/);
  assert.equal(buyer.recipientId, 'buyer1');
  assert.equal(buyer.title, 'Payment confirmed');
  assert.ok(seller.saveToInbox && buyer.saveToInbox);
});

test('delivery saves to the inbox and pushes when there is a token', async () => {
  const deps = fakeDeps({ farmer2: { fcmToken: 'tok' } });
  const [seller] = n.orderNotifications({ sellerId: 'farmer2', amountKobo: 100 });
  const res = await n.deliver(seller, deps);
  assert.deepEqual(res, { saved: true, pushed: true });
  assert.equal(deps.calls.added[0].uid, 'farmer2');
  assert.equal(deps.calls.added[0].doc.read, false);
  assert.equal(deps.calls.sent[0].token, 'tok');
  assert.equal(deps.calls.sent[0].data.route, '/orders');
  // FCM data values must all be strings.
  for (const v of Object.values(deps.calls.sent[0].data)) assert.equal(typeof v, 'string');
});

test('chat pushes are not saved to the Notifications list', async () => {
  const deps = fakeDeps({ buyer1: { fcmToken: 'tok' } });
  const msg = n.messageNotification({
    threadId: 'buyer1_farmer2',
    message: { fromId: 'farmer2', text: 'hi' },
  });
  const res = await n.deliver(msg, deps);
  assert.deepEqual(res, { saved: false, pushed: true });
  assert.equal(deps.calls.added.length, 0);
});

test('no token: inbox entry still saved, nothing pushed', async () => {
  const deps = fakeDeps({ farmer2: {} });
  const [seller] = n.orderNotifications({ sellerId: 'farmer2', amountKobo: 100 });
  assert.deepEqual(await n.deliver(seller, deps), { saved: true, pushed: false });
});

test('a dead token is removed so we stop trying it', async () => {
  const deps = fakeDeps({ buyer1: { fcmToken: 'dead' } });
  const msg = n.messageNotification({
    threadId: 'buyer1_farmer2',
    message: { fromId: 'farmer2', text: 'hi' },
  });
  const res = await n.deliver(msg, deps);
  assert.equal(res.pushed, false);
  assert.deepEqual(deps.calls.cleared, ['buyer1']);
});

test('a temporary push failure keeps the token', async () => {
  const deps = fakeDeps({ buyer1: { fcmToken: 'flaky' } });
  const msg = n.messageNotification({
    threadId: 'buyer1_farmer2',
    message: { fromId: 'farmer2', text: 'hi' },
  });
  await n.deliver(msg, deps);
  assert.deepEqual(deps.calls.cleared, []);
});
