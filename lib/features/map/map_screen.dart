import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/i18n/i18n.dart';
import '../../domain/entities/nearby_buyer.dart';

// Approximate centre-points for Nigerian states used by the mock buyers.
const _stateLatLng = <String, LatLng>{
  'Lagos': LatLng(6.5244, 3.3792),
  'FCT': LatLng(9.0765, 7.3986),
  'Kano': LatLng(12.0022, 8.5920),
  'Ogun': LatLng(7.1601, 3.3478),
  'Rivers': LatLng(4.8156, 7.0498),
  'Enugu': LatLng(6.4584, 7.5464),
  'Kaduna': LatLng(10.5264, 7.4384),
  'Oyo': LatLng(7.8511, 3.9470),
  'Ondo': LatLng(7.2500, 5.1950),
  'Borno': LatLng(11.8333, 13.1500),
  'Plateau': LatLng(9.2182, 9.5179),
  'Anambra': LatLng(6.2104, 7.0694),
  'Delta': LatLng(5.5320, 5.8987),
  'Sokoto': LatLng(13.0621, 5.2421),
  'Kwara': LatLng(8.4966, 4.5426),
};

// Default fallback when state is unknown.
const _defaultLatLng = LatLng(9.0820, 8.6753); // Nigeria centre

LatLng _latLngForBuyer(NearbyBuyer b) =>
    _stateLatLng[b.state] ?? _defaultLatLng;

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  static const _nigeria =
      CameraPosition(target: LatLng(9.0820, 8.6753), zoom: 6.0);

  static bool get _mapSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buyersAsync = ref.watch(buyersNearbyProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const T(
          'Nearby Buyers',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(buyersNearbyProvider),
          ),
        ],
      ),
      body: !_mapSupported
          ? const _MapUnsupportedPlaceholder()
          : buyersAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.deepGreen)),
              error: (_, __) =>
                  const Center(child: T('Could not load buyer locations.')),
              data: (buyers) {
                final markers = buyers.map((b) {
                  final pos = _latLngForBuyer(b);
                  return Marker(
                    markerId: MarkerId(b.id),
                    position: pos,
                    infoWindow: InfoWindow(
                      title: b.name,
                      snippet:
                          '${b.state} · ${b.distanceKm} km · ⭐ ${b.rating.toStringAsFixed(1)}${b.verified ? ' ✓' : ''}',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      b.verified
                          ? BitmapDescriptor.hueGreen
                          : BitmapDescriptor.hueOrange,
                    ),
                  );
                }).toSet();

                return Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: _nigeria,
                      myLocationButtonEnabled: true,
                      myLocationEnabled: true,
                      markers: markers,
                    ),
                    // Legend
                    Positioned(
                      bottom: 24,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xDD1E1E1E)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LegendRow(
                                color: AppColors.mintGreen,
                                label: tr('Verified buyer')),
                            const SizedBox(height: 4),
                            _LegendRow(
                                color: AppColors.warmOrange,
                                label: tr('Unverified buyer')),
                            const SizedBox(height: 4),
                            Text(
                              '${buyers.length} buyer${buyers.length == 1 ? '' : 's'} shown',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.gray),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.charcoal)),
      ],
    );
  }
}

class _MapUnsupportedPlaceholder extends StatelessWidget {
  const _MapUnsupportedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          T('Map view is available on Android and iOS.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          T('Run on a mobile device to see nearby buyers.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
