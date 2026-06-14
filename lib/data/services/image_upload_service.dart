import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads product images to Firebase Storage (production) or simulates
/// progress for demo / dev mode.
///
/// Caller receives progress ticks [0.0 → 1.0] via [onProgress], then the
/// download URL when the upload completes.
class ImageUploadService {
  // ── Firebase availability ──────────────────────────────────────────────────

  bool get _storageReady {
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

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Uploads the image at [filePath].
  ///
  /// [productId] is used as the storage path key.
  /// [userId]    scopes the path to the user's folder.
  /// [onProgress] fires with values in [0.0, 1.0].
  ///
  /// Returns the public download URL on success.
  Future<String> uploadProductImage({
    required String filePath,
    required String productId,
    String? userId,
    void Function(double progress)? onProgress,
  }) {
    if (_storageReady) {
      return _uploadToFirebase(
        filePath: filePath,
        productId: productId,
        userId: userId,
        onProgress: onProgress,
      );
    }
    return _uploadDemo(filePath: filePath, onProgress: onProgress);
  }

  // ── Firebase path ──────────────────────────────────────────────────────────

  Future<String> _uploadToFirebase({
    required String filePath,
    required String productId,
    String? userId,
    void Function(double)? onProgress,
  }) async {
    final ref = FirebaseStorage.instance
        .ref('product_images/${userId ?? 'anon'}/$productId.jpg');

    final task = ref.putFile(File(filePath));

    StreamSubscription<TaskSnapshot>? sub;
    sub = task.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0) {
        onProgress?.call(snap.bytesTransferred / snap.totalBytes);
      }
    });

    try {
      await task;
    } finally {
      await sub.cancel();
    }

    return await ref.getDownloadURL();
  }

  // ── Demo / dev path ────────────────────────────────────────────────────────

  /// Simulates ~1.5 s progress, then returns a stable placeholder URL.
  Future<String> _uploadDemo({
    required String filePath,
    void Function(double)? onProgress,
  }) async {
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 125));
      onProgress?.call(i / steps);
    }
    // Seed from path hash so repeated "uploads" of the same file return the
    // same URL — avoids flickering in demo mode.
    final seed = filePath.hashCode.abs() % 100;
    return 'https://picsum.photos/seed/$seed/400/300';
  }
}
