import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_client.dart';

class TenantRepository {
  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  Dio get _dio => ApiClient.instance;

  Map<String, dynamic> get _qp => {'user_id': _userId};

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/api/v1/tenant/me', queryParameters: _qp);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyUnit() async {
    final res = await _dio.get('/api/v1/tenant/my-unit', queryParameters: _qp);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getMyLease() async {
    try {
      final res =
          await _dio.get('/api/v1/tenant/my-lease', queryParameters: _qp);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMyInvoices() async {
    final res =
        await _dio.get('/api/v1/tenant/my-invoices', queryParameters: _qp);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getMyMaintenance() async {
    final res =
        await _dio.get('/api/v1/tenant/my-maintenance', queryParameters: _qp);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createMaintenance(
      Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/api/v1/tenant/my-maintenance',
      queryParameters: _qp,
      data: data,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyQueries() async {
    final res =
        await _dio.get('/api/v1/tenant/my-queries', queryParameters: _qp);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createQuery(Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/api/v1/tenant/my-queries',
      queryParameters: _qp,
      data: data,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> replyToQuery(
      String queryId, String body) async {
    final res = await _dio.post(
      '/api/v1/tenant/my-queries/$queryId/reply',
      queryParameters: {..._qp, 'body': body},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getServiceCatalog(
      String? category) async {
    final params = <String, dynamic>{};
    if (category != null) params['category'] = category;
    final res = await _dio.get('/api/v1/service-catalog/', queryParameters: params);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createServiceRequest(
      Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/api/v1/service-requests/',
      queryParameters: _qp,
      data: data,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyServiceRequests() async {
    final res = await _dio.get(
      '/api/v1/service-requests/my',
      queryParameters: _qp,
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, String>> createCheckoutSession({
    required String transactionId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    final res = await _dio.post(
      '/api/v1/payments/checkout',
      queryParameters: _qp,
      data: {
        'transaction_id': transactionId,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
      },
    );
    final data = res.data as Map<String, dynamic>;
    return {'url': data['url'] as String, 'session_id': data['session_id'] as String};
  }
}
