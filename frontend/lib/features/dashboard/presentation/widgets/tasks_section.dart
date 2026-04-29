import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/dashboard_data.dart';

class TasksSection extends StatelessWidget {
  const TasksSection({super.key, required this.tasks});

  final List<DashboardTask> tasks;

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
                  AppStrings.tasks,
                  style: TextStyle(
                    fontSize: AppDimensions.fontMD,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Add task
                GestureDetector(
                  onTap: () => context.go('/calendar'),
                  child: const Text(
                    AppStrings.addTask,
                    style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textLink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                // View all
                GestureDetector(
                  onTap: () => context.go('/calendar'),
                  child: const Text(
                    AppStrings.viewAll,
                    style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textLink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceXS),
                const Icon(
                  Icons.refresh_rounded,
                  size: AppDimensions.iconSM,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── Task rows ────────────────────────────────────────────
          ...tasks.map((task) => _TaskRow(task: task)),
        ],
      ),
    );
  }
}

class _TaskRow extends StatefulWidget {
  const _TaskRow({required this.task});

  final DashboardTask task;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _checked = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? AppColors.pageBg : Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD,
                vertical: 10,
              ),
              child: Row(
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: () => setState(() => _checked = !_checked),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _checked ? AppColors.accentGreen : Colors.transparent,
                        border: Border.all(
                          color: _checked
                              ? AppColors.accentGreen
                              : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: _checked
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceSM),

                  // Task name
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Text(
                          widget.task.title,
                          style: TextStyle(
                            fontSize: AppDimensions.fontBase,
                            color: _checked
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            decoration:
                                _checked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (widget.task.isRecurring) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.loop_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Property info
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.propertyName,
                          style: const TextStyle(
                            fontSize: AppDimensions.fontSM,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.task.propertyAddress,
                          style: const TextStyle(
                            fontSize: AppDimensions.fontXS,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Avatar
                  CircleAvatar(
                    radius: AppDimensions.avatarSM / 2,
                    backgroundColor: AppColors.accentGreenLight,
                    child: Text(
                      widget.task.avatarInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
          ],
        ),
      ),
    );
  }
}
