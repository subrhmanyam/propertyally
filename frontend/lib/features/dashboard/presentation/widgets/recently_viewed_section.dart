import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/dashboard_data.dart';

class RecentlyViewedSection extends StatelessWidget {
  const RecentlyViewedSection({super.key, required this.properties});

  final List<RecentProperty> properties;

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
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD,
              vertical: AppDimensions.spaceSM + 2,
            ),
            child: Row(
              children: [
                const Text(
                  AppStrings.recentlyViewed,
                  style: TextStyle(
                    fontSize: AppDimensions.fontMD,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.help_outline_rounded,
                  size: AppDimensions.iconSM,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── 2-column grid of property tiles ──────────────────────
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceXS),
            child: _PropertyGrid(properties: properties),
          ),
        ],
      ),
    );
  }
}

class _PropertyGrid extends StatelessWidget {
  const _PropertyGrid({required this.properties});

  final List<RecentProperty> properties;

  @override
  Widget build(BuildContext context) {
    // Build rows of 2 properties each
    final rows = <Widget>[];
    for (int i = 0; i < properties.length; i += 2) {
      final left = properties[i];
      final right = i + 1 < properties.length ? properties[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(child: _PropertyTile(property: left)),
            if (right != null)
              Expanded(child: _PropertyTile(property: right))
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < properties.length) {
        rows.add(const Divider(height: 1, color: AppColors.divider));
      }
    }
    return Column(children: rows);
  }
}

class _PropertyTile extends StatefulWidget {
  const _PropertyTile({required this.property});

  final RecentProperty property;

  @override
  State<_PropertyTile> createState() => _PropertyTileState();
}

class _PropertyTileState extends State<_PropertyTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered ? AppColors.pageBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceSM,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Property thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                child: widget.property.imageUrl != null
                    ? Image.network(
                        widget.property.imageUrl!,
                        width: AppDimensions.propertyThumbWidth,
                        height: AppDimensions.propertyThumbHeight,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: AppDimensions.propertyThumbWidth,
                        height: AppDimensions.propertyThumbHeight,
                        color: AppColors.progressCardBg,
                        child: const Icon(
                          Icons.home_outlined,
                          color: AppColors.accentGreen,
                          size: AppDimensions.iconMD,
                        ),
                      ),
              ),
              const SizedBox(width: AppDimensions.spaceSM),

              // Name + address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.property.name,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSM,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.property.address,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontXS,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(status: widget.property.status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
