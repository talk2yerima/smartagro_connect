import '../local/app_database.dart';
import '../services/payments_api.dart';

/// A payment reference stored on the device until the server confirms it.
class TransactionRef {
  const TransactionRef({
    required this.reference,
    required this.amountKobo,
    required this.email,
    required this.description,
    required this.status,
    required this.createdAt,
    this.verifiedAt,
  });

  factory TransactionRef.fromMap(Map<String, dynamic> m) => TransactionRef(
        reference: m['reference'] as String,
        amountKobo: m['amount_kobo'] as int,
        email: m['email'] as String,
        description: m['description'] as String,
        status: m['status'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        verifiedAt: m['verified_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['verified_at'] as int),
      );

  final String reference;
  final int amountKobo;
  final String email;
  final String description;

  /// `pending` | `abandoned` | `success` | `failed` | `reversed` |
  /// `amount_mismatch` — as reported by the payments backend.
  final String status;

  final DateTime createdAt;
  final DateTime? verifiedAt;

  double get amountNgn => amountKobo / 100;
  bool get isPending => !TransactionRefQueue.finalStatuses.contains(status);
}

/// Local history of payment references.
///
/// A reference is saved the moment checkout starts, so it is never lost if
/// the app is killed while the buyer is on the Paystack page. The source of
/// truth is the backend (`payments/{reference}` in Firestore, updated by the
/// Paystack webhook); this queue only asks the backend for the latest status.
class TransactionRefQueue {
  const TransactionRefQueue(this._db, this._api);

  final AppDatabase _db;
  final PaymentsApi _api;

  /// Statuses the backend will never change again.
  static const finalStatuses = {
    'success',
    'failed',
    'reversed',
    'amount_mismatch',
  };

  Future<void> enqueue({
    required String reference,
    required int amountKobo,
    required String email,
    required String description,
  }) async {
    await _db.enqueueTransactionRef(
      reference: reference,
      amountKobo: amountKobo,
      email: email,
      description: description,
    );
  }

  Future<List<TransactionRef>> pendingRefs() async {
    final maps = await _db.pendingTransactionRefs();
    return maps.map(TransactionRef.fromMap).toList();
  }

  /// Re-checks every unfinished reference with the backend.
  /// Safe to call on app start — network failures are retried next time.
  Future<void> drainPendingRefs() async {
    final pending = await pendingRefs();
    for (final ref in pending) {
      try {
        final status = await _api.verify(ref.reference);
        await _db.updateTransactionRefStatus(ref.reference, status);
      } catch (_) {
        // Retry next drain cycle.
      }
    }
  }

  /// Fetches the stored record for a single reference, or null if not found.
  Future<TransactionRef?> getRef(String reference) async {
    final m = await _db.getTransactionRef(reference);
    return m == null ? null : TransactionRef.fromMap(m);
  }

  /// Asks the backend to confirm [reference] and stores the result.
  Future<String> verifyRef(String reference) async {
    final status = await _api.verify(reference);
    await _db.updateTransactionRefStatus(reference, status);
    return status;
  }
}
