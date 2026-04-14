import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

class ApiConfig {
  ApiConfig._();
  static const String baseUrl = 'http://localhost';
  static const String propertiesBaseUrl = 'http://localhost:8002';
  static const String tenantsBaseUrl = 'http://localhost:8002';
  static const String accountingBaseUrl = 'http://localhost:8002';
  static const String maintenanceBaseUrl = 'http://localhost:8002';
  static const String reportsBaseUrl = 'http://localhost:8002';
}

class ApiClient {
  ApiClient._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Dio _buildDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.addAll([
      AuthInterceptor(storage: _storage, dio: dio),
      ErrorInterceptor(),
      LogInterceptor(requestBody: false, responseBody: false),
    ]);
    return dio;
  }

  static final Dio properties = _buildDio(ApiConfig.propertiesBaseUrl);
  static final Dio tenants = _buildDio(ApiConfig.tenantsBaseUrl);
  static final Dio accounting = _buildDio(ApiConfig.accountingBaseUrl);
  static final Dio maintenance = _buildDio(ApiConfig.maintenanceBaseUrl);
  static final Dio reports = _buildDio(ApiConfig.reportsBaseUrl);

  /// Generic instance for ad-hoc usage.
  static final Dio instance = _buildDio(ApiConfig.baseUrl);
}
