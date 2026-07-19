import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/listing.dart';

class PlatformStatusStrip extends StatelessWidget {
  const PlatformStatusStrip({super.key, required this.posts});

  final List<PlatformPost> posts;

  static const _knownPlatforms = [
    'housing_com',
    '99acres',
    'magicbricks',
    'nobroker'
  ];

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Text('Not published',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted));
    }
    final byKey = {for (final p in posts) p.platformKey: p};
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: _knownPlatforms.map((key) {
        final post = byKey[key];
        return _PlatformDot(platformKey: key, post: post);
      }).toList(),
    );
  }
}

class _PlatformDot extends StatelessWidget {
  const _PlatformDot({required this.platformKey, this.post});

  final String platformKey;
  final PlatformPost? post;

  Color get _color {
    if (post == null) return AppColors.textMuted.withValues(alpha: 0.3);
    return switch (post!.status) {
      'posted' => AppColors.success,
      'failed' => AppColors.error,
      'manual_required' => AppColors.warning,
      'posting' => AppColors.info,
      _ => AppColors.textMuted,
    };
  }

  String get _label {
    final name = switch (platformKey) {
      'housing_com' => 'Housing.com',
      '99acres' => '99acres',
      'magicbricks' => 'MagicBricks',
      'nobroker' => 'NoBroker',
      _ => platformKey,
    };
    final status = post?.status ?? 'not attempted';
    return '$name: $status';
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _label,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      ),
    );
  }
}
