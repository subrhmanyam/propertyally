import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/maintenance_request.dart';
import '../providers/maintenance_provider.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MaintenanceProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.pageBg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(provider: provider),
              if (provider.isLoading)
                const LinearProgressIndicator(
                    color: AppColors.accentGold, minHeight: 2),
              if (provider.hasError)
                _ErrorBanner(message: provider.errorMessage!),
              _KpiStrip(provider: provider),
              _FilterBar(
                  provider: provider, searchController: _searchController),
              Expanded(
                child: provider.filtered.isEmpty && !provider.isLoading
                    ? const _EmptyState()
                    : Responsive.isMobile(context)
                        ? _CardList(requests: provider.filtered)
                        : _RequestTable(requests: provider.filtered),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.provider});

  final MaintenanceProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.pagePadding,
        AppDimensions.pagePadding,
        12,
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maintenance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track and manage repair requests',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon:
                const Icon(Icons.refresh, color: AppColors.textMuted, size: 18),
            tooltip: 'Refresh',
            onPressed: provider.load,
          ),
          const SizedBox(width: 8),
          _NewRequestButton(provider: provider),
        ],
      ),
    );
  }
}

// ── KPI strip ─────────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.provider});

  final MaintenanceProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        0,
        AppDimensions.pagePadding,
        12,
      ),
      child: Row(
        children: [
          _KpiChip(
            label: 'Open',
            value: provider.openCount,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          _KpiChip(
            label: 'In Progress',
            value: provider.inProgressCount,
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          _KpiChip(
            label: 'Urgent',
            value: provider.urgentCount,
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip(
      {required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.provider, required this.searchController});

  final MaintenanceProvider provider;
  final TextEditingController searchController;

  static const _filters = [
    (MaintFilter.all, 'All'),
    (MaintFilter.open, 'Open'),
    (MaintFilter.inProgress, 'In Progress'),
    (MaintFilter.completed, 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        0,
        AppDimensions.pagePadding,
        12,
      ),
      child: Row(
        children: [
          Wrap(
            spacing: 6,
            children: _filters.map((f) {
              final active = provider.filter == f.$1;
              return GestureDetector(
                onTap: () => provider.setFilter(f.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? AppColors.accentSilver : AppColors.cardBg,
                    border: Border.all(
                      color: active ? AppColors.accentSilver : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    f.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          active ? AppColors.bgOuter : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          SizedBox(
            width: 220,
            height: 34,
            child: TextField(
              controller: searchController,
              onChanged: provider.setSearchQuery,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search requests…',
                hintStyle: TextStyle(fontSize: 12),
                prefixIcon:
                    Icon(Icons.search, color: AppColors.textMuted, size: 16),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop table ─────────────────────────────────────────────────────

class _RequestTable extends StatelessWidget {
  const _RequestTable({required this.requests});

  final List<MaintenanceRequest> requests;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.pageBg,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                ),
                child: const Row(
                  children: [
                    _TH(label: 'Title', flex: 4),
                    _TH(label: 'Category', flex: 2),
                    _TH(label: 'Priority', flex: 2),
                    _TH(label: 'Status', flex: 2),
                    _TH(label: 'Assigned To', flex: 2),
                    _TH(label: 'Created', flex: 2),
                    _TH(label: '', flex: 2),
                  ],
                ),
              ),
              ...requests.asMap().entries.map((e) => _RequestRow(
                    req: e.value,
                    isLast: e.key == requests.length - 1,
                  )),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.pagePadding),
      ],
    );
  }
}

class _TH extends StatelessWidget {
  const _TH({required this.label, this.flex = 1});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RequestRow extends StatefulWidget {
  const _RequestRow({required this.req, required this.isLast});

  final MaintenanceRequest req;
  final bool isLast;

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.req;
    final provider = context.read<MaintenanceProvider>();
    final fmt = DateFormat('MMM d, yyyy');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.pageBg : Colors.transparent,
          border: !widget.isLast
              ? const Border(bottom: BorderSide(color: AppColors.border))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textHeading,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (r.description != null)
                    Text(
                      r.description!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                r.category ?? '—',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              flex: 2,
              child: _PriorityBadge(priority: r.priority),
            ),
            Expanded(
              flex: 2,
              child: _StatusBadge(status: r.status),
            ),
            Expanded(
              flex: 2,
              child: Text(
                r.assignedTo ?? '—',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                fmt.format(r.createdAt),
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
            Expanded(
              flex: 2,
              child: _hovered
                  ? _StatusMenu(req: r, provider: provider)
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile card list ──────────────────────────────────────────────────

class _CardList extends StatelessWidget {
  const _CardList({required this.requests});

  final List<MaintenanceRequest> requests;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MaintenanceProvider>();
    return ListView.builder(
      padding:
          const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
      itemCount: requests.length,
      itemBuilder: (context, i) =>
          _RequestCard(req: requests[i], provider: provider),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.req, required this.provider});

  final MaintenanceRequest req;
  final MaintenanceProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  req.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
              _PriorityBadge(priority: req.priority),
            ],
          ),
          if (req.description != null) ...[
            const SizedBox(height: 4),
            Text(
              req.description!,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _StatusBadge(status: req.status),
              if (req.category != null) ...[
                const SizedBox(width: 8),
                Text(req.category!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
              const Spacer(),
              _StatusMenu(req: req, provider: provider),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status change menu ────────────────────────────────────────────────

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.req, required this.provider});

  final MaintenanceRequest req;
  final MaintenanceProvider provider;

  static const _options = [
    ('open', 'Open'),
    ('in_progress', 'In Progress'),
    ('on_hold', 'On Hold'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Change status',
      color: AppColors.cardBg,
      onSelected: (s) => provider.updateStatus(req, s),
      itemBuilder: (_) => _options
          .map((o) => PopupMenuItem(
                value: o.$1,
                child: Text(
                  o.$2,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                ),
              ))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'Update',
            style: TextStyle(fontSize: 11, color: AppColors.accentGold),
          ),
          SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 14, color: AppColors.accentGold),
        ],
      ),
    );
  }
}

// ── New request dialog ────────────────────────────────────────────────

class _NewRequestButton extends StatelessWidget {
  const _NewRequestButton({required this.provider});

  final MaintenanceProvider provider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.accentGoldDark,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.accentGold),
            SizedBox(width: 5),
            Text(
              'New Request',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accentGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _NewRequestDialog(provider: provider),
    );
  }
}

class _NewRequestDialog extends StatefulWidget {
  const _NewRequestDialog({required this.provider});

  final MaintenanceProvider provider;

  @override
  State<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends State<_NewRequestDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _assignedCtrl = TextEditingController();
  String _priority = 'medium';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _assignedCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.provider.createRequest({
        'title': _titleCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'category': _categoryCtrl.text.trim().isEmpty
            ? null
            : _categoryCtrl.text.trim(),
        'assigned_to': _assignedCtrl.text.trim().isEmpty
            ? null
            : _assignedCtrl.text.trim(),
        'priority': _priority,
        'status': 'open',
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      title: const Text(
        'New Maintenance Request',
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeading),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.error)),
              ),
            _Field(label: 'Title *', controller: _titleCtrl),
            const SizedBox(height: 10),
            _Field(label: 'Description', controller: _descCtrl, maxLines: 2),
            const SizedBox(height: 10),
            _Field(
                label: 'Category (e.g. Plumbing, Electrical)',
                controller: _categoryCtrl),
            const SizedBox(height: 10),
            _Field(label: 'Assigned To', controller: _assignedCtrl),
            const SizedBox(height: 10),
            const Text('Priority',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: ['low', 'medium', 'high', 'urgent'].map((p) {
                final active = _priority == p;
                return GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? _priorityColor(p).withValues(alpha: 0.2)
                          : Colors.transparent,
                      border: Border.all(
                        color: active ? _priorityColor(p) : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      p[0].toUpperCase() + p.substring(1),
                      style: TextStyle(
                        fontSize: 11,
                        color: active
                            ? _priorityColor(p)
                            : AppColors.textSecondary,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accentGold),
                )
              : const Text('Create',
                  style: TextStyle(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Color _priorityColor(String p) => switch (p) {
        'low' => AppColors.success,
        'high' => AppColors.warning,
        'urgent' => AppColors.error,
        _ => AppColors.info,
      };
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.label, required this.controller, this.maxLines = 1});

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared badges ─────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final MaintPriority priority;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (priority) {
      MaintPriority.low => (AppColors.success, 'Low'),
      MaintPriority.medium => (AppColors.info, 'Medium'),
      MaintPriority.high => (AppColors.warning, 'High'),
      MaintPriority.urgent => (AppColors.error, 'Urgent'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final MaintStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      MaintStatus.open => (AppColors.pendingBg, AppColors.warning, 'Open'),
      MaintStatus.inProgress => (
          AppColors.info.withValues(alpha: 0.15),
          AppColors.info,
          'In Progress'
        ),
      MaintStatus.onHold => (AppColors.border, AppColors.textMuted, 'On Hold'),
      MaintStatus.completed => (
          AppColors.occupiedBg,
          AppColors.success,
          'Completed'
        ),
      MaintStatus.cancelled => (
          AppColors.error.withValues(alpha: 0.1),
          AppColors.error,
          'Cancelled'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ── Empty & error states ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_outlined, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No maintenance requests',
            style: TextStyle(fontSize: 16, color: AppColors.textMuted),
          ),
          SizedBox(height: 4),
          Text(
            'Tap "New Request" to log a repair or issue.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.pagePadding, vertical: 8),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Text(message,
          style: const TextStyle(fontSize: 12, color: AppColors.error)),
    );
  }
}
