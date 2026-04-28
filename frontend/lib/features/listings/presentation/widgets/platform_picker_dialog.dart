import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/listings_provider.dart';

class PlatformPickerDialog extends StatefulWidget {
  const PlatformPickerDialog({super.key, required this.unitId});

  final String unitId;

  /// Returns the selected platform keys, or null if cancelled.
  static Future<List<String>?> show(BuildContext context, String unitId) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => PlatformPickerDialog(unitId: unitId),
    );
  }

  @override
  State<PlatformPickerDialog> createState() => _PlatformPickerDialogState();
}

class _PlatformPickerDialogState extends State<PlatformPickerDialog> {
  List<Map<String, dynamic>> _platforms = [];
  final Set<String> _selected = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final provider = context.read<ListingsProvider>();
      final platforms = await provider.getPlatformsForUnit(widget.unitId);
      if (mounted) {
        setState(() {
          _platforms = platforms;
          _selected.addAll(platforms.map((p) => p['key'].toString()));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      title: const Text(
        'Choose Platforms',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textHeading),
      ),
      content: SizedBox(
        width: 340,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
            : _error != null
                ? Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error))
                : _platforms.isEmpty
                    ? const Text(
                        'No platforms available for this property type.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Select the platforms to publish this listing to:',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 12),
                          ..._platforms.map((p) {
                            final key = p['key'].toString();
                            final name = p['name'].toString();
                            final isManual = p['api_type'] == 'manual';
                            return CheckboxListTile(
                              value: _selected.contains(key),
                              onChanged: (val) => setState(() {
                                if (val == true) {
                                  _selected.add(key);
                                } else {
                                  _selected.remove(key);
                                }
                              }),
                              title: Text(
                                name,
                                style: const TextStyle(fontSize: 13, color: AppColors.textHeading),
                              ),
                              subtitle: isManual
                                  ? const Text(
                                      'Manual posting — content will be generated for you to copy',
                                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    )
                                  : null,
                              activeColor: AppColors.accentGold,
                              checkColor: AppColors.bgOuter,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            );
                          }),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.toList()),
          child: Text(
            'Publish to ${_selected.length} Platform${_selected.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: _selected.isEmpty ? AppColors.textMuted : AppColors.accentGold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
