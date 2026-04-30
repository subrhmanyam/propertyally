import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/utils/responsive.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

enum _TenantNav { home, invoices, services, maintenance, messages }

class TenantShell extends StatelessWidget {
  const TenantShell({super.key, required this.child});

  final Widget child;

  static _TenantNav _toNav(String location) {
    if (location.startsWith('/tenant/invoices')) return _TenantNav.invoices;
    if (location.startsWith('/tenant/services')) return _TenantNav.services;
    if (location.startsWith('/tenant/maintenance')) {
      return _TenantNav.maintenance;
    }
    if (location.startsWith('/tenant/messages')) return _TenantNav.messages;
    return _TenantNav.home;
  }

  static String _toRoute(_TenantNav nav) => switch (nav) {
        _TenantNav.home => '/tenant',
        _TenantNav.invoices => '/tenant/invoices',
        _TenantNav.services => '/tenant/services',
        _TenantNav.maintenance => '/tenant/maintenance',
        _TenantNav.messages => '/tenant/messages',
      };

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final active = _toNav(location);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.bgOuter,
      bottomNavigationBar:
          isMobile ? _TenantBottomNav(active: active) : null,
      body: Row(
        children: [
          if (!isMobile) _TenantSidebar(active: active),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.contentBg,
                border: Border(
                    left: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Column(
                children: [
                  _TenantTopBar(),
                  Expanded(
                    child: Container(
                      color: AppColors.pageBg,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────

class _TenantSidebar extends StatelessWidget {
  const _TenantSidebar({required this.active});

  final _TenantNav active;

  static const _items = [
    (_TenantNav.home, Icons.home_outlined, 'Home'),
    (_TenantNav.invoices, Icons.receipt_long_outlined, 'Invoices'),
    (_TenantNav.services, Icons.home_repair_service_outlined, 'Services'),
    (_TenantNav.maintenance, Icons.build_outlined, 'Maintenance'),
    (_TenantNav.messages, Icons.chat_bubble_outline_rounded, 'Messages'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.spaceLG,
                AppDimensions.spaceXL,
                AppDimensions.spaceLG,
                AppDimensions.spaceLG),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentGold,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusXS),
                  ),
                  child: const Icon(Icons.domain,
                      color: AppColors.bgOuter, size: 16),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                const Text(
                  'TENANT',
                  style: TextStyle(
                    fontSize: AppDimensions.fontBase,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppDimensions.spaceMD),
          ..._items.map((item) => _SidebarItem(
                icon: item.$2,
                label: item.$3,
                active: active == item.$1,
                onTap: () => context.go(TenantShell._toRoute(item.$1)),
              )),
          const Spacer(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceSM,
              vertical: 2),
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD,
              vertical: AppDimensions.spaceSM),
          decoration: BoxDecoration(
            color: widget.active
                ? AppColors.sidebarItemActive
                : _hovered
                    ? AppColors.sidebarItemHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: AppDimensions.iconMD,
                color: widget.active
                    ? AppColors.sidebarIconActive
                    : AppColors.sidebarIcon,
              ),
              const SizedBox(width: AppDimensions.spaceSM),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: AppDimensions.fontBase,
                  fontWeight:
                      widget.active ? FontWeight.w600 : FontWeight.w400,
                  color: widget.active
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────

class _TenantTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceLG),
        decoration: const BoxDecoration(
          color: AppColors.contentBg,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            const Text(
              'Bogineni Group — Tenant Portal',
              style: TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              auth.userEmail,
              style: const TextStyle(
                  fontSize: AppDimensions.fontSM,
                  color: AppColors.textMuted),
            ),
            const SizedBox(width: AppDimensions.spaceMD),
            IconButton(
              icon: const Icon(Icons.logout_outlined,
                  color: AppColors.textMuted, size: AppDimensions.iconMD),
              tooltip: 'Sign out',
              onPressed: () => auth.signOut(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile bottom nav ─────────────────────────────────────────────────

class _TenantBottomNav extends StatelessWidget {
  const _TenantBottomNav({required this.active});

  final _TenantNav active;

  static const _items = [
    (_TenantNav.home, Icons.home_outlined, 'Home'),
    (_TenantNav.invoices, Icons.receipt_long_outlined, 'Invoices'),
    (_TenantNav.services, Icons.home_repair_service_outlined, 'Services'),
    (_TenantNav.maintenance, Icons.build_outlined, 'Maintenance'),
    (_TenantNav.messages, Icons.chat_bubble_outline_rounded, 'Messages'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        _items.indexWhere((e) => e.$1 == active).clamp(0, _items.length - 1);
    return NavigationBar(
      backgroundColor: AppColors.sidebarBg,
      indicatorColor: AppColors.sidebarItemActive,
      selectedIndex: currentIndex,
      onDestinationSelected: (i) =>
          context.go(TenantShell._toRoute(_items[i].$1)),
      destinations: _items
          .map((e) => NavigationDestination(
                icon: Icon(e.$2, color: AppColors.sidebarIcon),
                selectedIcon: Icon(e.$2, color: AppColors.sidebarIconActive),
                label: e.$3,
              ))
          .toList(),
    );
  }
}
