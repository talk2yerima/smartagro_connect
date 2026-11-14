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
