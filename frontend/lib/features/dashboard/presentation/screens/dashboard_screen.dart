import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/dashboard_data.dart';
import '../widgets/today_card.dart';
import '../widgets/tasks_section.dart';
import '../widgets/recently_viewed_section.dart';
import '../widgets/accounting_section.dart';

/// DashboardScreen — rendered as the child of AppShell's ShellRoute.
/// Does NOT wrap itself in AppShell; the router does that.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DashboardBody();
  }
}

class _DashboardBody extends StatelessWidget {
  // Using mock data — swap with Provider + Repository when backend is connected
  final DashboardData data = DashboardData.mock;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page title row ───────────────────────────────────
            _DashboardHeader(),
            const SizedBox(height: AppDimensions.spaceLG),

            // ── Main content: left + right columns ───────────────
            isMobile
                ? _MobileLayout(data: data)
                : _DesktopLayout(data: data),
          ],
        ),
      ),
    );
  }
}

// ── Page Header ──────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          AppStrings.dashboard,
          style: TextStyle(
            fontSize: AppDimensions.fontH2,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
          ),
          child: const Icon(
            Icons.tune_rounded,
            size: AppDimensions.iconMD,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Desktop Layout (2-column) ────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left column ──────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Column(
            children: [
              TodayCard(data: data),
              const SizedBox(height: AppDimensions.spaceMD),
              TasksSection(tasks: data.tasks),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spaceMD),

        // ── Right column ─────────────────────────────────────────
        Expanded(
          flex: 7,
          child: Column(
            children: [
              const RecentlyViewedSection(properties: []),
              const SizedBox(height: AppDimensions.spaceMD),
              AccountingSection(
                months: data.accountingMonths,
                totalIncome: data.totalIncome,
                totalExpenses: data.totalExpenses,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Mobile Layout (single column) ────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TodayCard(data: data),
        const SizedBox(height: AppDimensions.spaceMD),
        const RecentlyViewedSection(properties: []),
        const SizedBox(height: AppDimensions.spaceMD),
        TasksSection(tasks: data.tasks),
        const SizedBox(height: AppDimensions.spaceMD),
        AccountingSection(
          months: data.accountingMonths,
          totalIncome: data.totalIncome,
          totalExpenses: data.totalExpenses,
        ),
      ],
    );
  }
}
