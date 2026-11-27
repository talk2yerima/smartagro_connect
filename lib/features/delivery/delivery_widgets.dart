import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/i18n/i18n.dart';
import '../../core/services/app_lock.dart';
import '../../core/utils/geo.dart';
import '../../domain/entities/haulage_job.dart';

/// Google Maps only runs on phones; tests and desktop builds get a
/// placeholder instead.
bool get mapsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

const nigeriaCentre = LatLng(9.0820, 8.6753);

LatLng latLng(GeoPoint2 p) => LatLng(p.lat, p.lng);

/// "Gashua market, Yobe".
String placeText(JobPlace p) {
  if (p.state.isEmpty || p.label.contains(p.state)) return p.label;
  return '${p.label}, ${p.state}';
}

/// Turn-by-turn directions in Google Maps (or the browser).
Future<void> openNavigation(WidgetRef ref, GeoPoint2 to) async {
  ref.read(appLockProvider.notifier).allowNextReturn();
  final uri = Uri.parse('https://www.google.com/maps/dir/?api=1'
      '&destination=${to.lat},${to.lng}&travelmode=driving');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> callPhone(WidgetRef ref, String phone) async {
  ref.read(appLockProvider.notifier).allowNextReturn();
  await launchUrl(Uri(scheme: 'tel', path: phone));
}

/// Camera that shows all [points] with some room around them.
CameraUpdate fitPoints(List<GeoPoint2> points, {double padding = 70}) {
  final set = points.where((p) => p.isSet).toList();
  if (set.isEmpty) return CameraUpdate.newLatLngZoom(nigeriaCentre, 5.5);
  if (set.length == 1) return CameraUpdate.newLatLngZoom(latLng(set.first), 13);
  var s = set.first.lat, n = s, w = set.first.lng, e = w;
  for (final p in set) {
    s = math.min(s, p.lat);
    n = math.max(n, p.lat);
    w = math.min(w, p.lng);
    e = math.max(e, p.lng);
  }
  // Two points very close together: avoid zooming in to street level.
  if (n - s < 0.01 && e - w < 0.01) {
    return CameraUpdate.newLatLngZoom(LatLng((n + s) / 2, (e + w) / 2), 14);
  }
  return CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)), padding);
}

/// Pickup (green), drop-off (orange) and, when known, the truck (blue).
Set<Marker> jobMarkers(HaulageJob job, {GeoPoint2? truck}) => {
      Marker(
        markerId: const MarkerId('pickup'),
        position: latLng(job.pickup.point),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow:
            InfoWindow(title: tr('Pickup'), snippet: placeText(job.pickup)),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: latLng(job.dropoff.point),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow:
            InfoWindow(title: tr('Drop-off'), snippet: placeText(job.dropoff)),
      ),
      if (truck != null && truck.isSet)
        Marker(
          markerId: const MarkerId('truck'),
          position: latLng(truck),
          zIndexInt: 2,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: job.transporterName ?? 'Transporter'),
        ),
    };

/// The trip as a dashed line, and the truck's remaining leg as a solid one.
Set<Polyline> jobLines(HaulageJob job, {GeoPoint2? truck}) => {
      Polyline(
        polylineId: const PolylineId('trip'),
        points: [latLng(job.pickup.point), latLng(job.dropoff.point)],
        color: AppColors.gray,
        width: 4,
        patterns: [PatternItem.dash(24), PatternItem.gap(14)],
      ),
      if (truck != null && truck.isSet && job.isActive)
        Polyline(
          polylineId: const PolylineId('leg'),
          points: [latLng(truck), latLng(job.nextStop.point)],
          color: AppColors.infoBlue,
          width: 5,
        ),
    };

/// Pickup → drop-off, one under the other.
class RouteSummary extends StatelessWidget {
  const RouteSummary({super.key, required this.job, this.dense = false});

  final HaulageJob job;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final sub =
        AppColors.subText(Theme.of(context).brightness == Brightness.dark);
    Widget row(IconData icon, Color color, String title, JobPlace p) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '$title  ',
                      style: TextStyle(fontSize: 12, color: sub)),
                  TextSpan(
                      text: placeText(p),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: dense ? 13 : 14)),
                ]),
                maxLines: dense ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(Icons.trip_origin_rounded, AppColors.emerald, 'From', job.pickup),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
              width: 2, height: dense ? 8 : 12, color: AppColors.silver),
        ),
        row(Icons.place_rounded, AppColors.warmOrange, 'To', job.dropoff),
      ],
    );
  }
}

/// A small icon + text fact on a job ("168 km", "₦20,000").
class FactChip extends StatelessWidget {
  const FactChip(this.icon, this.text, {super.key, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? AppColors.text(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

/// Status pill for a delivery.
class JobStatusChip extends StatelessWidget {
  const JobStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'open' => (tr('Finding transporter'), AppColors.warmOrange),
      'accepted' => (tr('Driver assigned'), AppColors.infoBlue),
      'picked_up' => (tr('On the road'), AppColors.infoBlue),
      'delivered' => (tr('Delivered'), AppColors.emerald),
      _ => (tr('Cancelled'), AppColors.gray),
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

/// Shown instead of a map where Google Maps can't run.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => Container(
        color:
            AppColors.surface(Theme.of(context).brightness == Brightness.dark),
        alignment: Alignment.center,
        child:
            const Icon(Icons.map_outlined, size: 56, color: AppColors.silver),
      );
}
