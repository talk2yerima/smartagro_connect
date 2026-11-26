import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/haulage_providers.dart';
import '../../core/i18n/i18n.dart';
import '../../core/services/app_lock.dart';
import '../../core/utils/geo.dart';
import '../../data/services/location_service.dart';
import 'delivery_widgets.dart';

/// The place chosen on the map, with the name the phone found for it.
typedef PickedPlace = ({GeoPoint2 point, PlaceName? name});

/// Full-screen map: move the map under the pin, then "Use this place".
class PlacePickerScreen extends ConsumerStatefulWidget {
  const PlacePickerScreen({super.key, required this.title, this.start});

  final String title;
  final GeoPoint2? start;

  @override
  ConsumerState<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends ConsumerState<PlacePickerScreen> {
  GoogleMapController? _map;
  late GeoPoint2 _centre;
  PlaceName? _name;
  bool _looking = false;
  Timer? _debounce;
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    final s = widget.start;
    _centre = s != null && s.isSet
        ? s
        : GeoPoint2(nigeriaCentre.latitude, nigeriaCentre.longitude);
    if (s != null && s.isSet) _describe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _describe() async {
    final id = ++_lookup;
    setState(() => _looking = true);
    final name = await ref.read(locationServiceProvider).describe(_centre);
    if (!mounted || id != _lookup) return;
    setState(() {
      _name = name;
      _looking = false;
    });
  }

  Future<void> _goToMe() async {
    try {
      final here = await ref.read(locationServiceProvider).current(
          beforeSystemPrompt: () =>
              ref.read(appLockProvider.notifier).allowNextReturn());
      _centre = here;
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(latLng(here), 16));
      unawaited(_describe());
    } on LocationProblem catch (p) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(p.message),
        action: p.openSettings
            ? SnackBarAction(
                label: tr('Settings'),
                onPressed: () =>
                    ref.read(locationServiceProvider).openSettings())
            : null,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startSet = widget.start != null && widget.start!.isSet;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          if (mapsSupported)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: latLng(_centre), zoom: startSet ? 15 : 5.5),
              onMapCreated: (c) => _map = c,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onCameraMove: (p) {
                _centre = GeoPoint2(p.target.latitude, p.target.longitude);
                _debounce?.cancel();
              },
              onCameraIdle: () {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _describe);
              },
            )
          else
            const MapPlaceholder(),
          // The pin sits at the centre; its tip marks the place.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on_rounded,
                    size: 48, color: AppColors.errorRed),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 170,
            child: FloatingActionButton.small(
              heroTag: 'me',
              tooltip: tr('My location'),
              onPressed: _goToMe,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(isDark),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _looking
                          ? 'Finding the place name…'
                          : _name == null || _name!.label.isEmpty
                              ? 'Move the map so the pin sits on the place'
                              : [_name!.label, _name!.state]
                                  .where((s) => s.isNotEmpty)
                                  .join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_centre.lat.toStringAsFixed(5)}, '
                      '${_centre.lng.toStringAsFixed(5)}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.subText(isDark)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        label: const T('Use this place'),
                        onPressed: () => Navigator.of(context)
                            .pop<PickedPlace>((point: _centre, name: _name)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
