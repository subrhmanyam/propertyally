import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Icon container ───────────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.progressCardBg,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
              child: Icon(
                icon,
                size: AppDimensions.iconXL,
                color: AppColors.accentGreen,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceLG),

            // ── Title ────────────────────────────────────────────────
            Text(
              title,
              style: const TextStyle(
                fontSize: AppDimensions.fontH3,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceSM),

            // ── Description ──────────────────────────────────────────
            SizedBox(
              width: 320,
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // ── Action ───────────────────────────────────────────────
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDimensions.spaceLG),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                icon: Icons.add,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
