import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/dashboard_data.dart';

class TodayCard extends StatefulWidget {
  const TodayCard({super.key, required this.data});

  final DashboardData data;

  @override
  State<TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<TodayCard> {
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
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: AppDimensions.iconMD,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        TextSpan(
                          text: widget.data.todayDate,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: 'You have ',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        TextSpan(
                          text: '${widget.data.reminderCount} reminder',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const TextSpan(
                          text: ' for Today.  ',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () {},
                            child: const Text(
                              AppStrings.viewAll,
                              style: TextStyle(
                                color: AppColors.textLink,
                                fontWeight: FontWeight.w500,
                                fontSize: AppDimensions.fontBase,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── Onboarding progress card ─────────────────────────────
          _OnboardingCard(data: widget.data),
        ],
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: const BoxDecoration(
        color: AppColors.progressCardBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.radiusMD),
          bottomRight: Radius.circular(AppDimensions.radiusMD),
        ),
      ),
      child: Column(
        children: [
          // ── Progress header ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(data.onboardingProgress * 100).toInt()}% Complete',
                style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGreen,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: AppDimensions.iconMD),
                    onPressed: () {},
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Text(
                    '${data.onboardingStep}/${data.onboardingTotal}',
                    style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: AppDimensions.iconMD),
                    onPressed: () {},
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMD),

          // ── Circular progress illustration ────────────────────
          _ProgressRing(progress: data.onboardingProgress),
          const SizedBox(height: AppDimensions.spaceMD),

          // ── CTA ───────────────────────────────────────────────
          const Text(
            AppStrings.marketProperty,
            style: TextStyle(
              fontSize: AppDimensions.fontLG,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          const Text(
            AppStrings.marketDesc,
            style: TextStyle(
              fontSize: AppDimensions.fontSM,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          GestureDetector(
            onTap: () {},
            child: const Text(
              AppStrings.getStarted,
              style: TextStyle(
                fontSize: AppDimensions.fontBase,
                fontWeight: FontWeight.w600,
                color: AppColors.textLink,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
              SizedBox(width: 4),
              Text(
                AppStrings.estSetup,
                style: TextStyle(
                  fontSize: AppDimensions.fontXS,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring
          SizedBox(
            width: 110,
            height: 110,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentGreen),
              strokeCap: StrokeCap.round,
            ),
          ),
          // House icon placeholder
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.contentBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGreen.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.home_work_outlined,
              size: 36,
              color: AppColors.accentGreen,
            ),
          ),
        ],
      ),
    );
  }
}
