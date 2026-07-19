import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/entities/calendar_event.dart';
import '../providers/calendar_provider.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CalendarProvider()..load(),
      child: const _CalendarBody(),
    );
  }
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
          onPressed: () => _showCreateDialog(context, provider),
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

// ── Create event dialog ───────────────────────────────────────────────────────

void _showCreateDialog(BuildContext context, CalendarProvider provider) {
  showDialog<void>(
    context: context,
    builder: (_) => _CreateEventDialog(provider: provider),
  );
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({required this.provider});
  final CalendarProvider provider;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  EventType _type = EventType.meeting;
  DateTime _date = DateTime.now();
  bool _allDay = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          side: const BorderSide(color: AppColors.border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Event',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: AppDimensions.spaceMD),
              _Field(
                label: 'Title',
                controller: _titleCtrl,
              ),
              const SizedBox(height: AppDimensions.spaceSM),
              _Field(
                label: 'Description (optional)',
                controller: _descCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: AppDimensions.spaceSM),
              _DropdownField<EventType>(
                label: 'Type',
                value: _type,
                items: const [
                  (EventType.meeting, 'Meeting'),
                  (EventType.inspection, 'Inspection'),
                  (EventType.paymentDue, 'Payment Due'),
                  (EventType.leaseRenewal, 'Lease Renewal'),
                  (EventType.maintenance, 'Maintenance'),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: AppDimensions.spaceSM),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                          builder: (_, child) => Theme(
                            data: ThemeData.dark(),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: Text(DateFormat('dd MMM yyyy').format(_date),
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _allDay,
                        onChanged: (v) => setState(() => _allDay = v ?? true),
                        activeColor: AppColors.accentGold,
                      ),
                      const Text('All day',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceLG),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _titleCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            final event = CalendarEvent(
                              id: '',
                              title: _titleCtrl.text.trim(),
                              description: _descCtrl.text.trim().isEmpty
                                  ? null
                                  : _descCtrl.text.trim(),
                              eventType: _type,
                              startAt: DateTime(
                                  _date.year, _date.month, _date.day, 9),
                              allDay: _allDay,
                            );
                            await widget.provider.addEvent(event);
                            if (context.mounted) Navigator.pop(context);
                          },
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: AppColors.bgOuter),
                    child: const Text('Create',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.label, required this.controller, this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.pageBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      );
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<(T, String)> items;
  final void Function(T?) onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.cardBg,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                items: items
                    .map((i) => DropdownMenuItem<T>(
                          value: i.$1,
                          child: Text(i.$2),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
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
