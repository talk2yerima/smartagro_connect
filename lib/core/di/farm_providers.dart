import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/farm_profile.dart';
import 'auth_providers.dart';
import 'firestore_providers.dart';

/// A farmer's public profile, live.
final farmProfileProvider =
    StreamProvider.autoDispose.family<FarmProfile?, String>((ref, uid) {
  ref.watch(authSessionProvider.select((u) => u?.id));
  return ref
      .watch(firestoreServiceProvider)
      .userProfileStream(uid)
      .map((m) => m == null ? null : FarmProfile.fromMap(uid, m));
});

/// A seller's published reviews, newest first.
final sellerReviewsProvider = StreamProvider.autoDispose
    .family<List<SellerReview>, String>((ref, sellerId) {
  ref.watch(authSessionProvider.select((u) => u?.id));
  return ref.watch(firestoreServiceProvider).sellerReviewsStream(sellerId);
});

/// Farmers this person saved (kept on this phone).
class FavouriteFarmers extends StateNotifier<Set<String>> {
  FavouriteFarmers() : super(const {}) {
    _load();
  }

  static const _key = 'smartagro_favourite_farmers';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) state = {...?prefs.getStringList(_key)};
  }

  Future<void> toggle(String uid) async {
    state = state.contains(uid) ? ({...state}..remove(uid)) : {...state, uid};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }
}

final favouriteFarmersProvider =
    StateNotifierProvider<FavouriteFarmers, Set<String>>(
        (_) => FavouriteFarmers());
