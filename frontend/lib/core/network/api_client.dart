import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

class ApiConfig {
  ApiConfig._();
  // In production: flutter build web --dart-define=BACKEND_URL=https://your-backend.onrender.com
  static const String _backend = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://bogi-api-465312640914.asia-south1.run.app',
  );
  static const String baseUrl = _backend;
  static const String propertiesBaseUrl = _backend;
  static const String tenantsBaseUrl = _backend;
  static const String accountingBaseUrl = _backend;
  static const String maintenanceBaseUrl = _backend;
  static const String reportsBaseUrl = _backend;
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
        // Do not set Content-Type globally — Dio sets it per-request
        // (JSON for regular calls, multipart/form-data with boundary for uploads)
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
