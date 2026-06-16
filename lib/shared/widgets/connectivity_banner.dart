import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/initialization_provider.dart';

/// StreamProvider that emits `true` when at least one interface is online.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(connectivityWatcherProvider)
      .stream
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});

/// Amber strip shown at the top of a screen when connectivity is lost.
/// Zero height when online — no layout shift.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(isOnlineProvider);
    final isOffline = status.maybeWhen(data: (v) => !v, orElse: () => false);

    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: const Color(0xFFF57F17),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'You\'re offline — showing cached data',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: -1, duration: 250.ms, curve: Curves.easeOut);
  }
}
