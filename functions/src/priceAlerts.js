'use strict';

/**
 * Price alerts: a person asks to be told when a commodity's price rises
 * above, or falls below, a target. When an admin changes the price
 * (commodities/{id}), every active alert the new price crosses fires once
 * and is then switched off.
 *
 * priceAlerts/{id}: { uid, commodityId, commodityName, unit, targetNgn,
 *                     direction: 'above' | 'below', active, createdAt }
 */

/** Alerts that the move from [oldPrice] to [newPrice] crosses. */
function crossedAlerts(oldPrice, newPrice, alerts) {
  if (!Number.isFinite(oldPrice) || !Number.isFinite(newPrice) || oldPrice === newPrice) {
    return [];
  }
  return (alerts || []).filter((a) => {
    if (!a || a.active === false || !Number.isFinite(a.targetNgn)) return false;
    if (a.direction === 'above') return oldPrice < a.targetNgn && newPrice >= a.targetNgn;
    if (a.direction === 'below') return oldPrice > a.targetNgn && newPrice <= a.targetNgn;
    return false;
  });
}

function naira(n) {
  return `₦${String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}`;
}

/** The notification for one triggered alert. */
function alertNotification(alert, commodity, newPrice) {
  const name = (commodity && commodity.name) || alert.commodityName || 'A commodity';
  const unit = (commodity && commodity.unit) || alert.unit;
  const per = unit ? ` per ${unit}` : '';
  const moved = alert.direction === 'above' ? 'rose above' : 'fell below';
  return {
    recipientId: alert.uid,
    title: `${name} is now ${naira(newPrice)}${per}`,
    body: `The price ${moved} your alert of ${naira(alert.targetNgn)}.`,
    type: 'price_alert',
    route: `/main/market/commodity/${alert.commodityId}`,
    tag: `alert_${alert.id || alert.commodityId}`,
    saveToInbox: true,
  };
}

module.exports = { crossedAlerts, alertNotification };
