import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/tenant.dart';

class TenantRepository {
  TenantRepository({Dio? dio}) : _dio = dio ?? ApiClient.tenants;

  final Dio _dio;

  Future<List<Tenant>> listTenants({String? propertyId}) async {
    final queryParams = <String, dynamic>{
      if (propertyId != null) 'property_id': propertyId,
    };
    final response = await _dio.get(
      '/api/v1/tenants',
      queryParameters: queryParams,
    );
    final data = response.data as List? ?? [];
    return data
        .map((e) => Tenant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Tenant> getTenant(String id) async {
    final response = await _dio.get('/api/v1/tenants/$id');
    return Tenant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Tenant> createTenant(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/tenants', data: data);
    return Tenant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Lease?> getTenantLease(String tenantId) async {
    final response = await _dio.get('/api/v1/tenants/$tenantId/lease');
    if (response.data == null) return null;
    return Lease.fromJson(response.data as Map<String, dynamic>);
  }
}
