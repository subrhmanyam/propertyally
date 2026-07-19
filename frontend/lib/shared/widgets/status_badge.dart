import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';

enum PropertyStatus { occupied, vacant, pending }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final PropertyStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, textColor, label) = switch (status) {
      PropertyStatus.occupied => (
          AppColors.occupiedBg,
          AppColors.occupiedText,
          AppStrings.occupied
        ),
      PropertyStatus.vacant => (
          AppColors.vacantBg,
          AppColors.vacantText,
          AppStrings.vacant
        ),
      PropertyStatus.pending => (
          AppColors.pendingBg,
          AppColors.pendingText,
          AppStrings.pending
        ),
    };

    return Container(
      height: AppDimensions.badgeHeight,
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
