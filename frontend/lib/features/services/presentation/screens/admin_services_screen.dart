import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/network/api_client.dart';
import '../providers/services_provider.dart';

String _errorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return e.message ?? 'Something went wrong.';
  }
  return e.toString();
}

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key, this.initialRequestId});

  /// When set (e.g. from a notification's action_url), the matching
  /// request's detail dialog is opened automatically once loaded.
  final String? initialRequestId;

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  bool _openedInitialRequest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<ServicesProvider>();
      await p.load();
      _maybeOpenInitialRequest(p);
    });
  }

  @override
  void didUpdateWidget(covariant AdminServicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRequestId != oldWidget.initialRequestId) {
      _openedInitialRequest = false;
      _maybeOpenInitialRequest(context.read<ServicesProvider>());
    }
  }

  void _maybeOpenInitialRequest(ServicesProvider p) {
    final id = widget.initialRequestId;
    if (_openedInitialRequest || id == null || !mounted) return;
    Map<String, dynamic>? req;
    for (final r in p.requests) {
      if (r['id'] == id) {
        req = r;
        break;
      }
    }
    if (req == null) return;
    _openedInitialRequest = true;
    _openDetailDialog(context, p, req);
  }

  void _openDetailDialog(
      BuildContext context, ServicesProvider p, Map<String, dynamic> req) {
    final id = req['id'] as String;
    showDialog(
      context: context,
      builder: (_) => _ServiceDetailDialog(
        req: req,
        statuses: _RequestsTable._statuses,
        onUpdateDetails: (updates) async {
          try {
            await p.updateDetails(id, updates);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_errorMessage(e))),
              );
            }
            rethrow;
          }
        },
        onUploadDocument: (bytes, filename) async {
          try {
            return await p.uploadDocument(id, bytes, filename);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_errorMessage(e))),
              );
            }
            return null;
          }
        },
        onDeleteDocument: (docId) async {
          try {
            await p.deleteDocument(id, docId);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_errorMessage(e))),
              );
            }
          }
        },
      ),
    );
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
                    ('Initiated', 'Initiated'),
                    ('Review', 'Review'),
                    ('Approved', 'Approved'),
                    ('In progress', 'In Progress'),
                    ('Completed', 'Completed'),
                    ('Declined', 'Declined'),
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
                  onStatusChange: (id, status) async {
                    try {
                      await p.updateStatus(id, status);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_errorMessage(e))),
                        );
                      }
                    }
                  },
                  onUploadDocument: (id, bytes, filename) async {
                    try {
                      return await p.uploadDocument(id, bytes, filename);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_errorMessage(e))),
                        );
                      }
                      return null;
                    }
                  },
                  onDeleteDocument: (id, docId) async {
                    try {
                      await p.deleteDocument(id, docId);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_errorMessage(e))),
                        );
                      }
                    }
                  },
                  onUpdateDetails: (id, updates) async {
                    try {
                      await p.updateDetails(id, updates);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_errorMessage(e))),
                        );
                      }
                      rethrow;
                    }
                  },
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
    final initiated = requests.where((r) => r['status'] == 'Initiated').length;
    final inProgress =
        requests.where((r) => r['status'] == 'In progress').length;
    final completed = requests.where((r) => r['status'] == 'Completed').length;
    final urgent = requests
        .where((r) => r['priority'] == 'urgent' && r['status'] != 'Completed')
        .length;

    return Row(
      children: [
        _Kpi('Initiated', initiated, AppColors.vacantText),
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

// ── Requests table ─────────────────────────────────────────────────

class _RequestsTable extends StatelessWidget {
  const _RequestsTable({
    required this.requests,
    required this.onStatusChange,
    required this.onUploadDocument,
    required this.onDeleteDocument,
    required this.onUpdateDetails,
  });

  final List<Map<String, dynamic>> requests;
  final Future<void> Function(String id, String status) onStatusChange;
  final Future<Map<String, dynamic>?> Function(
      String id, Uint8List bytes, String filename) onUploadDocument;
  final Future<void> Function(String id, String documentId) onDeleteDocument;
  final Future<void> Function(String id, Map<String, dynamic> updates)
      onUpdateDetails;

  static const _statuses = [
    'Initiated',
    'Review',
    'Approved',
    'In progress',
    'Completed',
    'Declined',
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
              Expanded(flex: 2, child: _ColHeader('Expenses By')),
              Expanded(flex: 2, child: _ColHeader('Est. Cost')),
              Expanded(flex: 2, child: _ColHeader('Initiated')),
              Expanded(flex: 2, child: _ColHeader('Status')),
              Expanded(flex: 1, child: _ColHeader('Docs')),
              Expanded(flex: 1, child: _ColHeader('')),
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
              onUploadDocument: onUploadDocument,
              onDeleteDocument: onDeleteDocument,
              onUpdateDetails: onUpdateDetails,
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
  const _RequestRow({
    required this.req,
    required this.onStatusChange,
    required this.onUploadDocument,
    required this.onDeleteDocument,
    required this.onUpdateDetails,
    required this.statuses,
  });

  final Map<String, dynamic> req;
  final Future<void> Function(String id, String status) onStatusChange;
  final Future<Map<String, dynamic>?> Function(
      String id, Uint8List bytes, String filename) onUploadDocument;
  final Future<void> Function(String id, String documentId) onDeleteDocument;
  final Future<void> Function(String id, Map<String, dynamic> updates)
      onUpdateDetails;
  final List<String> statuses;

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _hovered = false;

  static final _costFmt =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final status = req['status'] as String? ?? 'Initiated';
    final priority = req['priority'] as String? ?? 'normal';
    final tenant = req['tenants'] as Map?;
    final tenantName = tenant != null
        ? '${tenant['first_name'] ?? ''} ${tenant['last_name'] ?? ''}'.trim()
        : '—';
    final serviceName = (req['service_catalog'] as Map?)?['name'] as String? ??
        req['service_name'] as String? ??
        '—';
    final unit = (req['leasing_units'] as Map?)?['name'] as String? ??
        req['leasing_unit_id'] as String? ??
        '—';
    final expensesBorneBy = req['expenses_borne_by'] as String? ?? '—';
    final estimatedCost = (req['estimated_cost'] as num?)?.toDouble();
    final initiatedDateRaw = req['initiated_date'] as String?;
    final initiatedDate = initiatedDateRaw != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(initiatedDateRaw))
        : '—';
    final approvalRequiredFrom = req['approval_required_from'] as String?;
    final docs =
        (req['documents'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final selectableStatuses = approvalRequiredFrom == 'Tenant'
        ? widget.statuses.where((s) => s != 'Approved').toList()
        : widget.statuses;

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
            horizontal: AppDimensions.spaceLG, vertical: AppDimensions.spaceMD),
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
              child: Text(expensesBorneBy,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(
                  estimatedCost != null ? _costFmt.format(estimatedCost) : '—',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(initiatedDate,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (approvalRequiredFrom != null)
                    Tooltip(
                      message: 'Awaiting $approvalRequiredFrom approval',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.hourglass_bottom,
                            size: 13, color: AppColors.pendingText),
                      ),
                    ),
                  _hovered
                      ? PopupMenuButton<String>(
                          color: AppColors.cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusXS),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          onSelected: (s) =>
                              widget.onStatusChange(req['id'] as String, s),
                          itemBuilder: (_) => selectableStatuses
                              .map((s) => PopupMenuItem(
                                    value: s,
                                    child: Text(
                                      s.toUpperCase(),
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
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: _DocsButton(
                docs: docs,
                onUpload: (bytes, filename) => widget.onUploadDocument(
                    req['id'] as String, bytes, filename),
                onDelete: (docId) =>
                    widget.onDeleteDocument(req['id'] as String, docId),
              ),
            ),
            Expanded(
              flex: 1,
              child: Tooltip(
                message: 'View details / update status',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => _ServiceDetailDialog(
                      req: req,
                      statuses: widget.statuses,
                      onUpdateDetails: (updates) =>
                          widget.onUpdateDetails(req['id'] as String, updates),
                      onUploadDocument: (bytes, filename) =>
                          widget.onUploadDocument(
                              req['id'] as String, bytes, filename),
                      onDeleteDocument: (docId) =>
                          widget.onDeleteDocument(req['id'] as String, docId),
                    ),
                  ),
                  child: const Icon(Icons.visibility_outlined,
                      size: 16, color: AppColors.textMuted),
                ),
              ),
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
      'Review' => (AppColors.pendingBg, AppColors.pendingText),
      'Approved' => (const Color(0xFF0A1A2E), AppColors.info),
      'In progress' => (AppColors.accentGoldDark, AppColors.accentGold),
      'Completed' => (AppColors.occupiedBg, AppColors.occupiedText),
      'Declined' => (const Color(0xFF2E1A1A), AppColors.error),
      _ => (AppColors.vacantBg, AppColors.vacantText), // Initiated
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(
            status.toUpperCase(),
            style:
                TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textMuted),
      ],
    );
  }
}

// ── Supporting documents ─────────────────────────────────────────────

class _DocsButton extends StatelessWidget {
  const _DocsButton({
    required this.docs,
    required this.onUpload,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> docs;
  final Future<Map<String, dynamic>?> Function(Uint8List bytes, String filename)
      onUpload;
  final Future<void> Function(String documentId) onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _DocumentsDialog(
            docs: docs, onUpload: onUpload, onDelete: onDelete),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file,
              size: 16,
              color: docs.isEmpty ? AppColors.textMuted : AppColors.accentGold),
          if (docs.isNotEmpty) ...[
            const SizedBox(width: 2),
            Text('${docs.length}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _DocumentsDialog extends StatefulWidget {
  const _DocumentsDialog({
    required this.docs,
    required this.onUpload,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> docs;
  final Future<Map<String, dynamic>?> Function(Uint8List bytes, String filename)
      onUpload;
  final Future<void> Function(String documentId) onDelete;

  @override
  State<_DocumentsDialog> createState() => _DocumentsDialogState();
}

class _DocumentsDialogState extends State<_DocumentsDialog> {
  late List<Map<String, dynamic>> _docs;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _docs = List.of(widget.docs);
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    final doc = await widget.onUpload(bytes, file.name);
    if (mounted) {
      setState(() {
        _uploading = false;
        if (doc != null) _docs = [..._docs, doc];
      });
    }
  }

  Future<void> _delete(Map<String, dynamic> doc) async {
    final id = doc['id'] as String?;
    if (id == null) return;
    await widget.onDelete(id);
    if (mounted) setState(() => _docs.removeWhere((d) => d['id'] == id));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Supporting Documents',
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
              const SizedBox(height: AppDimensions.spaceSM),
              if (_docs.isEmpty)
                const Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: AppDimensions.spaceLG),
                  child: Text('No documents uploaded yet.',
                      style: TextStyle(color: AppColors.textMuted)),
                )
              else
                ..._docs
                    .map((d) => _DocRow(doc: d, onDelete: () => _delete(d))),
              const SizedBox(height: AppDimensions.spaceMD),
              ElevatedButton.icon(
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.bgOuter))
                    : const Icon(Icons.upload_file, size: 16),
                label: Text(_uploading ? 'Uploading…' : 'Upload Document'),
                onPressed: _uploading ? null : _pickAndUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentSilver,
                  foregroundColor: AppColors.bgOuter,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onDelete});

  final Map<String, dynamic> doc;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = doc['name'] as String? ?? 'document';
    final size = doc['file_size'] as int?;
    final sizeLabel =
        size != null ? '${(size / 1024).toStringAsFixed(0)} KB' : '';
    final docId = doc['id'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: docId != null
                  ? () => launchUrlString(
                      '${ApiConfig.baseUrl}/api/v1/service-requests/documents/$docId/download')
                  : null,
              child: Text(name,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
          if (sizeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(sizeLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.delete_outline,
                size: 16, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

// ── Service detail / status dialog ────────────────────────────────────

class _ServiceDetailDialog extends StatefulWidget {
  const _ServiceDetailDialog({
    required this.req,
    required this.statuses,
    required this.onUpdateDetails,
    required this.onUploadDocument,
    required this.onDeleteDocument,
  });

  final Map<String, dynamic> req;
  final List<String> statuses;
  final Future<void> Function(Map<String, dynamic> updates) onUpdateDetails;
  final Future<Map<String, dynamic>?> Function(Uint8List bytes, String filename)
      onUploadDocument;
  final Future<void> Function(String documentId) onDeleteDocument;

  @override
  State<_ServiceDetailDialog> createState() => _ServiceDetailDialogState();
}

class _ServiceDetailDialogState extends State<_ServiceDetailDialog> {
  late String _status;
  late final TextEditingController _notesCtrl;
  late List<Map<String, dynamic>> _docs;
  bool _uploading = false;
  bool _saving = false;

  static final _costFmt =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  @override
  void initState() {
    super.initState();
    _status = widget.req['status'] as String? ?? 'Initiated';
    _notesCtrl =
        TextEditingController(text: widget.req['admin_notes'] as String? ?? '');
    _docs =
        (widget.req['documents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    final doc = await widget.onUploadDocument(bytes, file.name);
    if (mounted) {
      setState(() {
        _uploading = false;
        if (doc != null) _docs = [..._docs, doc];
      });
    }
  }

  Future<void> _deleteDoc(Map<String, dynamic> doc) async {
    final id = doc['id'] as String?;
    if (id == null) return;
    await widget.onDeleteDocument(id);
    if (mounted) setState(() => _docs.removeWhere((d) => d['id'] == id));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onUpdateDetails({
        'status': _status,
        'admin_notes': _notesCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Error already surfaced via SnackBar by the caller; keep dialog open.
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final approvalRequiredFrom = req['approval_required_from'] as String?;
    final selectableStatuses = approvalRequiredFrom == 'Tenant'
        ? widget.statuses.where((s) => s != 'Approved').toList()
        : widget.statuses;
    final serviceName = (req['service_catalog'] as Map?)?['name'] as String? ??
        req['service_name'] as String? ??
        '—';
    final category = (req['service_catalog'] as Map?)?['category'] as String?;
    final unit = (req['leasing_units'] as Map?)?['name'] as String? ??
        req['leasing_unit_id'] as String? ??
        '—';
    final tenant = req['tenants'] as Map?;
    final tenantName = tenant != null
        ? '${tenant['first_name'] ?? ''} ${tenant['last_name'] ?? ''}'.trim()
        : '—';
    final priority = req['priority'] as String? ?? 'normal';
    final requestedBy = req['requested_by'] as String? ?? 'Owner';
    final expensesBorneBy = req['expenses_borne_by'] as String? ?? '—';
    final estimatedCost = (req['estimated_cost'] as num?)?.toDouble();
    final initiatedDateRaw = req['initiated_date'] as String?;
    final initiatedDate = initiatedDateRaw != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(initiatedDateRaw))
        : '—';
    final description = req['description'] as String?;

    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD)),
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spaceLG,
                  AppDimensions.spaceLG,
                  AppDimensions.spaceLG,
                  AppDimensions.spaceSM),
              child: Row(
                children: [
                  Expanded(
                    child: Text(serviceName,
                        style: const TextStyle(
                            fontSize: AppDimensions.fontH3,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spaceLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppDimensions.spaceLG,
                      runSpacing: AppDimensions.spaceMD,
                      children: [
                        _DetailField('Category', category ?? '—'),
                        _DetailField('Property / Unit', unit),
                        _DetailField('Tenant', tenantName),
                        _DetailField('Priority', priority.toUpperCase()),
                        _DetailField('Requested By', requestedBy),
                        _DetailField('Expenses Borne By', expensesBorneBy),
                        _DetailField(
                            'Estimated Cost',
                            estimatedCost != null
                                ? _costFmt.format(estimatedCost)
                                : '—'),
                        _DetailField('Initiated Date', initiatedDate),
                      ],
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spaceMD),
                      const _Label('Description'),
                      const SizedBox(height: 4),
                      Text(description,
                          style: const TextStyle(
                              fontSize: AppDimensions.fontSM,
                              color: AppColors.textPrimary)),
                    ],
                    const SizedBox(height: AppDimensions.spaceMD),
                    if (approvalRequiredFrom != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spaceSM, vertical: 6),
                        margin: const EdgeInsets.only(
                            bottom: AppDimensions.spaceMD),
                        decoration: BoxDecoration(
                          color: AppColors.pendingBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hourglass_bottom,
                                size: 14, color: AppColors.pendingText),
                            const SizedBox(width: 6),
                            Text('Awaiting $approvalRequiredFrom approval',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.pendingText,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    const _Label('Status'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue:
                          selectableStatuses.contains(_status) ? _status : null,
                      dropdownColor: AppColors.cardBg,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppDimensions.fontSM),
                      decoration: _dec(''),
                      items: selectableStatuses
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                    const SizedBox(height: AppDimensions.spaceMD),
                    const _Label('Admin Notes'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppDimensions.fontSM),
                      decoration: _dec('Internal notes...'),
                    ),
                    const SizedBox(height: AppDimensions.spaceMD),
                    const _Label('Supporting Documents'),
                    const SizedBox(height: 6),
                    if (_docs.isEmpty)
                      const Text('No documents uploaded yet.',
                          style: TextStyle(
                              fontSize: AppDimensions.fontSM,
                              color: AppColors.textMuted))
                    else
                      ..._docs.map((d) =>
                          _DocRow(doc: d, onDelete: () => _deleteDoc(d))),
                    const SizedBox(height: AppDimensions.spaceSM),
                    OutlinedButton.icon(
                      icon: _uploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.textMuted))
                          : const Icon(Icons.upload_file,
                              size: 16, color: AppColors.textMuted),
                      label: Text(_uploading ? 'Uploading…' : 'Upload Document',
                          style: const TextStyle(color: AppColors.textMuted)),
                      onPressed: _uploading ? null : _pickAndUpload,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentSilver,
                      foregroundColor: AppColors.bgOuter,
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.bgOuter))
                        : const Text('Save'),
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

class _DetailField extends StatelessWidget {
  const _DetailField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: AppDimensions.fontSM, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
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
  String _expensesBorneBy = 'Owner';
  DateTime _initiatedDate = DateTime.now();
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
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
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickInitiatedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _initiatedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _initiatedDate = picked);
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
        expensesBorneBy: _expensesBorneBy,
        estimatedCost: double.tryParse(_costCtrl.text.trim()),
        initiatedDate: _initiatedDate,
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
                                  fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingCatalog)
                      const SizedBox(
                        height: 80,
                        child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accentSilver),
                        ),
                      )
                    else if (_catalog.isEmpty)
                      Container(
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.pageBg,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusXS),
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
                              _selectedServiceName = svc['name'] as String?;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
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
                                    _iconFor(svc['category'] as String? ?? ''),
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
                                            fontSize: AppDimensions.fontSM,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? AppColors.accentSilver
                                                : AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          svc['category'] as String? ?? '',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textMuted),
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
                      decoration: _dec('Describe the issue or requirement...'),
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
                              child: Text(v[0].toUpperCase() + v.substring(1))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _priority = v ?? 'normal'),
                    ),
                    const SizedBox(height: AppDimensions.spaceMD),

                    // Expenses borne by / Estimated cost
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label('Expenses Borne By'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _expensesBorneBy,
                                dropdownColor: AppColors.cardBg,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: AppDimensions.fontSM),
                                decoration: _dec(''),
                                items: ['Owner', 'Tenant']
                                    .map((v) => DropdownMenuItem(
                                        value: v, child: Text(v)))
                                    .toList(),
                                onChanged: (v) => setState(
                                    () => _expensesBorneBy = v ?? 'Owner'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label('Estimated Cost (₹)'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _costCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: AppDimensions.fontSM),
                                decoration: _dec('0'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceMD),

                    // Initiated date
                    _Label('Initiated Date'),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickInitiatedDate,
                      child: InputDecorator(
                        decoration: _dec(''),
                        child: Row(
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(_initiatedDate),
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: AppDimensions.fontSM),
                            ),
                            const Spacer(),
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: AppColors.textMuted),
                          ],
                        ),
                      ),
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
                      disabledBackgroundColor: AppColors.sidebarItemActive,
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.bgOuter))
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
      'electrical' ||
      'electrical maintenance' =>
        Icons.electrical_services_outlined,
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
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppColors.pageBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
