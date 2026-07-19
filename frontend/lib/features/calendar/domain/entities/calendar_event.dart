enum EventType { inspection, paymentDue, leaseRenewal, maintenance, meeting }

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.eventType,
    required this.startAt,
    this.endAt,
    this.description,
    this.allDay = false,
    this.leasingUnitId,
    this.tenantId,
  });

  final String id;
  final String title;
  final EventType eventType;
  final DateTime startAt;
  final DateTime? endAt;
  final String? description;
  final bool allDay;
  final String? leasingUnitId;
  final String? tenantId;

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        eventType: _parseType(j['event_type'] as String? ?? ''),
        startAt: DateTime.parse(j['start_at'] as String),
        endAt: j['end_at'] != null
            ? DateTime.tryParse(j['end_at'] as String)
            : null,
        description: j['description'] as String?,
        allDay: (j['all_day'] as bool?) ?? false,
        leasingUnitId: j['leasing_unit_id'] as String?,
        tenantId: j['tenant_id'] as String?,
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'description': description,
        'event_type': _typeKey(eventType),
        'start_at': startAt.toIso8601String(),
        if (endAt != null) 'end_at': endAt!.toIso8601String(),
        'all_day': allDay,
        if (leasingUnitId != null) 'leasing_unit_id': leasingUnitId,
        if (tenantId != null) 'tenant_id': tenantId,
      };

  static EventType _parseType(String s) => switch (s) {
        'inspection' => EventType.inspection,
        'payment_due' => EventType.paymentDue,
        'lease_renewal' => EventType.leaseRenewal,
        'maintenance' => EventType.maintenance,
        _ => EventType.meeting,
      };

  static String _typeKey(EventType t) => switch (t) {
        EventType.inspection => 'inspection',
        EventType.paymentDue => 'payment_due',
        EventType.leaseRenewal => 'lease_renewal',
        EventType.maintenance => 'maintenance',
        EventType.meeting => 'meeting',
      };
}
