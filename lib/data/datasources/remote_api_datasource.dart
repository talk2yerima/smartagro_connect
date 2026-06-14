import 'package:dio/dio.dart';

import '../../core/errors/failures.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';

/// Remote REST datasource (Dio). Falls back to local fixtures when unreachable.
class RemoteApiDataSource {
  RemoteApiDataSource(this._client);

  final DioClient _client;

  Future<List<Map<String, dynamic>>> fetchCommodities() async {
    try {
      final res = await _client.raw.get(ApiEndpoints.commodities());
      final data = res.data;
      if (data is Map && data['items'] is List) {
        return (data['items'] as List).cast<Map<String, dynamic>>();
      }
      throw const ServerFailure('Unexpected commodities payload');
    } on DioException catch (e) {
      throw _client.mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      final res = await _client.raw.get(ApiEndpoints.products());
      final data = res.data;
      if (data is Map && data['items'] is List) {
        return (data['items'] as List).cast<Map<String, dynamic>>();
      }
      throw const ServerFailure('Unexpected products payload');
    } on DioException catch (e) {
      throw _client.mapError(e);
    }
  }

  Future<void> createProduct(Map<String, dynamic> data) async {
    try {
      await _client.raw.post(ApiEndpoints.products(), data: data);
    } on DioException catch (e) {
      throw _client.mapError(e);
    }
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      await _client.raw.put(ApiEndpoints.productById(id), data: data);
    } on DioException catch (e) {
      throw _client.mapError(e);
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _client.raw.delete(ApiEndpoints.productById(id));
    } on DioException catch (e) {
      throw _client.mapError(e);
    }
  }
}
