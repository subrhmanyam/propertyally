enum TransactionType { income, expense }

enum TransactionStatus { paid, pending, overdue }

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    required this.description,
    required this.status,
    this.propertyId,
    this.propertyName,
    this.tenantId,
    this.tenantName,
    this.leaseId,
    this.referenceNo,
    this.notes,
  });

  final String id;
  final TransactionType type;
  final String category;
  final double amount;
  final DateTime date;
  final String description;
  final TransactionStatus status;
  final String? propertyId;
  final String? propertyName;
  final String? tenantId;
  final String? tenantName;
  final String? leaseId;
  final String? referenceNo;
  final String? notes;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id']?.toString() ?? '',
        type: json['type'] == 'income'
            ? TransactionType.income
            : TransactionType.expense,
        category: json['category']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        date:
            DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        description: json['description']?.toString() ?? '',
        status: _parseStatus(json['status']?.toString()),
        // DB column is leasing_unit_id; legacy mock used property_id
        propertyId:
            (json['leasing_unit_id'] ?? json['property_id'])?.toString(),
        propertyName: json['property_name']?.toString(),
        tenantId: json['tenant_id']?.toString(),
        tenantName: json['tenant_name']?.toString(),
        leaseId: json['lease_id']?.toString(),
        referenceNo: json['reference_no']?.toString(),
        notes: json['notes']?.toString(),
      );

  static TransactionStatus _parseStatus(String? s) => switch (s) {
        'pending' => TransactionStatus.pending,
        'overdue' => TransactionStatus.overdue,
        _ => TransactionStatus.paid,
      };
}
