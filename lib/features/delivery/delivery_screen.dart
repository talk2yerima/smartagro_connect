import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/haulage_providers.dart';
import '../../core/di/payment_providers.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/i18n/i18n.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/money_format.dart';
import '../../domain/delivery_pricing.dart';
import '../../domain/entities/haulage_job.dart';
import 'delivery_widgets.dart';
import 'driver_tracker.dart';
import 'jobs_screen.dart' show JobCard;

/// Road distance still to cover and when the truck should arrive, from its
/// last position: to the pickup and then the whole trip before collection,
/// straight to the drop-off after.
({double km, Duration time})? remainingTrip(HaulageJob job, GeoPoint2? truck) {
  if (truck == null || !truck.isSet || !job.isActive) return null;
  final km = job.isPickedUp
      ? estimatedRoadKm(truck, job.dropoff.point)
      : estimatedRoadKm(truck, job.pickup.point) + job.distanceKm;
  return (km: km, time: estimatedDriveTime(km));
}

/// One delivery, live: the map with pickup, drop-off and the truck, and
/// what this person can do next.
///
/// Buyer and seller follow the truck in real time; the transporter gets
/// distances, navigation, contacts and the pickup / delivered steps.
class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  GoogleMapController? _map;
  bool _fitted = false;
  bool _follow = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keeps "updated 20 s ago" and the arrival estimate fresh.
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _map?.dispose();
    super.dispose();
  }

  void _fit(HaulageJob job, GeoPoint2? truck) {
    _map?.animateCamera(fitPoints([
      job.pickup.point,
      job.dropoff.point,
      if (truck != null) truck,
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(haulageJobProvider(widget.jobId));
    final myId = ref.watch(authSessionProvider.select((u) => u?.id)) ?? '';
    final tracker = ref.watch(driverTrackerProvider);

    return jobAsync.when(
      loading: () => Scaffold(
          appBar: AppBar(title: const T('Delivery')),
          body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: AppBar(title: const T('Delivery')),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(friendlyError(e), textAlign: TextAlign.center)))),
      data: (job) {
        if (job == null) {
          return Scaffold(
            appBar: AppBar(title: const T('Delivery')),
            body: const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: T(
                  'No transport was booked through SmartAgro for this order.',
                  textAlign: TextAlign.center),
            )),
          );
        }
        final isDriver = job.transporterId == myId && myId.isNotEmpty;
        // The driver's own phone knows best where it is; everyone else sees
        // the last position it shared.
        final truck = isDriver && tracker.jobId == job.id
            ? (tracker.position ?? job.driverLocation?.point)
            : job.driverLocation?.point;

        if (_follow && truck != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) =>
              _map?.animateCamera(CameraUpdate.newLatLng(latLng(truck))));
        }
        final height = MediaQuery.of(context).size.height;

        return Scaffold(
          appBar: AppBar(
            title: const T('Delivery'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(child: JobStatusChip(status: job.status)),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: mapsSupported
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(
                            target: latLng(job.pickup.point), zoom: 8),
                        padding: EdgeInsets.only(bottom: height * 0.36),
                        markers: jobMarkers(job, truck: truck),
                        polylines: jobLines(job, truck: truck),
                        myLocationEnabled: isDriver,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        onMapCreated: (c) {
                          _map = c;
                          if (!_fitted) {
                            _fitted = true;
                            Future.delayed(const Duration(milliseconds: 300),
                                () => _fit(job, truck));
                          }
                        },
                      )
                    : const MapPlaceholder(),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'fit',
                      tooltip: tr('Show the whole route'),
                      onPressed: () {
                        setState(() => _follow = false);
                        _fit(job, truck);
                      },
                      child: const Icon(Icons.zoom_out_map_rounded),
                    ),
                    if (truck != null && job.isActive) ...[
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'follow',
                        tooltip: tr('Follow the truck'),
                        backgroundColor: _follow ? AppColors.infoBlue : null,
                        foregroundColor: _follow ? Colors.white : null,
                        onPressed: () {
                          setState(() => _follow = !_follow);
                          if (_follow) {
                            _map?.animateCamera(
                                CameraUpdate.newLatLngZoom(latLng(truck), 14));
                          }
                        },
                        child: const Icon(Icons.local_shipping_rounded),
                      ),
                    ],
                  ],
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.42,
                minChildSize: 0.2,
                maxChildSize: 0.9,
                builder: (context, scroll) => _Panel(
                  scroll: scroll,
                  job: job,
                  myId: myId,
                  isDriver: isDriver,
                  truck: truck,
                  tracker: tracker,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({
    required this.scroll,
    required this.job,
    required this.myId,
    required this.isDriver,
    required this.truck,
    required this.tracker,
  });

  final ScrollController scroll;
  final HaulageJob job;
  final String myId;
  final bool isDriver;
  final GeoPoint2? truck;
  final TrackerState tracker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isParty = myId == job.buyerId || myId == job.sellerId;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16)
        ],
      ),
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.silver,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (job.isActive) ...[
            _LiveStatus(job: job, truck: truck, isDriver: isDriver),
            const SizedBox(height: 14),
          ],
          Text(job.description, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          RouteSummary(job: job),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FactChip(Icons.route_rounded,
                  'Trip ${formatDistance(job.distanceKm)}'),
              FactChip(Icons.schedule_rounded,
                  '~${formatDuration(estimatedDriveTime(job.distanceKm))}'),
              FactChip(Icons.scale_outlined, '${job.weightKg} kg'),
              FactChip(Icons.local_shipping_outlined, vehicleFor(job.weightKg)),
              FactChip(Icons.payments_outlined, formatNgn(job.offerNgn)),
            ],
          ),
          if (job.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Notes: ${job.notes}', style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 16),
          if (isDriver)
            _DriverActions(job: job, truck: truck, tracker: tracker)
          else if (isParty)
            _PartyActions(job: job, myId: myId)
          else if (job.isOpen)
            JobCard(job: job),
          const SizedBox(height: 16),
          _Timeline(job: job),
        ],
      ),
    );
  }
}

/// Distance left, arrival time and how fresh the truck's position is.
class _LiveStatus extends StatelessWidget {
  const _LiveStatus(
      {required this.job, required this.truck, required this.isDriver});

  final HaulageJob job;
  final GeoPoint2? truck;
  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    final left = remainingTrip(job, truck);
    final updated = job.driverLocation?.updatedAt;
    final age = updated == null ? null : DateTime.now().difference(updated);
    final stale = age != null && age > const Duration(minutes: 5);
    final speed = job.driverLocation?.speedKmh;
    final next = job.isPickedUp ? 'drop-off' : 'pickup';
    final legKm = truck == null || !truck!.isSet
        ? null
        : estimatedRoadKm(truck!, job.nextStop.point);

    String freshness() {
      if (isDriver) return 'Your location is shared live';
      if (age == null) return 'Waiting for the driver\'s location';
      if (age.inSeconds < 60) return 'Live · updated just now';
      if (!stale) return 'Live · updated ${age.inMinutes} min ago';
      return 'Last seen ${age.inMinutes < 120 ? '${age.inMinutes} min' : '${age.inHours} h'} ago · '
          'the driver may be out of network';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (stale ? AppColors.warningOrange : AppColors.infoBlue)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.statusLabel,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          if (left != null)
            Row(
              children: [
                _Big(formatDistance(left.km), 'left in total'),
                _Big(DateFormat('h:mm a').format(DateTime.now().add(left.time)),
                    'arrival (about)'),
                if (legKm != null) _Big(formatDistance(legKm), 'to $next'),
              ],
            )
          else
            const T('Distance and arrival show once the driver shares '
                'their location.'),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                  stale ? Icons.signal_wifi_off_rounded : Icons.sensors_rounded,
                  size: 16,
                  color: stale ? AppColors.warningOrange : AppColors.infoBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${freshness()}'
                  '${speed != null && speed >= 3 && !stale ? ' · ${speed.round()} km/h' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.subText(
                        Theme.of(context).brightness == Brightness.dark))),
          ],
        ),
      );
}

/// A person on the delivery, with call and message buttons.
class _ContactRow extends ConsumerWidget {
  const _ContactRow({required this.role, required this.uid});

  final String role;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(orderContactProvider(uid)).valueOrNull;
    final myId = ref.watch(authSessionProvider.select((u) => u?.id)) ?? '';
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
          child: Text(
            (contact?.name.isNotEmpty ?? false)
                ? contact!.name[0].toUpperCase()
                : '?',
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.emerald),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.subText(
                          Theme.of(context).brightness == Brightness.dark))),
              Text(contact?.name ?? '…',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (contact?.phone != null)
          IconButton.filledTonal(
            tooltip: tr('Call'),
            icon: const Icon(Icons.call_rounded),
            onPressed: () => callPhone(ref, contact!.phone!),
          ),
        IconButton(
          tooltip: tr('Message'),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          onPressed: myId.isEmpty
              ? null
              : () {
                  final ids = [myId, uid]..sort();
                  context.push('/chat/${ids.join('_')}'
                      '?name=${Uri.encodeComponent(contact?.name ?? '')}'
                      '&peerId=$uid');
                },
        ),
      ],
    );
  }
}

mixin _Runs<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  bool busy = false;

  Future<void> run(Future<void> Function() action, String done) async {
    setState(() => busy = true);
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
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const T('Not yet')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _DriverActions extends ConsumerStatefulWidget {
  const _DriverActions(
      {required this.job, required this.truck, required this.tracker});

  final HaulageJob job;
  final GeoPoint2? truck;
  final TrackerState tracker;

  @override
  ConsumerState<_DriverActions> createState() => _DriverActionsState();
}

class _DriverActionsState extends ConsumerState<_DriverActions>
    with _Runs<_DriverActions> {
  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final db = ref.read(firestoreServiceProvider);
    final tracker = widget.tracker;
    final t = widget.truck;
    final children = <Widget>[];

    if (j.isActive) {
      final sharingThis = tracker.jobId == j.id;
      if (!sharingThis) {
        children.add(Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warningOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_off_rounded,
                  color: AppColors.warningOrange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tracker.problem?.message ??
                    'Your location is not being shared. The buyer cannot see '
                        'where the delivery is.'),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(driverTrackerProvider.notifier).start(j.id),
                child: const T('Share'),
              ),
            ],
          ),
        ));
      }
      final stop = j.nextStop;
      children.addAll([
        _ContactRow(
            role: j.isPickedUp ? 'Buyer (drop-off)' : 'Seller (pickup)',
            uid: j.isPickedUp ? j.buyerId : j.sellerId),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.navigation_rounded),
            label: Text('Navigate to ${j.isPickedUp ? 'drop-off' : 'pickup'}'
                '${t == null ? '' : ' · ${formatDistance(estimatedRoadKm(t, stop.point))}'}'),
            onPressed: () => openNavigation(ref, stop.point),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            icon: Icon(j.isPickedUp
                ? Icons.task_alt_rounded
                : Icons.inventory_2_outlined),
            label: Text(busy
                ? 'Saving…'
                : j.isPickedUp
                    ? 'Delivered to the buyer'
                    : 'I have picked up the produce'),
            onPressed: busy
                ? null
                : () async {
                    if (j.isPickedUp) {
                      if (!await confirm(
                          'Delivered?',
                          'Only confirm once the buyer has the produce. '
                              'Sharing your location stops.',
                          'Yes, delivered')) {
                        return;
                      }
                      await run(
                          () => db.markJobDelivered(j.id,
                              lat: t?.lat, lng: t?.lng),
                          'Delivered. Well done!');
                      ref.read(driverTrackerProvider.notifier).stop();
                    } else {
                      if (!await confirm(
                          'Picked up?',
                          'Confirm you have loaded the produce. The buyer '
                              'and seller will be told it is on the way.',
                          'Yes, picked up')) {
                        return;
                      }
                      await run(
                          () => db.markJobPickedUp(j.id,
                              lat: t?.lat, lng: t?.lng),
                          'On the way. The buyer can follow you live.');
                    }
                  },
          ),
        ),
        if (j.isAccepted) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await confirm(
                        'Give the job back?',
                        'It goes back on the board for another transporter. '
                            'The buyer and seller will be told.',
                        'Give it back')) {
                      return;
                    }
                    await run(
                        () => db.handBackHaulageJob(j.id), 'Job handed back.');
                    ref.read(driverTrackerProvider.notifier).stop();
                    if (context.mounted) context.pop();
                  },
            child: const T("I can't do this job"),
          ),
        ],
        const SizedBox(height: 12),
        _ContactRow(
            role: j.isPickedUp ? 'Seller (pickup)' : 'Buyer (drop-off)',
            uid: j.isPickedUp ? j.sellerId : j.buyerId),
      ]);
    } else if (j.isDelivered) {
      children.add(Text(
        'Delivered${j.deliveredAt == null ? '' : ' ${DateFormat('d MMM, h:mm a').format(j.deliveredAt!)}'}. '
        'Collect ${formatNgn(j.offerNgn)} from the person who booked you.',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ));
    } else if (j.isCancelled) {
      children.add(const T('This delivery was cancelled.'));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _PartyActions extends ConsumerStatefulWidget {
  const _PartyActions({required this.job, required this.myId});

  final HaulageJob job;
  final String myId;

  @override
  ConsumerState<_PartyActions> createState() => _PartyActionsState();
}

class _PartyActionsState extends ConsumerState<_PartyActions>
    with _Runs<_PartyActions> {
  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final isBuyer = widget.myId == j.buyerId;
    final db = ref.read(firestoreServiceProvider);
    final children = <Widget>[];

    if (j.transporterId != null && (j.isActive || j.isDelivered)) {
      children.addAll([
        _ContactRow(role: 'Transporter', uid: j.transporterId!),
        const SizedBox(height: 12),
      ]);
    }
    if (j.isOpen) {
      children.add(T(
        'Transporters are being told about this job. You will get a '
        'notification when one accepts.',
        style: TextStyle(
            fontSize: 13,
            color: AppColors.subText(
                Theme.of(context).brightness == Brightness.dark)),
      ));
    }
    if (j.isDelivered && isBuyer) {
      children.add(SizedBox(
        height: 48,
        child: FilledButton.icon(
          icon: const Icon(Icons.inventory_2_outlined),
          label: const T('Confirm on your order'),
          onPressed: () => context.go('/main/orders'),
        ),
      ));
    }
    if (j.isOpen || j.isAccepted) {
      children.add(TextButton(
        onPressed: busy
            ? null
            : () async {
                if (!await confirm(
                    'Cancel this transport request?',
                    j.isAccepted
                        ? 'The transporter has accepted and will be told. '
                            'You can request transport again later.'
                        : 'You can request transport again later.',
                    'Cancel request')) {
                  return;
                }
                await run(
                    () => db.cancelHaulageJob(j.id), 'Request cancelled.');
              },
        child: const T('Cancel request',
            style: TextStyle(color: AppColors.errorRed)),
      ));
    }
    if (j.isCancelled) {
      children.add(const T(
          'Cancelled. You can request transport again from the order.'));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.job});

  final HaulageJob job;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, h:mm a');
    final steps = [
      ('Requested', job.createdAt as DateTime?),
      (
        job.transporterName == null
            ? 'Transporter accepted'
            : '${job.transporterName} accepted',
        job.acceptedAt
      ),
      ('Picked up', job.pickedUpAt),
      ('Delivered', job.deliveredAt),
    ];
    final sub =
        AppColors.subText(Theme.of(context).brightness == Brightness.dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        T('Progress', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    steps[i].$2 != null
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: steps[i].$2 != null
                        ? AppColors.emerald
                        : AppColors.silver,
                  ),
                  if (i < steps.length - 1)
                    Container(width: 2, height: 18, color: AppColors.silver),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: steps[i].$1,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (steps[i].$2 != null)
                      TextSpan(
                          text: '  ${fmt.format(steps[i].$2!)}',
                          style: TextStyle(fontSize: 12, color: sub)),
                  ])),
                ),
              ),
            ],
          ),
        if (job.isCancelled)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: T('Cancelled',
                style: TextStyle(
                    color: AppColors.errorRed, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
