'use strict';

/**
 * Deliveries (haulage jobs): notifications for each step, and keeping the
 * order in step with its delivery.
 *
 * haulageJobs/{orderReference}:
 *   open → accepted → picked_up → delivered, or → cancelled by the buyer or
 *   seller; a transporter can hand an accepted job back (→ open).
 * firestore.rules decides who may take each step; this only reacts to them.
 */

const MAX_TRANSPORTER_ALERTS = 100;

function what(job) {
  return (job && job.description) || 'the produce';
}

function base(jobId) {
  return { type: 'delivery', route: `/delivery/${jobId}`, tag: `delivery_${jobId}`, saveToInbox: true };
}

function naira(n) {
  return `₦${Math.round(Number(n) || 0).toLocaleString('en-US')}`;
}

/**
 * Notifications for a job that was just written. [before] is null for a new
 * job. Returns [] when nothing worth telling happened.
 */
function jobNotifications(jobId, before, after) {
  if (!after) return [];
  const b = base(jobId);
  const out = [];
  const was = before ? before.status : null;
  const now = after.status;
  if (was === now) return out;
  const parties = [after.buyerId, after.sellerId].filter(Boolean);
  const toParties = (title, body, except) =>
    parties.filter((uid) => uid !== except).forEach((recipientId) => out.push({ ...b, recipientId, title, body }));

  // Posted (new, or reposted after a cancel): tell the other party.
  if (now === 'open' && (was === null || was === 'cancelled')) {
    toParties('Transport requested',
      `A transporter is being found to carry ${what(after)}.`, after.requesterId);
  }
  if (now === 'accepted' && was === 'open') {
    const name = after.transporterName || 'A transporter';
    toParties('Transporter found', `${name} accepted the job to carry ${what(after)}.`);
  }
  if (now === 'open' && was === 'accepted') {
    toParties('Transporter dropped out',
      `The job for ${what(after)} is back on the board for another transporter.`);
  }
  if (now === 'picked_up') {
    // The buyer hears through the order itself ("Your order is on the way").
    if (after.sellerId) {
      out.push({ ...b, recipientId: after.sellerId, title: 'Produce collected',
        body: `${after.transporterName || 'The transporter'} picked up ${what(after)}.` });
    }
  }
  if (now === 'delivered') {
    if (after.buyerId) {
      out.push({ ...b, recipientId: after.buyerId, title: 'Delivered',
        body: `${what(after)} has arrived. Check it, then tap "I received it" on the order.` });
    }
    if (after.sellerId) {
      out.push({ ...b, recipientId: after.sellerId, title: 'Delivered',
        body: `${what(after)} was delivered to the buyer.` });
    }
  }
  if (now === 'cancelled' && before && before.transporterId) {
    out.push({ ...b, route: '/jobs', recipientId: before.transporterId,
      title: 'Job cancelled', body: `The delivery of ${what(after)} was called off.` });
  }
  return out;
}

/**
 * Transporters to alert about a new open job: those whose profile location
 * mentions the pickup state; if nobody does, every transporter (capped).
 */
function transportersToAlert(job, transporters) {
  const state = String((job.pickup && job.pickup.state) || '').trim().toLowerCase();
  const eligible = transporters.filter((t) =>
    t.id !== job.buyerId && t.id !== job.sellerId && !t.banned);
  const nearby = state
    ? eligible.filter((t) => String(t.location || '').toLowerCase().includes(state))
    : [];
  return (nearby.length ? nearby : eligible).slice(0, MAX_TRANSPORTER_ALERTS);
}

function newJobAlert(jobId, job, recipientId) {
  const from = (job.pickup && (job.pickup.state || job.pickup.label)) || 'pickup';
  const to = (job.dropoff && (job.dropoff.state || job.dropoff.label)) || 'drop-off';
  const km = Math.round(Number(job.distanceKm) || 0);
  const pay = Number(job.offerNgn) > 0 ? ` · ${naira(job.offerNgn)}` : '';
  return {
    recipientId,
    type: 'delivery',
    route: '/jobs',
    tag: 'haulage_open',
    saveToInbox: false,
    title: `New job: ${from} → ${to}`,
    body: `${what(job)} · about ${km} km${pay}`,
  };
}

/** True when the order should now show as dispatched (collected, still "paid"). */
function shouldMarkOrderDispatched(before, after, order) {
  return Boolean(after && after.status === 'picked_up' &&
    (!before || before.status !== 'picked_up') &&
    order && order.status === 'paid');
}

module.exports = {
  jobNotifications,
  transportersToAlert,
  newJobAlert,
  shouldMarkOrderDispatched,
  MAX_TRANSPORTER_ALERTS,
};
