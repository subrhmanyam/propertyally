import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/entities/tenant.dart';
import '../providers/tenants_provider.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantsProvider>().loadTenants();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TenantsProvider>(
      builder: (context, provider, _) {
        final isMobile = Responsive.isMobile(context);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                _ScreenHeader(count: provider.tenants.length),
                const SizedBox(height: AppDimensions.spaceLG),

                // ── Filters ──────────────────────────────────────────
                _FilterRow(
                  provider: provider,
                  searchController: _searchController,
                ),
                const SizedBox(height: AppDimensions.spaceLG),

                // ── Content ──────────────────────────────────────────
                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (provider.tenants.isEmpty)
                  EmptyState(
                    icon: Icons.people_outline,
                    title: AppStrings.noTenants,
                    description: AppStrings.noTenantsDesc,
                    actionLabel: AppStrings.addTenant,
                    onAction: () {},
                  )
                else
                  isMobile
                      ? _TenantCardList(tenants: provider.tenants)
                      : _TenantTable(tenants: provider.tenants),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.tenants,
              style: TextStyle(
                fontSize: AppDimensions.fontH2,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (count > 0)
              Text(
                '$count tenants',
                style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const Spacer(),
        AppButton(
          label: AppStrings.addTenant,
          icon: Icons.person_add_outlined,
          onPressed: () {},
        ),
      ],
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.provider,
    required this.searchController,
  });

  final TenantsProvider provider;
  final TextEditingController searchController;

  static const _statuses = [
    AppStrings.filterAll,
    AppStrings.active,
    AppStrings.pending,
    AppStrings.inactive,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Status chips ─────────────────────────────────────────
        Wrap(
          spacing: AppDimensions.spaceSM,
          children: _statuses.map((s) {
            final active = provider.statusFilter == s;
            return GestureDetector(
              onTap: () => provider.setStatusFilter(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMD,
                  vertical: AppDimensions.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.accentGreen : AppColors.cardBg,
                  border: Border.all(
                    color: active ? AppColors.accentGreen : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: AppDimensions.fontBase,
                    fontWeight: FontWeight.w500,
                    color: active ? AppColors.bgOuter : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const Spacer(),

        // ── Search ──────────────────────────────────────────────
        SizedBox(
          width: 240,
          height: 38,
          child: TextField(
            controller: searchController,
            onChanged: provider.setSearchQuery,
            style: const TextStyle(
              fontSize: AppDimensions.fontBase,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: AppStrings.searchTenants,
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
                size: AppDimensions.iconMD,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Desktop table ─────────────────────────────────────────────────────

class _TenantTable extends StatelessWidget {
  const _TenantTable({required this.tenants});

  final List<Tenant> tenants;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD,
              vertical: AppDimensions.spaceSM,
            ),
            decoration: const BoxDecoration(
              color: AppColors.pageBg,
              border: Border(bottom: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusMD),
              ),
            ),
            child: const Row(
              children: [
                _TH(label: 'Name', flex: 3),
                _TH(label: 'Email', flex: 3),
                _TH(label: 'Phone', flex: 2),
                _TH(label: 'Move-in', flex: 2),
                _TH(label: 'Status', flex: 2),
                _TH(label: '', flex: 1),
              ],
            ),
          ),

          // ── Rows ───────────────────────────────────────────────
          ...tenants.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            return _TenantRow(
              tenant: t,
              isLast: i == tenants.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  const _TH({required this.label, this.flex = 1});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: AppDimensions.fontXS,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TenantRow extends StatefulWidget {
  const _TenantRow({required this.tenant, required this.isLast});

  final Tenant tenant;
  final bool isLast;

  @override
  State<_TenantRow> createState() => _TenantRowState();
}

class _TenantRowState extends State<_TenantRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tenant;
    final fmt = DateFormat('MMM d, yyyy');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/tenants/${t.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.pageBg : Colors.transparent,
            border: !widget.isLast
                ? const Border(bottom: BorderSide(color: AppColors.border))
                : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceMD,
            vertical: AppDimensions.spaceMD,
          ),
          child: Row(
            children: [
              // Name + avatar
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _TenantAvatar(tenant: t),
                    const SizedBox(width: AppDimensions.spaceSM),
                    Expanded(
                      child: Text(
                        t.fullName,
                        style: const TextStyle(
                          fontSize: AppDimensions.fontBase,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Email
              Expanded(
                flex: 3,
                child: Text(
                  t.email,
                  style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Phone
              Expanded(
                flex: 2,
                child: Text(
                  t.phone,
                  style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Move-in date
              Expanded(
                flex: 2,
                child: Text(
                  t.moveInDate != null ? fmt.format(t.moveInDate!) : '—',
                  style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Status badge
              Expanded(
                flex: 2,
                child: _TenantStatusBadge(status: t.status),
              ),
              // Arrow
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right,
                    size: AppDimensions.iconMD,
                    color: _hovered ? AppColors.accentGreen : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile card list ──────────────────────────────────────────────────

class _TenantCardList extends StatelessWidget {
  const _TenantCardList({required this.tenants});

  final List<Tenant> tenants;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return Column(
      children: tenants.map((t) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.spaceSM),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: ListTile(
            onTap: () => context.go('/tenants/${t.id}'),
            leading: _TenantAvatar(tenant: t),
            title: Text(
              t.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              t.email,
              style: const TextStyle(
                fontSize: AppDimensions.fontSM,
                color: AppColors.textMuted,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _TenantStatusBadge(status: t.status),
                if (t.moveInDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(t.moveInDate!),
                    style: const TextStyle(
                      fontSize: AppDimensions.fontXS,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────

class _TenantAvatar extends StatelessWidget {
  const _TenantAvatar({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final initials = tenant.firstName.isNotEmpty && tenant.lastName.isNotEmpty
        ? '${tenant.firstName[0]}${tenant.lastName[0]}'
        : tenant.firstName.isNotEmpty
            ? tenant.firstName[0]
            : '?';
    return CircleAvatar(
      radius: AppDimensions.avatarSM / 2,
      backgroundColor: AppColors.accentGreen,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppDimensions.fontXS,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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
