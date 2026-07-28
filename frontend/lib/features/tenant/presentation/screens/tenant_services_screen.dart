import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/network/api_client.dart';
import '../providers/tenant_provider.dart';

String _errorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return e.message ?? 'Something went wrong.';
  }
  return e.toString();
}

class TenantServicesScreen extends StatefulWidget {
  const TenantServicesScreen({super.key, this.initialRequestId});

  /// When set (e.g. from a notification's action_url), the matching
  /// request card is scrolled into view and highlighted once loaded.
  final String? initialRequestId;

  @override
  State<TenantServicesScreen> createState() => _TenantServicesScreenState();
}

class _TenantServicesScreenState extends State<TenantServicesScreen> {
  String? _selectedCategory;
  final _myRequestsScrollController = ScrollController();
  final Map<String, GlobalKey> _requestKeys = {};
  bool _openedInitialRequest = false;

  GlobalKey _keyFor(String requestId) =>
      _requestKeys.putIfAbsent(requestId, () => GlobalKey());

  @override
  void dispose() {
    _myRequestsScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TenantServicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRequestId != oldWidget.initialRequestId) {
      _openedInitialRequest = false;
    }
  }

  void _maybeOpenInitialRequest(BuildContext context, TenantProvider p,
      List<Map<String, dynamic>> requests) {
    final id = widget.initialRequestId;
    if (_openedInitialRequest || id == null) return;
    final index = requests.indexWhere((r) => r['id'] == id);
    if (index == -1) return;
    _openedInitialRequest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _requestKeys[id]?.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignment: 0.1,
        );
      }
      if (context.mounted) _openDetailDialog(context, p, requests[index]);
    });
  }

  void _openDetailDialog(
      BuildContext context, TenantProvider p, Map<String, dynamic> req) {
    final id = req['id'] as String;
    showDialog(
      context: context,
      builder: (_) => _TenantServiceDetailDialog(
        req: req,
        onDecide: (status) async {
          try {
            await p.decideServiceRequest(id, status);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_errorMessage(e))),
              );
            }
          }
        },
        onUploadDocument: (bytes, filename) async {
          try {
            return await p.uploadServiceRequestDocument(id, bytes, filename);
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
            await p.deleteServiceRequestDocument(id, docId);
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
    return Consumer<TenantProvider>(
      builder: (context, p, _) {
        _maybeOpenInitialRequest(context, p, p.serviceRequests);
        final catalog = p.serviceCatalog;
        final categories = catalog
            .map((s) => s['category'] as String)
            .toSet()
            .toList()
          ..sort();
        final filtered = _selectedCategory == null
            ? catalog
            : catalog.where((s) => s['category'] == _selectedCategory).toList();

        return Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request a Service',
                style: TextStyle(
                    fontSize: AppDimensions.fontH2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppDimensions.spaceSM),
              const Text(
                'Services are filtered to match your property type.',
                style: TextStyle(
                    fontSize: AppDimensions.fontSM, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppDimensions.spaceLG),

              if (p.serviceRequests.isNotEmpty) ...[
                const Text(
                  'My Requests',
                  style: TextStyle(
                      fontSize: AppDimensions.fontH3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppDimensions.spaceSM),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    controller: _myRequestsScrollController,
                    shrinkWrap: true,
                    itemCount: p.serviceRequests.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.spaceSM),
                    itemBuilder: (context, i) => _MyRequestListTile(
                      key: _keyFor(p.serviceRequests[i]['id'] as String),
                      req: p.serviceRequests[i],
                      highlighted:
                          p.serviceRequests[i]['id'] == widget.initialRequestId,
                      onViewDetails: () =>
                          _openDetailDialog(context, p, p.serviceRequests[i]),
                      onDecide: (status) async {
                        try {
                          await p.decideServiceRequest(
                              p.serviceRequests[i]['id'] as String, status);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_errorMessage(e))),
                            );
                          }
                        }
                      },
                      onUploadDocument: (bytes, filename) async {
                        try {
                          return await p.uploadServiceRequestDocument(
                              p.serviceRequests[i]['id'] as String,
                              bytes,
                              filename);
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
                          await p.deleteServiceRequestDocument(
                              p.serviceRequests[i]['id'] as String, docId);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_errorMessage(e))),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLG),
              ],

              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CategoryChip(
                      label: 'All',
                      selected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    ...categories.map((c) => _CategoryChip(
                          label: c,
                          selected: _selectedCategory == c,
                          onTap: () => setState(() => _selectedCategory = c),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLG),

              if (p.isLoading)
                const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accentSilver))
              else if (catalog.isEmpty)
                const Center(
                    child: Text('No services available for your property type.',
                        style: TextStyle(color: AppColors.textMuted)))
              else
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisExtent: 155,
                      crossAxisSpacing: AppDimensions.spaceMD,
                      mainAxisSpacing: AppDimensions.spaceMD,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _ServiceCard(
                      service: filtered[i],
                      onRequest: () =>
                          _showRequestDialog(context, p, filtered[i]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showRequestDialog(
      BuildContext context, TenantProvider p, Map<String, dynamic> service) {
    final descCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    String expensesBorneBy = 'Owner';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: Text(
            service['name'] as String,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service['description'] as String? ?? '',
                style: const TextStyle(
                    fontSize: AppDimensions.fontSM, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppDimensions.fontSM),
                decoration: InputDecoration(
                  hintText: 'Describe your request (optional)...',
                  hintStyle:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.pageBg,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              const Text('Expenses Borne By',
                  style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: expensesBorneBy,
                dropdownColor: AppColors.cardBg,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppDimensions.fontSM),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.pageBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                  ),
                ),
                items: ['Owner', 'Tenant']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => expensesBorneBy = v ?? 'Owner'),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              const Text('Estimated Cost (₹, optional)',
                  style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: costCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppDimensions.fontSM),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.pageBg,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                  ),
                ),
              ),
              if (expensesBorneBy == 'Owner') ...[
                const SizedBox(height: 6),
                const Text(
                  'The owner will need to approve this request before it proceeds.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentSilver,
                foregroundColor: AppColors.bgOuter,
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await p.addServiceRequest({
                    'service_id': service['id'],
                    'service_name': service['name'],
                    'description': descCtrl.text.trim(),
                    'priority': 'normal',
                    'expenses_borne_by': expensesBorneBy,
                    if (double.tryParse(costCtrl.text.trim()) != null)
                      'estimated_cost': double.parse(costCtrl.text.trim()),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Service request submitted.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppDimensions.fontSM,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.bgOuter : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onRequest});

  final Map<String, dynamic> service;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final sla = service['typical_sla_hours'] as int? ?? 24;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service['name'] as String,
            style: const TextStyle(
                fontSize: AppDimensions.fontBase,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            service['category'] as String,
            style: const TextStyle(
                fontSize: AppDimensions.fontSM, color: AppColors.accentGold),
          ),
          const SizedBox(height: 4),
          Text(
            service['description'] as String? ?? '',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Text('SLA: ${sla}h',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              const Spacer(),
              GestureDetector(
                onTap: onRequest,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceMD, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentSilver,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                  ),
                  child: const Text(
                    'Request',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.bgOuter),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── My Requests list tile ───────────────────────────────────────────

class _MyRequestListTile extends StatelessWidget {
  const _MyRequestListTile({
    super.key,
    required this.req,
    required this.onDecide,
    required this.onUploadDocument,
    required this.onDeleteDocument,
    required this.onViewDetails,
    this.highlighted = false,
  });

  final Map<String, dynamic> req;
  final Future<void> Function(String status) onDecide;
  final Future<Map<String, dynamic>?> Function(Uint8List bytes, String filename)
      onUploadDocument;
  final Future<void> Function(String documentId) onDeleteDocument;
  final VoidCallback onViewDetails;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final status = req['status'] as String? ?? 'Initiated';
    final serviceName = (req['service_catalog'] as Map?)?['name'] as String? ??
        req['service_name'] as String? ??
        'Service';
    final expensesBorneBy = req['expenses_borne_by'] as String?;
    final estimatedCost = (req['estimated_cost'] as num?)?.toDouble();
    final awaitingMe = req['approval_required_from'] == 'Tenant';
    final docs =
        (req['documents'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    return GestureDetector(
      onTap: onViewDetails,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceMD, vertical: AppDimensions.spaceSM),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(
            color: highlighted
                ? AppColors.accentGold
                : (awaitingMe ? AppColors.pendingText : AppColors.border),
            width: highlighted ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(serviceName,
                      style: const TextStyle(
                          fontSize: AppDimensions.fontSM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusPill(status),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (awaitingMe) ...[
                          _MiniButton(
                            label: 'Approve',
                            color: AppColors.occupiedText,
                            onTap: () => onDecide('Approved'),
                          ),
                          const SizedBox(width: 4),
                          _MiniButton(
                            label: 'Review',
                            color: AppColors.pendingText,
                            onTap: () => onDecide('Review'),
                          ),
                          const SizedBox(width: 4),
                          _MiniButton(
                            label: 'Decline',
                            color: AppColors.error,
                            onTap: () => onDecide('Declined'),
                          ),
                          const SizedBox(width: 4),
                        ],
                        _MiniButton(
                          label: docs.isEmpty
                              ? 'Documents'
                              : 'Documents (${docs.length})',
                          color: AppColors.textHeading,
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => _TenantDocumentsDialog(
                              docs: docs,
                              onUpload: onUploadDocument,
                              onDelete: onDeleteDocument,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (expensesBorneBy != null)
                  Text('Paid by: $expensesBorneBy',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                if (expensesBorneBy != null && estimatedCost != null)
                  const Text('   •   ',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textMuted)),
                if (estimatedCost != null)
                  Text(
                      'Est: ${NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN').format(estimatedCost)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton(
      {required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

// ── Service detail dialog (opened from the bell notification, or the
// "View" action on a request card) ──────────────────────────────────

class _TenantServiceDetailDialog extends StatelessWidget {
  const _TenantServiceDetailDialog({
    required this.req,
    required this.onDecide,
    required this.onUploadDocument,
    required this.onDeleteDocument,
  });

  final Map<String, dynamic> req;
  final Future<void> Function(String status) onDecide;
  final Future<Map<String, dynamic>?> Function(Uint8List bytes, String filename)
      onUploadDocument;
  final Future<void> Function(String documentId) onDeleteDocument;

  static final _costFmt =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  @override
  Widget build(BuildContext context) {
    final status = req['status'] as String? ?? 'Initiated';
    final serviceName = (req['service_catalog'] as Map?)?['name'] as String? ??
        req['service_name'] as String? ??
        'Service';
    final category = (req['service_catalog'] as Map?)?['category'] as String?;
    final unit = (req['leasing_units'] as Map?)?['name'] as String?;
    final priority = req['priority'] as String? ?? 'normal';
    final expensesBorneBy = req['expenses_borne_by'] as String?;
    final estimatedCost = (req['estimated_cost'] as num?)?.toDouble();
    final initiatedDateRaw = req['initiated_date'] as String?;
    final initiatedDate = initiatedDateRaw != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(initiatedDateRaw))
        : null;
    final description = req['description'] as String?;
    final awaitingMe = req['approval_required_from'] == 'Tenant';
    final docs =
        (req['documents'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD)),
      child: SizedBox(
        width: 460,
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
                    _StatusPill(status),
                    const SizedBox(height: AppDimensions.spaceMD),
                    Wrap(
                      spacing: AppDimensions.spaceLG,
                      runSpacing: AppDimensions.spaceSM,
                      children: [
                        if (category != null) _DetailRow('Category', category),
                        if (unit != null) _DetailRow('Property / Unit', unit),
                        _DetailRow('Priority', priority.toUpperCase()),
                        if (expensesBorneBy != null)
                          _DetailRow('Paid by', expensesBorneBy),
                        if (estimatedCost != null)
                          _DetailRow(
                              'Estimated Cost', _costFmt.format(estimatedCost)),
                        if (initiatedDate != null)
                          _DetailRow('Initiated', initiatedDate),
                      ],
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spaceMD),
                      const Text('Description',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(description,
                          style: const TextStyle(
                              fontSize: AppDimensions.fontSM,
                              color: AppColors.textPrimary)),
                    ],
                    const SizedBox(height: AppDimensions.spaceMD),
                    if (awaitingMe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spaceSM, vertical: 6),
                        margin: const EdgeInsets.only(
                            bottom: AppDimensions.spaceMD),
                        decoration: BoxDecoration(
                          color: AppColors.pendingBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_bottom,
                                size: 14, color: AppColors.pendingText),
                            SizedBox(width: 6),
                            Text('Awaiting your approval',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.pendingText,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        const Icon(Icons.attach_file,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                            docs.isEmpty
                                ? 'No documents'
                                : '${docs.length} document${docs.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(width: AppDimensions.spaceSM),
                        TextButton(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => _TenantDocumentsDialog(
                              docs: docs,
                              onUpload: onUploadDocument,
                              onDelete: onDeleteDocument,
                            ),
                          ),
                          child: const Text('Manage'),
                        ),
                      ],
                    ),
                    if (awaitingMe) ...[
                      const SizedBox(height: AppDimensions.spaceSM),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniButton(
                              label: 'Approve',
                              color: AppColors.occupiedText,
                              onTap: () {
                                onDecide('Approved');
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _MiniButton(
                              label: 'Review',
                              color: AppColors.pendingText,
                              onTap: () {
                                onDecide('Review');
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _MiniButton(
                              label: 'Decline',
                              color: AppColors.error,
                              onTap: () {
                                onDecide('Declined');
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: AppDimensions.fontSM,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(),
          style:
              TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ── Supporting documents (tenant side) ────────────────────────────────

class _TenantDocumentsDialog extends StatefulWidget {
  const _TenantDocumentsDialog({
    required this.docs,
    required this.onUpload,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> docs;
  final Future<Map<String, dynamic>?> Function(Uint8List bytes, String filename)
      onUpload;
  final Future<void> Function(String documentId) onDelete;

  @override
  State<_TenantDocumentsDialog> createState() => _TenantDocumentsDialogState();
}

class _TenantDocumentsDialogState extends State<_TenantDocumentsDialog> {
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
        width: 380,
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
                ..._docs.map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: d['id'] != null
                                  ? () => launchUrlString(
                                      '${ApiConfig.baseUrl}/api/v1/service-requests/documents/${d['id']}/download')
                                  : null,
                              child: Text(d['name'] as String? ?? 'document',
                                  style: const TextStyle(
                                      fontSize: AppDimensions.fontSM,
                                      color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _delete(d),
                            child: const Icon(Icons.delete_outline,
                                size: 16, color: AppColors.error),
                          ),
                        ],
                      ),
                    )),
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
