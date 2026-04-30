import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/tenant_provider.dart';

class TenantInvoicesScreen extends StatefulWidget {
  const TenantInvoicesScreen({super.key});

  @override
  State<TenantInvoicesScreen> createState() => _TenantInvoicesScreenState();
}

class _TenantInvoicesScreenState extends State<TenantInvoicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantProvider>().refreshInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TenantProvider>(
      builder: (context, p, _) {
        return Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Invoices',
                style: TextStyle(
                    fontSize: AppDimensions.fontH2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppDimensions.spaceXL),
              if (p.isLoading)
                const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accentSilver))
              else if (p.invoices.isEmpty)
                const Center(
                    child: Text('No invoices found.',
                        style: TextStyle(color: AppColors.textMuted)))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: p.invoices.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.spaceSM),
                    itemBuilder: (context, i) =>
                        _InvoiceCard(inv: p.invoices[i], provider: p),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InvoiceCard extends StatefulWidget {
  const _InvoiceCard({required this.inv, required this.provider});

  final Map<String, dynamic> inv;
  final TenantProvider provider;

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final result =
          await widget.provider.startPayment(widget.inv['id'] as String);
      final url = Uri.parse(result['url']!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.inv;
    final isPaid = inv['status'] == 'paid';
    final isOverdue = inv['status'] == 'overdue';
    final amount = (inv['amount'] as num?)?.toDouble() ?? 0;
    final refNo = inv['reference_no'] as String? ?? '';
    final desc = inv['description'] as String? ?? 'Invoice';
    final date = inv['date'] as String? ?? '';

    Color statusBg = AppColors.vacantBg;
    Color statusText = AppColors.vacantText;
    String statusLabel = 'Pending';
    if (isPaid) {
      statusBg = AppColors.occupiedBg;
      statusText = AppColors.occupiedText;
      statusLabel = 'Paid';
    } else if (isOverdue) {
      statusBg = AppColors.pendingBg;
      statusText = AppColors.pendingText;
      statusLabel = 'Overdue';
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              color: AppColors.textMuted, size: AppDimensions.iconLG),
          const SizedBox(width: AppDimensions.spaceLG),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${refNo.isNotEmpty ? '$refNo · ' : ''}$date',
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(statusLabel,
                    style: TextStyle(fontSize: 11, color: statusText)),
              ),
            ],
          ),
          if (!isPaid) ...[
            const SizedBox(width: AppDimensions.spaceLG),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: _paying ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: AppColors.bgOuter,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusXS)),
                ),
                child: _paying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.bgOuter))
                    : const Text('Pay',
                        style: TextStyle(
                            fontSize: AppDimensions.fontSM,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
