import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.storage, required this.dio});

  final FlutterSecureStorage storage;
  final Dio dio;

  static const _tokenKey = 'auth_token';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await storage.delete(key: _tokenKey);
      // Redirect to login — using GoRouter would require a NavigatorKey;
      // for now we let the ErrorInterceptor surface this as UnauthorizedException.
    }
    handler.next(err);
  }
}
