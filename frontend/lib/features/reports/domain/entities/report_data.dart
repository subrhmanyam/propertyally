class OccupancyReport {
  const OccupancyReport({
    required this.totalUnits,
    required this.occupied,
    required this.vacant,
    required this.inHouse,
    required this.ownerOccupied,
    required this.occupancyRate,
    required this.byCategory,
    required this.byFloor,
  });

  final int totalUnits;
  final int occupied;
  final int vacant;
  final int inHouse;
  final int ownerOccupied;
  final double occupancyRate;
  final List<OccupancyBreakdown> byCategory;
  final List<OccupancyBreakdown> byFloor;

  factory OccupancyReport.fromJson(Map<String, dynamic> j) => OccupancyReport(
        totalUnits: (j['total_units'] as num).toInt(),
        occupied: (j['occupied'] as num).toInt(),
        vacant: (j['vacant'] as num).toInt(),
        inHouse: (j['in_house'] as num).toInt(),
        ownerOccupied: (j['owner_occupied'] as num).toInt(),
        occupancyRate: (j['occupancy_rate'] as num).toDouble(),
        byCategory: (j['by_category'] as List? ?? [])
            .map((e) => OccupancyBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
        byFloor: (j['by_floor'] as List? ?? [])
            .map((e) => OccupancyBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OccupancyBreakdown {
  const OccupancyBreakdown({
    required this.label,
    required this.total,
    required this.occupied,
    required this.vacant,
    this.occupancyRate,
  });

  final String label;
  final int total;
  final int occupied;
  final int vacant;
  final double? occupancyRate;

  factory OccupancyBreakdown.fromJson(Map<String, dynamic> j) => OccupancyBreakdown(
        label: (j['category'] ?? j['floor'] ?? '') as String,
        total: (j['total'] as num).toInt(),
        occupied: (j['occupied'] as num).toInt(),
        vacant: (j['vacant'] as num).toInt(),
        occupancyRate: j['occupancy_rate'] != null ? (j['occupancy_rate'] as num).toDouble() : null,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class CashFlowReport {
  const CashFlowReport({
    required this.totalIncome,
    required this.totalExpenses,
    required this.net,
    required this.months,
  });

  final double totalIncome;
  final double totalExpenses;
  final double net;
  final List<MonthlyFlow> months;

  factory CashFlowReport.fromJson(Map<String, dynamic> j) => CashFlowReport(
        totalIncome: (j['total_income'] as num).toDouble(),
        totalExpenses: (j['total_expenses'] as num).toDouble(),
        net: (j['net'] as num).toDouble(),
        months: (j['months'] as List? ?? [])
            .map((e) => MonthlyFlow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MonthlyFlow {
  const MonthlyFlow({
    required this.month,
    required this.label,
    required this.income,
    required this.expenses,
    required this.net,
  });

  final String month;
  final String label;
  final double income;
  final double expenses;
  final double net;

  factory MonthlyFlow.fromJson(Map<String, dynamic> j) => MonthlyFlow(
        month: j['month'] as String,
        label: j['label'] as String,
        income: (j['income'] as num).toDouble(),
        expenses: (j['expenses'] as num).toDouble(),
        net: (j['net'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class RentCollectionReport {
  const RentCollectionReport({
    required this.period,
    required this.collected,
    required this.pending,
    required this.overdue,
    required this.total,
    required this.collectionRate,
    required this.byUnit,
  });

  final String period;
  final double collected;
  final double pending;
  final double overdue;
  final double total;
  final double collectionRate;
  final List<UnitRentSummary> byUnit;

  factory RentCollectionReport.fromJson(Map<String, dynamic> j) => RentCollectionReport(
        period: j['period'] as String,
        collected: (j['collected'] as num).toDouble(),
        pending: (j['pending'] as num).toDouble(),
        overdue: (j['overdue'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
        collectionRate: (j['collection_rate'] as num).toDouble(),
        byUnit: (j['by_unit'] as List? ?? [])
            .map((e) => UnitRentSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class UnitRentSummary {
  const UnitRentSummary({
    required this.unitId,
    required this.unitName,
    required this.collected,
    required this.pending,
    required this.overdue,
  });

  final String unitId;
  final String unitName;
  final double collected;
  final double pending;
  final double overdue;

  factory UnitRentSummary.fromJson(Map<String, dynamic> j) => UnitRentSummary(
        unitId: j['unit_id'] as String,
        unitName: j['unit_name'] as String,
        collected: (j['collected'] as num).toDouble(),
        pending: (j['pending'] as num).toDouble(),
        overdue: (j['overdue'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class MaintenanceCostReport {
  const MaintenanceCostReport({
    required this.totalRequests,
    required this.totalActualCost,
    required this.totalEstimatedCost,
    required this.byStatus,
    required this.byCategory,
    required this.byMonth,
    required this.byUnit,
  });

  final int totalRequests;
  final double totalActualCost;
  final double totalEstimatedCost;
  final Map<String, int> byStatus;
  final List<CategoryCost> byCategory;
  final List<MonthCost> byMonth;
  final List<UnitCost> byUnit;

  factory MaintenanceCostReport.fromJson(Map<String, dynamic> j) => MaintenanceCostReport(
        totalRequests: (j['total_requests'] as num).toInt(),
        totalActualCost: (j['total_actual_cost'] as num).toDouble(),
        totalEstimatedCost: (j['total_estimated_cost'] as num).toDouble(),
        byStatus: Map<String, int>.from(
            (j['by_status'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt()))),
        byCategory: (j['by_category'] as List? ?? [])
            .map((e) => CategoryCost.fromJson(e as Map<String, dynamic>))
            .toList(),
        byMonth: (j['by_month'] as List? ?? [])
            .map((e) => MonthCost.fromJson(e as Map<String, dynamic>))
            .toList(),
        byUnit: (j['by_unit'] as List? ?? [])
            .map((e) => UnitCost.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CategoryCost {
  const CategoryCost({required this.category, required this.count, required this.actualCost});
  final String category;
  final int count;
  final double actualCost;
  factory CategoryCost.fromJson(Map<String, dynamic> j) => CategoryCost(
        category: j['category'] as String,
        count: (j['count'] as num).toInt(),
        actualCost: (j['actual_cost'] as num).toDouble(),
      );
}

class MonthCost {
  const MonthCost({required this.month, required this.label, required this.cost});
  final String month;
  final String label;
  final double cost;
  factory MonthCost.fromJson(Map<String, dynamic> j) => MonthCost(
        month: j['month'] as String,
        label: j['label'] as String,
        cost: (j['cost'] as num).toDouble(),
      );
}

class UnitCost {
  const UnitCost({required this.unitId, required this.unitName, required this.count, required this.actualCost});
  final String unitId;
  final String unitName;
  final int count;
  final double actualCost;
  factory UnitCost.fromJson(Map<String, dynamic> j) => UnitCost(
        unitId: j['unit_id'] as String,
        unitName: j['unit_name'] as String,
        count: (j['count'] as num).toInt(),
        actualCost: (j['actual_cost'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class ProfitLossReport {
  const ProfitLossReport({
    required this.periodStart,
    required this.periodEnd,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netProfit,
    required this.profitMargin,
    required this.byMonth,
    required this.byUnit,
  });

  final String periodStart;
  final String periodEnd;
  final double totalIncome;
  final double totalExpenses;
  final double netProfit;
  final double profitMargin;
  final List<MonthlyFlow> byMonth;
  final List<UnitPL> byUnit;

  factory ProfitLossReport.fromJson(Map<String, dynamic> j) => ProfitLossReport(
        periodStart: j['period_start'] as String,
        periodEnd: j['period_end'] as String,
        totalIncome: (j['total_income'] as num).toDouble(),
        totalExpenses: (j['total_expenses'] as num).toDouble(),
        netProfit: (j['net_profit'] as num).toDouble(),
        profitMargin: (j['profit_margin'] as num).toDouble(),
        byMonth: (j['by_month'] as List? ?? [])
            .map((e) => MonthlyFlow.fromJson(e as Map<String, dynamic>))
            .toList(),
        byUnit: (j['by_unit'] as List? ?? [])
            .map((e) => UnitPL.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class UnitPL {
  const UnitPL({
    required this.unitId,
    required this.unitName,
    required this.income,
    required this.expenses,
    required this.netProfit,
  });

  final String unitId;
  final String unitName;
  final double income;
  final double expenses;
  final double netProfit;

  factory UnitPL.fromJson(Map<String, dynamic> j) => UnitPL(
        unitId: j['unit_id'] as String,
        unitName: j['unit_name'] as String,
        income: (j['income'] as num).toDouble(),
        expenses: (j['expenses'] as num).toDouble(),
        netProfit: (j['net_profit'] as num).toDouble(),
      );
}
