import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final height = small ? 32.0 : 40.0;
    final hPad = small ? AppDimensions.spaceMD : AppDimensions.spaceLG;
    final fontSize = small ? AppDimensions.fontSM : AppDimensions.fontBase;

    return SizedBox(
      height: height,
      child: switch (variant) {
        AppButtonVariant.primary => _PrimaryBtn(
            label: label,
            onPressed: onPressed,
            icon: icon,
            loading: loading,
            hPad: hPad,
            fontSize: fontSize,
          ),
        AppButtonVariant.secondary => _SecondaryBtn(
            label: label,
            onPressed: onPressed,
            icon: icon,
            loading: loading,
            hPad: hPad,
            fontSize: fontSize,
          ),
        AppButtonVariant.ghost => _GhostBtn(
            label: label,
            onPressed: onPressed,
            icon: icon,
            loading: loading,
            hPad: hPad,
            fontSize: fontSize,
          ),
        AppButtonVariant.danger => _DangerBtn(
            label: label,
            onPressed: onPressed,
            icon: icon,
            loading: loading,
            hPad: hPad,
            fontSize: fontSize,
          ),
      },
    );
  }
}

// ── Button content ────────────────────────────────────────────────────

class _BtnContent extends StatelessWidget {
  const _BtnContent({
    required this.label,
    required this.textColor,
    required this.fontSize,
    required this.loading,
    this.icon,
  });

  final String label;
  final Color textColor;
  final double fontSize;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(textColor),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppDimensions.iconSM, color: textColor),
          const SizedBox(width: AppDimensions.spaceXS),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Variants ──────────────────────────────────────────────────────────

// Primary: silver bg, black text — brand "action" style
class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.onPressed,
    required this.hPad,
    required this.fontSize,
    required this.loading,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final double hPad;
  final double fontSize;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentSilver,
        foregroundColor: AppColors.bgOuter,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: _BtnContent(
        label: label,
        textColor: AppColors.bgOuter,
        fontSize: fontSize,
        loading: loading,
        icon: icon,
      ),
    );
  }
}

// Secondary: transparent, silver border
class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({
    required this.label,
    required this.onPressed,
    required this.hPad,
    required this.fontSize,
    required this.loading,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final double hPad;
  final double fontSize;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentSilver,
        side: const BorderSide(color: AppColors.border),
        padding: EdgeInsets.symmetric(horizontal: hPad),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: _BtnContent(
        label: label,
        textColor: AppColors.textPrimary,
        fontSize: fontSize,
        loading: loading,
        icon: icon,
      ),
    );
  }
}

// Ghost: no bg, no border, muted text
class _GhostBtn extends StatelessWidget {
  const _GhostBtn({
    required this.label,
    required this.onPressed,
    required this.hPad,
    required this.fontSize,
    required this.loading,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final double hPad;
  final double fontSize;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: _BtnContent(
        label: label,
        textColor: AppColors.textMuted,
        fontSize: fontSize,
        loading: loading,
        icon: icon,
      ),
    );
  }
}

// Danger: error red bg, white text
class _DangerBtn extends StatelessWidget {
  const _DangerBtn({
    required this.label,
    required this.onPressed,
    required this.hPad,
    required this.fontSize,
    required this.loading,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final double hPad;
  final double fontSize;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: _BtnContent(
        label: label,
        textColor: Colors.white,
        fontSize: fontSize,
        loading: loading,
        icon: icon,
      ),
    );
  }
}
