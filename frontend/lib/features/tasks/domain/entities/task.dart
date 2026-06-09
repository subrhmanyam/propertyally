class Task {
  const Task({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    this.description,
    this.propertyId,
    this.leasingUnitId,
    this.assignedTo,
    this.dueDate,
    this.recurringRule,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? propertyId;
  final String? leasingUnitId;
  final String? assignedTo;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final String? recurringRule;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      propertyId: json['property_id']?.toString(),
      leasingUnitId: json['leasing_unit_id']?.toString(),
      assignedTo: json['assigned_to']?.toString(),
      priority: json['priority']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? 'open',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      recurringRule: json['recurring_rule']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
