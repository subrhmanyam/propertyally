import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/unit_agreement.dart';

class UnitAgreementDialog extends StatefulWidget {
  const UnitAgreementDialog({
    super.key,
    required this.unitId,
    required this.unitName,
    required this.isAdmin,
  });

  final String unitId;
  final String unitName;

  /// True → show Upload button. False → view-only (tenant portal).
  final bool isAdmin;

  static Future<void> show(
    BuildContext context, {
    required String unitId,
    required String unitName,
    bool isAdmin = true,
  }) =>
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (_) => UnitAgreementDialog(
          unitId: unitId,
          unitName: unitName,
          isAdmin: isAdmin,
        ),
      );

  @override
  State<UnitAgreementDialog> createState() => _UnitAgreementDialogState();
}

class _UnitAgreementDialogState extends State<UnitAgreementDialog> {
  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  UnitAgreement? _agreement;
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String? _uploadStatus;

  final _dateFmt = DateFormat('dd MMM yyyy');
  final _numFmt =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  @override
  void initState() {
    super.initState();
    _fetchAgreement();
  }

  Future<void> _fetchAgreement() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.properties
          .get('/api/v1/leasing/${widget.unitId}/agreement');
      setState(() {
        _agreement = UnitAgreement.fromJson(res.data as Map<String, dynamic>);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _loading = false;
        if (e.response?.statusCode == 404) {
          _agreement = null; // no agreement yet — show upload prompt
        } else {
          _error = 'Could not load agreement.';
        }
      });
    }
  }

  static const _maxBytes = 100 * 1024 * 1024; // 100 MB

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    if (bytes.lengthInBytes > _maxBytes) {
      setState(() => _error = 'File too large (max 100 MB).');
      return;
    }

    final contentType = _dioContentType(file.extension ?? 'pdf');
    final contentTypeStr = '${contentType.type}/${contentType.subtype}';

    setState(() {
      _uploading = true;
      _uploadStatus = 'Requesting upload URL…';
    });

    try {
      // Step 1: ask the backend for a signed GCS upload URL. Uploading
      // straight to Cloud Run would be capped at its ~32MB inbound request
      // limit — this bypasses that entirely for the file transfer itself.
      final urlRes = await ApiClient.properties.post(
        '/api/v1/leasing/${widget.unitId}/agreement/upload-url',
        queryParameters: {if (_userId != null) 'user_id': _userId},
        data: {'filename': file.name, 'content_type': contentTypeStr},
      );
      final uploadUrl = urlRes.data['upload_url'] as String;
      final storagePath = urlRes.data['storage_path'] as String;
      final orgId = urlRes.data['org_id'] as String;

      // Step 2: PUT the raw bytes directly to GCS.
      setState(() => _uploadStatus = 'Uploading file…');
      await Dio().put(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentTypeStr,
            Headers.contentLengthHeader: bytes.lengthInBytes,
          },
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      // Step 3: backend downloads it from GCS (outbound call, not subject
      // to the inbound limit) and runs Claude extraction.
      setState(() => _uploadStatus = 'Extracting fields…');
      final res = await ApiClient.properties.post(
        '/api/v1/leasing/${widget.unitId}/agreement/from-storage',
        queryParameters: {if (_userId != null) 'user_id': _userId},
        data: {
          'storage_path': storagePath,
          'filename': file.name,
          'content_type': contentTypeStr,
          'org_id': orgId,
        },
        options: Options(
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      setState(() {
        _agreement = UnitAgreement.fromJson(res.data as Map<String, dynamic>);
        _uploading = false;
        _uploadStatus = null;
      });
    } on DioException catch (e) {
      setState(() {
        _uploading = false;
        _uploadStatus = null;
        _error =
            (e.response?.data is Map ? e.response?.data['detail'] : null) ??
                'Upload failed.';
      });
    }
  }

  DioMediaType _dioContentType(String ext) {
    final map = {
      'pdf': DioMediaType('application', 'pdf'),
      'jpg': DioMediaType('image', 'jpeg'),
      'jpeg': DioMediaType('image', 'jpeg'),
      'png': DioMediaType('image', 'png'),
      'webp': DioMediaType('image', 'webp'),
    };
    return map[ext.toLowerCase()] ??
        DioMediaType('application', 'octet-stream');
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    return Dialog(
      backgroundColor: AppColors.cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: screenH - 64,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
                unitName: widget.unitName,
                onClose: () => Navigator.pop(context)),
            Flexible(child: _body()),
            if (widget.isAdmin)
              _Footer(
                agreement: _agreement,
                uploading: _uploading,
                onUpload: _pickAndUpload,
              ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_uploading) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_uploadStatus ?? 'Processing…',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 8),
            const Text(
              'Claude is reading the document and extracting fields…',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            TextButton(onPressed: _fetchAgreement, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_agreement == null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_file_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('No agreement uploaded yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Upload a lease/rental agreement PDF or image.\nClaude will auto-extract all key fields.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return _AgreementFields(
        agreement: _agreement!,
        dateFmt: _dateFmt,
        numFmt: _numFmt,
        unitId: widget.unitId);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.unitName, required this.onClose});

  final String unitName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppDimensions.spaceLG,
          AppDimensions.spaceMD, AppDimensions.spaceSM, AppDimensions.spaceMD),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              color: AppColors.accentGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Agreement Details',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(unitName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.agreement,
    required this.uploading,
    required this.onUpload,
  });

  final UnitAgreement? agreement;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceLG, vertical: AppDimensions.spaceMD),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (agreement != null)
            Expanded(
              child: Text(
                'Uploaded: ${agreement!.documentName ?? 'document'}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: AppDimensions.spaceSM),
          TextButton(
            onPressed: uploading ? null : () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          FilledButton.icon(
            onPressed: uploading ? null : onUpload,
            icon: const Icon(Icons.upload_file_outlined, size: 16),
            label: Text(
                agreement == null ? 'Upload Agreement' : 'Replace Document'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentSilver,
              foregroundColor: AppColors.bgOuter,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Extracted fields display ──────────────────────────────────────────────────

class _AgreementFields extends StatelessWidget {
  const _AgreementFields({
    required this.agreement,
    required this.dateFmt,
    required this.numFmt,
    required this.unitId,
  });

  final UnitAgreement agreement;
  final DateFormat dateFmt;
  final NumberFormat numFmt;
  final String unitId;

  @override
  Widget build(BuildContext context) {
    final a = agreement;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(
            title: 'Parties',
            rows: [
              _row('Lessor / Owner', a.ownerName),
              _row('Owner Address', a.ownerAddress),
              _row('Owner GSTIN', a.ownerGstin),
              _row('Lessee / Tenant', a.tenantName),
              _row('Tenant Address', a.tenantAddress),
              _row('Tenant GSTIN', a.tenantGstin),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceLG),
          _Section(
            title: 'Area',
            rows: [
              _row(
                  'Total Area',
                  a.totalAreaSqft != null
                      ? '${a.totalAreaSqft!.toStringAsFixed(0)} sq.ft'
                      : null),
              _row(
                  'Covered Area',
                  a.coveredAreaSqft != null
                      ? '${a.coveredAreaSqft!.toStringAsFixed(0)} sq.ft'
                      : null),
              _row(
                  'Open Area',
                  a.openAreaSqft != null
                      ? '${a.openAreaSqft!.toStringAsFixed(0)} sq.ft'
                      : null),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceLG),
          _Section(
            title: 'Space & Amenities',
            rows: [
              _row('Furnishing',
                  a.furnishingLabel.isNotEmpty ? a.furnishingLabel : null),
              _row(
                  'Car Parking',
                  a.carParkingCount != null
                      ? '${a.carParkingCount} space${a.carParkingCount == 1 ? '' : 's'}'
                      : null),
              if (a.amenities.isNotEmpty)
                _row('Other Amenities', a.amenities.join(', ')),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceLG),
          _Section(
            title: 'Financials',
            rows: [
              _row('Monthly Rent',
                  a.monthlyRent != null ? numFmt.format(a.monthlyRent) : null),
              _row(
                  'Monthly Maintenance',
                  a.monthlyMaintenance != null
                      ? numFmt.format(a.monthlyMaintenance)
                      : null),
              _row(
                  'Maintenance Paid By',
                  a.maintenancePaidByLabel.isNotEmpty
                      ? a.maintenancePaidByLabel
                      : null),
              _row(
                  'Security Deposit',
                  a.securityDeposit != null
                      ? numFmt.format(a.securityDeposit)
                      : null),
              _row('Profit Sharing', a.profitSharing),
              _row(
                  'Payment Due Day',
                  a.paymentDueDay != null
                      ? '${a.paymentDueDay}${_ordinal(a.paymentDueDay!)} of each month'
                      : null),
              if (a.isGstApplicable) ...[
                _row('CGST', a.cgstRate != null ? '${a.cgstRate}%' : null),
                _row('SGST', a.sgstRate != null ? '${a.sgstRate}%' : null),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.spaceLG),
          _Section(
            title: 'Lease Term',
            rows: [
              _row(
                  'Start Date',
                  a.leaseStartDate != null
                      ? dateFmt.format(a.leaseStartDate!)
                      : null),
              _row(
                  'End Date',
                  a.leaseEndDate != null
                      ? dateFmt.format(a.leaseEndDate!)
                      : null),
              _row(
                  'Notice Period',
                  a.noticePeriodDays != null
                      ? '${a.noticePeriodDays} days'
                      : null),
              _row(
                  'Agreement Date',
                  a.documentDate != null
                      ? dateFmt.format(a.documentDate!)
                      : null),
            ],
          ),
          if (a.fileUrl != null) ...[
            const SizedBox(height: AppDimensions.spaceLG),
            InkWell(
              onTap: () => launchUrlString(
                  '${ApiConfig.baseUrl}/api/v1/leasing/$unitId/agreement/download'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new,
                      size: 14, color: AppColors.accentGold),
                  SizedBox(width: 6),
                  Text('View original document',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentGold)),
                ],
              ),
            ),
          ],
          if (a.specialClauses.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spaceLG),
            _Section(
              title: 'Special Clauses',
              rows: [],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: a.specialClauses
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      color: AppColors.accentGold,
                                      fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(c,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Map<String, String?> _row(String label, String? value) =>
      {'label': label, 'value': value};

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    return switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    this.child,
  });

  final String title;
  final List<Map<String, String?>> rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // Show every row's label even when the document didn't have that field —
    // a blank value with a visible label makes it clear what wasn't found,
    // instead of silently hiding fields the agreement simply didn't mention.
    final visibleRows = rows;
    if (visibleRows.isEmpty && child == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            border: Border.all(color: AppColors.border),
          ),
          child: child != null
              ? Padding(
                  padding: const EdgeInsets.all(AppDimensions.spaceMD),
                  child: child,
                )
              : Column(
                  children: visibleRows.asMap().entries.map((e) {
                    final isLast = e.key == visibleRows.length - 1;
                    final value = e.value['value'];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spaceMD, vertical: 10),
                      decoration: isLast
                          ? null
                          : const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: AppColors.border))),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 180,
                            child: Text(e.value['label']!,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.textMuted)),
                          ),
                          Expanded(
                            child: Text(value ?? '—',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: value != null
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: value != null
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
