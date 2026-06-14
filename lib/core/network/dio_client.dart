import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import '../errors/failures.dart';

/// Dio client configured for SmartAgro REST backends.
///
/// Pass [getToken] — an async callback that returns the current Bearer token
/// (Firebase ID token or custom JWT).  The interceptor injects it on every
/// request and refreshes it automatically on a 401 response.
///
/// Pass [onUnauthorized] to handle the case where even a refreshed token is
/// rejected (e.g. account suspended) — typically calls AuthSessionNotifier.logout().
class DioClient {
  DioClient({
    required String baseUrl,
    Dio? dio,
    Future<String?> Function()? getToken,
    Future<String?> Function()? refreshToken,
    void Function()? onUnauthorized,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    // ── Auth interceptor ─────────────────────────────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401 && getToken != null) {
            // Try once with a force-refreshed token before giving up.
            try {
              final newToken = await (refreshToken ?? getToken).call();
              if (newToken != null && newToken.isNotEmpty) {
                final retryOpts = e.requestOptions;
                retryOpts.headers['Authorization'] = 'Bearer $newToken';
                final response = await _dio.fetch(retryOpts);
                handler.resolve(response);
                return;
              }
            } catch (_) {}
            // Refresh failed — session is invalid.
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );

    // ── Retry interceptor (exponential back-off for network errors) ───────
    // Retries up to 3 times on connection/timeout errors only — not on 4xx.
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        retries: 3,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 4),
        ],
        retryEvaluator: (error, attempt) =>
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError,
      ),
    );
  }

  final Dio _dio;

  Dio get raw => _dio;

  /// Maps Dio errors into domain [Failure] types for consistent UI handling.
  Failure mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkFailure('Connection issue. Showing offline data.');
    }
    final code = e.response?.statusCode;
    if (code == 401) return const AuthFailure('Session expired. Please sign in again.');
    if (code != null && code >= 500) {
      return ServerFailure('Server error ($code). Please try again.');
    }
    return NetworkFailure(e.message ?? 'Network error');
  }
}
