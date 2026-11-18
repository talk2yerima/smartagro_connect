import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/haulage_providers.dart';
import '../../core/di/payment_providers.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/utils/money_format.dart';
import '../../data/repositories/transaction_ref_queue.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/haulage_job.dart';
import '../../domain/entities/market_order.dart';
import '../../shared/widgets/empty_state.dart';
import '../delivery/delivery_widgets.dart';
import '../delivery/request_transport_screen.dart';

/// Orders, from the database (`orders/{ref}`, written by the payments
/// backend once Paystack confirms a payment).
///
/// Sellers get a "Sold" tab with what they receive and the buyer's contact
/// so they can arrange delivery. Everyone has "Bought". Payment attempts
/// that were never confirmed (kept on this phone) are listed under Bought.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(authSessionProvider.select((u) => u?.role ?? UserRole.buyer));
    final sells = role == UserRole.farmer || role == UserRole.admin;

    if (!sells) {
      return Scaffold(
        appBar: AppBar(title: const Text('My orders')),
        body: const _BoughtTab(),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Sold'), Tab(text: 'Bought')],
          ),
        ),
        body: const TabBarView(children: [_SoldTab(), _BoughtTab()]),
      ),
    );
  }
}

// ── Tabs ─────────────────────────────────────────────────────────────────────

class _SoldTab extends ConsumerWidget {
  const _SoldTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(soldOrdersProvider);
    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _LoadError(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(soldOrdersProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No sales yet',
            subtitle: 'When a buyer pays for your produce, the order appears '
                'here with their contact so you can arrange delivery.',
          );
        }
        final earned = list.fold<int>(
            0, (sum, o) => sum + (o.sellerShareKobo ?? o.amountKobo));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Summary(
              label: 'You received from ${list.length} '
                  '${list.length == 1 ? 'sale' : 'sales'}',
              amountKobo: earned,
            ),
            const SizedBox(height: 12),
            for (final o in list) ...[
              _OrderCard(order: o, asSeller: true),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _BoughtTab extends ConsumerWidget {
  const _BoughtTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(boughtOrdersProvider);
    final attempts = ref.watch(transactionHistoryProvider).valueOrNull ??
        const <TransactionRef>[];
    // Payment attempts on this phone that never became an order.
    final unconfirmed = attempts.where((a) => a.status != 'success').toList();

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _LoadError(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(boughtOrdersProvider),
      ),
      data: (list) {
        if (list.isEmpty && unconfirmed.isEmpty) {
          return const EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No orders yet',
            subtitle: 'Produce you buy will appear here, with the seller\'s '
                'contact for delivery.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(boughtOrdersProvider);
            ref.invalidate(transactionHistoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              for (final o in list) ...[
                _OrderCard(order: o, asSeller: false),
                const SizedBox(height: 10),
              ],
              if (unconfirmed.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Payments not completed',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final a in unconfirmed) ...[
                  _AttemptTile(attempt: a),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.amountKobo});

  final String label;
  final int amountKobo;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.gradientGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          Text(
            formatNgn(amountKobo / 100),
            style: TextStyle(
              color: isDark ? AppColors.softWhite : Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 2),
          Text('Paid to your bank by Paystack after each sale',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order, required this.asSeller});

  final MarketOrder order;

  /// True on the Sold tab: the other person is the buyer.
  final bool asSeller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;
    final sub = AppColors.subText(isDark);
    final otherId = asSeller ? order.buyerId : order.sellerId;
    final contact = ref.watch(orderContactProvider(otherId)).valueOrNull;
    final myId = ref.watch(authSessionProvider.select((u) => u?.id)) ?? '';

    final headline = asSeller
        ? 'You receive ${formatNgn((order.sellerShareKobo ?? order.amountKobo) / 100)}'
        : 'You paid ${formatNgn(order.amountKobo / 100)}';
    final detail = asSeller
        ? 'Buyer paid ${formatNgn(order.amountKobo / 100)}'
            '${order.platformFeeKobo != null ? ' · SmartAgro fee ${formatNgn(order.platformFeeKobo! / 100)}' : ''}'
        : null;
    final fmt = DateFormat('d MMM, h:mm a');
    final nextStep = switch ((asSeller, order.status)) {
      (true, 'paid') =>
        'Paid. Arrange delivery with the buyer or request transport.',
      (true, 'dispatched') => 'Dispatched '
          '${order.dispatchedAt == null ? '' : fmt.format(order.dispatchedAt!)}'
          '. Waiting for the buyer to confirm.',
      (true, 'received') => 'Delivered '
          '${order.receivedAt == null ? '' : fmt.format(order.receivedAt!)}.',
      (false, 'paid') =>
        'Paid. Agree delivery with the seller, or request transport.',
      (false, 'dispatched') => 'On the way since '
          '${order.dispatchedAt == null ? '' : fmt.format(order.dispatchedAt!)}'
          '. Tap "I received it" when it arrives.',
      (false, 'received') => 'You received this '
          '${order.receivedAt == null ? '' : fmt.format(order.receivedAt!)}.',
      _ => 'Paid.',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border_(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.description,
                    style: text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(DateFormat('d MMM yyyy, h:mm a').format(order.createdAt),
              style: TextStyle(fontSize: 12, color: sub)),
          const SizedBox(height: 10),
          Text(headline,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.lightGreen : AppColors.deepGreen,
              )),
          if (detail != null)
            Text(detail, style: TextStyle(fontSize: 12, color: sub)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 16, color: sub),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(nextStep,
                      style: TextStyle(fontSize: 13, color: sub))),
            ],
          ),
          _DeliveryPanel(order: order),
          if (order.shortfallKg > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                asSeller
                    ? 'Another buyer paid for the last stock first: you are '
                        '${order.shortfallKg} kg short on this order. Contact '
                        'the buyer to agree a refund or a replacement.'
                    : 'The seller ran ${order.shortfallKg} kg short (another '
                        'buyer paid first). They will contact you about a '
                        'refund or a replacement.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
          if (order.rating != null) ...[
            const SizedBox(height: 10),
            _RatingView(rating: order.rating!, review: order.review),
          ],
          _OrderActions(order: order, asSeller: asSeller),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${asSeller ? 'Buyer' : 'Seller'}: ${contact?.name ?? '…'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (contact?.phone != null)
                IconButton(
                  tooltip: 'Call ${asSeller ? 'buyer' : 'seller'}',
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () =>
                      launchUrl(Uri(scheme: 'tel', path: contact!.phone)),
                ),
              IconButton(
                tooltip: 'Message ${asSeller ? 'buyer' : 'seller'}',
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: otherId.isEmpty || myId.isEmpty
                    ? null
                    : () {
                        final ids = [myId, otherId]..sort();
                        context.push('/chat/${ids.join('_')}'
                            '?name=${Uri.encodeComponent(contact?.name ?? '')}'
                            '&peerId=$otherId');
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Transport for this order: ask for a transporter, or follow the one on
/// the way (live on a map).
class _DeliveryPanel extends ConsumerWidget {
  const _DeliveryPanel({required this.order});

  final MarketOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(haulageJobProvider(order.reference)).valueOrNull;
    final canRequest = order.isPaid || order.isDispatched;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void request([HaulageJob? previous]) => context.push('/delivery-request',
        extra: RequestTransportArgs(order: order, previous: previous));

    if (job == null || job.isCancelled) {
      if (!canRequest) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(job == null
                ? 'Request transport'
                : 'Transport cancelled · request again'),
            onPressed: () => request(job),
          ),
        ),
      );
    }

    final truck = job.driverLocation;
    final live = job.isActive &&
        truck != null &&
        DateTime.now().difference(truck.updatedAt).inMinutes < 5;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: AppColors.infoBlue.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/delivery/${job.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                    live ? Icons.sensors_rounded : Icons.local_shipping_rounded,
                    color: AppColors.infoBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.statusLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if (job.transporterName != null) job.transporterName!,
                          '${placeText(job.pickup)} → ${placeText(job.dropoff)}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(job.isActive ? 'Track' : 'View',
                    style: const TextStyle(
                        color: AppColors.infoBlue,
                        fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.infoBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'dispatched' => ('On the way', AppColors.infoBlue),
      'received' => ('Delivered', AppColors.emerald),
      _ => ('Paid', AppColors.warmOrange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// The one step this person can take next on the order, if any.
class _OrderActions extends ConsumerStatefulWidget {
  const _OrderActions({required this.order, required this.asSeller});

  final MarketOrder order;
  final bool asSeller;

  @override
  ConsumerState<_OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends ConsumerState<_OrderActions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Not yet')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final firestore = ref.read(firestoreServiceProvider);

    Widget button(String label, IconData icon, VoidCallback onTap,
            {bool outlined = false}) =>
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: outlined
                ? OutlinedButton.icon(
                    onPressed: _busy ? null : onTap,
                    icon: Icon(icon),
                    label: Text(label))
                : FilledButton.icon(
                    onPressed: _busy ? null : onTap,
                    icon: Icon(icon),
                    label: Text(_busy ? 'Saving…' : label)),
          ),
        );

    if (widget.asSeller && o.isPaid) {
      return button('Mark as dispatched', Icons.local_shipping_outlined,
          () async {
        if (!await _confirm(
            'Mark as dispatched?',
            'Only do this once the produce has left you and is on its way '
                'to the buyer. They will be told.',
            'Yes, dispatched')) {
          return;
        }
        await _run(() => firestore.markOrderDispatched(o.reference),
            'Marked as dispatched. The buyer has been told.');
      });
    }
    if (!widget.asSeller && (o.isPaid || o.isDispatched)) {
      return button('I received it', Icons.inventory_2_outlined, () async {
        if (!await _confirm(
            'Did you receive your order?',
            'Only confirm once the produce is with you and you have checked '
                'it. The seller will be told.',
            'Yes, I received it')) {
          return;
        }
        await _run(() => firestore.confirmOrderReceived(o.reference),
            'Thanks! Delivery confirmed.');
      });
    }
    if (!widget.asSeller && o.isReceived && o.rating == null) {
      return button('Rate the seller', Icons.star_outline_rounded, () async {
        final result = await showModalBottomSheet<(int, String)>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const _RateSheet(),
        );
        if (result == null) return;
        await _run(() => firestore.rateOrder(o.reference, result.$1, result.$2),
            'Thanks for rating the seller.');
      }, outlined: true);
    }
    return const SizedBox.shrink();
  }
}

class _RatingView extends StatelessWidget {
  const _RatingView({required this.rating, this.review});

  final int rating;
  final String? review;

  @override
  Widget build(BuildContext context) {
    final sub =
        AppColors.subText(Theme.of(context).brightness == Brightness.dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 18, color: AppColors.golden),
            const SizedBox(width: 6),
            Text('Buyer rating', style: TextStyle(fontSize: 12, color: sub)),
          ],
        ),
        if (review != null && review!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('"$review"',
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}

/// 1-5 stars and an optional short comment. Returns (stars, comment).
class _RateSheet extends StatefulWidget {
  const _RateSheet();

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  int _stars = 0;
  final _review = TextEditingController();

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  static const _labels = ['', 'Poor', 'Not great', 'OK', 'Good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How was this seller?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Your rating helps other buyers. You can rate once.'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.golden,
                  ),
                ),
            ],
          ),
          Center(child: Text(_labels[_stars])),
          const SizedBox(height: 12),
          TextField(
            controller: _review,
            maxLength: 500,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              hintText: 'Quality, freshness, delivery…',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _stars == 0
                ? null
                : () => Navigator.pop(context, (_stars, _review.text)),
            child: const Text('Submit rating'),
          ),
        ],
      ),
    );
  }
}

/// A payment started on this phone that never became an order.
class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.attempt});

  final TransactionRef attempt;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, color) = switch (attempt.status) {
      'failed' => ('Failed', AppColors.errorRed),
      'reversed' => ('Refunded', AppColors.errorRed),
      'amount_mismatch' => ('Under review', AppColors.warningOrange),
      'abandoned' => ('Not completed', AppColors.gray),
      _ => ('Waiting for confirmation', AppColors.warmOrange),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border_(isDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attempt.description,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${formatNgn(attempt.amountKobo / 100)} · '
                  '${DateFormat('d MMM, h:mm a').format(attempt.createdAt)}',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.subText(isDark)),
                ),
              ],
            ),
          ),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load your orders.\n$message',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
