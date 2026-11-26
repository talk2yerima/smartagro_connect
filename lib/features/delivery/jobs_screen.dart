import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/haulage_providers.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/i18n/i18n.dart';
import '../../core/services/app_lock.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/money_format.dart';
import '../../data/services/location_service.dart';
import '../../domain/delivery_pricing.dart';
import '../../domain/entities/haulage_job.dart';
import '../../shared/widgets/empty_state.dart';
import 'delivery_widgets.dart';
import 'driver_tracker.dart';

/// The transporter's job board: open deliveries nearest first, and the
/// jobs they took.
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  GeoPoint2? _me;
  bool _locating = false;
  String? _state; // pickup-state filter, null = all

  @override
  void initState() {
    super.initState();
    // Sort by distance straight away if location is already allowed.
    ref.read(locationServiceProvider).currentIfAllowed().then((p) {
      if (mounted && p != null) setState(() => _me = p);
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final location = ref.read(locationServiceProvider);
    try {
      final p = await location.current(
          beforeSystemPrompt: () =>
              ref.read(appLockProvider.notifier).allowNextReturn());
      if (mounted) setState(() => _me = p);
    } on LocationProblem catch (p) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(p.message),
          action: p.openSettings
              ? SnackBarAction(
                  label: tr('Settings'), onPressed: location.openSettings)
              : null,
        ));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg(isDark),
        appBar: AppBar(
          title: const T('Jobs'),
          actions: [
            IconButton(
              tooltip: tr('Sort by distance from me'),
              onPressed: _locating ? null : _locate,
              icon: _locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_me == null
                      ? Icons.location_searching_rounded
                      : Icons.my_location_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Open jobs'), Tab(text: 'My jobs')],
          ),
        ),
        body: Column(
          children: [
            const _LiveBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  _OpenJobs(
                    me: _me,
                    state: _state,
                    onState: (s) => setState(() => _state = s),
                    onLocate: _locate,
                  ),
                  _MyJobs(me: _me),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "You are sharing your location" while a delivery is under way.
class _LiveBanner extends ConsumerWidget {
  const _LiveBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(driverTrackerProvider);
    if (!tracker.sharing) return const SizedBox.shrink();
    return Material(
      color: AppColors.infoBlue,
      child: InkWell(
        onTap: () => context.push('/delivery/${tracker.jobId}'),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.sensors_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: T('Delivery under way · sharing your location',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenJobs extends ConsumerWidget {
  const _OpenJobs({
    required this.me,
    required this.state,
    required this.onState,
    required this.onLocate,
  });

  final GeoPoint2? me;
  final String? state;
  final ValueChanged<String?> onState;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authSessionProvider.select((u) => u?.id));
    final jobsAsync = ref.watch(openHaulageJobsProvider);
    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Error(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(openHaulageJobsProvider)),
      data: (all) {
        // A transporter can't carry their own order.
        final jobs =
            all.where((j) => j.buyerId != myId && j.sellerId != myId).toList();
        final states = {
          for (final j in jobs)
            if (j.pickup.state.isNotEmpty) j.pickup.state
        }.toList()
          ..sort();
        final shown = jobs
            .where((j) => state == null || j.pickup.state == state)
            .toList();
        if (me != null) {
          shown.sort((a, b) => straightLineKm(me!, a.pickup.point)
              .compareTo(straightLineKm(me!, b.pickup.point)));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(openHaulageJobsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All (${jobs.length})'),
                      selected: state == null,
                      onSelected: (_) => onState(null),
                    ),
                    for (final s in states) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(s),
                        selected: state == s,
                        onSelected: (_) => onState(s),
                      ),
                    ],
                  ],
                ),
              ),
              if (me == null) ...[
                const SizedBox(height: 10),
                _Hint(
                  icon: Icons.near_me_outlined,
                  text: 'Show the nearest jobs first and how far each '
                      'pickup is from you.',
                  action: 'Use my location',
                  onAction: onLocate,
                ),
              ],
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: tr('No open jobs right now'),
                    subtitle: tr('When a buyer or seller asks for transport, '
                        'the job appears here and you get a notification.'),
                  ),
                )
              else
                for (final j in shown) ...[
                  JobCard(job: j, me: me),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _MyJobs extends ConsumerWidget {
  const _MyJobs({required this.me});

  final GeoPoint2? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(myHaulageJobsProvider);
    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Error(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(myHaulageJobsProvider)),
      data: (jobs) {
        if (jobs.isEmpty) {
          return EmptyState(
            icon: Icons.assignment_outlined,
            title: tr('No jobs yet'),
            subtitle: tr('Jobs you accept show here, with the route, contacts '
                'and live tracking.'),
          );
        }
        final active = jobs.where((j) => j.isActive).toList();
        final past = jobs.where((j) => !j.isActive).toList();
        final delivered = past.where((j) => j.isDelivered).toList();
        final earned = delivered.fold<int>(0, (s, j) => s + j.offerNgn);
        final km = delivered.fold<double>(0, (s, j) => s + j.distanceKm);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            if (delivered.isNotEmpty)
              _Hint(
                icon: Icons.insights_rounded,
                text: '${delivered.length} delivered · about '
                    '${formatDistance(km)} driven · ${formatNgn(earned)} agreed',
              ),
            if (active.isNotEmpty) ...[
              const _SectionTitle('Under way'),
              for (final j in active) ...[
                JobCard(job: j, me: me, mine: true),
                const SizedBox(height: 12),
              ],
            ],
            if (past.isNotEmpty) ...[
              const _SectionTitle('Earlier'),
              for (final j in past) ...[
                JobCard(job: j, me: me, mine: true),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// One delivery on the board: route, distance, time, load and pay.
class JobCard extends ConsumerStatefulWidget {
  const JobCard({super.key, required this.job, this.me, this.mine = false});

  final HaulageJob job;
  final GeoPoint2? me;

  /// On "My jobs": no Accept button, show the status instead.
  final bool mine;

  @override
  ConsumerState<JobCard> createState() => _JobCardState();
}

class _JobCardState extends ConsumerState<JobCard> {
  bool _busy = false;

  Future<void> _accept() async {
    final j = widget.job;
    final me = ref.read(authSessionProvider);
    if (me == null) return;
    final toPickup =
        widget.me == null ? null : estimatedRoadKm(widget.me!, j.pickup.point);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const T('Accept this job?'),
        content: Text(
          '${j.description}\n'
          '${placeText(j.pickup)} → ${placeText(j.dropoff)}\n\n'
          '${toPickup == null ? '' : 'About ${formatDistance(toPickup)} to the pickup, then '}'
          'about ${formatDistance(j.distanceKm)} to the drop-off.\n'
          'Pay: ${formatNgn(j.offerNgn)}, paid to you directly.\n\n'
          'Your location will be shared with the buyer and seller until you '
          'deliver.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const T('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const T('Accept')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(firestoreServiceProvider)
          .acceptHaulageJob(j.id, me.id, me.name);
      await ref.read(driverTrackerProvider.notifier).start(j.id);
      if (mounted) context.push('/delivery/${j.id}');
    } on TimeoutException {
      // Firestore keeps the write and sends it when the network is back.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: T('Weak network: your acceptance will be sent when '
              'you are back online. Check My jobs.')));
    } catch (e) {
      if (!mounted) return;
      final taken = e.toString().contains('permission-denied');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(taken
              ? 'Another transporter took this job first.'
              : friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = AppColors.subText(isDark);
    final toPickup =
        widget.me == null ? null : estimatedRoadKm(widget.me!, j.pickup.point);
    return Material(
      color: AppColors.card(isDark),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/delivery/${j.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border_(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(j.description,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (widget.mine)
                    JobStatusChip(status: j.status)
                  else
                    Text(formatNgn(j.offerNgn),
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.lightGreen
                                : AppColors.deepGreen)),
                ],
              ),
              const SizedBox(height: 10),
              RouteSummary(job: j, dense: true),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FactChip(Icons.route_rounded,
                      'Trip ${formatDistance(j.distanceKm)}'),
                  FactChip(Icons.schedule_rounded,
                      '~${formatDuration(estimatedDriveTime(j.distanceKm))}'),
                  FactChip(Icons.scale_outlined,
                      '${NumberFormat.decimalPattern().format(j.weightKg)} kg'),
                  FactChip(
                      Icons.local_shipping_outlined, vehicleFor(j.weightKg)),
                  if (toPickup != null && j.isOpen)
                    FactChip(Icons.near_me_rounded,
                        '${formatDistance(toPickup)} to pickup',
                        color: AppColors.infoBlue),
                  if (widget.mine)
                    FactChip(Icons.payments_outlined, formatNgn(j.offerNgn)),
                ],
              ),
              if (j.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('“${j.notes}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: sub, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(_ago(j), style: TextStyle(fontSize: 12, color: sub)),
                  const Spacer(),
                  if (!widget.mine && j.isOpen)
                    FilledButton(
                      onPressed: _busy ? null : _accept,
                      child: Text(_busy ? 'Accepting…' : 'Accept'),
                    )
                  else
                    TextButton(
                      onPressed: () => context.push('/delivery/${j.id}'),
                      child: Text(j.isActive ? 'Open' : 'Details'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ago(HaulageJob j) {
    if (j.deliveredAt != null) {
      return 'Delivered ${DateFormat('d MMM, h:mm a').format(j.deliveredAt!)}';
    }
    final d = DateTime.now().difference(j.createdAt);
    if (d.inMinutes < 1) return 'Posted just now';
    if (d.inHours < 1) return 'Posted ${d.inMinutes} min ago';
    if (d.inDays < 1) return 'Posted ${d.inHours} h ago';
    return 'Posted ${DateFormat('d MMM').format(j.createdAt)}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(
      {required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.infoBlue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const T('Retry')),
            ],
          ),
        ),
      );
}
