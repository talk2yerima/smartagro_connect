import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagro_connect/data/local/app_database.dart';
import 'package:smartagro_connect/data/repositories/transaction_ref_queue.dart';
import 'package:smartagro_connect/data/services/payments_api.dart';

class MockDb extends Mock implements AppDatabase {}

class MockApi extends Mock implements PaymentsApi {}

Map<String, dynamic> _row(String reference, String status) => {
      'reference': reference,
      'amount_kobo': 2000000,
      'email': 'b@farm.ng',
      'description': '40 kg of Maize',
      'status': status,
      'created_at': DateTime(2026, 11, 14).millisecondsSinceEpoch,
      'verified_at': null,
    };

void main() {
  late MockDb db;
  late MockApi api;
  late TransactionRefQueue queue;

  setUp(() {
    db = MockDb();
    api = MockApi();
    queue = TransactionRefQueue(db, api);
    when(() => db.updateTransactionRefStatus(any(), any()))
        .thenAnswer((_) async {});
  });

  test('verifyRef stores the status returned by the backend', () async {
    when(() => api.verify('SA-1')).thenAnswer((_) async => 'success');

    expect(await queue.verifyRef('SA-1'), 'success');
    verify(() => db.updateTransactionRefStatus('SA-1', 'success')).called(1);
  });

  test('drainPendingRefs keeps going when one reference fails', () async {
    when(() => db.pendingTransactionRefs()).thenAnswer(
      (_) async => [_row('SA-1', 'pending'), _row('SA-2', 'abandoned')],
    );
    when(() => api.verify('SA-1')).thenThrow(const PaymentException('offline'));
    when(() => api.verify('SA-2')).thenAnswer((_) async => 'success');

    await queue.drainPendingRefs();

    verifyNever(() => db.updateTransactionRefStatus('SA-1', any()));
    verify(() => db.updateTransactionRefStatus('SA-2', 'success')).called(1);
  });

  test('isPending is false only for final statuses', () {
    for (final s in ['success', 'failed', 'reversed', 'amount_mismatch']) {
      expect(TransactionRef.fromMap(_row('r', s)).isPending, isFalse);
    }
    for (final s in ['pending', 'abandoned']) {
      expect(TransactionRef.fromMap(_row('r', s)).isPending, isTrue);
    }
  });
}
