import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/excel_importer.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
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
      _showSnack('PDF import not supported. Please fill in the form manually.');
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
    final companyName = rawName.contains('.')
        ? rawName.substring(0, rawName.lastIndexOf('.')).trim()
        : rawName.trim();

    final confirmed = await _showImportPreview(parsed, companyName);
    if (confirmed == true && mounted) {
      context.read<LeasingProvider>().addImported(parsed, companyName: companyName);
      _showSnack('${parsed.length} units imported under "$companyName".');
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
    final provider = context.read<LeasingProvider>();
    final result = await showLeasingForm(context);
    if (result != null && mounted) {
      // Tag with selected company or default
      final unit = result.copyWith(
        companyName: provider.selectedCompany ?? 'Bogineni Black',
      );
      await provider.add(unit);
    }
  }

  Future<void> _openEdit(LeasingUnit unit) async {
    final result = await showLeasingForm(context, unit: unit);
    if (result != null && mounted) {
      await context.read<LeasingProvider>().update(result);
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
          );
        }
        // Otherwise → show company portfolio cards
        return _CompanyView(
          provider: provider,
          onImport: _importFile,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Level 1 — Company / Portfolio cards
// ══════════════════════════════════════════════════════════════════════

class _CompanyView extends StatelessWidget {
  const _CompanyView({required this.provider, required this.onImport});

  final LeasingProvider provider;
  final VoidCallback onImport;

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
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                ),
                const Spacer(),
                AppButton(
                  label: 'Import File',
                  icon: Icons.upload_file_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: onImport,
                ),
              ],
            ),
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
                                onTap: () =>
                                    provider.selectCompany(c.name),
                              ))
                          .toList(),
                    )
                  : Wrap(
                      spacing: AppDimensions.spaceMD,
                      runSpacing: AppDimensions.spaceMD,
                      children: provider.companies
                          .map((c) => SizedBox(
                                width: isMobile ? double.infinity : 420,
                                child: _CompanyCard(
                                  summary: c,
                                  fmt: fmt,
                                  onTap: () =>
                                      provider.selectCompany(c.name),
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
        Row(children: [
          buildCard(0),
          const SizedBox(width: AppDimensions.spaceSM),
          buildCard(1),
        ]),
        const SizedBox(height: AppDimensions.spaceSM),
        Row(children: [
          buildCard(2),
          const SizedBox(width: AppDimensions.spaceSM),
          buildCard(3),
        ]),
      ]);
    }
    return Row(
      children: List.generate(4, (i) => Padding(
            padding: EdgeInsets.only(right: i < 3 ? AppDimensions.spaceSM : 0),
            child: buildCard(i),
          )),
    );
  }
}

class _CompanyCard extends StatefulWidget {
  const _CompanyCard({
    required this.summary,
    required this.fmt,
    required this.onTap,
  });

  final CompanySummary summary;
  final NumberFormat fmt;
  final VoidCallback onTap;

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
  });

  final LeasingProvider provider;
  final TextEditingController searchController;
  final List<(String, String)> statusFilters;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final ValueChanged<LeasingUnit> onEdit;
  final ValueChanged<LeasingUnit> onDelete;

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
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                ),
                const Spacer(),
                AppButton(
                  label: 'Import File',
                  icon: Icons.upload_file_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: onImport,
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                AppButton(
                  label: AppStrings.addProperty,
                  icon: Icons.add,
                  onPressed: onAdd,
                ),
              ],
            ),
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
              )
            else
              _UnitTable(
                units: provider.filtered,
                onEdit: onEdit,
                onDelete: onDelete,
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
        Row(children: [
          buildCard(0),
          const SizedBox(width: AppDimensions.spaceSM),
          buildCard(1),
        ]),
        const SizedBox(height: AppDimensions.spaceSM),
        Row(children: [
          buildCard(2),
          const SizedBox(width: AppDimensions.spaceSM),
          buildCard(3),
        ]),
      ]);
    }
    return Row(
      children: List.generate(4, (i) => Padding(
            padding: EdgeInsets.only(right: i < 3 ? AppDimensions.spaceSM : 0),
            child: buildCard(i),
          )),
    );
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
    return Row(
      children: [
        Wrap(
          spacing: AppDimensions.spaceSM,
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
        ),
        const Spacer(),
        SizedBox(
          width: 240,
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
        ),
      ],
    );
  }
}

// ── Desktop table ─────────────────────────────────────────────────────

class _UnitTable extends StatelessWidget {
  const _UnitTable({
    required this.units,
    required this.onEdit,
    required this.onDelete,
  });

  final List<LeasingUnit> units;
  final ValueChanged<LeasingUnit> onEdit;
  final ValueChanged<LeasingUnit> onDelete;

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
                _TH(label: '', flex: 1),
              ],
            ),
          ),
          ...units.asMap().entries.map((e) => _UnitRow(
                unit: e.value,
                isLast: e.key == units.length - 1,
                onEdit: onEdit,
                onDelete: onDelete,
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
  });

  final LeasingUnit unit;
  final bool isLast;
  final ValueChanged<LeasingUnit> onEdit;
  final ValueChanged<LeasingUnit> onDelete;

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
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionBtn(icon: Icons.edit_outlined, onTap: () => widget.onEdit(u)),
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
  const _ActionBtn({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: AppDimensions.spaceXS),
        child: Icon(icon,
            size: AppDimensions.iconMD,
            color: color ?? AppColors.textMuted),
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
  });

  final List<LeasingUnit> units;
  final ValueChanged<LeasingUnit> onEdit;
  final ValueChanged<LeasingUnit> onDelete;

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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD,
                vertical: AppDimensions.spaceXS),
            title: Text(u.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: AppDimensions.fontBase)),
            subtitle: Text('${u.category}  •  ${u.floor}',
                style: const TextStyle(
                    fontSize: AppDimensions.fontSM,
                    color: AppColors.textMuted)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  u.totalRent > 0 ? fmt.format(u.totalRent) : '—',
                  style: const TextStyle(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w700,
                      fontSize: AppDimensions.fontBase),
                ),
                const SizedBox(height: 4),
                _StatusBadge(status: u.status),
              ],
            ),
            onTap: () => onEdit(u),
            onLongPress: () => onDelete(u),
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
