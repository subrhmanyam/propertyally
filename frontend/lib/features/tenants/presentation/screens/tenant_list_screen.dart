import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/export_helper.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../properties/domain/entities/leasing_unit.dart';
import '../../../properties/presentation/providers/leasing_provider.dart';
import '../../../properties/presentation/widgets/leasing_form_dialog.dart';
import '../../domain/entities/tenant.dart';
import '../providers/tenants_provider.dart';
import '../widgets/tenant_form_dialog.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  LeasingUnit? _selectedUnit;
  bool _showUnassigned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantsProvider>().loadTenants();
      context.read<LeasingProvider>().load();
    });
  }

  void _exportCsv() {
    final tenants = context.read<TenantsProvider>().tenants;
    if (tenants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tenants to export.')),
      );
      return;
    }
    final csv = buildCsv(
      ['ID', 'First Name', 'Last Name', 'Email', 'Phone', 'Status', 'Unit ID', 'Move-in Date'],
      tenants.map((t) => [
        t.id, t.firstName, t.lastName, t.email, t.phone,
        t.status, t.unitId ?? '', t.moveInDate?.toIso8601String() ?? '',
      ]).toList(),
    );
    downloadCsv(csv, 'tenants_${DateTime.now().millisecondsSinceEpoch}.csv');
  }

  Future<void> _openAddTenant() async {
    final lp = context.read<LeasingProvider>();
    final tp = context.read<TenantsProvider>();
    if (lp.units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one property first.')),
      );
      return;
    }
    final data = await showTenantForm(
      context,
      units: lp.units,
      preselectedUnit: _selectedUnit,
    );
    if (data != null && mounted) {
      await tp.createTenant(data);
    }
  }

  Future<void> _confirmDeleteTenant(Tenant tenant) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete Tenant?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Remove ${tenant.fullName} permanently?',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<TenantsProvider>().deleteTenant(tenant.id);
    }
  }

  Future<void> _openEditProperty(LeasingUnit unit) async {
    final result = await showLeasingForm(context, unit: unit);
    if (result != null && mounted) {
      await context.read<LeasingProvider>().update(result);
      if (_selectedUnit?.id == result.id) {
        setState(() => _selectedUnit = result);
      }
    }
  }

  Future<void> _confirmDeleteProperty(LeasingUnit unit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete Property?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete "${unit.name}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<LeasingProvider>().delete(unit.id);
      if (_selectedUnit?.id == unit.id) {
        setState(() => _selectedUnit = null);
      }
    }
  }

  Future<void> _openAssignProperty(Tenant tenant, List<LeasingUnit> units) async {
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a property first.')),
      );
      return;
    }
    String selected = units.first.id;
    final unitId = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Assign Property',
              style: TextStyle(color: AppColors.textPrimary)),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            dropdownColor: AppColors.cardBg,
            isExpanded: true,
            style: const TextStyle(color: AppColors.textPrimary),
            items: units
                .map((u) => DropdownMenuItem(
                      value: u.id,
                      child: Text('${u.name}  ·  ${u.category}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setDialogState(() => selected = v!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Assign',
                  style: TextStyle(color: AppColors.accentGold)),
            ),
          ],
        ),
      ),
    );
    if (unitId != null && mounted) {
      await context
          .read<TenantsProvider>()
          .updateTenant(tenant.id, {'leasing_unit_id': unitId});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TenantsProvider, LeasingProvider>(
      builder: (context, tp, lp, _) {
        // ── Level 2: tenants for selected property ─────────────────
        if (_selectedUnit != null) {
          final unit = lp.units
                  .where((u) => u.id == _selectedUnit!.id)
                  .firstOrNull ??
              _selectedUnit!;
          final unitTenants =
              tp.tenants.where((t) => t.unitId == unit.id).toList();
          return _PropertyTenantsView(
            unit: unit,
            tenants: unitTenants,
            isLoading: tp.isLoading,
            onBack: () => setState(() => _selectedUnit = null),
            onAddTenant: _openAddTenant,
            onDeleteTenant: _confirmDeleteTenant,
            onDeleteProperty: _confirmDeleteProperty,
            onEditProperty: _openEditProperty,
          );
        }

        final unitIds = lp.units.map((u) => u.id).toSet();
        final unassignedTenants = tp.tenants
            .where((t) =>
                t.unitId == null ||
                t.unitId!.isEmpty ||
                !unitIds.contains(t.unitId))
            .toList();

        // ── Level 2b: tenants with no property assigned ─────────────
        if (_showUnassigned) {
          return _UnassignedTenantsView(
            tenants: unassignedTenants,
            isLoading: tp.isLoading,
            onBack: () => setState(() => _showUnassigned = false),
            onDeleteTenant: _confirmDeleteTenant,
            onAssignProperty: (t) => _openAssignProperty(t, lp.units),
          );
        }

        // Build per-unit tenant count
        final tenantCount = <String, int>{};
        for (final t in tp.tenants) {
          if (t.unitId != null && t.unitId!.isNotEmpty) {
            tenantCount[t.unitId!] = (tenantCount[t.unitId!] ?? 0) + 1;
          }
        }

        // ── Level 1: property cards ─────────────────────────────────
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.tenants,
                          style: TextStyle(
                            fontSize: AppDimensions.fontH2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Select a property to view and manage tenants',
                          style: TextStyle(
                              fontSize: AppDimensions.fontBase,
                              color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AppButton(
                      label: 'Export CSV',
                      icon: Icons.download_outlined,
                      variant: AppButtonVariant.ghost,
                      onPressed: _exportCsv,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceLG),
                if (!lp.isLoading && !tp.isLoading && unassignedTenants.isNotEmpty) ...[
                  _UnassignedBanner(
                    count: unassignedTenants.length,
                    onTap: () => setState(() => _showUnassigned = true),
                  ),
                  const SizedBox(height: AppDimensions.spaceLG),
                ],
                if (lp.isLoading || tp.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: CircularProgressIndicator(
                          color: AppColors.accentGold),
                    ),
                  )
                else if (lp.units.isEmpty)
                  const EmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'No Properties Yet',
                    description:
                        'Add properties in the Properties section first.',
                  )
                else
                  _PropertyGrid(
                    units: lp.units,
                    tenantCount: tenantCount,
                    onSelect: (unit) => setState(() => _selectedUnit = unit),
                    onDelete: _confirmDeleteProperty,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Warning banner: tenants missing a property ────────────────────────

class _UnassignedBanner extends StatelessWidget {
  const _UnassignedBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD, vertical: AppDimensions.spaceSM),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: AppDimensions.iconMD, color: AppColors.warning),
              const SizedBox(width: AppDimensions.spaceSM),
              Expanded(
                child: Text(
                  '$count tenant${count == 1 ? '' : 's'} without a property assigned',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              const Text('Review',
                  style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning)),
              const SizedBox(width: AppDimensions.spaceXS),
              const Icon(Icons.arrow_forward_ios,
                  size: 12, color: AppColors.warning),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Level 2 — tenant vcards for a property ────────────────────────────

class _PropertyTenantsView extends StatelessWidget {
  const _PropertyTenantsView({
    required this.unit,
    required this.tenants,
    required this.isLoading,
    required this.onBack,
    required this.onAddTenant,
    required this.onDeleteTenant,
    required this.onDeleteProperty,
    required this.onEditProperty,
  });

  final LeasingUnit unit;
  final List<Tenant> tenants;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onAddTenant;
  final ValueChanged<Tenant> onDeleteTenant;
  final ValueChanged<LeasingUnit> onDeleteProperty;
  final ValueChanged<LeasingUnit> onEditProperty;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Breadcrumb header ───────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back,
                            size: AppDimensions.iconMD,
                            color: AppColors.textMuted),
                        SizedBox(width: AppDimensions.spaceXS),
                        Text('Properties',
                            style: TextStyle(
                                fontSize: AppDimensions.fontBase,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                const Text('/',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 18)),
                const SizedBox(width: AppDimensions.spaceSM),
                Expanded(
                  child: Text(
                    unit.name,
                    style: const TextStyle(
                        fontSize: AppDimensions.fontH2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Edit property
                Tooltip(
                  message: 'Edit property',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onEditProperty(unit),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: const Padding(
                        padding: EdgeInsets.all(AppDimensions.spaceXS),
                        child: Icon(Icons.edit_outlined,
                            size: AppDimensions.iconMD,
                            color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceXS),
                // Delete property
                Tooltip(
                  message: 'Delete property',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onDeleteProperty(unit),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: const Padding(
                        padding: EdgeInsets.all(AppDimensions.spaceXS),
                        child: Icon(Icons.delete_outline,
                            size: AppDimensions.iconMD,
                            color: AppColors.error),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                AppButton(
                  label: AppStrings.addTenant,
                  icon: Icons.person_add_outlined,
                  onPressed: onAddTenant,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceSM),

            // ── Property meta chips ─────────────────────────────────
            Wrap(
              spacing: AppDimensions.spaceSM,
              children: [
                _InfoChip(label: unit.category),
                _InfoChip(label: unit.companyName),
                _InfoChip(label: unit.floor),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLG),

            // ── Tenant content ──────────────────────────────────────
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child:
                      CircularProgressIndicator(color: AppColors.accentGold),
                ),
              )
            else if (tenants.isEmpty)
              EmptyState(
                icon: Icons.people_outline,
                title: 'No Tenants Yet',
                description: 'Add the first tenant for ${unit.name}.',
                actionLabel: AppStrings.addTenant,
                onAction: onAddTenant,
              )
            else
              _TenantVCardGrid(
                tenants: tenants,
                onDelete: onDeleteTenant,
                propertyName: unit.name,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Level 2b — tenants with no property assigned ──────────────────────

class _UnassignedTenantsView extends StatelessWidget {
  const _UnassignedTenantsView({
    required this.tenants,
    required this.isLoading,
    required this.onBack,
    required this.onDeleteTenant,
    required this.onAssignProperty,
  });

  final List<Tenant> tenants;
  final bool isLoading;
  final VoidCallback onBack;
  final ValueChanged<Tenant> onDeleteTenant;
  final ValueChanged<Tenant> onAssignProperty;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back,
                            size: AppDimensions.iconMD,
                            color: AppColors.textMuted),
                        SizedBox(width: AppDimensions.spaceXS),
                        Text('Properties',
                            style: TextStyle(
                                fontSize: AppDimensions.fontBase,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                const Text('/',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 18)),
                const SizedBox(width: AppDimensions.spaceSM),
                const Icon(Icons.warning_amber_rounded,
                    size: AppDimensions.iconMD, color: AppColors.warning),
                const SizedBox(width: AppDimensions.spaceXS),
                const Expanded(
                  child: Text(
                    'Unassigned Tenants',
                    style: TextStyle(
                        fontSize: AppDimensions.fontH2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceXS),
            const Text(
              'These tenants aren\'t linked to a property. Assign one so they show up under the right property.',
              style: TextStyle(
                  fontSize: AppDimensions.fontBase, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppDimensions.spaceLG),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child:
                      CircularProgressIndicator(color: AppColors.accentGold),
                ),
              )
            else if (tenants.isEmpty)
              const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'All Tenants Assigned',
                description: 'Every tenant is linked to a property.',
              )
            else
              _TenantVCardGrid(
                tenants: tenants,
                onDelete: onDeleteTenant,
                onAssignProperty: onAssignProperty,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: AppDimensions.fontSM, color: AppColors.textMuted)),
    );
  }
}

// ── Tenant vcard grid ─────────────────────────────────────────────────

class _TenantVCardGrid extends StatelessWidget {
  const _TenantVCardGrid({
    required this.tenants,
    required this.onDelete,
    this.propertyName,
    this.onAssignProperty,
  });

  final List<Tenant> tenants;
  final ValueChanged<Tenant> onDelete;

  /// Property name shared by every tenant in this grid (all tenants here
  /// belong to the same property). Null when tenants have no property.
  final String? propertyName;
  final ValueChanged<Tenant>? onAssignProperty;

  @override
  Widget build(BuildContext context) {
    final cols =
        Responsive.value<int>(context, mobile: 1, tablet: 2, desktop: 3);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: cols == 1 ? 3.0 : 2.1,
        crossAxisSpacing: AppDimensions.spaceMD,
        mainAxisSpacing: AppDimensions.spaceMD,
      ),
      itemCount: tenants.length,
      itemBuilder: (_, i) => _TenantVCard(
        tenant: tenants[i],
        onDelete: onDelete,
        propertyName: propertyName,
        onAssignProperty: onAssignProperty,
      ),
    );
  }
}

class _TenantVCard extends StatefulWidget {
  const _TenantVCard({
    required this.tenant,
    required this.onDelete,
    this.propertyName,
    this.onAssignProperty,
  });

  final Tenant tenant;
  final ValueChanged<Tenant> onDelete;
  final String? propertyName;
  final ValueChanged<Tenant>? onAssignProperty;

  @override
  State<_TenantVCard> createState() => _TenantVCardState();
}

class _TenantVCardState extends State<_TenantVCard> {
  bool _hovered = false;
  final _fmt = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final t = widget.tenant;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.all(AppDimensions.spaceMD),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(
            color: _hovered ? AppColors.accentGold : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Top: avatar + name + status + delete ────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(tenant: t),
                const SizedBox(width: AppDimensions.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.fullName,
                        style: const TextStyle(
                          fontSize: AppDimensions.fontBase,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (t.email.isNotEmpty)
                        Text(
                          t.email,
                          style: const TextStyle(
                              fontSize: AppDimensions.fontXS,
                              color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _TenantStatusBadge(status: t.status),
                const SizedBox(width: AppDimensions.spaceXS),
                // Delete — always visible, large enough tap target
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onDelete(t),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: AppDimensions.iconSM,
                        color: _hovered
                            ? AppColors.error
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Property name / missing-property warning ─────────
            if (widget.propertyName != null && widget.propertyName!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.apartment_outlined,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.propertyName!,
                      style: const TextStyle(
                          fontSize: AppDimensions.fontXS,
                          color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 12, color: AppColors.warning),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'No property assigned',
                      style: TextStyle(
                          fontSize: AppDimensions.fontXS,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onAssignProperty != null)
                    GestureDetector(
                      onTap: () => widget.onAssignProperty!(t),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          'Assign',
                          style: TextStyle(
                              fontSize: AppDimensions.fontXS,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentGold,
                              decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                ],
              ),

            // ── Bottom: phone + move-in ──────────────────────────
            Row(
              children: [
                if (t.phone.isNotEmpty) ...[
                  const Icon(Icons.phone_outlined,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(t.phone,
                      style: const TextStyle(
                          fontSize: AppDimensions.fontXS,
                          color: AppColors.textMuted)),
                ],
                const Spacer(),
                if (t.moveInDate != null) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    _fmt.format(t.moveInDate!),
                    style: const TextStyle(
                        fontSize: AppDimensions.fontXS,
                        color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Level 1 — property selection grid ────────────────────────────────

class _PropertyGrid extends StatelessWidget {
  const _PropertyGrid({
    required this.units,
    required this.tenantCount,
    required this.onSelect,
    required this.onDelete,
  });

  final List<LeasingUnit> units;
  final Map<String, int> tenantCount;
  final ValueChanged<LeasingUnit> onSelect;
  final ValueChanged<LeasingUnit> onDelete;

  @override
  Widget build(BuildContext context) {
    final cols =
        Responsive.value<int>(context, mobile: 1, tablet: 2, desktop: 3);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: cols == 1 ? 3.0 : 2.2,
        crossAxisSpacing: AppDimensions.spaceMD,
        mainAxisSpacing: AppDimensions.spaceMD,
      ),
      itemCount: units.length,
      itemBuilder: (_, i) => _PropertyCard(
        unit: units[i],
        count: tenantCount[units[i].id] ?? 0,
        onTap: () => onSelect(units[i]),
        onDelete: () => onDelete(units[i]),
      ),
    );
  }
}

class _PropertyCard extends StatefulWidget {
  const _PropertyCard({
    required this.unit,
    required this.count,
    required this.onTap,
    required this.onDelete,
  });

  final LeasingUnit unit;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<_PropertyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.cardBg : AppColors.pageBg,
            border: Border.all(
              color: _hovered ? AppColors.accentGold : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Category + delete (always visible)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      u.category,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontXS,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentGold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Delete — opaque so it wins over card GestureDetector
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDelete,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: AppDimensions.iconSM,
                          color: _hovered
                              ? AppColors.error
                              : AppColors.textMuted
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Property name + portfolio
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.name,
                    style: const TextStyle(
                      fontSize: AppDimensions.fontH3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    u.companyName,
                    style: const TextStyle(
                        fontSize: AppDimensions.fontSM,
                        color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Tenant count + status + arrow
              Row(
                children: [
                  const Icon(Icons.people_outline,
                      size: AppDimensions.iconSM,
                      color: AppColors.textMuted),
                  const SizedBox(width: AppDimensions.spaceXS),
                  Text(
                    '${widget.count} tenant${widget.count == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: AppDimensions.fontSM,
                        color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  _UnitStatusBadge(status: u.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitStatusBadge extends StatelessWidget {
  const _UnitStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status.toLowerCase()) {
      'occupied' => (AppColors.occupiedBg, AppColors.occupiedText),
      'pending' => (AppColors.pendingBg, AppColors.pendingText),
      _ => (AppColors.vacantBg, AppColors.vacantText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
            fontSize: AppDimensions.fontXS,
            fontWeight: FontWeight.w600,
            color: fg),
      ),
    );
  }
}

// ── Shared widgets ───────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.tenant});
  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final initials = [
      if (tenant.firstName.isNotEmpty) tenant.firstName[0],
      if (tenant.lastName.isNotEmpty) tenant.lastName[0],
    ].join();
    return CircleAvatar(
      radius: AppDimensions.avatarSM / 2,
      backgroundColor: AppColors.accentGold,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
            color: AppColors.bgOuter,
            fontSize: AppDimensions.fontXS,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TenantStatusBadge extends StatelessWidget {
  const _TenantStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status.toLowerCase()) {
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
            color: fg),
      ),
    );
  }
}
