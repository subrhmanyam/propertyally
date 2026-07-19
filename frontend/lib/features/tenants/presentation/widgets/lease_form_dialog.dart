import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/entities/tenant.dart';

/// Opens the add/edit-lease form as a dialog. Returns a Map ready to
/// POST/PATCH to the leases API, or null on cancel. Pass [existingLease]
/// to edit it (form opens pre-filled); omit it to create a new one.
Future<Map<String, dynamic>?> showLeaseForm(BuildContext context,
    {Lease? existingLease}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _LeaseFormDialog(existingLease: existingLease),
  );
}

class _LeaseFormDialog extends StatefulWidget {
  const _LeaseFormDialog({this.existingLease});

  final Lease? existingLease;

  @override
  State<_LeaseFormDialog> createState() => _LeaseFormDialogState();
}

class _LeaseFormDialogState extends State<_LeaseFormDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late String _status;
  late final _rentCtrl = TextEditingController(
      text: widget.existingLease != null
          ? widget.existingLease!.monthlyRent.toStringAsFixed(0)
          : '');
  late final _depositCtrl = TextEditingController(
      text: widget.existingLease != null
          ? widget.existingLease!.depositAmount.toStringAsFixed(0)
          : '');
  final _dateFmt = DateFormat('dd MMM yyyy');

  bool get _isEditing => widget.existingLease != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingLease;
    _startDate = existing?.startDate ?? DateTime.now();
    _endDate =
        existing?.endDate ?? DateTime.now().add(const Duration(days: 365));
    _status = existing?.status ?? 'active';
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _depositCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submit() {
    Navigator.pop(context, {
      'start_date': _startDate.toIso8601String().substring(0, 10),
      'end_date': _endDate.toIso8601String().substring(0, 10),
      'monthly_rent': double.tryParse(_rentCtrl.text.trim()) ?? 0.0,
      'deposit_amount': double.tryParse(_depositCtrl.text.trim()) ?? 0.0,
      'status': _status,
    });
  }

  InputDecoration get _dec => InputDecoration(
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

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: AppDimensions.fontSM,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD)),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_isEditing ? 'Edit Lease' : 'Add Lease',
                      style: const TextStyle(
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
              const SizedBox(height: AppDimensions.spaceMD),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Start Date'),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickDate(isStart: true),
                          child: InputDecorator(
                            decoration: _dec,
                            child: Row(
                              children: [
                                Text(_dateFmt.format(_startDate),
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: AppDimensions.fontSM)),
                                const Spacer(),
                                const Icon(Icons.calendar_today_outlined,
                                    size: 14, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('End Date'),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickDate(isStart: false),
                          child: InputDecorator(
                            decoration: _dec,
                            child: Row(
                              children: [
                                Text(_dateFmt.format(_endDate),
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: AppDimensions.fontSM)),
                                const Spacer(),
                                const Icon(Icons.calendar_today_outlined,
                                    size: 14, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Monthly Rent (₹)'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _rentCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: AppDimensions.fontSM),
                          decoration: _dec.copyWith(hintText: '0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Deposit Amount (₹)'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _depositCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: AppDimensions.fontSM),
                          decoration: _dec.copyWith(hintText: '0'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              _label('Status'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _status,
                dropdownColor: AppColors.cardBg,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppDimensions.fontSM),
                decoration: _dec,
                items: ['active', 'pending', 'expired']
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v[0].toUpperCase() + v.substring(1))))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? 'active'),
              ),
              const SizedBox(height: AppDimensions.spaceLG),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: AppDimensions.spaceSM),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentSilver,
                      foregroundColor: AppColors.bgOuter,
                      elevation: 0,
                    ),
                    child: Text(_isEditing ? 'Save Changes' : 'Save Lease'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
