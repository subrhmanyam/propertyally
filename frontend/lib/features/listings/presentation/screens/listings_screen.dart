import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/entities/listing.dart';
import '../providers/listings_provider.dart';
import '../widgets/platform_picker_dialog.dart';
import '../widgets/platform_status_strip.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ListingsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ListingsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.pageBg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(onRefresh: provider.load),
              if (provider.isLoading)
                const LinearProgressIndicator(
                    color: AppColors.accentGold, minHeight: 2),
              if (provider.hasError)
                _ErrorBanner(message: provider.errorMessage!),
              Expanded(
                child: provider.listings.isEmpty && !provider.isLoading
                    ? const _EmptyState()
                    : _ListingsTable(listings: provider.listings),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.pagePadding,
        AppDimensions.pagePadding,
        12,
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Vacant units published to real estate platforms',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon:
                const Icon(Icons.refresh, color: AppColors.textMuted, size: 18),
            tooltip: 'Refresh',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _ListingsTable extends StatelessWidget {
  const _ListingsTable({required this.listings});

  final List<Listing> listings;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding:
          const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
      itemCount: listings.length,
      itemBuilder: (context, i) => _ListingRow(listing: listings[i]),
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing});

  final Listing listing;
  static final _rentFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ListingsProvider>();
    return GestureDetector(
      onTap: () => context.push('/listings/${listing.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Title + rent
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textHeading,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_rentFmt.format(listing.monthlyRent)}/month',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.accentGold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Platform status strip
            FutureBuilder<void>(
              future: provider.loadPlatformPosts(listing.id),
              builder: (_, __) => PlatformStatusStrip(
                posts: provider.postsFor(listing.id),
              ),
            ),
            const SizedBox(width: 16),
            // Trigger agent button if no posts yet
            if (provider.postsFor(listing.id).isEmpty)
              _TriggerButton(unitId: listing.leasingUnitId),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _TriggerButton extends StatelessWidget {
  const _TriggerButton({required this.unitId});

  final String unitId;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ListingsProvider>();
    return GestureDetector(
      onTap: () async {
        final selected = await PlatformPickerDialog.show(context, unitId);
        if (selected == null || selected.isEmpty || !context.mounted) return;
        try {
          await provider.triggerAgent(unitId, selected);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Publishing to ${selected.length} platform${selected.length == 1 ? '' : 's'}…')),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to trigger agent')),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accentGoldDark,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Publish',
          style: TextStyle(
              fontSize: 11,
              color: AppColors.accentGold,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.pagePadding, vertical: 8),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Text(message,
          style: const TextStyle(fontSize: 12, color: AppColors.error)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment_outlined, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No listings yet',
            style: TextStyle(fontSize: 16, color: AppColors.textMuted),
          ),
          SizedBox(height: 4),
          Text(
            'Listings are created automatically when a unit becomes vacant.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
