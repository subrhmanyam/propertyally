import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/tenant_provider.dart';

class TenantMaintenanceScreen extends StatefulWidget {
  const TenantMaintenanceScreen({super.key});

  @override
  State<TenantMaintenanceScreen> createState() =>
      _TenantMaintenanceScreenState();
}

class _TenantMaintenanceScreenState extends State<TenantMaintenanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantProvider>().refreshMaintenance();
    });
  }

  void _showNewRequest(BuildContext context, TenantProvider p) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('New Maintenance Request',
              style: TextStyle(color: AppColors.textPrimary)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('Title'),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppDimensions.fontSM),
                  decoration: _dec('e.g. Leaking tap in kitchen'),
                ),
                const SizedBox(height: AppDimensions.spaceMD),
                _Label('Description'),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppDimensions.fontSM),
                  decoration: _dec('Describe the issue...'),
                ),
                const SizedBox(height: AppDimensions.spaceMD),
                _Label('Priority'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  dropdownColor: AppColors.cardBg,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppDimensions.fontSM),
                  decoration: _dec(''),
                  items: ['low', 'medium', 'high', 'urgent']
                      .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v[0].toUpperCase() + v.substring(1))))
                      .toList(),
                  onChanged: (v) => setS(() => priority = v ?? 'medium'),
                ),
              ],
            ),
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
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await p.addMaintenance({
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'priority': priority,
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Request submitted.')),
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
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TenantProvider>(
      builder: (context, p, _) => Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Maintenance Requests',
                  style: TextStyle(
                      fontSize: AppDimensions.fontH2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Request'),
                  onPressed: () => _showNewRequest(context, p),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSilver,
                    foregroundColor: AppColors.bgOuter,
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceXL),
            if (p.isLoading)
              const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.accentSilver))
            else if (p.maintenance.isEmpty)
              const Center(
                  child: Text('No maintenance requests.',
                      style: TextStyle(color: AppColors.textMuted)))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: p.maintenance.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.spaceSM),
                  itemBuilder: (_, i) =>
                      _MaintenanceCard(req: p.maintenance[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.req});

  final Map<String, dynamic> req;

  @override
  Widget build(BuildContext context) {
    final status = req['status'] as String? ?? 'open';
    final priority = req['priority'] as String? ?? 'medium';

    final priorityColor = switch (priority) {
      'urgent' => AppColors.error,
      'high' => AppColors.warning,
      _ => AppColors.textMuted,
    };

    final statusColor = switch (status) {
      'completed' => AppColors.occupiedText,
      'in_progress' => AppColors.info,
      _ => AppColors.textMuted,
    };

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req['title'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                if ((req['description'] as String?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    req['description'] as String,
                    style: const TextStyle(
                        fontSize: AppDimensions.fontSM,
                        color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor),
              ),
              const SizedBox(height: 4),
              Text(
                priority.toUpperCase(),
                style: TextStyle(fontSize: 11, color: priorityColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: AppDimensions.fontSM,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
      );
}
