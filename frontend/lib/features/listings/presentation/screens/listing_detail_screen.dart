import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/entities/listing.dart';
import '../providers/listings_provider.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  static final _rentFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ListingsProvider>();
      if (provider.listings.isEmpty) provider.load();
      provider.loadPlatformPosts(widget.listingId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ListingsProvider>(
      builder: (context, provider, _) {
        final listing = provider.listings
            .where((l) => l.id == widget.listingId)
            .firstOrNull;
        final posts = provider.postsFor(widget.listingId);

        return Scaffold(
          backgroundColor: AppColors.pageBg,
          appBar: AppBar(
            backgroundColor: AppColors.topBarBg,
            elevation: 0,
            leading: const BackButton(color: AppColors.textPrimary),
            title: Text(
              listing?.title ?? 'Listing',
              style:
                  const TextStyle(fontSize: 15, color: AppColors.textHeading),
            ),
          ),
          body: provider.isLoading && listing == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accentGold))
              : listing == null
                  ? const Center(
                      child: Text('Listing not found',
                          style: TextStyle(color: AppColors.textMuted)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppDimensions.pagePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ListingInfoCard(listing: listing, rentFmt: _rentFmt),
                          const SizedBox(height: 20),
                          _PlatformGrid(
                            posts: posts,
                            listing: listing,
                            isLoading: provider.isLoading,
                            onRetry: (postId) =>
                                provider.retryPost(postId, listing.id),
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

class _ListingInfoCard extends StatelessWidget {
  const _ListingInfoCard({required this.listing, required this.rentFmt});

  final Listing listing;
  final NumberFormat rentFmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(listing.title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading)),
          const SizedBox(height: 8),
          _InfoRow('Monthly Rent', rentFmt.format(listing.monthlyRent)),
          if (listing.contactEmail != null)
            _InfoRow('Contact Email', listing.contactEmail!),
          if (listing.contactPhone != null)
            _InfoRow('Contact Phone', listing.contactPhone!),
          if (listing.description != null && listing.description!.isNotEmpty)
            _InfoRow('Description', listing.description!),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _PlatformGrid extends StatelessWidget {
  const _PlatformGrid({
    required this.posts,
    required this.listing,
    required this.isLoading,
    required this.onRetry,
  });

  final List<PlatformPost> posts;
  final Listing listing;
  final bool isLoading;
  final Future<void> Function(String postId) onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Platform Status',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading),
        ),
        const SizedBox(height: 12),
        if (isLoading && posts.isEmpty)
          const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold))
        else if (posts.isEmpty)
          const Text(
            'No platform posts yet. Tap Publish from the listings screen to start.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            itemCount: posts.length,
            itemBuilder: (context, i) => _PlatformCard(
              post: posts[i],
              onRetry: () => onRetry(posts[i].id),
            ),
          ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.post, required this.onRetry});

  final PlatformPost post;
  final VoidCallback onRetry;

  Color get _statusColor => switch (post.status) {
        'posted' => AppColors.success,
        'failed' => AppColors.error,
        'manual_required' => AppColors.warning,
        'posting' => AppColors.info,
        _ => AppColors.textMuted,
      };

  String get _statusLabel => switch (post.status) {
        'posted' => 'Posted',
        'failed' => 'Failed',
        'manual_required' => 'Manual Required',
        'posting' => 'Posting…',
        _ => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.platformName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeading,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: _statusColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_statusLabel,
              style: TextStyle(fontSize: 11, color: _statusColor)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (post.status == 'posted' && post.externalUrl != null)
                _CardAction(
                  label: 'View',
                  icon: Icons.open_in_new,
                  onTap: () => launchUrl(Uri.parse(post.externalUrl!)),
                ),
              if (post.status == 'failed')
                _CardAction(
                    label: 'Retry', icon: Icons.refresh, onTap: onRetry),
              if (post.status == 'manual_required')
                _CardAction(
                  label: 'Copy',
                  icon: Icons.copy,
                  onTap: () => _showCopyDialog(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCopyDialog(BuildContext context) {
    final content = [
      if (post.platformTitle != null) 'TITLE:\n${post.platformTitle}',
      if (post.platformDesc != null) '\nDESCRIPTION:\n${post.platformDesc}',
    ].join('\n');

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(
          'Copy for ${post.platformName}',
          style: const TextStyle(fontSize: 14, color: AppColors.textHeading),
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            content.isEmpty ? 'No content generated yet.' : content,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy All',
                style: TextStyle(color: AppColors.accentGold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close',
                style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.accentGold),
          const SizedBox(width: 3),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.accentGold)),
        ],
      ),
    );
  }
}
