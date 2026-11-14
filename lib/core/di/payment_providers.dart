import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/transaction_ref_queue.dart';
import '../../data/services/payments_api.dart';
import '../config/app_env.dart';
import 'auth_providers.dart';
import 'initialization_provider.dart';

final paymentsApiProvider = Provider<PaymentsApi>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return PaymentsApi(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
    baseUrl: AppEnv.functionsBase,
    idToken: () => auth.getIdToken(),
    isLive: () => auth.isLiveMode,
  );
});

final transactionRefQueueProvider = Provider<TransactionRefQueue>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(paymentsApiProvider);
  return TransactionRefQueue(db, api);
});

final transactionHistoryProvider =
    FutureProvider<List<TransactionRef>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final maps = await db.allTransactionRefs();
  return maps.map(TransactionRef.fromMap).toList();
});
