import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

class ServicesRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<Map<String, dynamic>>> listRequests({
    String? status,
    String? unitId,
  }) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (unitId != null) params['unit_id'] = unitId;
    final res =
        await _dio.get('/api/v1/service-requests/', queryParameters: params);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getCatalog({String? category}) async {
    final params = <String, dynamic>{};
    if (category != null) params['category'] = category;
    final res =
        await _dio.get('/api/v1/service-catalog/', queryParameters: params);
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
    String? expensesBorneBy,
    double? estimatedCost,
    DateTime? initiatedDate,
  }) async {
    final res = await _dio.post('/api/v1/service-requests/admin', data: {
      'leasing_unit_id': leasingUnitId,
      if (serviceId != null) 'service_id': serviceId,
      if (serviceName != null) 'service_name': serviceName,
      if (description != null && description.isNotEmpty)
        'description': description,
      'priority': priority,
      if (expensesBorneBy != null) 'expenses_borne_by': expensesBorneBy,
      if (estimatedCost != null) 'estimated_cost': estimatedCost,
      if (initiatedDate != null)
        'initiated_date': initiatedDate.toIso8601String(),
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRequest(
      String id, Map<String, dynamic> updates) async {
    final res = await _dio.patch('/api/v1/service-requests/$id', data: updates);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadDocument(
      String requestId, Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post(
      '/api/v1/service-requests/$requestId/documents',
      data: formData,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteDocument(String requestId, String documentId) async {
    await _dio
        .delete('/api/v1/service-requests/$requestId/documents/$documentId');
  }
}
