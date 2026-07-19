import 'package:flutter/foundation.dart';
import '../../data/repositories/tasks_repository.dart';
import '../../domain/entities/task.dart';

class TasksProvider extends ChangeNotifier {
  TasksProvider({TasksRepository? repository})
      : _repository = repository ?? TasksRepository();

  final TasksRepository _repository;

  List<Task> tasks = [];
  List<Map<String, dynamic>> units = [];
  bool isLoading = false;
  String _statusFilter = 'all';

  String get statusFilter => _statusFilter;
  List<Task> get filtered => _statusFilter == 'all'
      ? tasks
      : tasks.where((t) => t.status == _statusFilter).toList();

  void setFilter(String filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      tasks = await _repository.listTasks();
      units = await _repository.getUnits();
    } catch (_) {
      tasks = [];
      units = [];
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> createTask({
    required String title,
    String? description,
    String? propertyId,
    String? leasingUnitId,
    String? assignedTo,
    String priority = 'medium',
    String status = 'open',
    String? dueDate,
    String? recurringRule,
  }) async {
    final newTask = await _repository.createTask({
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (propertyId != null) 'property_id': propertyId,
      if (leasingUnitId != null) 'leasing_unit_id': leasingUnitId,
      if (assignedTo != null) 'assigned_to': assignedTo,
      'priority': priority,
      'status': status,
      if (dueDate != null) 'due_date': dueDate,
      if (recurringRule != null && recurringRule.isNotEmpty)
        'recurring_rule': recurringRule,
    });
    tasks = [newTask, ...tasks];
    notifyListeners();
  }

  Future<void> updateTaskStatus(String id, String status) async {
    final updated = await _repository.updateTask(id, {'status': status});
    final index = tasks.indexWhere((task) => task.id == id);
    if (index != -1) {
      tasks[index] = updated;
      notifyListeners();
    }
  }
}
