import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/entities/calendar_event.dart';
import '../providers/calendar_provider.dart';

/// Shared "New Event" dialog — used by the calendar screen and the dashboard
/// Events section, both against the same globally-registered [CalendarProvider].
class CreateEventDialog extends StatefulWidget {
  const CreateEventDialog({super.key, required this.provider});
  final CalendarProvider provider;

  @override
  State<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
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
