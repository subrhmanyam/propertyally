class Lease {
  const Lease({
    required this.id,
    required this.tenantId,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.status,
    this.depositAmount = 0,
  });

  final String id;
  final String tenantId;
  final DateTime startDate;
  final DateTime endDate;
  final double monthlyRent;
  final String status; // 'active', 'expired', 'pending'
  final double depositAmount;

  factory Lease.fromJson(Map<String, dynamic> json) => Lease(
        id: json['id']?.toString() ?? '',
        tenantId: json['tenant_id']?.toString() ?? '',
        startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ??
            DateTime.now(),
        endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ??
            DateTime.now().add(const Duration(days: 365)),
        monthlyRent: (json['monthly_rent'] as num?)?.toDouble() ?? 0.0,
        status: json['status']?.toString() ?? 'active',
        depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'monthly_rent': monthlyRent,
        'status': status,
        'deposit_amount': depositAmount,
      };

  static Lease mock(String tenantId, int index) => Lease(
        id: 'lease_$index',
        tenantId: tenantId,
        startDate: DateTime(2023, 1 + index % 12, 1),
        endDate: DateTime(2024, 1 + index % 12, 1),
        monthlyRent: 1200.0 + index * 100,
        status: index % 5 == 0 ? 'expired' : 'active',
        depositAmount: (1200.0 + index * 100) * 2,
      );
}

class Tenant {
  const Tenant({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.status,
    this.unitId,
    this.propertyId,
    this.companyName,
    this.floor,
    this.moveInDate,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String status; // 'active', 'inactive', 'pending'
  final String? unitId;
  final String? propertyId;
  final String? companyName;
  final String? floor;
  final DateTime? moveInDate;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  String get fullName => '$firstName $lastName';

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id']?.toString() ?? '',
        firstName: json['first_name']?.toString() ?? '',
        lastName: json['last_name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        status: json['status']?.toString() ?? 'active',
        unitId: json['leasing_unit_id']?.toString(),
        propertyId: json['leasing_unit_id']?.toString(),
        companyName: json['company_name']?.toString(),
        floor: json['floor']?.toString(),
        moveInDate:
            DateTime.tryParse(json['move_in_date']?.toString() ?? ''),
        emergencyContactName: json['emergency_contact_name']?.toString(),
        emergencyContactPhone: json['emergency_contact_phone']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'status': status,
        if (unitId != null) 'leasing_unit_id': unitId,
        if (moveInDate != null) 'move_in_date': moveInDate!.toIso8601String(),
        if (emergencyContactName != null)
          'emergency_contact_name': emergencyContactName,
        if (emergencyContactPhone != null)
          'emergency_contact_phone': emergencyContactPhone,
      };

  static final List<Tenant> mockList = List.generate(10, (i) => Tenant(
        id: 'tenant_$i',
        firstName: ['John', 'Jane', 'Mike', 'Sarah', 'Chris', 'Lisa', 'Tom', 'Amy', 'Bob', 'Emma'][i],
        lastName: ['Smith', 'Doe', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Martinez', 'Lee', 'Wilson'][i],
        email: 'tenant$i@example.com',
        phone: '555-01${i.toString().padLeft(2, '0')}',
        status: i % 4 == 0 ? 'pending' : 'active',
        unitId: 'unit_$i',
        propertyId: 'prop_${i % 6}',
        moveInDate: DateTime(2022, 1 + i % 12, 1),
        emergencyContactName: 'Emergency Contact $i',
        emergencyContactPhone: '555-99${i.toString().padLeft(2, '0')}',
      ));
}
