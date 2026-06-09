import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/task.dart';

class TasksRepository {
  TasksRepository() : _dio = ApiClient.instance;

  final Dio _dio;

  Future<List<Task>> listTasks({String? propertyId, String? status}) async {
    final params = <String, dynamic>{
      if (propertyId != null) 'property_id': propertyId,
      if (status != null) 'status': status,
    };
    final res = await _dio.get('/api/v1/tasks/', queryParameters: params);
    return (res.data as List)
        .cast<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getUnits() async {
    final res = await _dio.get('/api/v1/leasing/');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Task> createTask(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/v1/tasks/', data: data);
    return Task.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Task> updateTask(String id, Map<String, dynamic> updates) async {
    final res = await _dio.patch('/api/v1/tasks/$id', data: updates);
    return Task.fromJson(res.data as Map<String, dynamic>);
  }
}
