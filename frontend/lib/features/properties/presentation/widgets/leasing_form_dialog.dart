import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/leasing_unit.dart';

// ── Draft classes (mutable form state) ───────────────────────────────

/// Mutable draft used in the add/edit form.
class LeasingUnitDraft {
  LeasingUnitDraft({LeasingUnit? unit})
      : name = unit?.name ?? '',
        category = unit?.category ?? LeasingUnit.categories.first,
        floor = unit?.floor ?? LeasingUnit.floors.first,
        status = unit?.status ?? 'vacant',
        contact = unit?.contact ?? '',
        email = unit?.email ?? '',
        notes = unit?.notes ?? '',
        areas = unit?.areas.map((a) => AreaEntryDraft.from(a)).toList() ??
            [AreaEntryDraft()];

  String name, category, floor, status, contact, email, notes;
  List<AreaEntryDraft> areas;
}

class AreaEntryDraft {
  AreaEntryDraft({this.type = 'covered', double sqft = 0, double rate = 0})
      : sqftController = TextEditingController(
            text: sqft > 0
                ? sqft.toStringAsFixed(sqft % 1 == 0 ? 0 : 2)
                : ''),
        rateController = TextEditingController(
            text: rate > 0
                ? rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2)
                : '');

  AreaEntryDraft.from(AreaEntry a)
      : type = a.type,
        sqftController = TextEditingController(
            text: a.sqft > 0
                ? a.sqft.toStringAsFixed(a.sqft % 1 == 0 ? 0 : 2)
                : ''),
        rateController = TextEditingController(
            text: a.rate > 0
                ? a.rate.toStringAsFixed(a.rate % 1 == 0 ? 0 : 2)
                : '');

  String type;
  final TextEditingController sqftController;
  final TextEditingController rateController;

  double get sqft => double.tryParse(sqftController.text) ?? 0;
  double get rate => double.tryParse(rateController.text) ?? 0;
  double get rent => sqft * rate;

  void dispose() {
    sqftController.dispose();
    rateController.dispose();
  }

  AreaEntry toAreaEntry() => AreaEntry(type: type, sqft: sqft, rate: rate);
}

// ─────────────────────────────────────────────────────────────────────

/// Opens the leasing unit add/edit form as a dialog (desktop) or
/// bottom sheet (mobile). Returns a [LeasingUnit] on save, null on cancel.
Future<LeasingUnit?> showLeasingForm(
  BuildContext context, {
  LeasingUnit? unit,
  String? suggestedId,
}) {
  if (Responsive.isMobile(context)) {
    return showModalBottomSheet<LeasingUnit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeasingFormSheet(unit: unit, suggestedId: suggestedId),
    );
  }
  return showDialog<LeasingUnit>(
    context: context,
    barrierColor: AppColors.bgOuter.withValues(alpha: 0.7),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: _LeasingFormSheet(unit: unit, suggestedId: suggestedId),
    ),
  );
}

// ── Sheet / dialog body ───────────────────────────────────────────────

class _LeasingFormSheet extends StatefulWidget {
  const _LeasingFormSheet({this.unit, this.suggestedId});

  final LeasingUnit? unit;
  final String? suggestedId;

  @override
  State<_LeasingFormSheet> createState() => _LeasingFormSheetState();
}

class _LeasingFormSheetState extends State<_LeasingFormSheet> {
  late final LeasingUnitDraft _draft;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  @override
  void initState() {
    super.initState();
    _draft = LeasingUnitDraft(unit: widget.unit);
    _nameController.text = _draft.name;
    _contactController.text = _draft.contact;
    _emailController.text = _draft.email;
    _notesController.text = _draft.notes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    for (final a in _draft.areas) {
      a.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final areas = _draft.areas.map((a) => a.toAreaEntry()).toList();
    final id = widget.unit?.id ??
        widget.suggestedId ??
        'lu_${DateTime.now().millisecondsSinceEpoch}';

    final result = LeasingUnit(
      id: id,
      name: _nameController.text.trim(),
      category: _draft.category,
      floor: _draft.floor,
      status: _draft.status,
      areas: areas,
      contact: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !Responsive.isMobile(context);
    final title = widget.unit == null
        ? AppStrings.addProperty
        : AppStrings.editProperty;

    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
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
          // ── Title bar ───────────────────────────────────────────
          _TitleBar(
            title: title,
            onClose: () => Navigator.of(context).pop(),
          ),

          // ── Scrollable body ──────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spaceLG),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic info
                    _SectionLabel(AppStrings.basicInfo),
                    const SizedBox(height: AppDimensions.spaceSM),

                    // Name
                    _Field(
                      label: AppStrings.tenantName,
                      controller: _nameController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.spaceSM),

                    // Category + Floor
                    Row(
                      children: [
                        Expanded(
                          child: _DropdownField(
                            label: AppStrings.category,
                            value: _draft.category,
                            items: LeasingUnit.categories,
                            onChanged: (v) =>
                                setState(() => _draft.category = v!),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceSM),
                        Expanded(
                          child: _DropdownField(
                            label: AppStrings.floorLevel,
                            value: _draft.floor,
                            items: [
                              ...LeasingUnit.floors,
                              'Ground Floor & First Floor',
                              'Ground Floor & First Floor & Second Floor',
                            ],
                            onChanged: (v) =>
                                setState(() => _draft.floor = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSM),

                    // Status
                    _DropdownField(
                      label: AppStrings.status,
                      value: _draft.status,
                      items: LeasingUnit.statuses,
                      itemLabel: (s) => switch (s) {
                        'occupied' => 'Occupied',
                        'vacant' => 'Vacant',
                        'in_house' => 'In-house operation',
                        'owner_occupied' => 'Owner-occupied',
                        _ => s,
                      },
                      onChanged: (v) => setState(() => _draft.status = v!),
                    ),
                    const SizedBox(height: AppDimensions.spaceLG),

                    // Area entries
                    _SectionLabel(AppStrings.areaEntries),
                    const SizedBox(height: AppDimensions.spaceSM),
                    ..._draft.areas.asMap().entries.map((e) {
                      final i = e.key;
                      final a = e.value;
                      return _AreaEntryRow(
                        key: ValueKey(a),
                        draft: a,
                        fmt: _fmt,
                        onRemove: _draft.areas.length > 1
                            ? () => setState(() {
                                  a.dispose();
                                  _draft.areas.removeAt(i);
                                })
                            : null,
                        onChanged: () => setState(() {}),
                      );
                    }),
                    const SizedBox(height: AppDimensions.spaceSM),
                    GestureDetector(
                      onTap: () => setState(() {
                        _draft.areas.add(AreaEntryDraft());
                      }),
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline,
                              size: AppDimensions.iconMD,
                              color: AppColors.textLink),
                          const SizedBox(width: AppDimensions.spaceXS),
                          const Text(
                            AppStrings.addAreaEntry,
                            style: TextStyle(
                              fontSize: AppDimensions.fontBase,
                              color: AppColors.textLink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Total rent preview
                    const SizedBox(height: AppDimensions.spaceSM),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceMD),
                      decoration: BoxDecoration(
                        color: AppColors.pageBg,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusXS),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Total Monthly Rent',
                            style: TextStyle(
                              fontSize: AppDimensions.fontBase,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _fmt.format(_draft.areas
                                .fold(0.0, (s, a) => s + a.rent)),
                            style: const TextStyle(
                              fontSize: AppDimensions.fontH3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceLG),

                    // Contact info
                    _SectionLabel(AppStrings.contactInfo),
                    const SizedBox(height: AppDimensions.spaceSM),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            label: AppStrings.tenantName,
                            controller: _contactController,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceSM),
                        Expanded(
                          child: _Field(
                            label: AppStrings.email,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSM),
                    _Field(
                      label: AppStrings.notes,
                      controller: _notesController,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Footer ──────────────────────────────────────────────
          _FormFooter(onSave: _save),
        ],
      ),
    );
  }
}

// ── Area entry row ────────────────────────────────────────────────────

class _AreaEntryRow extends StatelessWidget {
  const _AreaEntryRow({
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type
          Expanded(
            flex: 3,
            child: _DropdownField(
              label: 'Type',
              value: draft.type,
              items: _types,
              itemLabel: (t) => _typeLabels[_types.indexOf(t)],
              onChanged: (v) {
                draft.type = v!;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          // Sq.ft
          Expanded(
            flex: 3,
            child: _Field(
              label: 'Sq.ft',
              controller: draft.sqftController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          // Rate ₹/sqft
          Expanded(
            flex: 3,
            child: _Field(
              label: '₹ / sqft',
              controller: draft.rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          // Computed rent
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rent',
                    style: TextStyle(
                        fontSize: AppDimensions.fontSM,
                        color: AppColors.textMuted)),
                const SizedBox(height: AppDimensions.spaceXS),
                Container(
                  height: 38,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppDimensions.spaceSM),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    border: Border.all(color: AppColors.border),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusXS),
                  ),
                  child: Text(
                    fmt.format(draft.rent),
                    style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Remove button
          const SizedBox(width: AppDimensions.spaceXS),
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: IconButton(
              onPressed: onRemove,
              icon: Icon(
                Icons.remove_circle_outline,
                size: AppDimensions.iconMD,
                color: onRemove != null ? AppColors.error : AppColors.border,
              ),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceLG,
        vertical: AppDimensions.spaceMD,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AppDimensions.fontH3,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close,
                size: AppDimensions.iconMD, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _FormFooter extends StatelessWidget {
  const _FormFooter({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          AppButton(
            label: AppStrings.cancel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          AppButton(
            label: AppStrings.save,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: AppDimensions.fontXS,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: AppDimensions.fontSM, color: AppColors.textMuted)),
        const SizedBox(height: AppDimensions.spaceXS),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: AppDimensions.fontBase,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
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
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String Function(String)? itemLabel;

  @override
  Widget build(BuildContext context) {
    final allItems = items.contains(value) ? items : [value, ...items];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: AppDimensions.fontSM, color: AppColors.textMuted)),
        const SizedBox(height: AppDimensions.spaceXS),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AppColors.cardBg,
          style: const TextStyle(
            fontSize: AppDimensions.fontBase,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
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
            filled: true,
            fillColor: AppColors.pageBg,
          ),
          items: allItems
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(itemLabel != null ? itemLabel!(s) : s),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
