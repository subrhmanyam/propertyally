import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Bell icon + unread badge for the top bar. Backs onto the existing
/// /api/v1/notifications in-app inbox endpoints (list, unread-count,
/// mark-read, mark-all-read) — those were already built server-side but
/// had no frontend consumer until this widget.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  int _unreadCount = 0;

  String? get _userId => context.read<AuthProvider>().user?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCount());
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    if (!mounted) return;
    final userId = _userId;
    if (userId == null) return;
    try {
      final res = await ApiClient.instance.get(
        '/api/v1/notifications/unread-count',
        queryParameters: {'user_id': userId},
      );
      if (mounted) {
        setState(
            () => _unreadCount = (res.data['count'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {
      // Badge just keeps its last known value — not worth surfacing an error.
    }
  }

  void _toggleOverlay() {
    if (_overlay != null) {
      _removeOverlay();
      return;
    }
    final userId = _userId;
    if (userId == null) return;
    _overlay = OverlayEntry(
      builder: (_) => _NotificationOverlay(
        link: _layerLink,
        userId: userId,
        onClose: _removeOverlay,
        onUnreadCountChanged: (count) {
          if (mounted) setState(() => _unreadCount = count);
        },
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
          onTap: _toggleOverlay,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceXS),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.topBarIcon, size: AppDimensions.iconMD),
                if (_unreadCount > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 15),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppColors.topBarBg, width: 1.5),
                      ),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dropdown overlay ────────────────────────────────────────────────────

class _NotificationOverlay extends StatelessWidget {
  const _NotificationOverlay({
    required this.link,
    required this.userId,
    required this.onClose,
    required this.onUnreadCountChanged,
  });

  final LayerLink link;
  final String userId;
  final VoidCallback onClose;
  final ValueChanged<int> onUnreadCountChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap-outside-to-dismiss barrier.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 360,
              constraints: const BoxConstraints(maxHeight: 440),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black54,
                      blurRadius: 16,
                      offset: Offset(0, 4)),
                ],
              ),
              child: _NotificationPanel(
                userId: userId,
                onUnreadCountChanged: onUnreadCountChanged,
                onNavigate: onClose,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Panel content ────────────────────────────────────────────────────────

class _NotificationPanel extends StatefulWidget {
  const _NotificationPanel({
    required this.userId,
    required this.onUnreadCountChanged,
    required this.onNavigate,
  });

  final String userId;
  final ValueChanged<int> onUnreadCountChanged;
  final VoidCallback onNavigate;

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _unreadCount =>
      _notifications.where((n) => n['is_read'] != true).length;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.get(
        '/api/v1/notifications/',
        queryParameters: {'user_id': widget.userId},
      );
      if (!mounted) return;
      setState(() {
        _notifications = (res.data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
      widget.onUnreadCountChanged(_unreadCount);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load notifications.';
        });
      }
    }
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['is_read'] == true) return;
    setState(() {
      final idx = _notifications.indexWhere((e) => e['id'] == n['id']);
      if (idx != -1) {
        _notifications[idx] = {..._notifications[idx], 'is_read': true};
      }
    });
    widget.onUnreadCountChanged(_unreadCount);
    try {
      await ApiClient.instance.put(
        '/api/v1/notifications/${n['id']}/read',
        queryParameters: {'user_id': widget.userId},
      );
    } catch (_) {
      // Local state already flipped — a failed server-side mark-read isn't
      // worth reverting the UI over.
    }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0) return;
    setState(() {
      _notifications =
          _notifications.map((n) => {...n, 'is_read': true}).toList();
    });
    widget.onUnreadCountChanged(0);
    try {
      await ApiClient.instance.put(
        '/api/v1/notifications/read-all',
        queryParameters: {'user_id': widget.userId},
      );
    } catch (_) {}
  }

  void _onTapNotification(Map<String, dynamic> n) {
    _markRead(n);
    final actionUrl = n['action_url'] as String?;
    if (actionUrl != null && actionUrl.startsWith('/')) {
      widget.onNavigate();
      context.go(actionUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.spaceMD,
              AppDimensions.spaceSM,
              AppDimensions.spaceSM,
              AppDimensions.spaceSM),
          child: Row(
            children: [
              const Text('Notifications',
                  style: TextStyle(
                      fontSize: AppDimensions.fontBase,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              if (_unreadCount > 0)
                TextButton(
                  onPressed: _markAllRead,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Mark all read',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.accentGold)),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Flexible(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(AppDimensions.spaceLG),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accentGold))),
                )
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(AppDimensions.spaceLG),
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.textMuted)),
                    )
                  : _notifications.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(AppDimensions.spaceLG),
                          child: Center(
                            child: Text('No notifications yet.',
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (_, i) => _NotificationTile(
                            notification: _notifications[i],
                            onTap: () => _onTapNotification(_notifications[i]),
                          ),
                        ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] == true;
    final title = notification['title'] as String? ?? '';
    final body = notification['body'] as String?;
    final type = notification['type'] as String? ?? 'info';
    final createdAt =
        DateTime.tryParse(notification['created_at'] as String? ?? '');

    final (icon, color) = switch (type) {
      'success' => (Icons.check_circle_outline, AppColors.occupiedText),
      'warning' => (Icons.warning_amber_rounded, AppColors.warning),
      'error' => (Icons.error_outline, AppColors.error),
      _ => (Icons.info_outline, AppColors.info),
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead ? Colors.transparent : AppColors.sidebarItemHover,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceMD, vertical: AppDimensions.spaceSM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppDimensions.spaceSM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: AppDimensions.fontSM,
                          fontWeight:
                              isRead ? FontWeight.w500 : FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(body,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                        DateFormat('MMM d, h:mm a').format(createdAt.toLocal()),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 6, top: 4),
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: AppColors.accentGold, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
