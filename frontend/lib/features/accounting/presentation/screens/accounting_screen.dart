import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/entities/transaction.dart';
import '../providers/accounting_provider.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountingProvider>().loadTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _generateInvoices(AccountingProvider provider) async {
    try {
      final result = await provider.generateInvoices();
      if (!mounted) return;
      final created = result['created'] ?? 0;
      final skipped = result['skipped_already_exists'] ?? 0;
      final period = result['period'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created == 0
                ? 'All invoices for $period already generated ($skipped leases)'
                : '$created invoice${created == 1 ? '' : 's'} generated for $period'
                    '${skipped > 0 ? ', $skipped already existed' : ''}',
          ),
          backgroundColor:
              created > 0 ? AppColors.success : AppColors.textMuted,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate invoices: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  provider: provider,
                  onGenerate: () => _generateInvoices(provider),
                ),
                const SizedBox(height: AppDimensions.spaceLG),
                _KpiRow(provider: provider),
                const SizedBox(height: AppDimensions.spaceLG),
                _FilterRow(
                  provider: provider,
                  searchController: _searchController,
                ),
                const SizedBox(height: AppDimensions.spaceLG),
                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (provider.filtered.isEmpty)
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: AppStrings.noTransactions,
                    description: AppStrings.noTransactionsDesc,
                  )
                else
                  Responsive.isMobile(context)
                      ? _TransactionCardList(transactions: provider.filtered)
                      : _TransactionTable(transactions: provider.filtered),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.provider, required this.onGenerate});

  final AccountingProvider provider;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.accounting,
              style: TextStyle(
                fontSize: AppDimensions.fontH2,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${provider.transactions.length} transactions',
              style: const TextStyle(
                fontSize: AppDimensions.fontBase,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (provider.isGenerating)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accentGold),
            ),
          ),
        AppButton(
          label: 'Generate Invoices',
          icon: Icons.receipt_outlined,
          onPressed: provider.isGenerating ? null : onGenerate,
        ),
        const SizedBox(width: 8),
        AppButton(
          label: AppStrings.addTransaction,
          icon: Icons.add,
          onPressed: () {},
        ),
      ],
    );
  }
}

// ── KPI cards ─────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.provider});

  final AccountingProvider provider;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final cards = [
      _KpiData(
        label: AppStrings.totalIncome,
        value: provider.totalIncome,
        icon: Icons.trending_up_rounded,
        positive: true,
      ),
      _KpiData(
        label: AppStrings.totalExpenses,
        value: provider.totalExpenses,
        icon: Icons.trending_down_rounded,
        positive: false,
      ),
      _KpiData(
        label: AppStrings.netIncome,
        value: provider.netIncome,
        icon: Icons.account_balance_outlined,
        positive: provider.netIncome >= 0,
      ),
      _KpiData(
        label: AppStrings.outstandingRent,
        value: provider.outstandingRent,
        icon: Icons.pending_actions_outlined,
        positive: false,
        isWarning: true,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(children: [
            Expanded(child: _KpiCard(data: cards[0])),
            const SizedBox(width: AppDimensions.spaceSM),
            Expanded(child: _KpiCard(data: cards[1])),
          ]),
          const SizedBox(height: AppDimensions.spaceSM),
          Row(children: [
            Expanded(child: _KpiCard(data: cards[2])),
            const SizedBox(width: AppDimensions.spaceSM),
            Expanded(child: _KpiCard(data: cards[3])),
          ]),
        ],
      );
    }

    return Row(
      children: cards
          .map((d) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: d == cards.last ? 0 : AppDimensions.spaceSM,
                  ),
                  child: _KpiCard(data: d),
                ),
              ))
          .toList(),
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.positive,
    this.isWarning = false,
  });

  final String label;
  final double value;
  final IconData icon;
  final bool positive;
  final bool isWarning;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final iconColor = data.isWarning
        ? AppColors.warning
        : data.positive
            ? AppColors.success
            : AppColors.error;

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
          Row(
            children: [
              Icon(data.icon, size: AppDimensions.iconMD, color: iconColor),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          Text(
            fmt.format(data.value),
            style: const TextStyle(
              fontSize: AppDimensions.fontH2,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: AppDimensions.fontSM,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.provider, required this.searchController});

  final AccountingProvider provider;
  final TextEditingController searchController;

  static const _filterValues = [
    AccountingFilter.all,
    AccountingFilter.income,
    AccountingFilter.expenses,
    AccountingFilter.rentRoll,
  ];

  static const _filterLabels = [
    AppStrings.filterAll,
    AppStrings.income,
    AppStrings.expenses,
    AppStrings.rentRoll,
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    Widget chips = Wrap(
      spacing: AppDimensions.spaceSM,
      children: List.generate(_filterValues.length, (i) {
        final filterVal = _filterValues[i];
        final label = _filterLabels[i];
        final active = provider.filter == filterVal;
        return GestureDetector(
          onTap: () => provider.setFilter(filterVal),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD,
              vertical: AppDimensions.spaceXS,
            ),
            decoration: BoxDecoration(
              color: active ? AppColors.accentSilver : AppColors.cardBg,
              border: Border.all(
                color: active ? AppColors.accentSilver : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Text(
              label,
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

    Widget search = SizedBox(
      width: 240,
      height: 38,
      child: TextField(
        controller: searchController,
        onChanged: provider.setSearchQuery,
        style: const TextStyle(
          fontSize: AppDimensions.fontBase,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          hintText: AppStrings.searchTransactions,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: AppDimensions.iconMD,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chips,
          const SizedBox(height: AppDimensions.spaceSM),
          SizedBox(width: double.infinity, height: 38, child: search),
        ],
      );
    }

    return Row(
      children: [
        chips,
        const Spacer(),
        search,
      ],
    );
  }
}

// ── Desktop table ─────────────────────────────────────────────────────

class _TransactionTable extends StatelessWidget {
  const _TransactionTable({required this.transactions});

  final List<Transaction> transactions;

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
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD,
              vertical: AppDimensions.spaceSM,
            ),
            decoration: const BoxDecoration(
              color: AppColors.pageBg,
              border: Border(bottom: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusMD),
              ),
            ),
            child: const Row(
              children: [
                _TH(label: 'Date', flex: 2),
                _TH(label: 'Invoice #', flex: 2),
                _TH(label: 'Description', flex: 4),
                _TH(label: 'Category', flex: 2),
                _TH(label: 'Amount', flex: 2),
                _TH(label: 'Status', flex: 3),
              ],
            ),
          ),

          // Data rows
          ...transactions.asMap().entries.map((e) {
            return _TransactionRow(
              transaction: e.value,
              isLast: e.key == transactions.length - 1,
            );
          }),
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

class _TransactionRow extends StatefulWidget {
  const _TransactionRow({required this.transaction, required this.isLast});

  final Transaction transaction;
  final bool isLast;

  @override
  State<_TransactionRow> createState() => _TransactionRowState();
}

class _TransactionRowState extends State<_TransactionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final provider = context.read<AccountingProvider>();
    final fmt = DateFormat('MMM d, yyyy');
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final canMarkPaid =
        t.status != TransactionStatus.paid && t.type == TransactionType.income;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
          vertical: AppDimensions.spaceMD,
        ),
        child: Row(
          children: [
            // Date
            Expanded(
              flex: 2,
              child: Text(
                fmt.format(t.date),
                style: const TextStyle(
                  fontSize: AppDimensions.fontSM,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            // Invoice #
            Expanded(
              flex: 2,
              child: Text(
                t.referenceNo ?? '—',
                style: const TextStyle(
                  fontSize: AppDimensions.fontSM,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            // Description
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _TypeIcon(type: t.type),
                  const SizedBox(width: AppDimensions.spaceSM),
                  Expanded(
                    child: Text(
                      t.description,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Category
            Expanded(
              flex: 2,
              child: Text(
                t.category,
                style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            // Amount
            Expanded(
              flex: 2,
              child: Text(
                '${t.type == TransactionType.expense ? '-' : '+'}${money.format(t.amount)}',
                style: TextStyle(
                  fontSize: AppDimensions.fontBase,
                  fontWeight: FontWeight.w600,
                  color: t.type == TransactionType.income
                      ? AppColors.success
                      : AppColors.textPrimary,
                ),
              ),
            ),
            // Status + Mark Paid action
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _StatusBadge(status: t.status),
                  if (canMarkPaid && _hovered) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => provider.markPaid(t.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.occupiedBg,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusXS),
                          border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Mark Paid',
                          style: TextStyle(
                            fontSize: AppDimensions.fontXS,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile card list ──────────────────────────────────────────────────

class _TransactionCardList extends StatelessWidget {
  const _TransactionCardList({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final provider = context.read<AccountingProvider>();

    return Column(
      children: transactions.map((t) {
        final canMarkPaid = t.status != TransactionStatus.paid &&
            t.type == TransactionType.income;
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
              vertical: AppDimensions.spaceXS,
            ),
            leading: _TypeIcon(type: t.type),
            title: Text(
              t.description,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: AppDimensions.fontBase,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${t.referenceNo != null ? '${t.referenceNo}  •  ' : ''}${t.category}  •  ${fmt.format(t.date)}',
              style: const TextStyle(
                fontSize: AppDimensions.fontSM,
                color: AppColors.textMuted,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${t.type == TransactionType.expense ? '-' : '+'}${money.format(t.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: AppDimensions.fontBase,
                    color: t.type == TransactionType.income
                        ? AppColors.success
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _StatusBadge(status: t.status),
                if (canMarkPaid) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => provider.markPaid(t.id),
                    child: const Text(
                      'Mark Paid',
                      style: TextStyle(
                        fontSize: AppDimensions.fontXS,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: type == TransactionType.income
            ? AppColors.occupiedBg
            : AppColors.pendingBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      child: Icon(
        type == TransactionType.income
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded,
        size: AppDimensions.iconSM,
        color: type == TransactionType.income
            ? AppColors.success
            : AppColors.warning,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, textColor, label) = switch (status) {
      TransactionStatus.paid => (
          AppColors.occupiedBg,
          AppColors.occupiedText,
          'Paid'
        ),
      TransactionStatus.pending => (
          AppColors.pendingBg,
          AppColors.pendingText,
          'Pending'
        ),
      TransactionStatus.overdue => (
          const Color(0xFF2E0A0A),
          AppColors.error,
          'Overdue',
        ),
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
