import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/current_org.dart';
import '../../../../core/utils/excel_importer.dart';
import '../../../../core/utils/export_helper.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../invoices/presentation/invoice_generator_dialog.dart';
import '../../../listings/presentation/providers/listings_provider.dart';
import '../widgets/unit_agreement_dialog.dart';
import '../../../listings/presentation/widgets/platform_picker_dialog.dart';
import '../../domain/entities/leasing_unit.dart';
import '../providers/leasing_provider.dart';
import '../widgets/leasing_form_dialog.dart';

class LeasingListScreen extends StatefulWidget {
  const LeasingListScreen({super.key});

  @override
  State<LeasingListScreen> createState() => _LeasingListScreenState();
}

class _LeasingListScreenState extends State<LeasingListScreen> {
  final _searchController = TextEditingController();

  static const _statusFilters = [
    ('all', 'All'),
    ('occupied', 'Occupied'),
    ('vacant', 'Vacant'),
    ('in_house', 'In-house'),
    ('owner_occupied', 'Owner-occupied'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeasingProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── File import ────────────────────────────────────────────────────

  /// Archives the raw imported file in GCS (org_{org}/general/import/...),
  /// alongside the parsed data. Best-effort: a failure here (e.g. the org
  /// schema migration hasn't been run yet) must not block the import itself.
  Future<void> _archiveImportFile(Uint8List bytes, String filename) async {
    final orgId = await getCurrentOrgId();
    if (orgId == null) {
      debugPrint('GCS archive skipped for "$filename": no org for current user.');
      return;
    }
    // The real object path (with its server-generated uuid prefix) is only
    // known on success; this is the deterministic part, logged either way
    // so a failure is still traceable to where the file should have landed.
    final intendedPath = 'org_$orgId/general/import/$filename';
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'doc_type': 'import',
        'org_id': orgId,
      });
      final resp = await ApiClient.properties.post('/api/v1/documents/upload', data: formData);
      final storagePath = (resp.data as Map?)?['storage_path'];
      debugPrint('GCS archive OK for "$filename": $storagePath');
    } catch (e) {
      debugPrint('GCS archive FAILED for "$filename" (intended path: $intendedPath): $e');
      if (mounted) _showSnack('Imported, but could not archive the original file.');
    }
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final ext = (file.extension ?? '').toLowerCase();

    if (ext == 'pdf') {
      final bytes = file.bytes;
      if (bytes == null) { _showSnack('Could not read file bytes.'); return; }
      _showSnack('Parsing PDF with AI… this may take a few seconds.');
      try {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: file.name),
        });
        final resp = await ApiClient.properties.post(
          '/api/v1/leasing/import-pdf',
          data: formData,
        );
        final rawList = (resp.data as List?) ?? [];
        final parsed = rawList.map((e) {
          final m = e as Map<String, dynamic>;
          final areas = (m['areas'] as List? ?? []).map((a) {
            final am = a as Map<String, dynamic>;
            return AreaEntry(
              type: am['type']?.toString() ?? 'covered',
              sqft: (am['sqft'] as num?)?.toDouble() ?? 0,
              rate: (am['rate'] as num?)?.toDouble() ?? 0,
            );
          }).toList();
          return LeasingUnit(
            id: 'lu_${DateTime.now().millisecondsSinceEpoch}_${rawList.indexOf(e)}',
            name: m['name']?.toString() ?? '',
            companyName: m['company_name']?.toString() ?? '',
            category: m['category']?.toString() ?? 'Other',
            floor: m['floor']?.toString() ?? 'Ground Floor',
            status: m['status']?.toString() ?? 'vacant',
            areas: areas,
          );
        }).toList();
        if (!mounted) return;
        if (parsed.isEmpty) {
          _showSnack('No properties found in PDF.');
          return;
        }
        final rawName = file.name;
        final companyName = parsed.first.companyName.isNotEmpty
            ? parsed.first.companyName
            : (rawName.contains('.') ? rawName.substring(0, rawName.lastIndexOf('.')).trim() : rawName.trim());
        final confirmed = await _showImportPreview(parsed, companyName);
        if (confirmed == true && mounted) {
          await context.read<LeasingProvider>().addImported(parsed, companyName: companyName);
          await _archiveImportFile(bytes, file.name);
          if (mounted) _showSnack('${parsed.length} units imported from PDF.');
        }
      } on DioException catch (e) {
        if (mounted) _showSnack('PDF import failed: ${e.response?.data ?? e.message}');
      }
      return;
    }
    if (ext == 'csv') {
      _showSnack('CSV import coming soon. Use .xlsx for now.');
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) { _showSnack('Could not read file bytes.'); return; }

    final parsed = parseExcelBytes(bytes);
    if (!mounted) return;
    if (parsed.isEmpty) {
      _showSnack('Could not parse the Excel file. Make sure it follows the expected format.');
      return;
    }

    // File name (without extension) becomes the company/portfolio name
    final rawName = file.name;
    final baseName = rawName.contains('.')
        ? rawName.substring(0, rawName.lastIndexOf('.')).trim()
        : rawName.trim();
    final companyName = baseName.replaceAll(RegExp(r'[-_]+'), ' ').trim();

    final confirmed = await _showImportPreview(parsed, companyName);
    if (confirmed == true && mounted) {
      await context.read<LeasingProvider>().addImported(parsed, companyName: companyName);
      await _archiveImportFile(bytes, file.name);
      if (mounted) _showSnack('${parsed.length} units imported under "$companyName".');
    }
  }

  Future<bool?> _showImportPreview(List<LeasingUnit> units, String companyName) {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            side: const BorderSide(color: AppColors.border)),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Import Preview — $companyName',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontH3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: AppDimensions.spaceXS),
              Text('${units.length} units will be added under this portfolio',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted)),
              const SizedBox(height: AppDimensions.spaceMD),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: units.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (_, i) {
                    final u = units[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spaceSM),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(u.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500)),
                          ),
                          Text(u.category,
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: AppDimensions.fontSM)),
                          const SizedBox(width: AppDimensions.spaceMD),
                          Text(fmt.format(u.totalRent),
                              style: const TextStyle(
                                  color: AppColors.accentGold,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLG),
              Row(
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'Import All',
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportCsv() {
    final units = context.read<LeasingProvider>().units;
    if (units.isEmpty) { _showSnack('No properties to export.'); return; }
    final csv = buildCsv(
      ['ID', 'Name', 'Portfolio', 'Category', 'Floor', 'Status', 'Total Rent (₹)'],
      units.map((u) => [u.id, u.name, u.companyName, u.category, u.floor, u.status, u.totalRent]).toList(),
    );
    downloadCsv(csv, 'properties_${DateTime.now().millisecondsSinceEpoch}.csv');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openAdd() async {
    final result = await showLeasingForm(context);
    if (result != null && mounted) {
      await context.read<LeasingProvider>().add(result);
    }
  }

  Future<void> _openEdit(LeasingUnit unit) async {
    final result = await showLeasingForm(context, unit: unit);
    if (result != null && mounted) {
      await context.read<LeasingProvider>().update(result);
    }
  }

  void _generateInvoice(LeasingUnit unit) {
    InvoiceGeneratorDialog.show(context, unit);
  }

  void _viewAgreement(LeasingUnit unit) {
    UnitAgreementDialog.show(
      context,
      unitId: unit.id,
      unitName: unit.name,
      isAdmin: true,
    );
  }

  Future<void> _publishUnit(LeasingUnit unit) async {
    final selected = await PlatformPickerDialog.show(context, unit.id);
    if (selected == null || selected.isEmpty || !mounted) return;
    try {
      await context.read<ListingsProvider>().triggerAgent(unit.id, selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Publishing "${unit.name}" to ${selected.length} platform${selected.length == 1 ? '' : 's'}…',
            ),
            backgroundColor: AppColors.cardBg,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to trigger agent')),
        );
      }
    }
  }

  Future<void> _confirmDeleteCompany(CompanySummary summary) async {
    final unitCount = summary.units.length;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete Portfolio?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete "${summary.name}" and all $unitCount ${unitCount == 1 ? 'property' : 'properties'} under it?\n\nThis will also remove all tenants linked to these properties. This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<LeasingProvider>().deletePortfolio(summary);
    }
  }

  Future<void> _confirmDelete(LeasingUnit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete unit?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Remove "${unit.name}" from the leasing list?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<LeasingProvider>().delete(unit.id);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<LeasingProvider>(
      builder: (context, provider, _) {
        // If a company is selected → show unit list for that company
        if (provider.selectedCompany != null) {
          return _UnitsView(
            provider: provider,
            searchController: _searchController,
            statusFilters: _statusFilters,
            onAdd: _openAdd,
            onImport: _importFile,
            onEdit: _openEdit,
            onDelete: _confirmDelete,
            onPublish: _publishUnit,
            onGenerateInvoice: _generateInvoice,
            onViewAgreement: _viewAgreement,
          );
        }
        // Otherwise → show company portfolio cards
        return _CompanyView(
          provider: provider,
          onImport: _importFile,
          onExport: _exportCsv,
          onAdd: _openAdd,
          onDeleteCompany: _confirmDeleteCompany,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Level 1 — Company / Portfolio cards
// ══════════════════════════════════════════════════════════════════════

class _CompanyView extends StatelessWidget {
  const _CompanyView({
    required this.provider,
    required this.onImport,
    required this.onExport,
    required this.onAdd,
    required this.onDeleteCompany,
  });

  final LeasingProvider provider;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onAdd;
  final ValueChanged<CompanySummary> onDeleteCompany;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Builder(builder: (context) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    AppStrings.properties,
                    style: TextStyle(
                      fontSize: AppDimensions.fontH2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${provider.companies.length} ${provider.companies.length == 1 ? 'portfolio' : 'portfolios'} · ${provider.totalUnits} units total',
                    style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              );
              final buttons = Wrap(
                spacing: AppDimensions.spaceSM,
                runSpacing: AppDimensions.spaceSM,
                children: [
                  AppButton(
                    label: 'Export CSV',
                    icon: Icons.download_outlined,
                    variant: AppButtonVariant.ghost,
                    onPressed: onExport,
                  ),
                  AppButton(
                    label: 'Import File',
                    icon: Icons.upload_file_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: onImport,
                  ),
                  AppButton(
                    label: 'Add Property',
                    icon: Icons.add,
                    onPressed: onAdd,
                  ),
                ],
              );
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: AppDimensions.spaceMD),
                    buttons,
                  ],
                );
              }
              return Row(children: [title, const Spacer(), buttons]);
            }),
            const SizedBox(height: AppDimensions.spaceXL),

            // ── Portfolio KPI strip ──
            _PortfolioKpiRow(provider: provider),
            const SizedBox(height: AppDimensions.spaceXL),

            // ── Company cards ──
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (provider.companies.isEmpty)
              EmptyState(
                icon: Icons.domain_outlined,
                title: AppStrings.noProperties,
                description: AppStrings.noPropertiesDesc,
                actionLabel: 'Import File',
                onAction: onImport,
              )
            else
              isMobile
                  ? Column(
                      children: provider.companies
                          .map((c) => _CompanyCard(
                                summary: c,
                                fmt: fmt,
                                onTap: () => provider.selectCompany(c.name),
                                onDelete: () => onDeleteCompany(c),
                              ))
                          .toList(),
                    )
                  : Wrap(
                      spacing: AppDimensions.spaceMD,
                      runSpacing: AppDimensions.spaceMD,
                      children: provider.companies
                          .map((c) => SizedBox(
                                width: 420,
                                child: _CompanyCard(
                                  summary: c,
                                  fmt: fmt,
                                  onTap: () => provider.selectCompany(c.name),
                                  onDelete: () => onDeleteCompany(c),
                                ),
                              ))
                          .toList(),
                    ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioKpiRow extends StatelessWidget {
  const _PortfolioKpiRow({required this.provider});

  final LeasingProvider provider;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    final isMobile = Responsive.isMobile(context);

    final values = [
      provider.totalUnits.toString(),
      provider.occupiedCount.toString(),
      provider.vacantCount.toString(),
      fmt.format(provider.totalMonthlyRent),
    ];
    const labels = ['Total Units', 'Occupied', 'Vacant', 'Monthly Revenue'];
    const icons = [
      Icons.domain_outlined,
      Icons.check_circle_outline,
      Icons.radio_button_unchecked,
      Icons.currency_rupee,
    ];

    Expanded buildCard(int i) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? AppDimensions.spaceSM : 0),
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icons[i], size: AppDimensions.iconMD, color: AppColors.accentGold),
                const SizedBox(height: AppDimensions.spaceSM),
                Text(values[i],
                    style: const TextStyle(
                        fontSize: AppDimensions.fontH2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(labels[i],
                    style: const TextStyle(
                        fontSize: AppDimensions.fontSM,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
        );

    if (isMobile) {
      return Column(children: [
        Row(children: [buildCard(0), buildCard(1)]),
        const SizedBox(height: AppDimensions.spaceSM),
        Row(children: [buildCard(2), buildCard(3)]),
      ]);
    }
    return Row(children: List.generate(4, buildCard));
  }
}

class _CompanyCard extends StatefulWidget {
  const _CompanyCard({
    required this.summary,
    required this.fmt,
    required this.onTap,
    required this.onDelete,
  });

  final CompanySummary summary;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_CompanyCard> createState() => _CompanyCardState();
}

class _CompanyCardState extends State<_CompanyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final occupancyPct = s.totalUnits == 0 ? 0.0 : s.occupiedCount / s.totalUnits;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.pageBg : AppColors.cardBg,
            border: Border.all(
              color: _hovered ? AppColors.accentSilver : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentGoldDark,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                    ),
                    child: const Icon(Icons.domain,
                        color: AppColors.accentGold, size: AppDimensions.iconLG),
                  ),
                  const SizedBox(width: AppDimensions.spaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OWNER',
                          style: const TextStyle(
                            fontSize: AppDimensions.fontXS,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontSize: AppDimensions.fontH3,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${s.totalUnits} leasing units',
                          style: const TextStyle(
                            fontSize: AppDimensions.fontSM,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hovered)
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: const Icon(Icons.delete_outline,
                          size: AppDimensions.iconMD, color: AppColors.error),
                    )
                  else
                    const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceLG),

              // ── Revenue ──
              Text(
                widget.fmt.format(s.totalMonthlyRent),
                style: const TextStyle(
                  fontSize: AppDimensions.fontH2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
              const Text(
                'Monthly Revenue',
                style: TextStyle(
                  fontSize: AppDimensions.fontSM,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLG),

              // ── Occupancy stats ──
              Row(
                children: [
                  _StatPill(label: 'Occupied', value: s.occupiedCount, color: AppColors.success),
                  const SizedBox(width: AppDimensions.spaceSM),
                  _StatPill(label: 'Vacant', value: s.vacantCount, color: AppColors.textMuted),
                  const SizedBox(width: AppDimensions.spaceSM),
                  if (s.inHouseCount > 0)
                    _StatPill(label: 'In-house', value: s.inHouseCount, color: AppColors.info),
                  if (s.ownerOccupiedCount > 0) ...[
                    const SizedBox(width: AppDimensions.spaceSM),
                    _StatPill(label: 'Owner', value: s.ownerOccupiedCount, color: AppColors.accentGold),
                  ],
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMD),

              // ── Occupancy bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: occupancyPct,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                '${(occupancyPct * 100).toStringAsFixed(0)}% occupancy',
                style: const TextStyle(
                  fontSize: AppDimensions.fontXS,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          fontSize: AppDimensions.fontXS,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Level 2 — Unit list for a selected company
// ══════════════════════════════════════════════════════════════════════

class _UnitsView extends StatelessWidget {
  const _UnitsView({
    required this.provider,
    required this.searchController,
    required this.statusFilters,
    required this.onAdd,
    required this.onImport,
    required this.onEdit,
    required this.onDelete,
    required this.onPublish,
    required this.onGenerateInvoice,
    required this.onViewAgreement,
  });

  final LeasingProvider provider;
  final TextEditingController searchController;
  final List<(String, String)> statusFilters;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final ValueChanged<LeasingUnit> onEdit;
  final ValueChanged<LeasingUnit> onDelete;
  final ValueChanged<LeasingUnit> onPublish;
  final ValueChanged<LeasingUnit> onGenerateInvoice;
  final ValueChanged<LeasingUnit> onViewAgreement;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final summary = provider.selectedCompanySummary;
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Breadcrumb ──
            GestureDetector(
              onTap: () => provider.selectCompany(null),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_ios,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  const Text(
                    'Properties',
                    style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('/',
                        style: TextStyle(color: AppColors.textMuted,
                            fontSize: AppDimensions.fontSM)),
                  ),
                  Text(
                    provider.selectedCompany ?? '',
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMD),

            // ── Header ──
            Builder(builder: (context) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.selectedCompany ?? '',
                    style: const TextStyle(
                      fontSize: AppDimensions.fontH2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (summary != null)
                    Text(
                      '${summary.totalUnits} units · ${fmt.format(summary.totalMonthlyRent)}/mo',
                      style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              );
              final buttons = Wrap(
                spacing: AppDimensions.spaceSM,
                runSpacing: AppDimensions.spaceSM,
                children: [
                  AppButton(
                    label: 'Import File',
                    icon: Icons.upload_file_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: onImport,
                  ),
                  AppButton(
                    label: AppStrings.addProperty,
                    icon: Icons.add,
                    onPressed: onAdd,
                  ),
                ],
              );
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: AppDimensions.spaceMD),
                    buttons,
                  ],
                );
              }
              return Row(children: [title, const Spacer(), buttons]);
            }),
            const SizedBox(height: AppDimensions.spaceLG),

            // ── KPI row ──
            _UnitsKpiRow(provider: provider),
            const SizedBox(height: AppDimensions.spaceLG),

            // ── Filters ──
            _FilterRow(
              provider: provider,
              searchController: searchController,
              statusFilters: statusFilters,
            ),
            const SizedBox(height: AppDimensions.spaceLG),

            // ── Content ──
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (provider.filtered.isEmpty)
              EmptyState(
                icon: Icons.domain_outlined,
                title: AppStrings.noProperties,
                description: AppStrings.noPropertiesDesc,
                actionLabel: AppStrings.addProperty,
                onAction: onAdd,
              )
            else if (isMobile)
              _UnitCardList(
                units: provider.filtered,
                onEdit: onEdit,
                onDelete: onDelete,
                onPublish: onPublish,
                onGenerateInvoice: onGenerateInvoice,
                onViewAgreement: onViewAgreement,
              )
            else
              _UnitTable(
                units: provider.filtered,
                onEdit: onEdit,
                onDelete: onDelete,
                onPublish: onPublish,
                onGenerateInvoice: onGenerateInvoice,
                onViewAgreement: onViewAgreement,
              ),
          ],
        ),
      ),
    );
  }
}

class _UnitsKpiRow extends StatelessWidget {
  const _UnitsKpiRow({required this.provider});

  final LeasingProvider provider;

  @override
  Widget build(BuildContext context) {
    final summary = provider.selectedCompanySummary;
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    final isMobile = Responsive.isMobile(context);

    final values = [
      (summary?.totalUnits ?? 0).toString(),
      (summary?.occupiedCount ?? 0).toString(),
      (summary?.vacantCount ?? 0).toString(),
      fmt.format(summary?.totalMonthlyRent ?? 0),
    ];
    const labels = ['Total Units', 'Occupied', 'Vacant', 'Monthly Rent'];
    const icons = [
      Icons.domain_outlined,
      Icons.check_circle_outline,
      Icons.radio_button_unchecked,
      Icons.currency_rupee,
    ];

    Expanded buildCard(int i) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? AppDimensions.spaceSM : 0),
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icons[i], size: AppDimensions.iconMD, color: AppColors.accentGold),
                const SizedBox(height: AppDimensions.spaceSM),
                Text(values[i],
                    style: const TextStyle(
                        fontSize: AppDimensions.fontH2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(labels[i],
                    style: const TextStyle(
                        fontSize: AppDimensions.fontSM,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
        );

    if (isMobile) {
      return Column(children: [
        Row(children: [buildCard(0), buildCard(1)]),
        const SizedBox(height: AppDimensions.spaceSM),
        Row(children: [buildCard(2), buildCard(3)]),
      ]);
    }
    return Row(children: List.generate(4, buildCard));
  }
}

// ── Filters ───────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.provider,
    required this.searchController,
    required this.statusFilters,
  });

  final LeasingProvider provider;
  final TextEditingController searchController;
  final List<(String, String)> statusFilters;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final chips = Wrap(
      spacing: AppDimensions.spaceSM,
      runSpacing: AppDimensions.spaceSM,
      children: List.generate(statusFilters.length, (i) {
        final filterValue = statusFilters[i].$1;
        final filterLabel = statusFilters[i].$2;
        final active = provider.statusFilter == filterValue;
        return GestureDetector(
          onTap: () => provider.setStatusFilter(filterValue),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD,
                vertical: AppDimensions.spaceXS),
            decoration: BoxDecoration(
              color: active ? AppColors.accentSilver : AppColors.cardBg,
              border: Border.all(
                  color: active ? AppColors.accentSilver : AppColors.border),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Text(
              filterLabel,
              style: TextStyle(
                fontSize: AppDimensions.fontBase,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.bgOuter : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );

    final search = SizedBox(
      width: isMobile ? double.infinity : 240,
      height: 38,
      child: TextField(
        controller: searchController,
        onChanged: provider.setSearchQuery,
        style: const TextStyle(
            fontSize: AppDimensions.fontBase, color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: AppStrings.searchProperties,
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.textMuted, size: AppDimensions.iconMD),
          contentPadding: EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [chips, const SizedBox(height: AppDimensions.spaceSM), search],
      );
    }
    return Row(children: [Expanded(child: chips), const SizedBox(width: AppDimensions.spaceMD), search]);
  }
}

// ── Desktop table ─────────────────────────────────────────────────────

class _UnitTable extends StatelessWidget {
  const _UnitTable({
    required this.units,
    required this.onEdit,
    required this.onDelete,
    required this.onPublish,
    required this.onGenerateInvoice,
    required this.onViewAgreement,
  });

  final List<LeasingUnit> units;
  final ValueChanged<LeasingUnit> onEdit;
  final ValueChanged<LeasingUnit> onDelete;
  final ValueChanged<LeasingUnit> onPublish;
  final ValueChanged<LeasingUnit> onGenerateInvoice;
  final ValueChanged<LeasingUnit> onViewAgreement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD,
                vertical: AppDimensions.spaceSM),
            decoration: const BoxDecoration(
              color: AppColors.pageBg,
              border: Border(bottom: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusMD)),
            ),
            child: const Row(
              children: [
                _TH(label: 'Unit Name', flex: 4),
                _TH(label: 'Category', flex: 3),
                _TH(label: 'Floor', flex: 3),
                _TH(label: 'Total Sq.ft', flex: 2),
                _TH(label: 'Monthly Rent', flex: 3),
                _TH(label: 'Status', flex: 2),
                _TH(label: '', flex: 5),
              ],
            ),
          ),
          ...units.asMap().entries.map((e) => _UnitRow(
                unit: e.value,
                isLast: e.key == units.length - 1,
                onEdit: onEdit,
                onDelete: onDelete,
                onPublish: onPublish,
                onGenerateInvoice: onGenerateInvoice,
                onViewAgreement: onViewAgreement,
              )),
        ],
      ),
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
          fontSize: AppDimensions.fontXS,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _UnitRow extends StatefulWidget {
  const _UnitRow({
    required this.unit,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
    required this.onPublish,
    required this.onGenerateInvoice,
    required this.onViewAgreement,
  });

  final LeasingUnit unit;
  final bool isLast;
  final ValueChanged<LeasingUnit> onEdit;
  final ValueChanged<LeasingUnit> onDelete;
  final ValueChanged<LeasingUnit> onPublish;
  final ValueChanged<LeasingUnit> onGenerateInvoice;
  final ValueChanged<LeasingUnit> onViewAgreement;

  @override
  State<_UnitRow> createState() => _UnitRowState();
}

class _UnitRowState extends State<_UnitRow> {
  bool _hovered = false;
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onEdit(u),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.pageBg : Colors.transparent,
            border: !widget.isLast
                ? const Border(bottom: BorderSide(color: AppColors.border))
                : null,
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD,
              vertical: AppDimensions.spaceMD),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(u.name,
                    style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 3,
                child: Text(u.category,
                    style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 3,
                child: Text(u.floor,
                    style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${u.totalSqft.toStringAsFixed(u.totalSqft % 1 == 0 ? 0 : 1)} sqft',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  u.totalRent > 0 ? _fmt.format(u.totalRent) : '—',
                  style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
              Expanded(flex: 2, child: _StatusBadge(status: u.status)),
              Expanded(
                // 5 action icons need ~180px minimum — flex 1 (out of ~18)
                // wasn't enough and pushed delete off the right edge.
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: 'Publish to platforms',
                      child: _ActionBtn(
                        icon: Icons.language_outlined,
                        color: AppColors.accentGold,
                        enabled: u.status == 'vacant',
                        onTap: () => widget.onPublish(u),
                      ),
                    ),
                    Tooltip(
                      message: 'Generate Invoice',
                      child: _ActionBtn(
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.accentGold,
                        enabled: u.status == 'occupied' || u.status == 'in_house',
                        onTap: () => widget.onGenerateInvoice(u),
                      ),
                    ),
                    Tooltip(
                      message: 'Agreement Details',
                      child: _ActionBtn(
                        icon: Icons.info_outline_rounded,
                        color: AppColors.info,
                        onTap: () => widget.onViewAgreement(u),
                      ),
                    ),
                    _ActionBtn(
                        icon: Icons.edit_outlined,
                        color: Colors.white,
                        onTap: () => widget.onEdit(u)),
                    _ActionBtn(
                        icon: Icons.delete_outline,
                        color: AppColors.error,
                        onTap: () => widget.onDelete(u)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.color,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceSM),
        child: Icon(icon,
            size: AppDimensions.iconMD,
            color: enabled
                ? (color ?? AppColors.textMuted)
                : AppColors.textMuted),
      ),
    );
  }
}

// ── Mobile card list ──────────────────────────────────────────────────

class _UnitCardList extends StatelessWidget {
  const _UnitCardList({
    required this.units,
    required this.onEdit,
    required this.onDelete,
    required this.onPublish,
    required this.onGenerateInvoice,
    required this.onViewAgreement,
  });

  final List<LeasingUnit> units;
  final ValueChanged<LeasingUnit> onEdit;
  final ValueChanged<LeasingUnit> onDelete;
  final ValueChanged<LeasingUnit> onPublish;
  final ValueChanged<LeasingUnit> onGenerateInvoice;
  final ValueChanged<LeasingUnit> onViewAgreement;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    return Column(
      children: units.map((u) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.spaceSM),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD,
                vertical: AppDimensions.spaceSM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name + rent ──────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(u.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: AppDimensions.fontBase)),
                    ),
                    const SizedBox(width: AppDimensions.spaceSM),
                    Text(
                      u.totalRent > 0 ? fmt.format(u.totalRent) : '—',
                      style: const TextStyle(
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w700,
                          fontSize: AppDimensions.fontBase),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // ── Category/floor + status ──────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text('${u.category}  •  ${u.floor}',
                          style: const TextStyle(
                              fontSize: AppDimensions.fontSM,
                              color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: AppDimensions.spaceSM),
                    _StatusBadge(status: u.status),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSM),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppDimensions.spaceXS),
                // ── Actions row — below name/description ─────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionBtn(
                      icon: Icons.language_outlined,
                      color: AppColors.accentGold,
                      enabled: u.status == 'vacant',
                      onTap: () => onPublish(u),
                    ),
                    _ActionBtn(
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.accentGold,
                      enabled: u.status == 'occupied' || u.status == 'in_house',
                      onTap: () => onGenerateInvoice(u),
                    ),
                    _ActionBtn(
                      icon: Icons.info_outline_rounded,
                      color: AppColors.info,
                      onTap: () => onViewAgreement(u),
                    ),
                    _ActionBtn(
                      icon: Icons.edit_outlined,
                      color: Colors.white,
                      onTap: () => onEdit(u),
                    ),
                    _ActionBtn(
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      onTap: () => onDelete(u),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, textColor, label) = switch (status) {
      'occupied' => (AppColors.occupiedBg, AppColors.occupiedText, 'Occupied'),
      'vacant' => (AppColors.vacantBg, AppColors.vacantText, 'Vacant'),
      'in_house' => (const Color(0xFF0A1A2E), AppColors.info, 'In-house'),
      'owner_occupied' => (const Color(0xFF1E1500), AppColors.accentGold, 'Owner-occupied'),
      _ => (AppColors.vacantBg, AppColors.vacantText, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppDimensions.fontXS,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
