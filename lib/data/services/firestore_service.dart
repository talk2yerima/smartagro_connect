import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;

import '../../core/utils/app_logger.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/chat_models.dart';

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

  /// How long to wait for the server to confirm a write. Firestore applies
  /// writes to its local cache at once and keeps retrying in the background,
  /// but the returned future only completes when the server answers, which
  /// never happens while offline. After this delay the write is treated as
  /// saved offline instead of leaving a spinner running forever.
  static const writeConfirmTimeout = Duration(seconds: 8);

  /// Awaits [write] for up to [writeConfirmTimeout]. A rejection that arrives
  /// in time (e.g. permission denied) is rethrown; a write still pending after
  /// that is left to sync on its own and any later failure is logged.
  Future<void> _awaitWrite(Future<void> write, String label) async {
    try {
      await write.timeout(writeConfirmTimeout);
    } on TimeoutException {
      log.w('[Firestore] $label pending — saved offline, will sync');
      unawaited(write.then<void>(
        (_) => log.d('[Firestore] $label synced'),
        onError: (Object e) => log.e('[Firestore] $label failed', error: e),
      ));
    }
  }

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
      log.e('[Firestore] saveUserProfile failed', error: e);
    }
  }

  Future<void> updateUserProfile(
    String uid, {
    String? name,
    String? phone,
    String? location,
    String? avatarUrl,
  }) async {
    if (!isAvailable) return;
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = phone;
      if (location != null) data['location'] = location;
      if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      log.e('[Firestore] updateUserProfile failed', error: e);
    }
  }

  Future<void> saveFcmToken(String uid, String token) async {
    if (!isAvailable) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log.e('[Firestore] saveFcmToken failed', error: e);
    }
  }

  Future<void> setUserVerified(String uid, {required bool verified}) async {
    if (!isAvailable) return;
    try {
      await _db.collection('users').doc(uid).update({
        'verified': verified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log.e('[Firestore] setUserVerified failed', error: e);
      rethrow;
    }
  }

  Future<void> setUserBanned(String uid, {required bool banned}) async {
    if (!isAvailable) return;
    try {
      await _db.collection('users').doc(uid).update({
        'banned': banned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log.e('[Firestore] setUserBanned failed', error: e);
      rethrow;
    }
  }

  /// Returns the full Firestore profile for [uid], or `null` if the document
  /// does not exist. Throws on Firestore errors.
  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    if (!isAvailable) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] =
          (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    return {'id': doc.id, ...data};
  }

  /// Returns the stored role, or `null` if the document does not exist.
  /// Throws on Firestore errors so the caller can distinguish "not found"
  /// from "read failed" and avoid overwriting valid data.
  Future<UserRole?> getUserRole(String uid) async {
    if (!isAvailable) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final roleName = doc.data()?['role'] as String?;
    if (roleName == null) return null;
    return UserRole.values.firstWhere(
      (r) => r.name == roleName,
      orElse: () => UserRole.farmer,
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Stream<List<AppNotification>> notificationsStream(String uid) {
    if (!isAvailable) return Stream.value([]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return AppNotification(
                id: doc.id,
                title: d['title'] as String? ?? '',
                body: d['body'] as String? ?? '',
                type: d['type'] as String? ?? 'system',
                createdAt:
                    (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                read: d['read'] as bool? ?? false,
              );
            }).toList());
  }

  Future<void> markNotificationRead(String uid, String notificationId) async {
    if (!isAvailable) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      log.e('[Firestore] markNotificationRead failed', error: e);
    }
  }

  Future<void> markAllNotificationsRead(String uid) async {
    if (!isAvailable) return;
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      log.e('[Firestore] markAllNotificationsRead failed', error: e);
    }
  }

  // ── Product listings ───────────────────────────────────────────────────────

  Future<String?> addProduct(Map<String, dynamic> data) async {
    if (!isAvailable) return null;
    try {
      // doc() assigns the id locally, so the listing gets an id even offline.
      final ref = _db.collection('products').doc();
      await _awaitWrite(
        ref.set({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        }),
        'addProduct',
      );
      log.d('[Firestore] addProduct → ${ref.id}');
      return ref.id;
    } catch (e) {
      log.e('[Firestore] addProduct failed', error: e);
      return null;
    }
  }

  /// Updates only [fields] on a listing. Callers must not include `sellerId`
  /// or `verified`: the security rules reject edits to those.
  Future<void> updateProduct(String id, Map<String, dynamic> fields) async {
    await _awaitWrite(
      _db.collection('products').doc(id).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      'updateProduct',
    );
  }

  Future<void> deleteProduct(String id) async {
    await _awaitWrite(
      _db.collection('products').doc(id).delete(),
      'deleteProduct',
    );
  }

  /// Active listings, newest first. Throws when Firestore can't answer (and
  /// has nothing cached), so callers can tell "no listings" from "offline".
  Future<List<Map<String, dynamic>>> fetchProducts() async {
    if (!isAvailable) return [];
    try {
      final snap = await _db
          .collection('products')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        // Convert Firestore Timestamps to ISO strings for SQLite compatibility.
        for (final key in ['createdAt', 'updatedAt']) {
          if (data[key] is Timestamp) {
            data[key] = (data[key] as Timestamp).toDate().toIso8601String();
          }
        }
        return <String, dynamic>{'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      log.e('[Firestore] fetchProducts failed', error: e);
      rethrow;
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  /// Deterministic thread ID: sorted UIDs joined with '_'.
  static String chatThreadId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<List<ChatThread>> chatThreadsStream(String uid) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final participants =
                  List<String>.from(data['participants'] as List? ?? []);
              final peerId =
                  participants.firstWhere((id) => id != uid, orElse: () => '');
              final names = Map<String, String>.from(
                  (data['names'] as Map?)?.cast<String, String>() ?? {});
              final roles = Map<String, String>.from(
                  (data['roles'] as Map?)?.cast<String, String>() ?? {});
              final unread = Map<String, dynamic>.from(
                  (data['unreadCounts'] as Map?) ?? {});
              final lastReadAt =
                  Map<String, dynamic>.from((data['lastReadAt'] as Map?) ?? {});
              final peerReadTs = lastReadAt[peerId];
              final peerLastReadAt =
                  peerReadTs is Timestamp ? peerReadTs.toDate() : null;
              return ChatThread(
                id: doc.id,
                peerId: peerId,
                peerName: names[peerId] ?? 'Unknown',
                peerRole: roles[peerId] ?? '',
                lastMessage: data['lastMessage'] as String? ?? '',
                updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                unread: (unread[uid] as num?)?.toInt() ?? 0,
                peerLastReadAt: peerLastReadAt,
              );
            }).toList());
  }

  Stream<List<ChatMessage>> chatMessagesStream(String threadId, String myUid) {
    return _db
        .collection('chats')
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final fromId = data['fromId'] as String? ?? '';
              final ts = data['sentAt'];
              final sentAt = ts is Timestamp ? ts.toDate() : DateTime.now();
              final kindName = data['kind'] as String? ?? 'text';
              final kind = ChatMessageKind.values.firstWhere(
                (k) => k.name == kindName,
                orElse: () => ChatMessageKind.text,
              );
              return ChatMessage(
                id: doc.id,
                threadId: threadId,
                fromMe: fromId == myUid,
                text: data['text'] as String? ?? '',
                sentAt: sentAt,
                kind: kind,
                imageUrl: data['imageUrl'] as String?,
              );
            }).toList());
  }

  Future<void> sendChatMessage({
    required String threadId,
    required String fromId,
    required String fromName,
    required String fromRole,
    required String peerId,
    required String peerName,
    required String peerRole,
    required String text,
    String? imageUrl,
  }) async {
    if (!isAvailable) return;
    try {
      final msgRef =
          _db.collection('chats').doc(threadId).collection('messages').doc();
      final threadRef = _db.collection('chats').doc(threadId);
      final batch = _db.batch();

      final msgData = <String, dynamic>{
        'fromId': fromId,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
        'kind': imageUrl != null ? 'image' : 'text',
      };
      if (imageUrl != null) msgData['imageUrl'] = imageUrl;

      batch.set(msgRef, msgData);

      batch.set(
          threadRef,
          {
            'participants': ([fromId, peerId]..sort()),
            'names': {fromId: fromName, peerId: peerName},
            'roles': {fromId: fromRole, peerId: peerRole},
            'lastMessage': imageUrl != null ? '📷 Image' : text,
            'updatedAt': FieldValue.serverTimestamp(),
            // set() treats a dotted key like 'unreadCounts.uid' as a literal
            // field name, so the counts must be a nested map (merged deeply).
            'unreadCounts': {
              fromId: 0,
              peerId: FieldValue.increment(1),
            },
          },
          SetOptions(merge: true));

      await _awaitWrite(batch.commit(), 'sendChatMessage');
    } catch (e) {
      log.e('[Firestore] sendChatMessage failed', error: e);
      rethrow;
    }
  }

  /// Marks [threadId] as read for [uid]: resets unread count and records
  /// the read timestamp so the peer can show blue double-ticks.
  Future<void> markThreadRead(String threadId, String uid) async {
    if (!isAvailable) return;
    try {
      await _db.collection('chats').doc(threadId).update({
        'lastReadAt.$uid': FieldValue.serverTimestamp(),
        'unreadCounts.$uid': 0,
      });
    } catch (_) {}
  }

  /// Writes or removes a typing heartbeat for [uid] in [threadId].
  Future<void> setTyping(String threadId, String uid, bool isTyping) async {
    if (!isAvailable) return;
    try {
      if (isTyping) {
        await _db.collection('chats').doc(threadId).set(
          {
            'typing': {uid: FieldValue.serverTimestamp()}
          },
          SetOptions(merge: true),
        );
      } else {
        await _db.collection('chats').doc(threadId).update(
          {'typing.$uid': FieldValue.delete()},
        );
      }
    } catch (_) {}
  }

  /// Emits `true` when [peerId] has a fresh typing heartbeat (< 6 s old).
  Stream<bool> peerTypingStream(String threadId, String peerId) {
    if (!isAvailable) return Stream.value(false);
    return _db.collection('chats').doc(threadId).snapshots().map((snap) {
      if (!snap.exists) return false;
      final typing = snap.data()?['typing'] as Map<String, dynamic>? ?? {};
      final ts = typing[peerId];
      if (ts == null) return false;
      final dt = ts is Timestamp ? ts.toDate() : null;
      if (dt == null) return false;
      return DateTime.now().difference(dt).inSeconds < 6;
    });
  }

  /// Generates a new message document ID for the given thread (used to
  /// build a stable Firebase Storage path before the batch write).
  String newMessageId(String threadId) =>
      _db.collection('chats').doc(threadId).collection('messages').doc().id;

  // ── Admin ─────────────────────────────────────────────────────────────────

  // ── Admin aggregates ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchAdminStats() async {
    if (!isAvailable) return {};
    try {
      final results = await Future.wait([
        _db.collection('users').get(),
        _db.collection('products').where('status', isEqualTo: 'active').get(),
        _db.collection('reports').where('status', isEqualTo: 'pending').get(),
      ]);
      final usersSnap = results[0];
      final productsSnap = results[1];
      final reportsSnap = results[2];

      int farmers = 0, buyers = 0, transporters = 0, verified = 0;
      for (final doc in usersSnap.docs) {
        final d = doc.data();
        switch (d['role'] as String? ?? '') {
          case 'farmer':
            farmers++;
          case 'buyer':
            buyers++;
          case 'transporter':
            transporters++;
        }
        if (d['verified'] as bool? ?? false) verified++;
      }

      double gmv = 0;
      for (final doc in productsSnap.docs) {
        final d = doc.data();
        final price = (d['priceNgn'] as num?)?.toDouble() ?? 0;
        final qty = (d['quantityKg'] as num?)?.toDouble() ?? 0;
        gmv += price * qty;
      }

      return {
        'totalUsers': usersSnap.size,
        'farmers': farmers,
        'buyers': buyers,
        'transporters': transporters,
        'verified': verified,
        'totalListings': productsSnap.size,
        'gmvNgn': gmv,
        'pendingReports': reportsSnap.size,
      };
    } catch (e) {
      log.e('[Firestore] fetchAdminStats failed', error: e);
      return {};
    }
  }

  // ── Reports / moderation ──────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> reportsStream() {
    if (!isAvailable) return Stream.value([]);
    return _db
        .collection('reports')
        .orderBy('reportedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              if (data['reportedAt'] is Timestamp) {
                data['reportedAt'] = (data['reportedAt'] as Timestamp)
                    .toDate()
                    .toIso8601String();
              }
              return <String, dynamic>{'id': doc.id, ...data};
            }).toList())
        .transform(StreamTransformer.fromHandlers(
          handleData: (data, sink) => sink.add(data),
          handleError: (e, _, sink) {
            log.e('[Firestore] reportsStream error', error: e);
            sink.add([]);
          },
          handleDone: (sink) => sink.close(),
        ));
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    if (!isAvailable) return;
    try {
      await _db.collection('reports').doc(reportId).update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log.e('[Firestore] updateReportStatus failed', error: e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    if (!isAvailable) return [];
    try {
      final snap = await _db
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] =
              (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return <String, dynamic>{'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      log.e('[Firestore] fetchAllUsers failed', error: e);
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> commoditiesStream() {
    if (!isAvailable) return Stream.value([]);
    return _db
        .collection('commodities')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              // Convert any Timestamps to ISO strings for safety.
              for (final key in ['createdAt', 'updatedAt']) {
                if (data[key] is Timestamp) {
                  data[key] =
                      (data[key] as Timestamp).toDate().toIso8601String();
                }
              }
              return <String, dynamic>{'id': doc.id, ...data};
            }).toList())
        .transform(StreamTransformer.fromHandlers(
          handleData: (data, sink) => sink.add(data),
          handleError: (e, _, sink) {
            log.e('[Firestore] commoditiesStream error', error: e);
            sink.add([]);
          },
          handleDone: (sink) => sink.close(),
        ));
  }

  Future<void> upsertCommodity(String id, Map<String, dynamic> data) async {
    if (!isAvailable) return;
    try {
      await _db.collection('commodities').doc(id).set(
        {...data, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      log.e('[Firestore] upsertCommodity failed', error: e);
    }
  }

  Future<void> deleteCommodity(String id) async {
    if (!isAvailable) return;
    try {
      await _db.collection('commodities').doc(id).delete();
    } catch (e) {
      log.e('[Firestore] deleteCommodity failed', error: e);
    }
  }

  Future<DateTime?> fetchUserCreatedAt(String uid) async {
    if (!isAvailable) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final ts = doc.data()?['createdAt'];
      return ts is Timestamp ? ts.toDate() : null;
    } catch (e) {
      log.e('[Firestore] fetchUserCreatedAt failed', error: e);
      return null;
    }
  }

  Future<void> submitReport({
    required String productId,
    required String productTitle,
    required String reportedBy,
    required String reason,
  }) async {
    if (!isAvailable) return;
    try {
      await _db.collection('reports').add({
        'productId': productId,
        'productTitle': productTitle,
        'reportedBy': reportedBy,
        'reason': reason,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      log.e('[Firestore] submitReport failed', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBuyers() async {
    if (!isAvailable) return [];
    try {
      final snap =
          await _db.collection('users').where('role', isEqualTo: 'buyer').get();
      return snap.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      log.e('[Firestore] fetchBuyers failed', error: e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAdminActivity({int limit = 5}) async {
    if (!isAvailable) return [];
    try {
      final results = await Future.wait([
        _db
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get(),
        _db
            .collection('products')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get(),
      ]);
      final usersSnap = results[0];
      final productsSnap = results[1];

      final items = <Map<String, dynamic>>[];
      for (final doc in usersSnap.docs) {
        final d = doc.data();
        final ts = d['createdAt'];
        items.add({
          'type': 'new_user',
          'name': d['name'] as String? ?? 'Unknown',
          'role': d['role'] as String? ?? 'farmer',
          'timestamp': ts is Timestamp ? ts.toDate() : null,
        });
      }
      for (final doc in productsSnap.docs) {
        final d = doc.data();
        final ts = d['createdAt'];
        items.add({
          'type': 'new_listing',
          'title': d['title'] as String? ?? 'Product',
          'sellerName': d['sellerName'] as String? ?? '',
          'timestamp': ts is Timestamp ? ts.toDate() : null,
        });
      }
      items.sort((a, b) {
        final at = a['timestamp'] as DateTime?;
        final bt = b['timestamp'] as DateTime?;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
      return items.take(limit).toList();
    } catch (e) {
      log.e('[Firestore] fetchAdminActivity failed', error: e);
      return [];
    }
  }
}
