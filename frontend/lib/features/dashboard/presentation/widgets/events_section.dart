import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../calendar/domain/entities/calendar_event.dart';
import '../../../calendar/presentation/providers/calendar_provider.dart';
import '../../../calendar/presentation/widgets/create_event_dialog.dart';
import '../../../services/presentation/providers/services_provider.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';

/// Merged "Events" feed for the dashboard — combines upcoming calendar
/// events, open service requests (anything not yet Completed/Declined), and
/// open tasks (anything not yet completed/cancelled) into a single,
/// date-sorted list. Replaces the old `TasksSection`, which rendered fake,
/// unpersisted rows disconnected from any real data.
class EventsSection extends StatefulWidget {
  const EventsSection({super.key});

  @override
  State<EventsSection> createState() => _EventsSectionState();
}

class _EventsSectionState extends State<EventsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final services = context.read<ServicesProvider>();
      if (services.requests.isEmpty && !services.isLoading) {
        services.load();
      }
      final calendar = context.read<CalendarProvider>();
      if (calendar.allEvents.isEmpty && !calendar.isLoading) {
        calendar.load();
      }
      final tasks = context.read<TasksProvider>();
      if (tasks.tasks.isEmpty && !tasks.isLoading) {
        tasks.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final services = context.watch<ServicesProvider>();
    final tasks = context.watch<TasksProvider>();

    final items = <_DashboardEventItem>[
      ...calendar.upcomingEvents.map(_fromCalendarEvent),
      ...services.requests
          .where((r) => !{'Completed', 'Declined'}.contains(r['status']))
          .map(_fromServiceRequest),
      ...tasks.tasks
          .where((t) => !{'completed', 'cancelled'}.contains(t.status))
          .map(_fromTask),
    ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));

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
                  AppStrings.events,
                  style: TextStyle(
                    fontSize: AppDimensions.fontMD,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => CreateEventDialog(provider: calendar),
                  ),
                  child: const Text(
                    AppStrings.addEvent,
                    style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textLink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
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
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── Rows ─────────────────────────────────────────────────
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppDimensions.spaceLG),
              child: Text(
                'No upcoming events, service requests, or tasks.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            ...items.take(8).map((item) => _EventRow(item: item)),
        ],
      ),
    );
  }

  _DashboardEventItem _fromCalendarEvent(CalendarEvent event) {
    return _DashboardEventItem(
      kind: _EventKind.calendarEvent,
      title: event.title,
      subtitle: _eventTypeLabel(event.eventType),
      dateTime: event.startAt,
      statusLabel: _eventTypeLabel(event.eventType),
      statusColor: _eventColor(event.eventType),
      onTap: () => context.go('/calendar'),
    );
  }

  _DashboardEventItem _fromServiceRequest(Map<String, dynamic> req) {
    final serviceName = (req['service_catalog'] as Map?)?['name'] as String? ??
        req['service_name'] as String? ??
        'Service request';
    final unitName = (req['leasing_units'] as Map?)?['name'] as String?;
    final status = req['status'] as String? ?? 'Initiated';
    final dateRaw =
        req['initiated_date'] as String? ?? req['created_at'] as String?;
    final date = dateRaw != null ? DateTime.tryParse(dateRaw) : null;
    final id = req['id'] as String?;

    return _DashboardEventItem(
      kind: _EventKind.serviceRequest,
      title: serviceName,
      subtitle: unitName,
      dateTime: date ?? DateTime.now(),
      statusLabel: status,
      statusColor: _serviceStatusColor(status),
      onTap: () => id != null
          ? context.go('/services?request_id=$id')
          : context.go('/services'),
    );
  }

  _DashboardEventItem _fromTask(Task task) {
    return _DashboardEventItem(
      kind: _EventKind.task,
      title: task.title,
      subtitle: task.assignedTo,
      dateTime: task.dueDate ?? task.createdAt ?? DateTime.now(),
      statusLabel: task.status,
      statusColor: _taskStatusColor(task.status),
      onTap: () => context.go('/tasks'),
    );
  }
}

enum _EventKind { calendarEvent, serviceRequest, task }

class _DashboardEventItem {
  const _DashboardEventItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.dateTime,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final _EventKind kind;
  final String title;
  final String? subtitle;
  final DateTime dateTime;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.item});

  final _DashboardEventItem item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      _EventKind.calendarEvent => Icons.event_outlined,
      _EventKind.serviceRequest => Icons.build_outlined,
      _EventKind.task => Icons.check_circle_outline,
    };
    final dateLabel = DateFormat('dd MMM').format(item.dateTime);

    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceMD,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppDimensions.spaceSM),
            Expanded(
              flex: 3,
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.subtitle ?? '—',
                style: const TextStyle(
                  fontSize: AppDimensions.fontSM,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(dateLabel,
                style: const TextStyle(
                    fontSize: AppDimensions.fontXS,
                    color: AppColors.textMuted)),
            const SizedBox(width: AppDimensions.spaceSM),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: item.statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.statusLabel.toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: item.statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _eventTypeLabel(EventType type) => switch (type) {
      EventType.leaseRenewal => 'Lease Renewal',
      EventType.paymentDue => 'Payment Due',
      EventType.inspection => 'Inspection',
      EventType.maintenance => 'Maintenance',
      EventType.meeting => 'Meeting',
    };

Color _eventColor(EventType type) => switch (type) {
      EventType.leaseRenewal => AppColors.accentGold,
      EventType.paymentDue => AppColors.info,
      EventType.inspection => AppColors.warning,
      EventType.maintenance => AppColors.error,
      EventType.meeting => AppColors.accentSilver,
    };

Color _serviceStatusColor(String status) => switch (status) {
      'Review' => AppColors.warning,
      'Approved' => AppColors.info,
      'In progress' => AppColors.accentGold,
      _ => AppColors.textMuted, // Initiated
    };

Color _taskStatusColor(String status) => switch (status) {
      'in_progress' => AppColors.accentGold,
      _ => AppColors.textMuted, // open
    };
