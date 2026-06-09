import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/entities/report_data.dart';
import '../providers/reports_provider.dart';

final _inr = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportsProvider()..loadAll(),
      child: const _ReportsBody(),
    );
  }
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, p, _) {
        return Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text('Reports',
                      style: TextStyle(
                          fontSize: AppDimensions.fontH2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => p.refresh(),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceLG),

              // Tab bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in [
                      (ReportTab.occupancy, Icons.domain_rounded, 'Occupancy'),
                      (ReportTab.cashFlow, Icons.trending_up_rounded, 'Cash Flow'),
                      (ReportTab.rentCollection, Icons.receipt_long_rounded, 'Rent'),
                      (ReportTab.maintenanceCosts, Icons.build_rounded, 'Maintenance'),
                      (ReportTab.profitLoss, Icons.bar_chart_rounded, 'P&L'),
                    ])
                      _TabChip(
                        icon: entry.$2,
                        label: entry.$3,
                        selected: p.activeTab == entry.$1,
                        onTap: () => p.selectTab(entry.$1),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLG),

              if (p.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
                )
              else if (p.hasError)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 36),
                        const SizedBox(height: 12),
                        Text(p.errorMessage ?? 'Error loading report',
                            style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: p.refresh, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: switch (p.activeTab) {
                      ReportTab.occupancy => p.occupancy == null
                          ? const SizedBox.shrink()
                          : _OccupancyTab(report: p.occupancy!),
                      ReportTab.cashFlow => p.cashFlow == null
                          ? const SizedBox.shrink()
                          : _CashFlowTab(report: p.cashFlow!),
                      ReportTab.rentCollection => p.rentCollection == null
                          ? const SizedBox.shrink()
                          : _RentCollectionTab(report: p.rentCollection!),
                      ReportTab.maintenanceCosts => p.maintenanceCosts == null
                          ? const SizedBox.shrink()
                          : _MaintenanceCostTab(report: p.maintenanceCosts!),
                      ReportTab.profitLoss => p.profitLoss == null
                          ? const SizedBox.shrink()
                          : _ProfitLossTab(report: p.profitLoss!),
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab chip ─────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentGold : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accentGold : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? AppColors.bgOuter : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.bgOuter : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── KPI card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0)),
      );
}

// ── 1. Occupancy ──────────────────────────────────────────────────────────────

class _OccupancyTab extends StatelessWidget {
  const _OccupancyTab({required this.report});
  final OccupancyReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI row
        LayoutBuilder(builder: (_, c) {
          final wide = c.maxWidth > 500;
          final cards = [
            _KpiCard(
              label: 'Total Units',
              value: '${report.totalUnits}',
              icon: Icons.domain_rounded,
            ),
            _KpiCard(
              label: 'Occupied',
              value: '${report.occupied}',
              valueColor: AppColors.success,
              icon: Icons.check_circle_outline_rounded,
            ),
            _KpiCard(
              label: 'Vacant',
              value: '${report.vacant}',
              valueColor: AppColors.warning,
              icon: Icons.radio_button_unchecked_rounded,
            ),
            _KpiCard(
              label: 'Occupancy Rate',
              value: '${report.occupancyRate}%',
              valueColor: AppColors.accentGold,
              icon: Icons.percent_rounded,
            ),
          ];
          return wide
              ? Row(
                  children: cards
                      .map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c)))
                      .toList())
              : Column(
                  children: cards
                      .map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
                      .toList());
        }),
        const SizedBox(height: AppDimensions.spaceXL),

        // By category chart
        if (report.byCategory.isNotEmpty) ...[
          const _SectionHeader('By Category'),
          _HorizontalBarSection(
            items: report.byCategory
                .map((b) => _BarItem(b.label, b.occupied.toDouble(), b.total.toDouble()))
                .toList(),
          ),
          const SizedBox(height: AppDimensions.spaceXL),
        ],

        // By floor table
        if (report.byFloor.isNotEmpty) ...[
          const _SectionHeader('By Floor'),
          _SimpleTable(
            columns: const ['Floor', 'Total', 'Occupied', 'Vacant'],
            rows: report.byFloor
                .map((f) => [f.label, '${f.total}', '${f.occupied}', '${f.vacant}'])
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ── 2. Cash Flow ──────────────────────────────────────────────────────────────

class _CashFlowTab extends StatelessWidget {
  const _CashFlowTab({required this.report});
  final CashFlowReport report;

  @override
  Widget build(BuildContext context) {
    final maxVal = report.months.fold<double>(
        0,
        (m, e) => [m, e.income, e.expenses].reduce((a, b) => a > b ? a : b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (_, c) {
          final wide = c.maxWidth > 500;
          final cards = [
            _KpiCard(
              label: 'Total Income',
              value: _inr.format(report.totalIncome),
              valueColor: AppColors.success,
              icon: Icons.arrow_downward_rounded,
            ),
            _KpiCard(
              label: 'Total Expenses',
              value: _inr.format(report.totalExpenses),
              valueColor: AppColors.error,
              icon: Icons.arrow_upward_rounded,
            ),
            _KpiCard(
              label: 'Net Cash Flow',
              value: _inr.format(report.net),
              valueColor: report.net >= 0 ? AppColors.success : AppColors.error,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ];
          return wide
              ? Row(
                  children: cards
                      .map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c)))
                      .toList())
              : Column(
                  children: cards
                      .map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
                      .toList());
        }),
        const SizedBox(height: AppDimensions.spaceXL),

        const _SectionHeader('Monthly Income vs Expenses'),
        if (report.months.isNotEmpty && maxVal > 0)
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= report.months.length) return const SizedBox.shrink();
                        if (report.months.length > 6 && i % 2 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(report.months[i].label,
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textMuted)),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.border, strokeWidth: 0.5),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: report.months.asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(
                        toY: e.value.income, color: AppColors.success, width: 6, borderRadius: BorderRadius.circular(2)),
                    BarChartRodData(
                        toY: e.value.expenses, color: AppColors.error, width: 6, borderRadius: BorderRadius.circular(2)),
                  ]);
                }).toList(),
              ),
            ),
          )
        else
          const _EmptyChart(),

        const SizedBox(height: 8),
        Row(children: [
          _Legend(color: AppColors.success, label: 'Income'),
          const SizedBox(width: 16),
          _Legend(color: AppColors.error, label: 'Expenses'),
        ]),
        const SizedBox(height: AppDimensions.spaceXL),

        const _SectionHeader('Monthly Breakdown'),
        _SimpleTable(
          columns: const ['Month', 'Income', 'Expenses', 'Net'],
          rows: report.months.reversed.take(6).map((m) => [
            m.label,
            _inr.format(m.income),
            _inr.format(m.expenses),
            _inr.format(m.net),
          ]).toList(),
        ),
      ],
    );
  }
}

// ── 3. Rent Collection ────────────────────────────────────────────────────────

class _RentCollectionTab extends StatelessWidget {
  const _RentCollectionTab({required this.report});
  final RentCollectionReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (_, c) {
          final wide = c.maxWidth > 500;
          final cards = [
            _KpiCard(
              label: 'Collected',
              value: _inr.format(report.collected),
              valueColor: AppColors.success,
              icon: Icons.check_circle_outline_rounded,
            ),
            _KpiCard(
              label: 'Pending',
              value: _inr.format(report.pending),
              valueColor: AppColors.warning,
              icon: Icons.schedule_rounded,
            ),
            _KpiCard(
              label: 'Overdue',
              value: _inr.format(report.overdue),
              valueColor: AppColors.error,
              icon: Icons.warning_amber_rounded,
            ),
            _KpiCard(
              label: 'Collection Rate',
              value: '${report.collectionRate}%',
              valueColor: AppColors.accentGold,
              icon: Icons.percent_rounded,
            ),
          ];
          return wide
              ? Row(
                  children: cards
                      .map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c)))
                      .toList())
              : Column(
                  children: cards
                      .map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
                      .toList());
        }),
        const SizedBox(height: AppDimensions.spaceXL),

        if (report.byUnit.isNotEmpty) ...[
          const _SectionHeader('By Unit'),
          _SimpleTable(
            columns: const ['Unit', 'Collected', 'Pending', 'Overdue'],
            rows: report.byUnit.map((u) => [
              u.unitName,
              _inr.format(u.collected),
              u.pending > 0 ? _inr.format(u.pending) : '—',
              u.overdue > 0 ? _inr.format(u.overdue) : '—',
            ]).toList(),
          ),
        ] else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('No rent transactions found for this period.',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          ),
      ],
    );
  }
}

// ── 4. Maintenance Costs ──────────────────────────────────────────────────────

class _MaintenanceCostTab extends StatelessWidget {
  const _MaintenanceCostTab({required this.report});
  final MaintenanceCostReport report;

  @override
  Widget build(BuildContext context) {
    final openCount = report.byStatus['open'] ?? 0;
    final completedCount = report.byStatus['completed'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (_, c) {
          final wide = c.maxWidth > 500;
          final cards = [
            _KpiCard(
              label: 'Total Requests',
              value: '${report.totalRequests}',
              icon: Icons.build_rounded,
            ),
            _KpiCard(
              label: 'Total Cost',
              value: _inr.format(report.totalActualCost),
              valueColor: AppColors.warning,
              icon: Icons.payments_outlined,
            ),
            _KpiCard(
              label: 'Open',
              value: '$openCount',
              valueColor: AppColors.error,
              icon: Icons.radio_button_unchecked,
            ),
            _KpiCard(
              label: 'Completed',
              value: '$completedCount',
              valueColor: AppColors.success,
              icon: Icons.check_circle_outline_rounded,
            ),
          ];
          return wide
              ? Row(
                  children: cards
                      .map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c)))
                      .toList())
              : Column(
                  children: cards
                      .map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
                      .toList());
        }),
        const SizedBox(height: AppDimensions.spaceXL),

        if (report.byCategory.isNotEmpty) ...[
          const _SectionHeader('Cost by Category'),
          _HorizontalBarSection(
            items: report.byCategory
                .map((c) => _BarItem(c.category, c.actualCost, report.totalActualCost))
                .toList(),
            formatValue: (v) => _inr.format(v),
          ),
          const SizedBox(height: AppDimensions.spaceXL),
        ],

        if (report.byUnit.isNotEmpty) ...[
          const _SectionHeader('By Unit'),
          _SimpleTable(
            columns: const ['Unit', 'Requests', 'Total Cost'],
            rows: report.byUnit.take(10).map((u) => [
              u.unitName,
              '${u.count}',
              _inr.format(u.actualCost),
            ]).toList(),
          ),
        ],
      ],
    );
  }
}

// ── 5. Profit & Loss ──────────────────────────────────────────────────────────

class _ProfitLossTab extends StatelessWidget {
  const _ProfitLossTab({required this.report});
  final ProfitLossReport report;

  @override
  Widget build(BuildContext context) {
    final maxVal = report.byMonth.fold<double>(
        0,
        (m, e) => [m, e.income, e.expenses].reduce((a, b) => a > b ? a : b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (_, c) {
          final wide = c.maxWidth > 500;
          final cards = [
            _KpiCard(
              label: 'Total Income',
              value: _inr.format(report.totalIncome),
              valueColor: AppColors.success,
              icon: Icons.trending_up_rounded,
            ),
            _KpiCard(
              label: 'Total Expenses',
              value: _inr.format(report.totalExpenses),
              valueColor: AppColors.error,
              icon: Icons.trending_down_rounded,
            ),
            _KpiCard(
              label: 'Net Profit',
              value: _inr.format(report.netProfit),
              valueColor: report.netProfit >= 0 ? AppColors.success : AppColors.error,
              icon: Icons.account_balance_rounded,
            ),
            _KpiCard(
              label: 'Profit Margin',
              value: '${report.profitMargin}%',
              valueColor: AppColors.accentGold,
              icon: Icons.percent_rounded,
            ),
          ];
          return wide
              ? Row(
                  children: cards
                      .map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c)))
                      .toList())
              : Column(
                  children: cards
                      .map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
                      .toList());
        }),
        const SizedBox(height: AppDimensions.spaceXL),

        const _SectionHeader('Monthly P&L'),
        if (report.byMonth.isNotEmpty && maxVal > 0)
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= report.byMonth.length) return const SizedBox.shrink();
                        if (report.byMonth.length > 6 && i % 2 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(report.byMonth[i].label,
                              style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 0.5),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: report.byMonth.asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(
                        toY: e.value.income,
                        color: AppColors.success,
                        width: 6,
                        borderRadius: BorderRadius.circular(2)),
                    BarChartRodData(
                        toY: e.value.expenses,
                        color: AppColors.error,
                        width: 6,
                        borderRadius: BorderRadius.circular(2)),
                  ]);
                }).toList(),
              ),
            ),
          )
        else
          const _EmptyChart(),

        const SizedBox(height: 8),
        Row(children: [
          _Legend(color: AppColors.success, label: 'Income'),
          const SizedBox(width: 16),
          _Legend(color: AppColors.error, label: 'Expenses'),
        ]),
        const SizedBox(height: AppDimensions.spaceXL),

        if (report.byUnit.isNotEmpty) ...[
          const _SectionHeader('P&L by Unit'),
          _SimpleTable(
            columns: const ['Unit', 'Income', 'Expenses', 'Net Profit'],
            rows: report.byUnit.take(15).map((u) => [
              u.unitName,
              _inr.format(u.income),
              _inr.format(u.expenses),
              _inr.format(u.netProfit),
            ]).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _BarItem {
  const _BarItem(this.label, this.value, this.maxValue);
  final String label;
  final double value;
  final double maxValue;
}

class _HorizontalBarSection extends StatelessWidget {
  const _HorizontalBarSection({required this.items, this.formatValue});
  final List<_BarItem> items;
  final String Function(double)? formatValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          final pct = item.maxValue > 0 ? item.value / item.maxValue : 0.0;
          final isLast = e.key == items.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD, vertical: 10),
            decoration: isLast
                ? null
                : const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                SizedBox(
                    width: 130,
                    child: Text(item.label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct.toDouble().clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.accentGold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  child: Text(
                    formatValue != null
                        ? formatValue!(item.value)
                        : '${item.value.toStringAsFixed(0)} / ${item.maxValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SimpleTable extends StatelessWidget {
  const _SimpleTable({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No data available',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: columns
                  .map((c) => Expanded(
                        child: Text(c,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.5)),
                      ))
                  .toList(),
            ),
          ),
          // Rows
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMD, vertical: 10),
              decoration: isLast
                  ? null
                  : const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: e.value
                    .map((cell) => Expanded(
                          child: Text(cell,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary)),
                        ))
                    .toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      );
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text('No data for this period',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      );
}
