import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/tenant_provider.dart';

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TenantProvider>(
      builder: (context, p, _) {
        if (p.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.accentSilver));
        }
        final tenant = p.profile?['tenant'] as Map?;
        final unit = tenant?['leasing_units'] as Map?;
        final openMaint =
            p.maintenance.where((m) => m['status'] == 'open').length;
        final openQueries =
            p.queries.where((q) => q['status'] == 'open').length;
        final unpaidInvoices =
            p.invoices.where((i) => i['status'] != 'paid').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: const TextStyle(
                    fontSize: AppDimensions.fontH2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              if (tenant != null)
                Text(
                  '${tenant['first_name'] ?? ''} ${tenant['last_name'] ?? ''}'
                      .trim(),
                  style: const TextStyle(
                      fontSize: AppDimensions.fontH3,
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: AppDimensions.spaceXL),

              // Unit card
              if (unit != null)
                _InfoCard(
                  title: 'My Unit',
                  children: [
                    _Row('Unit', unit['name'] ?? '—'),
                    _Row('Floor', unit['floor']?.toString() ?? '—'),
                    _Row('Category', unit['category'] ?? '—'),
                    _Row('Status', unit['status'] ?? '—'),
                  ],
                ),

              const SizedBox(height: AppDimensions.spaceLG),

              // Quick-action tiles
              Text(
                'Quick Actions',
                style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              Wrap(
                spacing: AppDimensions.spaceMD,
                runSpacing: AppDimensions.spaceMD,
                children: [
                  _ActionTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Invoices',
                    badge: unpaidInvoices,
                    onTap: () => context.go('/tenant/invoices'),
                  ),
                  _ActionTile(
                    icon: Icons.home_repair_service_outlined,
                    label: 'Services',
                    badge: 0,
                    onTap: () => context.go('/tenant/services'),
                  ),
                  _ActionTile(
                    icon: Icons.build_outlined,
                    label: 'Maintenance',
                    badge: openMaint,
                    onTap: () => context.go('/tenant/maintenance'),
                  ),
                  _ActionTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Messages',
                    badge: openQueries,
                    onTap: () => context.go('/tenant/messages'),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceXL),

              // Recent invoices
              if (p.invoices.isNotEmpty) ...[
                Text(
                  'Recent Invoices',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: AppDimensions.spaceMD),
                ...p.invoices.take(3).map((inv) => _InvoiceRow(inv)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppDimensions.spaceMD),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSM),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: AppDimensions.fontSM,
                    color: AppColors.textMuted)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: AppDimensions.fontSM,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.badge,
      required this.onTap});

  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(AppDimensions.spaceLG),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon,
                    size: AppDimensions.iconXL, color: AppColors.accentSilver),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceSM),
            Text(label,
                style: const TextStyle(
                    fontSize: AppDimensions.fontSM,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow(this.inv);

  final Map<String, dynamic> inv;

  @override
  Widget build(BuildContext context) {
    final isPaid = inv['status'] == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceSM),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceLG, vertical: AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              inv['description'] ?? 'Invoice',
              style: const TextStyle(
                  fontSize: AppDimensions.fontSM, color: AppColors.textPrimary),
            ),
          ),
          Text(
            '₹${(inv['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
            style: const TextStyle(
                fontSize: AppDimensions.fontSM,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isPaid ? AppColors.occupiedBg : AppColors.vacantBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isPaid ? 'Paid' : 'Due',
              style: TextStyle(
                  fontSize: 11,
                  color:
                      isPaid ? AppColors.occupiedText : AppColors.vacantText),
            ),
          ),
        ],
      ),
    );
  }
}
