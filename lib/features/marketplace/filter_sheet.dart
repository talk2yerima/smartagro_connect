import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/haulage_providers.dart';
import '../../core/i18n/i18n.dart';
import '../../core/services/app_lock.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/money_format.dart';
import '../../data/services/location_service.dart';
import '../../domain/listing_filter.dart';

/// What the filter sheet hands back.
typedef FilterResult = ({ListingFilter filter, int sortIndex, GeoPoint2? me});

/// Steps for the distance slider, in km.
const distanceSteps = [10.0, 25.0, 50.0, 100.0, 200.0, 300.0, 500.0];

/// Sort, price range, distance, state, verified farmers, ready now /
/// pre-order, sold out — with a live count of matching listings.
Future<FilterResult?> showListingFilterSheet(
  BuildContext context, {
  required ListingFilter current,
  required int sortIndex,
  required List<String> sortLabels,
  required int minPrice,
  required int maxPrice,
  required List<String> states,
  required GeoPoint2? me,
  required int Function(ListingFilter filter, GeoPoint2? me) countFor,
}) {
  return showModalBottomSheet<FilterResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(
      current: current,
      sortIndex: sortIndex,
      sortLabels: sortLabels,
      minPrice: minPrice,
      maxPrice: math.max(maxPrice, minPrice + 1),
      states: states,
      me: me,
      countFor: countFor,
    ),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({
    required this.current,
    required this.sortIndex,
    required this.sortLabels,
    required this.minPrice,
    required this.maxPrice,
    required this.states,
    required this.me,
    required this.countFor,
  });

  final ListingFilter current;
  final int sortIndex;
  final List<String> sortLabels;
  final int minPrice;
  final int maxPrice;
  final List<String> states;
  final GeoPoint2? me;
  final int Function(ListingFilter, GeoPoint2?) countFor;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late ListingFilter _f = widget.current;
  late int _sort = widget.sortIndex;
  late GeoPoint2? _me = widget.me;
  bool _locating = false;

  Future<void> _locate() async {
    setState(() => _locating = true);
    final location = ref.read(locationServiceProvider);
    try {
      final here = await location.current(
          beforeSystemPrompt: () =>
              ref.read(appLockProvider.notifier).allowNextReturn());
      if (!mounted) return;
      setState(() {
        _me = here;
        _f = _f.copyWith(maxDistanceKm: () => _f.maxDistanceKm ?? 100);
      });
    } on LocationProblem catch (p) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(p.message)));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = AppColors.subText(isDark);
    final title = Theme.of(context)
        .textTheme
        .titleSmall!
        .copyWith(fontWeight: FontWeight.w700);
    final lo = (_f.minPrice ?? widget.minPrice)
        .clamp(widget.minPrice, widget.maxPrice)
        .toDouble();
    final hi = (_f.maxPrice ?? widget.maxPrice)
        .clamp(widget.minPrice, widget.maxPrice)
        .toDouble();
    final count = widget.countFor(_f, _me);
    final stepIndex = _f.maxDistanceKm == null
        ? distanceSteps.length - 1
        : distanceSteps
            .indexWhere((d) => d >= _f.maxDistanceKm!)
            .clamp(0, distanceSteps.length - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
          child: Row(
            children: [
              T('Filters', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _f = ListingFilter.none;
                  _sort = 0;
                }),
                child: const T('Reset'),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              T('Sort by', style: title),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < widget.sortLabels.length; i++)
                    ChoiceChip(
                      label: Text(widget.sortLabels[i]),
                      selected: _sort == i,
                      onSelected: (_) => setState(() => _sort = i),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  T('Price per kg', style: title),
                  const Spacer(),
                  Text('${formatNgn(lo.round())} – ${formatNgn(hi.round())}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              RangeSlider(
                min: widget.minPrice.toDouble(),
                max: widget.maxPrice.toDouble(),
                values: RangeValues(lo, hi),
                labels:
                    RangeLabels(formatNgn(lo.round()), formatNgn(hi.round())),
                onChanged: (v) => setState(() {
                  final start = v.start.round();
                  final end = v.end.round();
                  _f = _f.copyWith(
                    minPrice: () => start <= widget.minPrice ? null : start,
                    maxPrice: () => end >= widget.maxPrice ? null : end,
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  T('Distance from you', style: title),
                  const Spacer(),
                  if (_me != null)
                    Text(
                        _f.maxDistanceKm == null
                            ? 'Any distance'
                            : 'Within ${formatDistance(_f.maxDistanceKm!)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              if (_me == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _locate,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: const T('Use my location'),
                  ),
                )
              else
                Slider(
                  min: 0,
                  max: (distanceSteps.length - 1).toDouble(),
                  divisions: distanceSteps.length - 1,
                  value: stepIndex.toDouble(),
                  label: stepIndex == distanceSteps.length - 1
                      ? 'Any'
                      : formatDistance(distanceSteps[stepIndex]),
                  onChanged: (v) => setState(() {
                    final i = v.round();
                    _f = _f.copyWith(
                        maxDistanceKm: () => i == distanceSteps.length - 1
                            ? null
                            : distanceSteps[i]);
                  }),
                ),
              T(
                'By road, about. Listings without a town use their state '
                'capital.',
                style: TextStyle(fontSize: 11, color: sub),
              ),
              const SizedBox(height: 20),
              T('Availability', style: title),
              const SizedBox(height: 8),
              SegmentedButton<ReadyFilter>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ReadyFilter.any, label: T('Any')),
                  ButtonSegment(
                      value: ReadyFilter.readyNow, label: T('Ready now')),
                  ButtonSegment(
                      value: ReadyFilter.preOrder, label: T('Pre-order')),
                ],
                selected: {_f.ready},
                onSelectionChanged: (s) =>
                    setState(() => _f = _f.copyWith(ready: s.first)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                key: ValueKey(_f.state),
                initialValue: _f.state,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('State'),
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: T('All states')),
                  for (final s in widget.states)
                    DropdownMenuItem<String?>(value: s, child: Text(s)),
                ],
                onChanged: (v) =>
                    setState(() => _f = _f.copyWith(state: () => v)),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const T('Verified farmers only'),
                secondary: const Icon(Icons.verified_rounded,
                    color: AppColors.infoBlue),
                value: _f.verifiedOnly,
                onChanged: (v) =>
                    setState(() => _f = _f.copyWith(verifiedOnly: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const T('Hide sold out'),
                secondary: const Icon(Icons.remove_shopping_cart_outlined),
                value: _f.hideSoldOut,
                onChanged: (v) =>
                    setState(() => _f = _f.copyWith(hideSoldOut: v)),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop<FilterResult>(
                    context, (filter: _f, sortIndex: _sort, me: _me)),
                child: Text(count == 0
                    ? 'No listings match'
                    : 'Show $count listing${count == 1 ? '' : 's'}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
