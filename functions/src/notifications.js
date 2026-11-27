'use strict';

/**
 * Notifications: who to tell about what, and how to deliver it.
 *
 * Pure logic with injected dependencies so it can be unit-tested without
 * Firebase. index.js wires it to Firestore triggers and Cloud Messaging.
 *
 * - New chat message → push to the other person (not saved to their
 *   Notifications list: chats would flood it).
 * - New paid order → push + Notifications-list entry for seller and buyer.
 */

const PREVIEW_LENGTH = 100;

/** Tokens FCM will never accept again (app uninstalled, data cleared). */
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** "₦50,000" from kobo, without relying on the server's locale data. */
function formatNaira(kobo) {
  const naira = Math.round(Number(kobo || 0) / 100);
  return `₦${String(naira).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}`;
}

function preview(message) {
  if (message.kind === 'voice' || message.audioUrl) return '🎤 Voice note';
  if (message.kind === 'image' || message.imageUrl) return '📷 Photo';
  const text = String(message.text || '').replace(/\s+/g, ' ').trim();
  if (!text) return 'New message';
  return text.length > PREVIEW_LENGTH ? `${text.slice(0, PREVIEW_LENGTH - 1)}…` : text;
}

/**
 * The push for a new chat message, or null when there is no one to tell.
 * Chat ids are the two user ids sorted and joined with "_".
 */
function messageNotification({ threadId, message, thread }) {
  if (!message || !message.fromId || typeof threadId !== 'string') return null;
  const recipientId = threadId.split('_').find((id) => id && id !== message.fromId);
  if (!recipientId) return null;

  const names = (thread && thread.names) || {};
  const senderName = names[message.fromId] || 'New message';
  return {
    recipientId,
    title: senderName,
    body: preview(message),
    type: 'message',
    // Opens the chat with the sender when tapped.
    route: `/chat/${threadId}?name=${encodeURIComponent(senderName)}` +
      `&peerId=${encodeURIComponent(message.fromId)}`,
    // One notification per chat on the phone, replaced by newer messages.
    tag: `chat_${threadId}`,
    saveToInbox: false,
  };
}

/** Pushes for a newly paid order: one to the seller, one to the buyer. */
function orderNotifications(order) {
  if (!order) return [];
  const what = order.description || 'your order';
  const amount = formatNaira(order.amountKobo);
  const out = [];
  if (order.sellerId) {
    out.push({
      recipientId: order.sellerId,
      title: 'New paid order',
      body: `${what}, ${amount}. Contact the buyer to arrange delivery.`,
      type: 'order',
      route: '/orders',
      tag: `order_${order.reference || ''}`,
      saveToInbox: true,
    });
  }
  if (order.buyerId) {
    out.push({
      recipientId: order.buyerId,
      title: 'Payment confirmed',
      body: `${what}, ${amount}. The seller has been told.`,
      type: 'order',
      route: '/orders',
      tag: `order_${order.reference || ''}`,
      saveToInbox: true,
    });
  }
  return out;
}

/**
 * Notifications for delivery-tracking changes on an order:
 * dispatched → tell the buyer; received → tell the seller; rated → tell
 * the seller. Returns [] for any other update.
 */
function orderStatusNotifications(before, after) {
  if (!before || !after) return [];
  const what = after.description || 'your order';
  const base = {
    type: 'order',
    route: '/orders',
    tag: `order_${after.reference || ''}`,
    saveToInbox: true,
  };
  const out = [];
  if (before.status !== 'dispatched' && after.status === 'dispatched' && after.buyerId) {
    out.push({
      ...base,
      recipientId: after.buyerId,
      title: 'Your order is on the way',
      body: `The seller has dispatched ${what}. Tap "I received it" when it arrives.`,
    });
  }
  if (before.status !== 'received' && after.status === 'received' && after.sellerId) {
    out.push({
      ...base,
      recipientId: after.sellerId,
      title: 'Delivery confirmed',
      body: `The buyer received ${what}.`,
    });
  }
  if (!before.rating && Number.isInteger(after.rating) && after.sellerId) {
    const stars = '★'.repeat(after.rating) + '☆'.repeat(5 - after.rating);
    const review = String(after.review || '').trim();
    out.push({
      ...base,
      recipientId: after.sellerId,
      title: `New rating: ${stars}`,
      body: review ? `"${review.slice(0, 120)}"` : `For ${what}.`,
    });
  }
  return out;
}

/**
 * Delivers one notification.
 *
 * deps:
 *   getUser(uid)              → { fcmToken? } | undefined
 *   addNotification(uid, doc) → saves to users/{uid}/notifications
 *   send(message)             → FCM send; throws { code } on failure
 *   clearToken(uid)           → removes a dead fcmToken
 *   log?                      → { warn(msg, extra) }
 *
 * Returns { saved, pushed } so callers and tests can see what happened.
 */
async function deliver(n, deps) {
  const result = { saved: false, pushed: false };
  if (!n || !n.recipientId) return result;

  if (n.saveToInbox) {
    await deps.addNotification(n.recipientId, {
      title: n.title,
      body: n.body,
      type: n.type,
      route: n.route || null,
      read: false,
    });
    result.saved = true;
  }

  const user = await deps.getUser(n.recipientId);
  const token = user && user.fcmToken;
  if (!token) return result;

  try {
    await deps.send({
      token,
      notification: { title: n.title, body: n.body },
      // Strings only: FCM data values must be strings. The app opens
      // `route` when the notification is tapped.
      data: { type: n.type, route: n.route || '' },
      android: {
        priority: 'high',
        notification: { tag: n.tag },
      },
    });
    result.pushed = true;
  } catch (err) {
    if (err && DEAD_TOKEN_CODES.has(err.code)) {
      await deps.clearToken(n.recipientId);
    } else if (deps.log) {
      deps.log.warn('Push failed', { uid: n.recipientId, code: err && err.code });
    }
  }
  return result;
}

module.exports = {
  formatNaira,
  preview,
  messageNotification,
  orderNotifications,
  orderStatusNotifications,
  deliver,
  DEAD_TOKEN_CODES,
};
