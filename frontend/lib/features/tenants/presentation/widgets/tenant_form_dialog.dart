import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../properties/domain/entities/leasing_unit.dart';
import '../../../properties/presentation/providers/leasing_provider.dart';
import '../../../properties/presentation/widgets/leasing_form_dialog.dart';
import '../../domain/entities/tenant.dart';
import '../providers/tenants_provider.dart';

/// The single "edit a tenant" flow for the whole app — opens the form,
/// saves it, and handles the standard side effects (marking the property
/// occupied on first add, refreshing tenant-detail state, surfacing
/// errors). Both the property-level tenant view (`/tenants`) and the named
/// tenant's own page (`/tenants/:id`) call this instead of each keeping
/// their own copy of the save logic.
Future<void> editTenant(
  BuildContext context, {
  required List<LeasingUnit> units,
  required LeasingUnit preselectedUnit,
  Tenant? existingTenant,
}) async {
  final data = await showTenantForm(
    context,
    units: units,
    preselectedUnit: preselectedUnit,
    existingTenant: existingTenant,
  );
  if (data == null || !context.mounted) return;

  final tp = context.read<TenantsProvider>();

  if (existingTenant != null) {
    await tp.updateTenant(existingTenant.id, data);
    if (context.mounted) await tp.loadTenant(existingTenant.id);
    if (context.mounted && tp.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update tenant: ${tp.errorMessage}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return;
  }

  final tenant = await tp.createTenant(data);
  if (tenant == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Could not add tenant: ${tp.errorMessage ?? 'unknown error'}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return;
  }
  if (context.mounted) {
    await markPropertyOccupiedIfVacant(context, tenant.unitId);
  }
}

/// A property is "vacant" until it has an occupant — adding or assigning a
/// tenant contact to it means it no longer is, so flip the status
/// automatically rather than leaving the admin to do it by hand. Shared by
/// [editTenant] and the "assign an unassigned tenant to a property" flow.
Future<void> markPropertyOccupiedIfVacant(
    BuildContext context, String? unitId) async {
  if (unitId == null || unitId.isEmpty) return;
  final lp = context.read<LeasingProvider>();
  final unit = lp.units.where((u) => u.id == unitId).firstOrNull;
  if (unit == null) return;
  const alreadyOccupied = {'occupied', 'in_house', 'owner_occupied'};
  if (alreadyOccupied.contains(unit.status)) return;
  await lp.update(unit.copyWith(status: 'occupied'));
}

/// Opens the tenant-details form as a dialog (desktop) or bottom sheet
/// (mobile). Returns a Map ready to POST/PATCH to the tenants API, or null
/// on cancel. Pass [existingTenant] to edit it (form opens pre-filled);
/// omit it to create a new one (form opens blank).
Future<Map<String, dynamic>?> showTenantForm(
  BuildContext context, {
  required List<LeasingUnit> units,
  LeasingUnit? preselectedUnit,
  Tenant? existingTenant,
}) {
  if (units.isEmpty) return Future.value(null);
  final defaultUnit = preselectedUnit ?? units.first;

  if (Responsive.isMobile(context)) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TenantFormSheet(
          units: units,
          defaultUnit: defaultUnit,
          existingTenant: existingTenant),
    );
  }
  return showDialog<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true,
    barrierColor: AppColors.bgOuter.withValues(alpha: 0.7),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: _TenantFormSheet(
          units: units,
          defaultUnit: defaultUnit,
          existingTenant: existingTenant),
    ),
  );
}

// ── Draft ─────────────────────────────────────────────────────────────

class _Draft {
  _Draft(
      {required this.unitId,
      required this.businessType,
      required List<String> floors})
      : status = 'active',
        moveInDate = DateTime.now(),
        areas = [AreaEntryDraft()],
        companyName = '',
        selectedFloors = List<String>.from(floors);

  String unitId;
  String businessType;
  String companyName;
  List<String> selectedFloors;
  String status;
  DateTime? moveInDate;
  List<AreaEntryDraft> areas;
}

// ── Form sheet ────────────────────────────────────────────────────────

class _TenantFormSheet extends StatefulWidget {
  const _TenantFormSheet({
    required this.units,
    required this.defaultUnit,
    this.existingTenant,
  });

  final List<LeasingUnit> units;
  final LeasingUnit defaultUnit;
  final Tenant? existingTenant;

  @override
  State<_TenantFormSheet> createState() => _TenantFormSheetState();
}

class _TenantFormSheetState extends State<_TenantFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _Draft _draft;
  final _companyNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  static const _statuses = ['active', 'pending', 'inactive'];
  final _dateFmt = DateFormat('MMM d, yyyy');
  final _rentFmt =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  @override
  void initState() {
    super.initState();
    final cat = widget.defaultUnit.category;
    final fl = widget.defaultUnit.floor;
    _draft = _Draft(
      unitId: widget.defaultUnit.id,
      businessType: LeasingUnit.categories.contains(cat)
          ? cat
          : LeasingUnit.categories.first,
      floors:
          LeasingUnit.floors.contains(fl) ? [fl] : [LeasingUnit.floors.first],
    );

    final existing = widget.existingTenant;
    if (existing != null) {
      _firstNameCtrl.text = existing.firstName;
      _lastNameCtrl.text = existing.lastName;
      _emailCtrl.text = existing.email;
      _phoneCtrl.text = existing.phone;
      _companyNameCtrl.text = existing.companyName ?? '';
      _draft.status = existing.status;
      _draft.moveInDate = existing.moveInDate;
    }
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    for (final a in _draft.areas) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.moveInDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentGold,
            surface: AppColors.cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _draft.moveInDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_draft.unitId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a property before saving.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final data = <String, dynamic>{
      'leasing_unit_id': _draft.unitId,
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'status': _draft.status,
      'company_name': _companyNameCtrl.text.trim(),
      'business_type': _draft.businessType,
      'floor': _draft.selectedFloors.join(', '),
      'area_entries': _draft.areas
          .map((a) => {'type': a.type, 'sqft': a.sqft, 'rate': a.rate})
          .toList(),
      if (_draft.moveInDate != null)
        'move_in_date': _draft.moveInDate!.toIso8601String().substring(0, 10),
    };
    Navigator.of(context).pop(data);
  }

  InputDecoration get _dec => InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceSM, vertical: AppDimensions.spaceSM),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.accentSilver),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.error),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.error),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
        ),
        filled: true,
        fillColor: AppColors.pageBg,
      );

  @override
  Widget build(BuildContext context) {
    final isDesktop = !Responsive.isMobile(context);

    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 600,
        maxHeight: screenHeight * 0.88,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border),
          borderRadius: isDesktop
              ? BorderRadius.circular(AppDimensions.radiusMD)
              : const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusLG)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleBar(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spaceLG),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('PROPERTY', required: true),
                      const SizedBox(height: AppDimensions.spaceXS),
                      _buildPropertyDropdown(),
                      const SizedBox(height: AppDimensions.spaceMD),
                      Row(
                        children: [
                          Expanded(child: _buildBusinessTypeSection()),
                          const SizedBox(width: AppDimensions.spaceSM),
                          Expanded(child: _buildFloorSection()),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceMD),
                      _sectionLabel('AREA BREAKDOWN'),
                      const SizedBox(height: AppDimensions.spaceSM),
                      ..._draft.areas.asMap().entries.map((e) {
                        final i = e.key;
                        final a = e.value;
                        return _TenantAreaRow(
                          key: ValueKey(a),
                          draft: a,
                          fmt: _rentFmt,
                          onRemove: _draft.areas.length > 1
                              ? () => setState(() {
                                    a.dispose();
                                    _draft.areas.removeAt(i);
                                  })
                              : null,
                          onChanged: () => setState(() {}),
                        );
                      }),
                      const SizedBox(height: AppDimensions.spaceXS),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _draft.areas.add(AreaEntryDraft())),
                        child: Row(
                          children: const [
                            Icon(Icons.add_circle_outline,
                                size: AppDimensions.iconMD,
                                color: AppColors.accentGold),
                            SizedBox(width: AppDimensions.spaceXS),
                            Text('Add area entry',
                                style: TextStyle(
                                    fontSize: AppDimensions.fontBase,
                                    color: AppColors.accentGold,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceSM),
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceSM),
                        decoration: BoxDecoration(
                          color: AppColors.pageBg,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusXS),
                        ),
                        child: Row(
                          children: [
                            const Text('Monthly Rent',
                                style: TextStyle(
                                    fontSize: AppDimensions.fontBase,
                                    color: AppColors.textMuted)),
                            const Spacer(),
                            Text(
                              _rentFmt.format(
                                  _draft.areas.fold(0.0, (s, a) => s + a.rent)),
                              style: const TextStyle(
                                  fontSize: AppDimensions.fontH3,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentGold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMD),
                      _sectionLabel('TENANT NAME', required: true),
                      const SizedBox(height: AppDimensions.spaceXS),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField(
                                  _firstNameCtrl, 'First name',
                                  required: true)),
                          const SizedBox(width: AppDimensions.spaceSM),
                          Expanded(
                              child: _buildTextField(_lastNameCtrl, 'Last name',
                                  required: true)),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceSM),
                      _buildTextField(_companyNameCtrl,
                          'Company / Business name (optional)'),
                      const SizedBox(height: AppDimensions.spaceMD),
                      _sectionLabel('CONTACT'),
                      const SizedBox(height: AppDimensions.spaceXS),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField(_emailCtrl, 'Email',
                                  keyboardType: TextInputType.emailAddress)),
                          const SizedBox(width: AppDimensions.spaceSM),
                          Expanded(
                              child: _buildTextField(_phoneCtrl, 'Phone',
                                  keyboardType: TextInputType.phone)),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceMD),
                      Row(
                        children: [
                          Expanded(child: _buildStatusDropdown()),
                          const SizedBox(width: AppDimensions.spaceSM),
                          Expanded(child: _buildDatePicker()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceLG, vertical: AppDimensions.spaceMD),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Text(
            widget.existingTenant != null
                ? 'Edit Tenant Details'
                : 'Add Tenant',
            style: const TextStyle(
                fontSize: AppDimensions.fontH3,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close,
                size: AppDimensions.iconMD, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('BUSINESS TYPE'),
        const SizedBox(height: AppDimensions.spaceXS),
        DropdownButtonFormField<String>(
          initialValue: _draft.businessType,
          dropdownColor: AppColors.cardBg,
          isExpanded: true,
          style: const TextStyle(
              fontSize: AppDimensions.fontBase, color: AppColors.textPrimary),
          decoration: _dec,
          items: LeasingUnit.categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _draft.businessType = v!),
        ),
      ],
    );
  }

  Widget _buildFloorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('FLOOR (SELECT ALL THAT APPLY)'),
        const SizedBox(height: AppDimensions.spaceXS),
        Wrap(
          spacing: AppDimensions.spaceXS,
          runSpacing: AppDimensions.spaceXS,
          children: LeasingUnit.floors.map((floor) {
            final selected = _draft.selectedFloors.contains(floor);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  if (_draft.selectedFloors.length > 1) {
                    _draft.selectedFloors.remove(floor);
                  }
                } else {
                  _draft.selectedFloors.add(floor);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accentGold.withValues(alpha: 0.15)
                      : AppColors.pageBg,
                  border: Border.all(
                    color: selected ? AppColors.accentGold : AppColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(Icons.check,
                            size: 13, color: AppColors.accentGold),
                      ),
                    Text(
                      floor,
                      style: TextStyle(
                        fontSize: AppDimensions.fontBase,
                        color: selected
                            ? AppColors.accentGold
                            : AppColors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPropertyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _draft.unitId,
      dropdownColor: AppColors.cardBg,
      isExpanded: true,
      style: const TextStyle(
          fontSize: AppDimensions.fontBase, color: AppColors.textPrimary),
      decoration: _dec,
      items: widget.units
          .map((u) => DropdownMenuItem(
                value: u.id,
                child: Text(
                  '${u.name}  ·  ${u.category}',
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => _draft.unitId = v!),
      validator: (v) => (v == null || v.isEmpty) ? 'Select a property' : null,
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('STATUS'),
        const SizedBox(height: AppDimensions.spaceXS),
        DropdownButtonFormField<String>(
          initialValue: _draft.status,
          dropdownColor: AppColors.cardBg,
          style: const TextStyle(
              fontSize: AppDimensions.fontBase, color: AppColors.textPrimary),
          decoration: _dec,
          items: _statuses
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s[0].toUpperCase() + s.substring(1)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _draft.status = v!),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('MOVE-IN DATE'),
        const SizedBox(height: AppDimensions.spaceXS),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            height: 44,
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.spaceSM),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: AppDimensions.spaceXS),
                Text(
                  _draft.moveInDate != null
                      ? _dateFmt.format(_draft.moveInDate!)
                      : 'Select date',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          AppButton(
            label: 'CANCEL',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          AppButton(
            label:
                widget.existingTenant != null ? 'SAVE CHANGES' : 'ADD TENANT',
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {bool required = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
                fontSize: AppDimensions.fontXS,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(
                  fontSize: AppDimensions.fontXS,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                  letterSpacing: 1.0),
            ),
        ],
      );

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool required = false,
    TextInputType? keyboardType,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        style: const TextStyle(
            fontSize: AppDimensions.fontBase, color: AppColors.textPrimary),
        decoration: _dec.copyWith(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
        ),
      );
}

// ── Area entry row ─────────────────────────────────────────────────────

class _TenantAreaRow extends StatelessWidget {
  const _TenantAreaRow({
    super.key,
    required this.draft,
    required this.fmt,
    required this.onChanged,
    this.onRemove,
  });

  final AreaEntryDraft draft;
  final NumberFormat fmt;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  static const _types = ['covered', 'open', 'common'];
  static const _typeLabels = ['Covered Area', 'Open Area', 'Common Area'];

  static const _labelStyle = TextStyle(
    fontSize: AppDimensions.fontSM,
    color: AppColors.textMuted,
  );

  static InputDecoration get _fieldDec => InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceSM, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.accentSilver),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
        ),
        filled: true,
        fillColor: AppColors.pageBg,
      );

  Widget _col(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          const SizedBox(height: AppDimensions.spaceXS),
          field,
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Type
          Expanded(
            flex: 3,
            child: _col(
              'Type',
              DropdownButtonFormField<String>(
                initialValue: draft.type,
                dropdownColor: AppColors.cardBg,
                isExpanded: true,
                style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    color: AppColors.textPrimary),
                decoration: _fieldDec,
                items: List.generate(
                  _types.length,
                  (i) => DropdownMenuItem(
                      value: _types[i], child: Text(_typeLabels[i])),
                ),
                onChanged: (v) {
                  draft.type = v!;
                  onChanged();
                },
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          // Sq.ft
          Expanded(
            flex: 2,
            child: _col(
              'Sq.ft',
              TextFormField(
                controller: draft.sqftController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    color: AppColors.textPrimary),
                decoration:
                    _fieldDec.copyWith(hintText: '0', hintStyle: _labelStyle),
                onChanged: (_) => onChanged(),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          // ₹/sqft
          Expanded(
            flex: 2,
            child: _col(
              '₹ / sqft',
              TextFormField(
                controller: draft.rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    color: AppColors.textPrimary),
                decoration:
                    _fieldDec.copyWith(hintText: '0', hintStyle: _labelStyle),
                onChanged: (_) => onChanged(),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          // Computed rent
          Expanded(
            flex: 2,
            child: _col(
              'Rent',
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceSM),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                ),
                child: Text(
                  fmt.format(draft.rent),
                  style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      color: AppColors.accentGold),
                ),
              ),
            ),
          ),
          // Remove button — aligned to bottom of fields
          if (onRemove != null)
            Padding(
              padding: const EdgeInsets.only(left: AppDimensions.spaceXS),
              child: SizedBox(
                height: 44,
                child: GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.remove_circle_outline,
                      size: AppDimensions.iconMD, color: AppColors.error),
                ),
              ),
            )
          else
            const SizedBox(width: AppDimensions.iconMD + AppDimensions.spaceXS),
        ],
      ),
    );
  }
}
