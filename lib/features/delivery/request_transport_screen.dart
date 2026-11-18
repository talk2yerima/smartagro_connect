import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/nigerian_states.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/haulage_providers.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/services/app_lock.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/money_format.dart';
import '../../data/services/location_service.dart';
import '../../domain/delivery_pricing.dart';
import '../../domain/entities/haulage_job.dart';
import '../../domain/entities/market_order.dart';
import 'place_picker_screen.dart';

/// What the Request transport screen needs: the paid order, and the last
/// (cancelled) request to start from, if any.
class RequestTransportArgs {
  const RequestTransportArgs({required this.order, this.previous});

  final MarketOrder order;
  final HaulageJob? previous;
}

/// Buyer or seller of a paid order asks for a transporter: pickup and
/// drop-off on the map, the load, and what they will pay.
class RequestTransportScreen extends ConsumerStatefulWidget {
  const RequestTransportScreen({super.key, required this.args});

  final RequestTransportArgs args;

  @override
  ConsumerState<RequestTransportScreen> createState() =>
      _RequestTransportScreenState();
}

class _PlaceDraft {
  _PlaceDraft([JobPlace? from])
      : point = from?.point,
        label = TextEditingController(text: from?.label ?? ''),
        state = kNigerianStates.contains(from?.state) ? from!.state : null;

  GeoPoint2? point;
  final TextEditingController label;
  String? state;

  bool get ready => point != null && label.text.trim().isNotEmpty;

  Map<String, dynamic> toMap() => JobPlace(
        label: label.text.trim(),
        state: state ?? '',
        lat: double.parse(point!.lat.toStringAsFixed(6)),
        lng: double.parse(point!.lng.toStringAsFixed(6)),
      ).toMap();
}

class _RequestTransportScreenState
    extends ConsumerState<RequestTransportScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _PlaceDraft _pickup;
  late final _PlaceDraft _dropoff;
  late final TextEditingController _weight;
  late final TextEditingController _offer;
  late final TextEditingController _notes;
  bool _offerEdited = false;
  bool _busy = false;
  String? _locating; // 'pickup' | 'dropoff' while finding the phone

  @override
  void initState() {
    super.initState();
    final prev = widget.args.previous;
    _pickup = _PlaceDraft(prev?.pickup);
    _dropoff = _PlaceDraft(prev?.dropoff);
    final kg = prev?.weightKg ?? widget.args.order.quantityKg;
    _weight = TextEditingController(text: kg == null ? '' : '$kg');
    _offer = TextEditingController(
        text: prev == null || prev.offerNgn == 0 ? '' : '${prev.offerNgn}');
    _offerEdited = prev != null;
    _notes = TextEditingController(text: prev?.notes ?? '');
    _updateSuggestion();
  }

  @override
  void dispose() {
    for (final c in [_pickup.label, _dropoff.label, _weight, _offer, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _roadKm => _pickup.point != null && _dropoff.point != null
      ? estimatedRoadKm(_pickup.point!, _dropoff.point!)
      : null;

  int get _weightKg => int.tryParse(_weight.text.trim()) ?? 0;

  /// Keeps the offer in step with distance and load until the person
  /// types their own amount.
  void _updateSuggestion() {
    final km = _roadKm;
    if (_offerEdited || km == null || _weightKg <= 0) return;
    _offer.text = '${suggestedFareNgn(km, _weightKg)}';
  }

  void _setPlace(_PlaceDraft d, GeoPoint2 point, PlaceName? name) {
    setState(() {
      d.point = point;
      if (name != null) {
        if (name.label.isNotEmpty) d.label.text = name.label;
        if (name.state.isNotEmpty) d.state = name.state;
      }
      _updateSuggestion();
    });
  }

  Future<void> _useMyLocation(_PlaceDraft d, String which) async {
    setState(() => _locating = which);
    final location = ref.read(locationServiceProvider);
    try {
      final here = await location.current(
          beforeSystemPrompt: () =>
              ref.read(appLockProvider.notifier).allowNextReturn());
      final name = await location.describe(here);
      if (mounted) _setPlace(d, here, name);
    } on LocationProblem catch (p) {
      _snack(p.message,
          action: p.openSettings
              ? SnackBarAction(
                  label: 'Settings', onPressed: location.openSettings)
              : null);
    } finally {
      if (mounted) setState(() => _locating = null);
    }
  }

  Future<void> _chooseOnMap(_PlaceDraft d, String title) async {
    final other = identical(d, _pickup) ? _dropoff : _pickup;
    final picked = await Navigator.of(context).push<PickedPlace>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            PlacePickerScreen(title: title, start: d.point ?? other.point),
      ),
    );
    if (picked != null && mounted) _setPlace(d, picked.point, picked.name);
  }

  void _snack(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_pickup.ready || !_dropoff.ready) {
      _snack('Set both the pickup and the drop-off place.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final me = ref.read(authSessionProvider);
    if (me == null) return;
    final o = widget.args.order;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await ref.read(firestoreServiceProvider).postHaulageJob(
            orderReference: o.reference,
            requesterId: me.id,
            sellerId: o.sellerId,
            buyerId: o.buyerId,
            description: o.description,
            weightKg: _weightKg,
            pickup: _pickup.toMap(),
            dropoff: _dropoff.toMap(),
            distanceKm: _roadKm!,
            offerNgn: int.tryParse(_offer.text.trim()) ?? 0,
            notes: _notes.text,
          );
      if (!mounted) return;
      _snack('Transport requested. Transporters nearby have been told.');
      context.pushReplacement('/delivery/${o.reference}');
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = AppColors.subText(isDark);
    final o = widget.args.order;
    final km = _roadKm;

    return Scaffold(
      appBar: AppBar(title: const Text('Request transport')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(o.description, style: Theme.of(context).textTheme.titleMedium),
            Text('Order ${o.reference}',
                style: TextStyle(fontSize: 12, color: sub)),
            const SizedBox(height: 16),
            _PlaceCard(
              title: 'Pickup',
              hint: "Where the produce is (the seller's farm or store)",
              icon: Icons.trip_origin_rounded,
              color: AppColors.emerald,
              draft: _pickup,
              locating: _locating == 'pickup',
              onMyLocation: () => _useMyLocation(_pickup, 'pickup'),
              onMap: () => _chooseOnMap(_pickup, 'Pickup place'),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _PlaceCard(
              title: 'Drop-off',
              hint: 'Where the buyer receives it',
              icon: Icons.place_rounded,
              color: AppColors.warmOrange,
              draft: _dropoff,
              locating: _locating == 'dropoff',
              onMyLocation: () => _useMyLocation(_dropoff, 'dropoff'),
              onMap: () => _chooseOnMap(_dropoff, 'Drop-off place'),
              onChanged: () => setState(() {}),
            ),
            if (km != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded, color: AppColors.infoBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'About ${formatDistance(km)} by road · '
                        '~${formatDuration(estimatedDriveTime(km))} driving',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _weight,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Load (kg)',
                prefixIcon: const Icon(Icons.scale_outlined),
                helperText: _weightKg > 0 ? vehicleFor(_weightKg) : null,
              ),
              onChanged: (_) => setState(_updateSuggestion),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim()) ?? 0;
                if (n <= 0) return 'Enter the weight in kg';
                if (n > 100000) return 'That is more than one trip can carry';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _offer,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'You will pay the transporter (₦)',
                prefixIcon: const Icon(Icons.payments_outlined),
                helperText: km != null && _weightKg > 0
                    ? 'Suggested ${formatNgn(suggestedFareNgn(km, _weightKg))} '
                        'for this distance and load'
                    : 'Set the places and load to see a suggestion',
              ),
              onChanged: (_) => _offerEdited = true,
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Enter what you will pay';
                if (n > 100000000) return 'That amount is too large';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Notes for the driver (optional)',
                hintText: 'e.g. Call when you reach the junction',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You pay the transporter directly when they deliver. Only you, '
              'the other party on this order and the transporter who accepts '
              'can follow the delivery on the map.',
              style: TextStyle(fontSize: 12, color: sub),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.local_shipping_rounded),
                label: Text(_busy ? 'Posting…' : 'Find a transporter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.title,
    required this.hint,
    required this.icon,
    required this.color,
    required this.draft,
    required this.locating,
    required this.onMyLocation,
    required this.onMap,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final IconData icon;
  final Color color;
  final _PlaceDraft draft;
  final bool locating;
  final VoidCallback onMyLocation;
  final VoidCallback onMap;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = AppColors.subText(isDark);
    final set = draft.point != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color:
                set ? color.withValues(alpha: 0.5) : AppColors.border_(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              if (set)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.emerald, size: 18),
            ],
          ),
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(fontSize: 12, color: sub)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: locating ? null : onMyLocation,
                  icon: locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('I am here'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(set ? 'Move pin' : 'Pick on map'),
                ),
              ),
            ],
          ),
          if (set) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.label,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Place name or landmark',
                hintText: 'e.g. Gashua grain market, gate 2',
                isDense: true,
                counterText: '',
              ),
              onChanged: (_) => onChanged(),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Describe the place' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              // Re-created when a map pick fills in the state.
              key: ValueKey(draft.state),
              initialValue: draft.state,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'State', isDense: true),
              items: [
                for (final s in kNigerianStates)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) {
                draft.state = v;
                onChanged();
              },
              validator: (v) => v == null ? 'Choose the state' : null,
            ),
          ],
        ],
      ),
    );
  }
}
