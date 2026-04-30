import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/services_provider.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<ServicesProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServicesProvider>(
      builder: (context, p, _) => Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Service Requests',
                  style: TextStyle(
                      fontSize: AppDimensions.fontH2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Request'),
                  onPressed: () => _showNewRequestDialog(context, p),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSilver,
                    foregroundColor: AppColors.bgOuter,
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLG),

            // ── KPI strip ────────────────────────────────────────
            _KpiStrip(requests: p.requests),
            const SizedBox(height: AppDimensions.spaceLG),

            // ── Filter chips ─────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in [
                    ('all', 'All'),
                    ('open', 'Open'),
                    ('in_progress', 'In Progress'),
                    ('completed', 'Completed'),
                    ('cancelled', 'Cancelled'),
                  ])
                    _FilterChip(
                      label: f.$2,
                      selected: p.statusFilter == f.$1,
                      onTap: () => p.setFilter(f.$1),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceLG),

            // ── List ─────────────────────────────────────────────
            if (p.isLoading)
              const Expanded(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accentSilver)),
              )
            else if (p.filtered.isEmpty)
              const Expanded(
                child: Center(
                    child: Text('No service requests.',
                        style: TextStyle(color: AppColors.textMuted))),
              )
            else
              Expanded(
                child: _RequestsTable(
                  requests: p.filtered,
                  onStatusChange: (id, status) => p.updateStatus(id, status),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── New request dialog ─────────────────────────────────────────
  void _showNewRequestDialog(BuildContext ctx, ServicesProvider p) {
    showDialog(
      context: ctx,
      builder: (_) => _NewRequestDialog(provider: p),
    );
  }
}

// ── KPI strip ─────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.requests});

  final List<Map<String, dynamic>> requests;

  @override
  Widget build(BuildContext context) {
    final open = requests.where((r) => r['status'] == 'open').length;
    final inProgress =
        requests.where((r) => r['status'] == 'in_progress').length;
    final completed =
        requests.where((r) => r['status'] == 'completed').length;
    final urgent = requests
        .where((r) => r['priority'] == 'urgent' && r['status'] != 'completed')
        .length;

    return Row(
      children: [
        _Kpi('Open', open, AppColors.vacantText),
        const SizedBox(width: AppDimensions.spaceMD),
        _Kpi('In Progress', inProgress, AppColors.info),
        const SizedBox(width: AppDimensions.spaceMD),
        _Kpi('Completed', completed, AppColors.occupiedText),
        const SizedBox(width: AppDimensions.spaceMD),
        _Kpi('Urgent', urgent, AppColors.error),
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

// ── Filter chip ────────────────────────────────────────────────────

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
              color:
                  selected ? AppColors.accentSilver : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: AppDimensions.fontSM,
                fontWeight: FontWeight.w500,
                color:
                    selected ? AppColors.bgOuter : AppColors.textMuted)),
      ),
    );
  }
}

// ── Requests table ─────────────────────────────────────────────────

class _RequestsTable extends StatelessWidget {
  const _RequestsTable(
      {required this.requests, required this.onStatusChange});

  final List<Map<String, dynamic>> requests;
  final void Function(String id, String status) onStatusChange;

  static const _statuses = [
    'open',
    'in_progress',
    'on_hold',
    'completed',
    'cancelled'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceLG,
              vertical: AppDimensions.spaceSM),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: _ColHeader('Service')),
              Expanded(flex: 2, child: _ColHeader('Unit')),
              Expanded(flex: 2, child: _ColHeader('Tenant')),
              Expanded(flex: 1, child: _ColHeader('Priority')),
              Expanded(flex: 2, child: _ColHeader('Status')),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.border, height: 1),
            itemBuilder: (_, i) => _RequestRow(
              req: requests[i],
              onStatusChange: onStatusChange,
              statuses: _statuses,
            ),
          ),
        ),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: AppDimensions.fontSM,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.3));
}

class _RequestRow extends StatefulWidget {
  const _RequestRow(
      {required this.req,
      required this.onStatusChange,
      required this.statuses});

  final Map<String, dynamic> req;
  final void Function(String id, String status) onStatusChange;
  final List<String> statuses;

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final status = req['status'] as String? ?? 'open';
    final priority = req['priority'] as String? ?? 'normal';
    final tenant = req['tenants'] as Map?;
    final tenantName = tenant != null
        ? '${tenant['first_name'] ?? ''} ${tenant['last_name'] ?? ''}'.trim()
        : '—';
    final serviceName =
        (req['service_catalog'] as Map?)?['name'] as String? ??
            req['service_name'] as String? ??
            '—';
    final unit = req['leasing_unit_id'] as String? ?? '—';

    final priorityColor = switch (priority) {
      'urgent' => AppColors.error,
      'high' => AppColors.warning,
      _ => AppColors.textMuted,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? AppColors.sidebarItemHover : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceLG,
            vertical: AppDimensions.spaceMD),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(serviceName,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(unit,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(tenantName,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: Text(priority.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor)),
            ),
            Expanded(
              flex: 2,
              child: _hovered
                  ? PopupMenuButton<String>(
                      color: AppColors.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusXS),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onSelected: (s) =>
                          widget.onStatusChange(req['id'] as String, s),
                      itemBuilder: (_) => widget.statuses
                          .map((s) => PopupMenuItem(
                                value: s,
                                child: Text(
                                  s.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSM,
                                    color: s == status
                                        ? AppColors.accentSilver
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ))
                          .toList(),
                      child: _StatusBadge(status),
                    )
                  : _StatusBadge(status),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'completed' => (AppColors.occupiedBg, AppColors.occupiedText),
      'in_progress' => (const Color(0xFF0A1A2E), AppColors.info),
      'cancelled' => (AppColors.sidebarItemActive, AppColors.textMuted),
      'on_hold' => (AppColors.pendingBg, AppColors.pendingText),
      _ => (AppColors.vacantBg, AppColors.vacantText),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_drop_down,
            size: 16, color: AppColors.textMuted),
      ],
    );
  }
}

// ── New request dialog ─────────────────────────────────────────────

class _NewRequestDialog extends StatefulWidget {
  const _NewRequestDialog({required this.provider});

  final ServicesProvider provider;

  @override
  State<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends State<_NewRequestDialog> {
  String? _selectedUnitId;
  String? _selectedServiceId;
  String? _selectedServiceName;
  String _priority = 'normal';
  final _descCtrl = TextEditingController();
  List<Map<String, dynamic>> _catalog = [];
  bool _loadingCatalog = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    // If units weren't loaded yet (dialog opened before load() completed), fetch them now
    if (widget.provider.units.isEmpty) {
      widget.provider.loadUnits();
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog({String? category}) async {
    setState(() => _loadingCatalog = true);
    final catalog = await widget.provider.getCatalog(category: category);
    if (mounted) {
      setState(() {
        _catalog = catalog;
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _onUnitSelected(String unitId) async {
    setState(() {
      _selectedUnitId = unitId;
      _selectedServiceId = null;
      _selectedServiceName = null;
    });
    final units = widget.provider.units;
    final unit = units.firstWhere((u) => u['id'] == unitId, orElse: () => {});
    final category = unit['category'] as String?;
    await _loadCatalog(category: category);
  }

  Future<void> _submit() async {
    if (_selectedUnitId == null || _selectedServiceId == null) return;
    setState(() => _submitting = true);
    try {
      await widget.provider.createRequest(
        leasingUnitId: _selectedUnitId!,
        serviceId: _selectedServiceId,
        serviceName: _selectedServiceName,
        description: _descCtrl.text.trim(),
        priority: _priority,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider so dropdown rebuilds when units finish loading
    final units = context.watch<ServicesProvider>().units;
    final canSubmit =
        _selectedUnitId != null && _selectedServiceId != null && !_submitting;

    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD)),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spaceLG,
                  AppDimensions.spaceLG,
                  AppDimensions.spaceLG,
                  AppDimensions.spaceMD),
              child: Row(
                children: [
                  const Text('New Service Request',
                      style: TextStyle(
                          fontSize: AppDimensions.fontH3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // ── Scrollable body ────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spaceLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Property / Unit picker
                    _Label('Property / Unit *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedUnitId,
                      dropdownColor: AppColors.cardBg,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppDimensions.fontSM),
                      decoration: _dec('Select a property / unit...'),
                      items: units
                          .map((u) => DropdownMenuItem(
                                value: u['id'] as String,
                                child: Text(
                                    '${u['name']}  —  ${u['category']}  (Floor ${u['floor']})'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _onUnitSelected(v);
                      },
                    ),
                    const SizedBox(height: AppDimensions.spaceLG),

                    // Service catalog grid
                    Row(
                      children: [
                        _Label('Select Service *'),
                        if (_selectedUnitId != null) ...[
                          const SizedBox(width: 8),
                          const Text('— filtered by unit type',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingCatalog)
                      const SizedBox(
                        height: 80,
                        child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentSilver),
                        ),
                      )
                    else if (_catalog.isEmpty)
                      Container(
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.pageBg,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusXS),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'No services available for this unit type.',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: AppDimensions.fontSM),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3.8,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _catalog.length,
                        itemBuilder: (_, i) {
                          final svc = _catalog[i];
                          final sid = svc['id'] as String;
                          final selected = _selectedServiceId == sid;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedServiceId = sid;
                              _selectedServiceName =
                                  svc['name'] as String?;
                            }),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.sidebarItemActive
                                    : AppColors.pageBg,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.accentSilver
                                      : AppColors.border,
                                  width: selected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusXS),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _iconFor(
                                        svc['category'] as String? ??
                                            ''),
                                    size: 16,
                                    color: selected
                                        ? AppColors.accentSilver
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          svc['name'] as String? ?? '',
                                          style: TextStyle(
                                            fontSize:
                                                AppDimensions.fontSM,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? AppColors.accentSilver
                                                : AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          svc['category'] as String? ??
                                              '',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color:
                                                  AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    const Icon(Icons.check_circle,
                                        size: 14,
                                        color: AppColors.accentSilver),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: AppDimensions.spaceLG),

                    // Description
                    _Label('Description (optional)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppDimensions.fontSM),
                      decoration:
                          _dec('Describe the issue or requirement...'),
                    ),
                    const SizedBox(height: AppDimensions.spaceMD),

                    // Priority
                    _Label('Priority'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      dropdownColor: AppColors.cardBg,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppDimensions.fontSM),
                      decoration: _dec(''),
                      items: ['normal', 'high', 'urgent']
                          .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                  v[0].toUpperCase() + v.substring(1))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _priority = v ?? 'normal'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Action bar ─────────────────────────────────────
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: AppDimensions.spaceSM),
                  ElevatedButton(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentSilver,
                      foregroundColor: AppColors.bgOuter,
                      disabledBackgroundColor:
                          AppColors.sidebarItemActive,
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.bgOuter))
                        : const Text('Submit Request'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String category) => switch (category.toLowerCase()) {
      'construction' || 'carpentry' => Icons.handyman_outlined,
      'electrical' || 'electrical maintenance' => Icons.electrical_services_outlined,
      'plumbing' => Icons.plumbing_outlined,
      'hvac' || 'air conditioning' => Icons.ac_unit_outlined,
      'cleaning' => Icons.cleaning_services_outlined,
      'it support' || 'networking' => Icons.computer_outlined,
      'security' => Icons.security_outlined,
      'decoration' || 'interior' => Icons.format_paint_outlined,
      'pest control' => Icons.pest_control_outlined,
      _ => Icons.home_repair_service_outlined,
    };

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppColors.pageBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.accentSilver),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
    );

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: AppDimensions.fontSM,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary));
}
