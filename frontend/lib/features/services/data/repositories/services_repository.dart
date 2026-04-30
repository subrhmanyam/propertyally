import 'package:dio/dio.dart';

class ServicesRepository {
  static const _base = 'http://localhost:8000';
  final Dio _dio = Dio(BaseOptions(baseUrl: _base));

  Future<List<Map<String, dynamic>>> listRequests({
    String? status,
    String? unitId,
  }) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (unitId != null) params['unit_id'] = unitId;
    final res = await _dio.get('/api/v1/service-requests/', queryParameters: params);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getCatalog({String? category}) async {
    final params = <String, dynamic>{};
    if (category != null) params['category'] = category;
    final res = await _dio.get('/api/v1/service-catalog/', queryParameters: params);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getUnits() async {
    final res = await _dio.get('/api/v1/leasing/');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createAdminRequest({
    required String leasingUnitId,
    String? serviceId,
    String? serviceName,
    String? description,
    String priority = 'normal',
  }) async {
    final res = await _dio.post('/api/v1/service-requests/admin', data: {
      'leasing_unit_id': leasingUnitId,
      if (serviceId != null) 'service_id': serviceId,
      if (serviceName != null) 'service_name': serviceName,
      if (description != null && description.isNotEmpty) 'description': description,
      'priority': priority,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRequest(
      String id, Map<String, dynamic> updates) async {
    final res = await _dio.patch('/api/v1/service-requests/$id', data: updates);
    return res.data as Map<String, dynamic>;
  }
}
