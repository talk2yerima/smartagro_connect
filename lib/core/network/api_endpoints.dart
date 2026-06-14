/// Central registry for REST paths (versioned API).
abstract final class ApiEndpoints {
  static const String v1 = '/v1';
  static String commodities() => '$v1/market/commodities';
  static String products() => '$v1/market/products';
  static String productById(String id) => '$v1/market/products/$id';
  static String buyersNearby() => '$v1/geo/buyers/nearby';
  static String chatThreads() => '$v1/chat/threads';
  static String authLogin() => '$v1/auth/login';
  static String authRegister() => '$v1/auth/register';
}
