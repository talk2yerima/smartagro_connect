import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/data/services/payments_api.dart';

/// Records requests and replies with a canned JSON response.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PaymentsApi _api(
  _FakeAdapter adapter, {
  bool live = true,
  String? token = 'id-token',
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return PaymentsApi(
    dio: dio,
    baseUrl: 'https://fn.test',
    idToken: () async => token,
    isLive: () => live,
  );
}

void main() {
  group('PaymentsApi.initialize', () {
    test('sends only the product id and returns the server amount', () async {
      final adapter = _FakeAdapter(200, {
        'result': {
          'reference': 'SA-1',
          'authorizationUrl': 'https://checkout.paystack.com/x',
          'amountKobo': 2000000,
          'description': '40 kg of Maize',
        },
      });

      final result = await _api(adapter).initialize(
        productId: 'p1',
        email: 'b@farm.ng',
      );

      expect(result.reference, 'SA-1');
      expect(result.amountKobo, 2000000);
      final req = adapter.requests.single;
      expect(req.uri.toString(), 'https://fn.test/initializePayment');
      expect(req.headers['Authorization'], 'Bearer id-token');
      expect(req.data, {
        'data': {'productId': 'p1', 'email': 'b@farm.ng'},
      });
    });

    test('surfaces the server error message', () async {
      final adapter = _FakeAdapter(400, {
        'error': {
          'status': 'FAILED_PRECONDITION',
          'message': 'This listing is sold out.',
        },
      });

      expect(
        () => _api(adapter).initialize(productId: 'p1'),
        throwsA(
          isA<PaymentException>().having(
            (e) => e.message,
            'message',
            'This listing is sold out.',
          ),
        ),
      );
    });

    test('refuses in demo mode without calling the server', () async {
      final adapter = _FakeAdapter(200, {});
      await expectLater(
        () => _api(adapter, live: false).initialize(productId: 'p1'),
        throwsA(isA<PaymentException>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test('refuses when there is no signed-in token', () async {
      final adapter = _FakeAdapter(200, {});
      await expectLater(
        () => _api(adapter, token: null).initialize(productId: 'p1'),
        throwsA(isA<PaymentException>()),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('PaymentsApi.verify', () {
    test('returns the status decided by the server', () async {
      final adapter = _FakeAdapter(200, {
        'result': {'reference': 'SA-1', 'status': 'success'},
      });

      expect(await _api(adapter).verify('SA-1'), 'success');
      expect(adapter.requests.single.data, {
        'data': {'reference': 'SA-1'},
      });
    });
  });
}
