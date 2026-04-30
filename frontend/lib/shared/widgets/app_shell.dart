import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import 'sidebar_nav.dart';
import 'top_bar.dart';

/// Main layout shell: dark outer background + sidebar + white content area.
/// Wraps the current GoRouter child and determines the active nav item from
/// the current route path.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final activeItem = _toNavItem(location);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.bgOuter,
      bottomNavigationBar:
          isMobile ? _MobileBottomNav(activeItem: activeItem) : null,
      body: Row(
        children: [
          // ── Sidebar (tablet/desktop only) ───────────────────────
          if (!isMobile)
            SidebarNav(
              activeItem: activeItem,
              onItemTap: (item) => context.go(_toRoute(item)),
            ),

          // ── Main content area ─────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.contentBg,
                border: Border(
                  left: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Column(
                children: [
                  TopBar(onMenuTap: isMobile ? () {} : null),
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

  static NavItem _toNavItem(String location) {
    if (location.startsWith('/properties')) return NavItem.properties;
    if (location.startsWith('/tenants')) return NavItem.tenants;
    if (location.startsWith('/accounting')) return NavItem.accounting;
    if (location.startsWith('/maintenance')) return NavItem.maintenance;
    if (location.startsWith('/services')) return NavItem.services;
    if (location.startsWith('/reports')) return NavItem.reports;
    if (location.startsWith('/listings')) return NavItem.listings;
    if (location.startsWith('/calendar')) return NavItem.calendar;
    if (location.startsWith('/documents')) return NavItem.documents;
    return NavItem.dashboard;
  }

  static String _toRoute(NavItem item) => switch (item) {
        NavItem.dashboard => '/',
        NavItem.properties => '/properties',
        NavItem.tenants => '/tenants',
        NavItem.accounting => '/accounting',
        NavItem.maintenance => '/maintenance',
        NavItem.services => '/services',
        NavItem.reports => '/reports',
        NavItem.listings => '/listings',
        NavItem.calendar => '/calendar',
        NavItem.documents => '/documents',
      };
}

// ── Mobile bottom nav (5 primary items) ─────────────────────────────

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({required this.activeItem});

  final NavItem activeItem;

  @override
  Widget build(BuildContext context) {
    const items = [
      NavItem.dashboard,
      NavItem.properties,
      NavItem.tenants,
      NavItem.accounting,
      NavItem.maintenance,
    ];
    const icons = [
      Icons.grid_view_rounded,
      Icons.home_outlined,
      Icons.people_outline_rounded,
      Icons.monetization_on_outlined,
      Icons.build_outlined,
    ];
    const labels = ['Dashboard', 'Properties', 'Tenants', 'Accounting', 'Maintenance'];

    final currentIndex = items.indexOf(activeItem).clamp(0, items.length - 1);

    return NavigationBar(
      backgroundColor: AppColors.sidebarBg,
      indicatorColor: AppColors.sidebarItemActive,
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => context.go(AppShell._toRoute(items[i])),
      destinations: List.generate(
        items.length,
        (i) => NavigationDestination(
          icon: Icon(icons[i], color: AppColors.sidebarIcon),
          selectedIcon: Icon(icons[i], color: AppColors.sidebarIconActive),
          label: labels[i],
        ),
      ),
    );
  }
}
