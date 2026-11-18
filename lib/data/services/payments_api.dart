import 'package:dio/dio.dart';

/// Client for the SmartAgro payments backend (Firebase Cloud Functions in
/// `functions/`).
///
/// The app never talks to Paystack with a secret key. It only sends the
/// product id; the backend looks up the price, starts the Paystack checkout,
/// and later confirms the payment with Paystack itself. Calls use the Firebase
/// callable-function HTTPS protocol, so this works on every platform
/// (including Windows, where the `cloud_functions` plugin is unavailable).
class PaymentsApi {
  PaymentsApi({
    required Dio dio,
    required String baseUrl,
    required Future<String?> Function() idToken,
    required bool Function() isLive,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _idToken = idToken,
        _isLive = isLive;

  final Dio _dio;
  final String _baseUrl;
  final Future<String?> Function() _idToken;
  final bool Function() _isLive;

  /// Starts a payment for [productId]. The amount is decided by the server.
  Future<PaymentInitResult> initialize({
    required String productId,
    String? email,
  }) async {
    final result = await _call('initializePayment', {
      'productId': productId,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return PaymentInitResult(
      reference: result['reference'] as String,
      authorizationUrl: result['authorizationUrl'] as String,
      amountKobo: (result['amountKobo'] as num).toInt(),
      description: result['description'] as String? ?? '',
    );
  }

  // ── Farmer payouts ───────────────────────────────────────────────────────

  /// Banks that accept transfers, and SmartAgro's fee in percent.
  Future<({List<Bank> banks, int feePercent})> listBanks() async {
    final result = await _call('listBanks', const {});
    final banks = (result['banks'] as List? ?? const [])
        .whereType<Map>()
        .map((b) => Bank(name: '${b['name']}', code: '${b['code']}'))
        .toList();
    return (
      banks: banks,
      feePercent: (result['feePercent'] as num?)?.toInt() ?? 5,
    );
  }

  /// The name the bank has on file for this account ("Check account").
  Future<String> resolveBankAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    final result = await _call('resolveBankAccount', {
      'accountNumber': accountNumber,
      'bankCode': bankCode,
    });
    return result['accountName'] as String? ?? '';
  }

  /// Saves the seller's bank account; future sales are split to it.
  Future<PayoutAccount> savePayoutAccount({
    required String accountNumber,
    required Bank bank,
  }) async {
    final result = await _call('savePayoutAccount', {
      'accountNumber': accountNumber,
      'bankCode': bank.code,
      'bankName': bank.name,
    });
    return PayoutAccount.fromMap(result);
  }

  /// Asks the server to confirm [reference] with Paystack.
  /// Returns the server status: `success`, `pending`, `failed`, `abandoned`,
  /// `reversed` or `amount_mismatch`.
  Future<String> verify(String reference) async {
    final result = await _call('verifyPayment', {'reference': reference});
    return result['status'] as String;
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (!_isLive()) {
      throw const PaymentException(
        'Payments are unavailable in demo mode. Sign in with a live account.',
      );
    }
    final token = await _idToken();
    if (token == null || token.isEmpty) {
      throw const PaymentException('Please sign in again to continue.');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/$name',
        data: {'data': data},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      final body = response.data;
      final result = body?['result'];
      if (result is! Map) {
        throw const PaymentException('Unexpected response from server.');
      }
      return Map<String, dynamic>.from(result);
    } on DioException catch (e) {
      throw PaymentException(_messageFrom(e));
    }
  }

  static String _messageFrom(DioException e) {
    // The payments backend hasn't been deployed (no such function yet).
    if (e.response?.statusCode == 404) {
      return "Payments aren't switched on yet. Please try again later.";
    }
    final body = e.response?.data;
    if (body is Map && body['error'] is Map) {
      final message = (body['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'Network error. Check your connection and try again.',
      _ => 'Payment service error. Please try again.',
    };
  }
}

class PaymentInitResult {
  const PaymentInitResult({
    required this.reference,
    required this.authorizationUrl,
    required this.amountKobo,
    required this.description,
  });

  final String reference;
  final String authorizationUrl;
  final int amountKobo;
  final String description;
}

class PaymentException implements Exception {
  const PaymentException(this.message);

  final String message;

  @override
  String toString() => 'PaymentException: $message';
}

class Bank {
  const Bank({required this.name, required this.code});

  final String name;
  final String code;
}

/// A seller's saved payout account, as shown back to them (masked).
class PayoutAccount {
  const PayoutAccount({
    required this.bankName,
    required this.accountName,
    required this.accountNumberMasked,
  });

  factory PayoutAccount.fromMap(Map<dynamic, dynamic> m) => PayoutAccount(
        bankName: '${m['bankName'] ?? ''}',
        accountName: '${m['accountName'] ?? ''}',
        accountNumberMasked: '${m['accountNumberMasked'] ?? ''}',
      );

  final String bankName;
  final String accountName;
  final String accountNumberMasked;
}
