enum MaintPriority { low, medium, high, urgent }

enum MaintStatus { open, inProgress, onHold, completed, cancelled }

class MaintenanceRequest {
  const MaintenanceRequest({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.description,
    this.category,
    this.leasingUnitId,
    this.tenantId,
    this.assignedTo,
    this.estimatedCost,
    this.actualCost,
    this.scheduledDate,
    this.completedDate,
    this.notes,
    this.photos = const [],
  });

  final String id;
  final String title;
  final MaintPriority priority;
  final MaintStatus status;
  final DateTime createdAt;
  final String? description;
  final String? category;
  final String? leasingUnitId;
  final String? tenantId;
  final String? assignedTo;
  final double? estimatedCost;
  final double? actualCost;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final String? notes;
  final List<String> photos;

  factory MaintenanceRequest.fromJson(Map<String, dynamic> json) =>
      MaintenanceRequest(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        priority: _parsePriority(json['priority']?.toString()),
        status: _parseStatus(json['status']?.toString()),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        description: json['description']?.toString(),
        category: json['category']?.toString(),
        leasingUnitId: json['leasing_unit_id']?.toString(),
        tenantId: json['tenant_id']?.toString(),
        assignedTo: json['assigned_to']?.toString(),
        estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
        actualCost: (json['actual_cost'] as num?)?.toDouble(),
        scheduledDate: json['scheduled_date'] != null
            ? DateTime.tryParse(json['scheduled_date'].toString())
            : null,
        completedDate: json['completed_date'] != null
            ? DateTime.tryParse(json['completed_date'].toString())
            : null,
        notes: json['notes']?.toString(),
        photos: (json['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );

  static MaintPriority _parsePriority(String? s) => switch (s) {
        'low' => MaintPriority.low,
        'high' => MaintPriority.high,
        'urgent' => MaintPriority.urgent,
        _ => MaintPriority.medium,
      };

  static MaintStatus _parseStatus(String? s) => switch (s) {
        'in_progress' => MaintStatus.inProgress,
        'on_hold' => MaintStatus.onHold,
        'completed' => MaintStatus.completed,
        'cancelled' => MaintStatus.cancelled,
        _ => MaintStatus.open,
      };

  Map<String, dynamic> toJson() => {
        'title': title,
        'priority': priority.name,
        'status': _statusToApi(status),
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (leasingUnitId != null) 'leasing_unit_id': leasingUnitId,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (estimatedCost != null) 'estimated_cost': estimatedCost,
        if (notes != null) 'notes': notes,
      };

  static String _statusToApi(MaintStatus s) => switch (s) {
        MaintStatus.inProgress => 'in_progress',
        MaintStatus.onHold => 'on_hold',
        MaintStatus.completed => 'completed',
        MaintStatus.cancelled => 'cancelled',
        MaintStatus.open => 'open',
      };
}
