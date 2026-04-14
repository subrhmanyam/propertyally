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
  final String? notes;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id']?.toString() ?? '',
        type: json['type'] == 'income'
            ? TransactionType.income
            : TransactionType.expense,
        category: json['category']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        description: json['description']?.toString() ?? '',
        status: _parseStatus(json['status']?.toString()),
        propertyId: json['property_id']?.toString(),
        propertyName: json['property_name']?.toString(),
        tenantId: json['tenant_id']?.toString(),
        tenantName: json['tenant_name']?.toString(),
        notes: json['notes']?.toString(),
      );

  static TransactionStatus _parseStatus(String? s) => switch (s) {
        'pending' => TransactionStatus.pending,
        'overdue' => TransactionStatus.overdue,
        _ => TransactionStatus.paid,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'description': description,
        'status': status.name,
        if (propertyId != null) 'property_id': propertyId,
        if (propertyName != null) 'property_name': propertyName,
        if (tenantId != null) 'tenant_id': tenantId,
        if (tenantName != null) 'tenant_name': tenantName,
        if (notes != null) 'notes': notes,
      };

  // ── Mock data ────────────────────────────────────────────────────────
  static final List<Transaction> mockList = _buildMockList();

  static List<Transaction> _buildMockList() {
    final now = DateTime.now();
    final txns = <Transaction>[];

    final tenantNames = [
      'John Smith', 'Jane Doe', 'Mike Johnson', 'Sarah Williams',
      'Chris Brown', 'Lisa Jones', 'Tom Garcia', 'Amy Martinez',
    ];
    final propertyNames = [
      'Oakwood Apartments', 'River View Condos', 'Sunset Villas',
      'Downtown Lofts', 'Park Place', 'Harbor Heights',
    ];

    // Generate 3 months of transactions
    int id = 0;
    for (int monthOffset = 0; monthOffset < 3; monthOffset++) {
      final month = DateTime(now.year, now.month - monthOffset, 1);

      // Rent income — one per tenant per month
      for (int t = 0; t < tenantNames.length; t++) {
        final rent = 1200.0 + t * 150.0;
        final day = 1 + (t % 5);
        final isOverdue = monthOffset == 0 && t >= 6;
        final isPending = monthOffset == 0 && t == 5;
        txns.add(Transaction(
          id: 'txn_${id++}',
          type: TransactionType.income,
          category: 'Rent',
          amount: rent,
          date: DateTime(month.year, month.month, day),
          description: 'Monthly Rent — ${tenantNames[t]}',
          status: isOverdue
              ? TransactionStatus.overdue
              : isPending
                  ? TransactionStatus.pending
                  : TransactionStatus.paid,
          propertyId: 'prop_${t % 6}',
          propertyName: propertyNames[t % 6],
          tenantId: 'tenant_$t',
          tenantName: tenantNames[t],
        ));
      }

      // Expenses
      final expenses = [
        ('Maintenance', 'Plumbing repair — Unit 4B', 285.0, 'prop_0', propertyNames[0]),
        ('Insurance', 'Property insurance premium', 420.0, 'prop_1', propertyNames[1]),
        ('Utilities', 'Common area electricity', 310.0, 'prop_2', propertyNames[2]),
        ('Maintenance', 'HVAC service — annual', 650.0, 'prop_0', propertyNames[0]),
        ('Management Fee', 'Property management fee (8%)', 880.0, 'prop_3', propertyNames[3]),
        ('Landscaping', 'Monthly grounds keeping', 175.0, 'prop_4', propertyNames[4]),
        ('Taxes', 'Property tax installment', 1200.0, 'prop_5', propertyNames[5]),
      ];

      for (int e = 0; e < expenses.length; e++) {
        final (cat, desc, amt, pId, pName) = expenses[e];
        txns.add(Transaction(
          id: 'txn_${id++}',
          type: TransactionType.expense,
          category: cat,
          amount: amt,
          date: DateTime(month.year, month.month, 5 + e * 3),
          description: desc,
          status: TransactionStatus.paid,
          propertyId: pId,
          propertyName: pName,
        ));
      }
    }

    // Sort newest first
    txns.sort((a, b) => b.date.compareTo(a.date));
    return txns;
  }
}
