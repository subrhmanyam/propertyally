import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/property.dart';
import '../providers/properties_provider.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PropertiesProvider>().loadProperties();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PropertiesProvider>(
      builder: (context, provider, _) {
        final isDesktop = Responsive.isDesktop(context);
        final isMobile = Responsive.isMobile(context);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                _ScreenHeader(totalCount: provider.allProperties.length),
                const SizedBox(height: AppDimensions.spaceLG),

                // ── Filter & search row ──────────────────────────────
                _FilterRow(
                  provider: provider,
                  searchController: _searchController,
                ),
                const SizedBox(height: AppDimensions.spaceLG),

                // ── Content ──────────────────────────────────────────
                if (provider.isLoading)
                  const _LoadingGrid()
                else if (provider.properties.isEmpty)
                  EmptyState(
                    icon: Icons.home_outlined,
                    title: AppStrings.noProperties,
                    description: AppStrings.noPropertiesDesc,
                    actionLabel: AppStrings.addProperty,
                    onAction: () {},
                  )
                else
                  _PropertyGrid(
                    properties: provider.properties,
                    crossAxisCount: isDesktop
                        ? 3
                        : isMobile
                            ? 1
                            : 2,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.properties,
              style: TextStyle(
                fontSize: AppDimensions.fontH2,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (totalCount > 0)
              Text(
                '$totalCount properties',
                style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const Spacer(),
        AppButton(
          label: AppStrings.addProperty,
          icon: Icons.add,
          onPressed: () {},
        ),
      ],
    );
  }
}

// ── Filter row ───────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.provider,
    required this.searchController,
  });

  final PropertiesProvider provider;
  final TextEditingController searchController;

  static const _filters = [
    AppStrings.filterAll,
    AppStrings.occupied,
    AppStrings.vacant,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Filter chips ─────────────────────────────────────────
        Wrap(
          spacing: AppDimensions.spaceSM,
          children: _filters.map((f) {
            final active = provider.statusFilter == f;
            return GestureDetector(
              onTap: () => provider.setStatusFilter(f),
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
                  f,
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
            decoration: InputDecoration(
              hintText: AppStrings.searchProperties,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
                size: AppDimensions.iconMD,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Property grid ─────────────────────────────────────────────────────

class _PropertyGrid extends StatelessWidget {
  const _PropertyGrid({
    required this.properties,
    required this.crossAxisCount,
  });

  final List<Property> properties;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppDimensions.spaceMD,
        mainAxisSpacing: AppDimensions.spaceMD,
        childAspectRatio: 1.05,
      ),
      itemCount: properties.length,
      itemBuilder: (context, i) => _PropertyCard(property: properties[i]),
    );
  }
}

// ── Property card ─────────────────────────────────────────────────────

class _PropertyCard extends StatefulWidget {
  const _PropertyCard({required this.property});

  final Property property;

  @override
  State<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<_PropertyCard> {
  bool _hovered = false;

  Property get p => widget.property;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final monthlyRent = p.units.fold<double>(
      0,
      (sum, u) => sum + (u.status == 'occupied' ? u.rentAmount : 0),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/properties/${p.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(
              color: _hovered ? AppColors.accentGreen : AppColors.border,
              width: _hovered ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.accentGreen.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image / placeholder header ───────────────────────
              _PropertyThumb(property: p),

              // ── Body ─────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spaceMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + type chip
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: AppDimensions.fontMD,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spaceXS),
                          _TypeChip(label: p.propertyType),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceXS),

                      // Address
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${p.city}, ${p.state}',
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSM,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Occupancy bar
                      _OccupancyBar(
                        occupied: p.occupiedUnits,
                        total: p.totalUnits,
                        rate: p.occupancyRate,
                      ),
                      const SizedBox(height: AppDimensions.spaceSM),

                      // Stats row
                      Row(
                        children: [
                          _StatChip(
                            icon: Icons.home_work_outlined,
                            value: '${p.totalUnits} units',
                          ),
                          const SizedBox(width: AppDimensions.spaceSM),
                          _StatChip(
                            icon: Icons.attach_money,
                            value: fmt.format(monthlyRent),
                          ),
                        ],
                      ),
                    ],
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

// ── Property thumbnail ────────────────────────────────────────────────

class _PropertyThumb extends StatelessWidget {
  const _PropertyThumb({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    if (property.photos.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusMD),
        ),
        child: Image.network(
          property.photos.first,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _PlaceholderThumb(property: property),
        ),
      );
    }
    return _PlaceholderThumb(property: property);
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.progressCardBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusMD),
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.home_work_outlined,
              size: 48,
              color: AppColors.accentGreen.withValues(alpha: 0.4),
            ),
          ),
          // Status badge top-right
          Positioned(
            top: AppDimensions.spaceSM,
            right: AppDimensions.spaceSM,
            child: StatusBadge(
              status: property.isActive
                  ? PropertyStatus.occupied
                  : PropertyStatus.vacant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Occupancy bar ─────────────────────────────────────────────────────

class _OccupancyBar extends StatelessWidget {
  const _OccupancyBar({
    required this.occupied,
    required this.total,
    required this.rate,
  });

  final int occupied;
  final int total;
  final double rate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$occupied/$total occupied',
              style: const TextStyle(
                fontSize: AppDimensions.fontXS,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              '${rate.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: AppDimensions.fontXS,
                fontWeight: FontWeight.w600,
                color: AppColors.textGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          child: LinearProgressIndicator(
            value: rate / 100,
            minHeight: 5,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(
              rate >= 80
                  ? AppColors.accentGreen
                  : rate >= 50
                      ? AppColors.warning
                      : AppColors.error,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Small reusable chips ──────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.progressCardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: AppDimensions.fontXS,
          color: AppColors.textGreen,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppDimensions.iconSM, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppDimensions.fontXS,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Loading skeleton grid ─────────────────────────────────────────────

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppDimensions.spaceMD,
        mainAxisSpacing: AppDimensions.spaceMD,
        childAspectRatio: 1.05,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
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
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusMD),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(height: 16, width: 140),
                  const SizedBox(height: 8),
                  _ShimmerBox(height: 12, width: 100),
                  const Spacer(),
                  _ShimmerBox(height: 5, width: double.infinity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.height, required this.width});

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
    );
  }
}
