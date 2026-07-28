import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/leasing_unit.dart';

// ── Draft classes (mutable form state) ───────────────────────────────

/// Mutable draft used in the add/edit form.
class LeasingUnitDraft {
  LeasingUnitDraft({LeasingUnit? unit})
      : name = unit?.name ?? '',
        companyName = unit?.companyName ?? '',
        category = unit?.category ?? LeasingUnit.categories.first,
        floor = unit?.floor ?? LeasingUnit.floors.first,
        status = unit?.status ?? 'vacant',
        contact = unit?.contact ?? '',
        email = unit?.email ?? '',
        notes = unit?.notes ?? '',
        photos = List<String>.from(unit?.photos ?? const []),
        areas = unit?.areas.map((a) => AreaEntryDraft.from(a)).toList() ??
            [AreaEntryDraft()];

  String name, companyName, category, floor, status, contact, email, notes;
  List<AreaEntryDraft> areas;
  List<String> photos;
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
  // useRootNavigator: true is required when inside a GoRouter ShellRoute —
  // without it, the shell's nested navigator intercepts the call and the
  // dialog never appears.
  if (Responsive.isMobile(context)) {
    return showModalBottomSheet<LeasingUnit>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeasingFormSheet(unit: unit, suggestedId: suggestedId),
    );
  }
  return showDialog<LeasingUnit>(
    context: context,
    useRootNavigator: true,
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
  String? get _userId => Supabase.instance.client.auth.currentUser?.id;
  static const _kCustom = '__custom__';

  late final LeasingUnitDraft _draft;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _draft = LeasingUnitDraft(unit: widget.unit);
    _nameController.text = _draft.name;
    _companyController.text = _draft.companyName;
    _contactController.text = _draft.contact;
    _emailController.text = _draft.email;
    _notesController.text = _draft.notes;

    // If saved category is not in the standard list, treat it as custom Other.
    if (_draft.category.isNotEmpty &&
        !LeasingUnit.categories.contains(_draft.category)) {
      _customCategoryController.text = _draft.category;
      _draft.category = _kCustom;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    for (final a in _draft.areas) {
      a.dispose();
    }
    super.dispose();
  }

  void _onCategoryChanged(String? v) {
    if (v == null) return;
    setState(() {
      if (v == 'Other') {
        _draft.category = _kCustom;
        _customCategoryController.clear();
      } else {
        _draft.category = v;
        _customCategoryController.clear();
      }
    });
  }

  Future<void> _pickAndUploadPhotos() async {
    final unitId = widget.unit?.id;
    if (unitId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    setState(() => _uploadingPhoto = true);
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      try {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: file.name),
        });
        final res = await ApiClient.properties.post(
          '/api/v1/leasing/$unitId/photos',
          queryParameters: {if (_userId != null) 'user_id': _userId},
          data: formData,
        );
        final photos = (res.data['photos'] as List?)?.map((e) => e.toString()).toList();
        if (photos != null && mounted) {
          setState(() => _draft.photos = photos);
        }
      } on DioException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not upload "${file.name}": '
              '${(e.response?.data is Map ? e.response?.data['detail'] : null) ?? e.message}'),
          backgroundColor: AppColors.error,
        ));
      }
    }
    if (mounted) setState(() => _uploadingPhoto = false);
  }

  Future<void> _deletePhoto(String photoUrl) async {
    final unitId = widget.unit?.id;
    if (unitId == null) return;
    setState(() => _draft.photos.remove(photoUrl));
    try {
      await ApiClient.properties.delete(
        '/api/v1/leasing/$unitId/photos',
        queryParameters: {if (_userId != null) 'user_id': _userId},
        data: {'photo_url': photoUrl},
      );
    } on DioException catch (_) {
      // Best-effort — the photo stays removed from this form's view even if
      // the backend delete failed; retrying is just re-uploading, not worse.
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final category = _draft.category == _kCustom
        ? _customCategoryController.text.trim()
        : _draft.category;
    if (category.isEmpty) return;

    final areas = _draft.areas.map((a) => a.toAreaEntry()).toList();
    final id = widget.unit?.id ??
        widget.suggestedId ??
        'lu_${DateTime.now().millisecondsSinceEpoch}';

    final result = LeasingUnit(
      id: id,
      name: _nameController.text.trim(),
      companyName: _companyController.text.trim(),
      category: category,
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
      photos: _draft.photos,
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

                    // Owner Name + Property Name
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            label: 'Owner Name',
                            controller: _companyController,
                            hint: 'e.g. Bogineni Group',
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Name missing' : null,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceSM),
                        Expanded(
                          child: _Field(
                            label: 'Property Name',
                            controller: _nameController,
                            hint: 'e.g. Nandhini Restaurant',
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSM),

                    // Property Category
                    Row(
                      children: [
                        Expanded(
                          child: _DropdownField(
                            label: 'Property Category',
                            value: _draft.category == _kCustom
                                ? 'Other'
                                : (_draft.category.isEmpty
                                    ? LeasingUnit.categories.first
                                    : _draft.category),
                            items: LeasingUnit.categories,
                            onChanged: _onCategoryChanged,
                          ),
                        ),
                        if (_draft.category == _kCustom) ...[
                          const SizedBox(width: AppDimensions.spaceSM),
                          Expanded(
                            child: _Field(
                              label: 'Custom Category',
                              controller: _customCategoryController,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSM),

                    // Floor
                    _DropdownField(
                      label: AppStrings.floorLevel,
                      value: _draft.floor,
                      items: [
                        ...LeasingUnit.floors,
                        'Ground Floor & First Floor',
                        'Ground Floor & First Floor & Second Floor',
                      ],
                      onChanged: (v) => setState(() => _draft.floor = v!),
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

                    // Photos — only once the property exists, since photo
                    // uploads are keyed by its real (server-assigned) id.
                    if (widget.unit != null) ...[
                      const SizedBox(height: AppDimensions.spaceLG),
                      _SectionLabel('Photos'),
                      const SizedBox(height: AppDimensions.spaceSM),
                      _PhotoGrid(
                        photos: _draft.photos,
                        uploading: _uploadingPhoto,
                        onAdd: _pickAndUploadPhotos,
                        onDelete: _deletePhoto,
                      ),
                    ] else ...[
                      const SizedBox(height: AppDimensions.spaceLG),
                      Text(
                        'Save the property first, then reopen it to add photos.',
                        style: const TextStyle(
                            fontSize: AppDimensions.fontSM,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
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

// ── Photo grid ───────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.uploading,
    required this.onAdd,
    required this.onDelete,
  });

  final List<String> photos;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spaceSM,
      runSpacing: AppDimensions.spaceSM,
      children: [
        for (final url in photos)
          _PhotoThumb(url: url, onDelete: () => onDelete(url)),
        _AddPhotoTile(uploading: uploading, onTap: uploading ? null : onAdd),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url, required this.onDelete});

  final String url;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            child: Image.network(
              url,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 88,
                height: 88,
                color: AppColors.pageBg,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textMuted),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.bgOuter,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    size: 14, color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.uploading, required this.onTap});

  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.pageBg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        ),
        child: uploading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.textMuted, size: AppDimensions.iconLG),
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
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
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
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: AppDimensions.fontBase,
              color: AppColors.textMuted,
            ),
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
