import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map surface for buyers/markets; requires Android/iOS Maps API key.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const _lagos =
      CameraPosition(target: LatLng(6.5244, 3.3792), zoom: 11);

  static bool get _mapSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby map')),
      body: _mapSupported
          ? GoogleMap(
              initialCameraPosition: _lagos,
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              markers: {
                const Marker(
                  markerId: MarkerId('sample-buyer'),
                  position: LatLng(6.4541, 3.3947),
                  infoWindow: InfoWindow(title: 'Sample buyer hub'),
                ),
              },
            )
          : const _MapUnsupportedPlaceholder(),
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
          Icon(Icons.map_outlined, size: 64,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Map view is available on Android and iOS.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Run on a mobile device or emulator to see nearby buyers.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
