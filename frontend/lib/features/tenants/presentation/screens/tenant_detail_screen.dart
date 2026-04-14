import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/tenant.dart';
import '../providers/tenants_provider.dart';

class TenantDetailScreen extends StatefulWidget {
  const TenantDetailScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantsProvider>().loadTenant(widget.tenantId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TenantsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.selectedTenant == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final tenant = provider.selectedTenant;
        if (tenant == null) {
          return const Center(child: Text('Tenant not found.'));
        }

        final lease = provider.selectedLease;
        final isMobile = Responsive.isMobile(context);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Back navigation ──────────────────────────────────
                _BackRow(),

                const SizedBox(height: AppDimensions.spaceLG),

                // ── Profile header ───────────────────────────────────
                _TenantHeader(tenant: tenant),

                const SizedBox(height: AppDimensions.spaceLG),

                // ── Content grid ─────────────────────────────────────
                isMobile
                    ? _MobileLayout(tenant: tenant, lease: lease)
                    : _DesktopLayout(tenant: tenant, lease: lease),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Back row ──────────────────────────────────────────────────────────

class _BackRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/tenants'),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chevron_left, size: AppDimensions.iconMD, color: AppColors.textMuted),
          Text(
            AppStrings.tenants,
            style: TextStyle(fontSize: AppDimensions.fontBase, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────

class _TenantHeader extends StatelessWidget {
  const _TenantHeader({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final initials = tenant.firstName.isNotEmpty && tenant.lastName.isNotEmpty
        ? '${tenant.firstName[0]}${tenant.lastName[0]}'
        : '?';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Large avatar ────────────────────────────────────────
          CircleAvatar(
            radius: AppDimensions.avatarLG / 2,
            backgroundColor: AppColors.accentGreen,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppDimensions.fontH3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceLG),

          // ── Name + status ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tenant.fullName,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontH2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceMD),
                    _TenantStatusBadge(status: tenant.status),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceXS),
                Row(
                  children: [
                    const Icon(Icons.mail_outline, size: AppDimensions.iconSM, color: AppColors.textMuted),
                    const SizedBox(width: AppDimensions.spaceXS),
                    Text(
                      tenant.email,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceLG),
                    const Icon(Icons.phone_outlined, size: AppDimensions.iconSM, color: AppColors.textMuted),
                    const SizedBox(width: AppDimensions.spaceXS),
                    Text(
                      tenant.phone,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Actions ─────────────────────────────────────────────
          AppButton(
            label: AppStrings.edit,
            variant: AppButtonVariant.secondary,
            icon: Icons.edit_outlined,
            small: true,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

// ── Layout helpers ────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.tenant, required this.lease});

  final Tenant tenant;
  final Lease? lease;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _ContactCard(tenant: tenant),
              if (tenant.emergencyContactName != null) ...[
                const SizedBox(height: AppDimensions.spaceMD),
                _EmergencyCard(tenant: tenant),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spaceMD),

        // Right column
        Expanded(
          flex: 7,
          child: lease != null
              ? _LeaseCard(lease: lease!)
              : const _NoLeaseCard(),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.tenant, required this.lease});

  final Tenant tenant;
  final Lease? lease;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (lease != null) _LeaseCard(lease: lease!),
        const SizedBox(height: AppDimensions.spaceMD),
        _ContactCard(tenant: tenant),
        if (tenant.emergencyContactName != null) ...[
          const SizedBox(height: AppDimensions.spaceMD),
          _EmergencyCard(tenant: tenant),
        ],
      ],
    );
  }
}

// ── Info cards ────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMMM d, yyyy');
    return _SectionCard(
      title: AppStrings.contactInfo,
      icon: Icons.person_outline,
      rows: [
        _DetailRow(label: AppStrings.tenantName, value: tenant.fullName),
        _DetailRow(label: AppStrings.email, value: tenant.email),
        _DetailRow(label: AppStrings.phone, value: tenant.phone),
        if (tenant.moveInDate != null)
          _DetailRow(
            label: AppStrings.moveInDate,
            value: fmt.format(tenant.moveInDate!),
          ),
      ],
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: AppStrings.emergencyContact,
      icon: Icons.emergency_outlined,
      rows: [
        if (tenant.emergencyContactName != null)
          _DetailRow(label: AppStrings.tenantName, value: tenant.emergencyContactName!),
        if (tenant.emergencyContactPhone != null)
          _DetailRow(label: AppStrings.phone, value: tenant.emergencyContactPhone!),
      ],
    );
  }
}

class _LeaseCard extends StatelessWidget {
  const _LeaseCard({required this.lease});

  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMMM d, yyyy');
    final currency = NumberFormat.currency(symbol: r'$');
    final now = DateTime.now();
    final daysLeft = lease.endDate.difference(now).inDays;
    final isExpiring = daysLeft < 60 && daysLeft > 0;
    final isExpired = daysLeft <= 0;

    return _SectionCard(
      title: AppStrings.leaseInfo,
      icon: Icons.description_outlined,
      headerTrailing: _LeaseStatusChip(
        isExpired: isExpired,
        isExpiring: isExpiring,
        status: lease.status,
      ),
      rows: [
        _DetailRow(label: AppStrings.leaseStart, value: fmt.format(lease.startDate)),
        _DetailRow(label: AppStrings.leaseEnd, value: fmt.format(lease.endDate)),
        _DetailRow(
          label: AppStrings.monthlyRent,
          value: currency.format(lease.monthlyRent),
        ),
        _DetailRow(
          label: AppStrings.deposit,
          value: currency.format(lease.depositAmount),
        ),
        if (isExpiring)
          _DetailRow(
            label: 'Days Remaining',
            value: '$daysLeft days',
            valueColor: AppColors.warning,
          ),
      ],
    );
  }
}

class _NoLeaseCard extends StatelessWidget {
  const _NoLeaseCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.description_outlined,
            size: AppDimensions.iconXL,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppDimensions.spaceMD),
          const Text(
            'No active lease',
            style: TextStyle(
              fontSize: AppDimensions.fontMD,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          const Text(
            'This tenant does not have a current lease on file.',
            style: TextStyle(
              fontSize: AppDimensions.fontBase,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceLG),
          AppButton(label: 'Add Lease', icon: Icons.add, onPressed: () {}),
        ],
      ),
    );
  }
}

// ── Reusable section card ─────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.headerTrailing,
  });

  final String title;
  final IconData icon;
  final List<_DetailRow> rows;
  final Widget? headerTrailing;

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
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            child: Row(
              children: [
                Icon(icon, size: AppDimensions.iconMD, color: AppColors.accentGreen),
                const SizedBox(width: AppDimensions.spaceSM),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppDimensions.fontMD,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (headerTrailing != null) ...[
                  const Spacer(),
                  headerTrailing!,
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Rows
          ...rows.asMap().entries.map((e) => Column(
                children: [
                  e.value,
                  if (e.key < rows.length - 1)
                    const Divider(height: 1, color: AppColors.border),
                ],
              )),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMD,
        vertical: AppDimensions.spaceMD,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppDimensions.fontBase,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: AppDimensions.fontBase,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lease status chip ─────────────────────────────────────────────────

class _LeaseStatusChip extends StatelessWidget {
  const _LeaseStatusChip({
    required this.isExpired,
    required this.isExpiring,
    required this.status,
  });

  final bool isExpired;
  final bool isExpiring;
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, textColor, label) = isExpired
        ? (AppColors.error.withValues(alpha: 0.12), AppColors.error, 'Expired')
        : isExpiring
            ? (AppColors.warning.withValues(alpha: 0.12), AppColors.warning, 'Expiring Soon')
            : (AppColors.occupiedBg, AppColors.occupiedText, 'Active');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppDimensions.fontXS,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// ── Tenant status badge ───────────────────────────────────────────────

class _TenantStatusBadge extends StatelessWidget {
  const _TenantStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, textColor, label) = switch (status.toLowerCase()) {
      'active' => (AppColors.occupiedBg, AppColors.occupiedText, 'Active'),
      'pending' => (AppColors.pendingBg, AppColors.pendingText, 'Pending'),
      _ => (AppColors.vacantBg, AppColors.vacantText, 'Inactive'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppDimensions.fontXS,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
