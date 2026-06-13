import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/maintenance_request.dart';

class MaintenanceRepository {
  final Dio _dio = ApiClient.maintenance;

  Future<List<MaintenanceRequest>> getAll({
    String? status,
    String? priority,
    String? leasingUnitId,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (priority != null) params['priority'] = priority;
    if (leasingUnitId != null) params['leasing_unit_id'] = leasingUnitId;

    final resp = await _dio.get(
      '/api/v1/maintenance/',
      queryParameters: params.isEmpty ? null : params,
    );
    final list = (resp.data as List?) ?? [];
    return list.map((e) => MaintenanceRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MaintenanceRequest> create(Map<String, dynamic> data) async {
    final resp = await _dio.post('/api/v1/maintenance/', data: data);
    return MaintenanceRequest.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Updates only the status by sending the existing request fields with new status.
  Future<MaintenanceRequest> updateStatus(MaintenanceRequest req, String newStatus) async {
    final body = req.toJson()..['status'] = newStatus;
    final resp = await _dio.put('/api/v1/maintenance/${req.id}', data: body);
    return MaintenanceRequest.fromJson(resp.data as Map<String, dynamic>);
  }
}
