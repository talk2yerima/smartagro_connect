import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';

/// Thin wrapper around Cloud Firestore for user profiles and product listings.
///
/// All methods silently no-op / return empty when Firebase is not configured.
class FirestoreService {
  bool get isAvailable {
    try {
      if (Firebase.apps.isEmpty) return false;
      final key = Firebase.app().options.apiKey;
      return key.isNotEmpty &&
          !key.startsWith('YOUR_') &&
          !key.startsWith('REPLACE_');
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── User profiles ──────────────────────────────────────────────────────────

  Future<void> saveUserProfile(
    String uid, {
    required String name,
    required String email,
    required UserRole role,
  }) async {
    if (!isAvailable) return;
    try {
      await _db.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] saveUserProfile failed: $e');
    }
  }

  Future<UserRole?> getUserRole(String uid) async {
    if (!isAvailable) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final roleName = doc.data()?['role'] as String?;
      if (roleName == null) return null;
      return UserRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => UserRole.farmer,
      );
    } catch (e) {
      debugPrint('[Firestore] getUserRole failed: $e');
      return null;
    }
  }

  // ── Product listings ───────────────────────────────────────────────────────

  Future<String?> addProduct(Map<String, dynamic> data) async {
    if (!isAvailable) return null;
    try {
      final ref = await _db.collection('products').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      debugPrint('[Firestore] addProduct → ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('[Firestore] addProduct failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    if (!isAvailable) return [];
    try {
      final snap = await _db
          .collection('products')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) => <String, dynamic>{
            'id': doc.id,
            ...doc.data(),
          }).toList();
    } catch (e) {
      debugPrint('[Firestore] fetchProducts failed: $e');
      return [];
    }
  }
}
