import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/tenant_provider.dart';

class TenantServicesScreen extends StatefulWidget {
  const TenantServicesScreen({super.key});

  @override
  State<TenantServicesScreen> createState() => _TenantServicesScreenState();
}

class _TenantServicesScreenState extends State<TenantServicesScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Consumer<TenantProvider>(
      builder: (context, p, _) {
        final catalog = p.serviceCatalog;
        final categories = catalog
            .map((s) => s['category'] as String)
            .toSet()
            .toList()
          ..sort();
        final filtered = _selectedCategory == null
            ? catalog
            : catalog
                .where((s) => s['category'] == _selectedCategory)
                .toList();

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
                    fontSize: AppDimensions.fontSM,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: AppDimensions.spaceLG),

              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CategoryChip(
                      label: 'All',
                      selected: _selectedCategory == null,
                      onTap: () =>
                          setState(() => _selectedCategory = null),
                    ),
                    ...categories.map((c) => _CategoryChip(
                          label: c,
                          selected: _selectedCategory == c,
                          onTap: () =>
                              setState(() => _selectedCategory = c),
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
                    child: Text(
                        'No services available for your property type.',
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
                      onRequest: () => _showRequestDialog(context, p, filtered[i]),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                  fontSize: AppDimensions.fontSM,
                  color: AppColors.textMuted),
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
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusXS),
                ),
              ),
            ),
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
  const _ServiceCard(
      {required this.service, required this.onRequest});

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
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted),
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
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusXS),
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
