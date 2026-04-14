import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/dashboard_data.dart';

class AccountingSection extends StatelessWidget {
  const AccountingSection({
    super.key,
    required this.months,
    required this.totalIncome,
    required this.totalExpenses,
  });

  final List<AccountingMonth> months;
  final double totalIncome;
  final double totalExpenses;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Bar chart card ──────────────────────────────────────
        Expanded(
          flex: 3,
          child: _ChartCard(months: months),
        ),
        const SizedBox(width: AppDimensions.spaceSM),

        // ── Income / Expenses tiles ─────────────────────────────
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _SummaryTile(
                label: AppStrings.income,
                amount: totalIncome,
                isIncome: true,
              ),
              const SizedBox(height: AppDimensions.spaceSM),
              _SummaryTile(
                label: AppStrings.expenses,
                amount: totalExpenses,
                isIncome: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bar chart card ───────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.months});

  final List<AccountingMonth> months;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD,
              vertical: AppDimensions.spaceSM + 2,
            ),
            child: Row(
              children: [
                const Text(
                  AppStrings.accounting,
                  style: TextStyle(
                    fontSize: AppDimensions.fontMD,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                  ),
                  child: Row(
                    children: const [
                      Text(
                        AppStrings.last30Days,
                        style: TextStyle(
                          fontSize: AppDimensions.fontSM,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down,
                          size: AppDimensions.iconSM, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    AppStrings.viewAll,
                    style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textLink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceXS),
                const Icon(Icons.help_outline_rounded,
                    size: AppDimensions.iconSM, color: AppColors.textMuted),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Chart
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            child: SizedBox(
              height: 160,
              child: _BarChart(months: months),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.months});

  final List<AccountingMonth> months;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 6000,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.bgOuter,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = months[groupIndex];
              final isIncome = rodIndex == 0;
              final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
              return BarTooltipItem(
                '${isIncome ? 'Income' : 'Expense'}\n${fmt.format(isIncome ? month.income : month.expense)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    months[idx].month,
                    style: const TextStyle(
                      fontSize: AppDimensions.fontXS,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
              reservedSize: 20,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1000,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  '${(value / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(
                    fontSize: AppDimensions.fontXS,
                    color: AppColors.textMuted,
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 1000,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.divider,
            strokeWidth: 1,
          ),
          drawVerticalLine: false,
        ),
        barGroups: List.generate(months.length, (i) {
          final m = months[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: m.income,
                color: AppColors.chartGreen,
                width: 6,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
              BarChartRodData(
                toY: m.expense,
                color: AppColors.chartGold,
                width: 6,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
            ],
            barsSpace: 3,
          );
        }),
      ),
    );
  }
}

// ── Summary tiles ────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.isIncome,
  });

  final String label;
  final double amount;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMD,
        vertical: AppDimensions.spaceLG,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppDimensions.fontBase,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            fmt.format(amount),
            style: TextStyle(
              fontSize: AppDimensions.fontH2,
              fontWeight: FontWeight.w700,
              color: isIncome ? AppColors.textPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
