import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../presentation/providers/tasks_provider.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TasksProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksProvider>(
      builder: (context, provider, _) => Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Tasks',
                  style: TextStyle(
                      fontSize: AppDimensions.fontH2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Task'),
                  onPressed: () => _showNewTaskDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSilver,
                    foregroundColor: AppColors.bgOuter,
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLG),
            _TaskKpiStrip(tasks: provider.tasks),
            const SizedBox(height: AppDimensions.spaceLG),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in [
                    ('all', 'All'),
                    ('open', 'Open'),
                    ('in_progress', 'In Progress'),
                    ('completed', 'Completed'),
                    ('cancelled', 'Cancelled'),
                  ])
                    _FilterChip(
                      label: filter.$2,
                      selected: provider.statusFilter == filter.$1,
                      onTap: () => provider.setFilter(filter.$1),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceLG),
            Expanded(
              child: provider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentSilver))
                  : provider.filtered.isEmpty
                      ? const Center(
                          child: Text('No tasks found.',
                              style: TextStyle(color: AppColors.textMuted)))
                      : _TasksTable(
                          tasks: provider.filtered,
                          onStatusChange: provider.updateTaskStatus,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _NewTaskDialog(),
    );
  }
}

class _TaskKpiStrip extends StatelessWidget {
  const _TaskKpiStrip({required this.tasks});

  final List<dynamic> tasks;

  @override
  Widget build(BuildContext context) {
    final open = tasks.where((t) => t.status == 'open').length;
    final inProgress = tasks.where((t) => t.status == 'in_progress').length;
    final completed = tasks.where((t) => t.status == 'completed').length;
    final overdue = tasks
        .where((t) =>
            t.status != 'completed' &&
            t.dueDate != null &&
            t.dueDate!.isBefore(DateTime.now()))
        .length;

    return Row(
      children: [
        _Kpi('Open', open, AppColors.vacantText),
        const SizedBox(width: AppDimensions.spaceMD),
        _Kpi('In Progress', inProgress, AppColors.info),
        const SizedBox(width: AppDimensions.spaceMD),
        _Kpi('Completed', completed, AppColors.occupiedText),
        const SizedBox(width: AppDimensions.spaceMD),
        _Kpi('Overdue', overdue, AppColors.error),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceLG, vertical: AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: AppDimensions.fontH2,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: AppDimensions.fontSM, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: AppDimensions.spaceSM),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceMD, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSilver : AppColors.cardBg,
          border: Border.all(
              color: selected ? AppColors.accentSilver : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: AppDimensions.fontSM,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.bgOuter : AppColors.textMuted)),
      ),
    );
  }
}

class _TasksTable extends StatelessWidget {
  const _TasksTable({required this.tasks, required this.onStatusChange});

  final List<dynamic> tasks;
  final void Function(String id, String status) onStatusChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceLG,
              vertical: AppDimensions.spaceSM),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: const Row(
            children: [
              Expanded(
                  flex: 3,
                  child: Text('Task',
                      style: TextStyle(
                          fontSize: AppDimensions.fontSM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted))),
              Expanded(
                  flex: 2,
                  child: Text('Property / Unit',
                      style: TextStyle(
                          fontSize: AppDimensions.fontSM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted))),
              Expanded(
                  flex: 2,
                  child: Text('Due',
                      style: TextStyle(
                          fontSize: AppDimensions.fontSM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted))),
              Expanded(
                  flex: 1,
                  child: Text('Priority',
                      style: TextStyle(
                          fontSize: AppDimensions.fontSM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted))),
              Expanded(
                  flex: 2,
                  child: Text('Status',
                      style: TextStyle(
                          fontSize: AppDimensions.fontSM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted))),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.border, height: 1),
            itemBuilder: (_, index) {
              final task = tasks[index];
              return _TaskRow(task: task, onStatusChange: onStatusChange);
            },
          ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onStatusChange});

  final dynamic task;
  final void Function(String id, String status) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final dueDate = task.dueDate != null
        ? '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}'
        : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceLG, vertical: AppDimensions.spaceMD),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(task.title,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 2,
              child: Text(
                  '${task.propertyId ?? '-'} ${task.leasingUnitId ?? ''}',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 2,
              child: Text(dueDate,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted))),
          Expanded(
              flex: 1,
              child: Text(task.priority.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary))),
          Expanded(
              flex: 2,
              child: PopupMenuButton<String>(
                onSelected: (s) => onStatusChange(task.id as String, s),
                itemBuilder: (_) => [
                  'open',
                  'in_progress',
                  'completed',
                  'cancelled'
                ]
                    .map((status) => PopupMenuItem(
                        value: status,
                        child: Text(status.replaceAll('_', ' ').toUpperCase())))
                    .toList(),
                child: _StatusBadge(task.status as String),
              )),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (status) {
      'completed' => AppColors.occupiedBg,
      'in_progress' => AppColors.info,
      'cancelled' => AppColors.sidebarItemActive,
      _ => AppColors.vacantBg,
    };
    final foregroundColor = switch (status) {
      'completed' => AppColors.occupiedText,
      'in_progress' => AppColors.textPrimary,
      'cancelled' => AppColors.textMuted,
      _ => AppColors.vacantText,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS)),
      child: Text(status.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: foregroundColor)),
    );
  }
}

class _NewTaskDialog extends StatefulWidget {
  const _NewTaskDialog();

  @override
  State<_NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<_NewTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _propertyId;
  String? _leasingUnitId;
  String? _assignedTo;
  String _priority = 'medium';
  String _status = 'open';
  String _recurringRule = '';
  DateTime? _dueDate;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await context.read<TasksProvider>().createTask(
            title: _titleCtrl.text.trim(),
            description: _descriptionCtrl.text.trim(),
            propertyId: _propertyId,
            leasingUnitId: _leasingUnitId,
            assignedTo: _assignedTo,
            priority: _priority,
            status: _status,
            dueDate: _dueDate?.toIso8601String(),
            recurringRule: _recurringRule.isNotEmpty ? _recurringRule : null,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving task: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<TasksProvider>().units;
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      title: const Text('New Task',
          style: TextStyle(color: AppColors.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleCtrl, decoration: _dec('Task title')),
            const SizedBox(height: AppDimensions.spaceMD),
            TextField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: _dec('Details')),
            const SizedBox(height: AppDimensions.spaceMD),
            DropdownButtonFormField<String>(
              value: _priority,
              dropdownColor: AppColors.cardBg,
              decoration: _dec('Priority'),
              items: ['low', 'medium', 'high', 'urgent']
                  .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p[0].toUpperCase() + p.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? 'medium'),
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            DropdownButtonFormField<String>(
              value: _status,
              dropdownColor: AppColors.cardBg,
              decoration: _dec('Status'),
              items: ['open', 'in_progress', 'completed', 'cancelled']
                  .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p[0].toUpperCase() + p.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? 'open'),
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            DropdownButtonFormField<String>(
              value: _leasingUnitId,
              dropdownColor: AppColors.cardBg,
              decoration: _dec('Assign to unit (optional)'),
              items: units
                  .map((u) => DropdownMenuItem(
                      value: u['id'] as String,
                      child: Text(u['name']?.toString() ??
                          u['id']?.toString() ??
                          'Unit')))
                  .toList(),
              onChanged: (v) => setState(() => _leasingUnitId = v),
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            TextField(
              decoration: _dec('Assign to team member (optional)'),
              onChanged: (value) => _assignedTo = value,
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                    border: Border.all(color: AppColors.border)),
                child: Text(
                    _dueDate != null
                        ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                        : 'Due date (optional)',
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            TextField(
                controller: TextEditingController(text: _recurringRule),
                decoration: _dec('Recurring rule (e.g. monthly)'),
                onChanged: (value) => _recurringRule = value),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentSilver,
                foregroundColor: AppColors.bgOuter,
                elevation: 0),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.bgOuter))
                : const Text('Create')),
      ],
    );
  }
}

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppColors.pageBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS)),
      enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS)),
      focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.accentSilver),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS)),
    );
