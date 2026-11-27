import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/location_service.dart';
import '../../domain/entities/haulage_job.dart';
import 'auth_providers.dart';
import 'firestore_providers.dart';

final locationServiceProvider =
    Provider<LocationService>((_) => LocationService());

/// The delivery for one order, live (null when none was requested).
final haulageJobProvider =
    StreamProvider.autoDispose.family<HaulageJob?, String>((ref, orderRef) {
  // Re-subscribe when the account changes (rules depend on who is asking).
  ref.watch(authSessionProvider.select((u) => u?.id));
  return ref.watch(firestoreServiceProvider).haulageJobStream(orderRef);
});

/// Jobs waiting for a transporter (transporters only).
final openHaulageJobsProvider =
    StreamProvider.autoDispose<List<HaulageJob>>((ref) {
  final uid = ref.watch(authSessionProvider.select((u) => u?.id));
  if (uid == null) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).openHaulageJobsStream();
});

/// Jobs the signed-in transporter accepted.
final myHaulageJobsProvider =
    StreamProvider.autoDispose<List<HaulageJob>>((ref) {
  final uid = ref.watch(authSessionProvider.select((u) => u?.id));
  if (uid == null) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).myHaulageJobsStream(uid);
});
