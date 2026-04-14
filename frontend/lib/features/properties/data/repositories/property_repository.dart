import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/property.dart';

class PropertyRepository {
  PropertyRepository({Dio? dio}) : _dio = dio ?? ApiClient.properties;

  final Dio _dio;

  Future<List<Property>> listProperties() async {
    final response = await _dio.get('/api/v1/properties');
    final data = response.data as List? ?? [];
    return data
        .map((e) => Property.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Property> getProperty(String id) async {
    final response = await _dio.get('/api/v1/properties/$id');
    return Property.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Property> createProperty(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/properties', data: data);
    return Property.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Unit> updateUnitStatus(
    String propertyId,
    String unitId,
    String status,
  ) async {
    final response = await _dio.patch(
      '/api/v1/properties/$propertyId/units/$unitId/status',
      data: {'status': status},
    );
    return Unit.fromJson(response.data as Map<String, dynamic>);
  }
}
