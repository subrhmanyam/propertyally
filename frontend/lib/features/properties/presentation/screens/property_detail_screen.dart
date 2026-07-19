import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/property.dart';
import '../providers/properties_provider.dart';

class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PropertiesProvider>().loadProperty(widget.propertyId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PropertiesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.selectedProperty == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final property = provider.selectedProperty;
        if (property == null) {
          return const Center(child: Text('Property not found.'));
        }

        final isMobile = Responsive.isMobile(context);

        return Column(
          children: [
            // ── Sticky header ──────────────────────────────────────
            _DetailHeader(property: property),

            // ── Tab bar ────────────────────────────────────────────
            _TabBar(controller: _tabController),

            // ── Tab views ──────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _UnitsTab(property: property, isMobile: isMobile),
                  _InfoTab(property: property),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Detail header ─────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final monthlyRent = property.units.fold<double>(
      0,
      (sum, u) => sum + (u.status == 'occupied' ? u.rentAmount : 0),
    );

    return Container(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back + actions ──────────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/properties'),
                child: const Row(
                  children: [
                    Icon(
                      Icons.chevron_left,
                      size: AppDimensions.iconMD,
                      color: AppColors.textMuted,
                    ),
                    Text(
                      AppStrings.properties,
                      style: TextStyle(
                        fontSize: AppDimensions.fontBase,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                label: AppStrings.edit,
                variant: AppButtonVariant.secondary,
                icon: Icons.edit_outlined,
                small: true,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMD),

          // ── Property name + address ────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.progressCardBg,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                child: const Icon(
                  Icons.home_work_outlined,
                  color: AppColors.accentGreen,
                  size: AppDimensions.iconLG,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontH2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceXS),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: AppDimensions.iconSM,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          property.address,
                          style: const TextStyle(
                            fontSize: AppDimensions.fontBase,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceLG),

          // ── KPI stat cards ──────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _KpiCard(
                  label: AppStrings.totalUnits,
                  value: '${property.totalUnits}',
                  icon: Icons.home_work_outlined,
                  iconColor: AppColors.info,
                ),
                const SizedBox(width: AppDimensions.spaceMD),
                _KpiCard(
                  label: AppStrings.occupiedUnits,
                  value: '${property.occupiedUnits}',
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.success,
                ),
                const SizedBox(width: AppDimensions.spaceMD),
                _KpiCard(
                  label: AppStrings.vacantUnits,
                  value: '${property.totalUnits - property.occupiedUnits}',
                  icon: Icons.radio_button_unchecked,
                  iconColor: AppColors.warning,
                ),
                const SizedBox(width: AppDimensions.spaceMD),
                _KpiCard(
                  label: AppStrings.occupancyRate,
                  value: '${property.occupancyRate.toStringAsFixed(0)}%',
                  icon: Icons.pie_chart_outline,
                  iconColor: AppColors.accentGreen,
                ),
                const SizedBox(width: AppDimensions.spaceMD),
                _KpiCard(
                  label: AppStrings.monthlyRent,
                  value: fmt.format(monthlyRent),
                  icon: Icons.attach_money,
                  iconColor: AppColors.accentGold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppDimensions.iconMD, color: iconColor),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppDimensions.fontH2,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppDimensions.fontSM,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: TabBar(
        controller: controller,
        labelColor: AppColors.accentGreen,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accentGreen,
        indicatorWeight: 2,
        labelStyle: const TextStyle(
          fontSize: AppDimensions.fontBase,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: AppDimensions.fontBase,
        ),
        tabs: const [
          Tab(text: AppStrings.units),
          Tab(text: AppStrings.propertyDetails),
        ],
      ),
    );
  }
}

// ── Units tab ─────────────────────────────────────────────────────────

class _UnitsTab extends StatelessWidget {
  const _UnitsTab({required this.property, required this.isMobile});

  final Property property;
  final bool isMobile;

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
                Text(
                  '${property.units.length} ${AppStrings.units}',
                  style: const TextStyle(
                    fontSize: AppDimensions.fontMD,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                AppButton(
                  label: 'Add Unit',
                  icon: Icons.add,
                  small: true,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            isMobile
                ? _UnitCardList(units: property.units)
                : _UnitTable(units: property.units),
          ],
        ),
      ),
    );
  }
}

class _UnitTable extends StatelessWidget {
  const _UnitTable({required this.units});

  final List<Unit> units;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────────────
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
                _HeaderCell(label: AppStrings.unitNumber, flex: 2),
                _HeaderCell(label: AppStrings.bedrooms, flex: 1),
                _HeaderCell(label: AppStrings.bathrooms, flex: 1),
                _HeaderCell(label: AppStrings.rentAmount, flex: 2),
                _HeaderCell(label: AppStrings.status, flex: 2),
              ],
            ),
          ),

          // ── Data rows ──────────────────────────────────────────
          ...units.asMap().entries.map((e) {
            final i = e.key;
            final unit = e.value;
            return Container(
              decoration: BoxDecoration(
                border: i < units.length - 1
                    ? const Border(
                        bottom: BorderSide(color: AppColors.border),
                      )
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMD,
                  vertical: AppDimensions.spaceMD,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Unit ${unit.unitNumber}',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontBase,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${unit.bedrooms} bd',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontBase,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${unit.bathrooms} ba',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontBase,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        fmt.format(unit.rentAmount),
                        style: const TextStyle(
                          fontSize: AppDimensions.fontBase,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: StatusBadge(
                        status: unit.status == 'occupied'
                            ? PropertyStatus.occupied
                            : unit.status == 'pending'
                                ? PropertyStatus.pending
                                : PropertyStatus.vacant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, this.flex = 1});

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

class _UnitCardList extends StatelessWidget {
  const _UnitCardList({required this.units});

  final List<Unit> units;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    return Column(
      children: units.map((unit) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.spaceSM),
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit ${unit.unitNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${unit.bedrooms} bd · ${unit.bathrooms} ba · ${fmt.format(unit.rentAmount)}/mo',
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSM,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                status: unit.status == 'occupied'
                    ? PropertyStatus.occupied
                    : unit.status == 'pending'
                        ? PropertyStatus.pending
                        : PropertyStatus.vacant,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Info tab ──────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(
              title: 'Property Information',
              rows: [
                _InfoRow(label: AppStrings.address, value: property.address),
                _InfoRow(
                    label: AppStrings.propertyType,
                    value: property.propertyType),
                if (property.yearBuilt != null)
                  _InfoRow(
                    label: AppStrings.yearBuilt,
                    value: '${property.yearBuilt}',
                  ),
                _InfoRow(
                  label: AppStrings.totalUnits,
                  value: '${property.totalUnits}',
                ),
              ],
            ),
            if (property.amenities.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spaceMD),
              _AmenitiesCard(amenities: property.amenities),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

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
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: AppDimensions.fontMD,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

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
            width: 160,
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
              style: const TextStyle(
                fontSize: AppDimensions.fontBase,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenitiesCard extends StatelessWidget {
  const _AmenitiesCard({required this.amenities});

  final List<String> amenities;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.amenities,
            style: TextStyle(
              fontSize: AppDimensions.fontMD,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMD),
          Wrap(
            spacing: AppDimensions.spaceSM,
            runSpacing: AppDimensions.spaceSM,
            children: amenities.map((a) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.progressCardBg,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                ),
                child: Text(
                  a,
                  style: const TextStyle(
                    fontSize: AppDimensions.fontSM,
                    color: AppColors.textGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
