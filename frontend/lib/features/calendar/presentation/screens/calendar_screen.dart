import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/entities/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../widgets/create_event_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<CalendarProvider>().load());
  }

  @override
  Widget build(BuildContext context) => const _CalendarBody();
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, p, _) => Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(provider: p),
            if (p.isLoading)
              const LinearProgressIndicator(
                  color: AppColors.accentGold, minHeight: 2),
            const SizedBox(height: AppDimensions.spaceLG),
            Expanded(
              child: LayoutBuilder(builder: (_, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _MonthGrid(provider: p)),
                      const SizedBox(width: AppDimensions.spaceLG),
                      SizedBox(
                        width: 280,
                        child: _EventsSidebar(provider: p),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _MonthGrid(provider: p),
                    const SizedBox(height: AppDimensions.spaceLG),
                    Expanded(child: _EventsSidebar(provider: p)),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.provider});
  final CalendarProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Calendar',
            style: TextStyle(
                fontSize: AppDimensions.fontH2,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const Spacer(),
        TextButton.icon(
          onPressed: () async {
            await provider.syncFromLeases();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Lease & rent events synced'),
                backgroundColor: AppColors.success,
              ));
            }
          },
          icon: const Icon(Icons.sync_rounded, size: 15),
          label: const Text('Sync Leases', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => CreateEventDialog(provider: provider),
          ),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New Event'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentGold,
            foregroundColor: AppColors.bgOuter,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── Month grid ────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.provider});
  final CalendarProvider provider;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final month = provider.focusedMonth;
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final firstDay = DateTime(month.year, month.month, 1);
    // Monday-based: Mon=0 … Sun=6
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Month navigation
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: AppColors.textMuted, size: 20),
                  onPressed: provider.prevMonth,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                Text(monthLabel,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted, size: 20),
                  onPressed: provider.nextMonth,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Weekday headers
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: _weekdays
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // Day cells
          ...List.generate(rows, (rowIdx) {
            return Row(
              children: List.generate(7, (colIdx) {
                final cellIdx = rowIdx * 7 + colIdx;
                final dayNum = cellIdx - startOffset + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 52));
                }
                final cellDate = DateTime(month.year, month.month, dayNum);
                final isToday = cellDate.year == today.year &&
                    cellDate.month == today.month &&
                    cellDate.day == today.day;
                final isSelected = provider.selectedDay != null &&
                    cellDate.year == provider.selectedDay!.year &&
                    cellDate.month == provider.selectedDay!.month &&
                    cellDate.day == provider.selectedDay!.day;
                final events = provider.eventsForDay(cellDate);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => provider.selectDay(cellDate),
                    child: Container(
                      height: 52,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentGold
                            : isToday
                                ? AppColors.accentGoldDark
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$dayNum',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isToday || isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.bgOuter
                                      : AppColors.textPrimary)),
                          if (events.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: events
                                  .take(3)
                                  .map((e) => Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.bgOuter
                                              : _eventColor(e.eventType),
                                          shape: BoxShape.circle,
                                        ),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Events sidebar ────────────────────────────────────────────────────────────

class _EventsSidebar extends StatelessWidget {
  const _EventsSidebar({required this.provider});
  final CalendarProvider provider;

  @override
  Widget build(BuildContext context) {
    final selected = provider.selectedDay;
    final events =
        selected != null ? provider.selectedDayEvents : provider.upcomingEvents;
    final title = selected != null
        ? DateFormat('EEE, d MMM').format(selected)
        : 'Upcoming Events';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text('No events',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
          )
        else
          ...events.map((e) => _EventTile(
                event: e,
                onDelete: () => provider.deleteEvent(e.id),
              )),
        // Legend
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: const [
            _DotLegend(color: AppColors.accentGold, label: 'Renewal'),
            _DotLegend(color: AppColors.info, label: 'Rent Due'),
            _DotLegend(color: AppColors.warning, label: 'Inspection'),
            _DotLegend(color: AppColors.error, label: 'Maintenance'),
            _DotLegend(color: AppColors.accentSilver, label: 'Meeting'),
          ],
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onDelete});
  final CalendarEvent event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.eventType);
    final timeFmt = event.allDay
        ? 'All day'
        : DateFormat('h:mm a').format(event.startAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        border: Border(
          left: BorderSide(color: color, width: 3),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(timeFmt,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(event.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.textMuted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _DotLegend extends StatelessWidget {
  const _DotLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _eventColor(EventType type) => switch (type) {
      EventType.leaseRenewal => AppColors.accentGold,
      EventType.paymentDue => AppColors.info,
      EventType.inspection => AppColors.warning,
      EventType.maintenance => AppColors.error,
      EventType.meeting => AppColors.accentSilver,
    };
