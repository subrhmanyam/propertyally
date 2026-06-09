import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

enum NavItem {
  dashboard,
  properties,
  reports,
  tenants,
  accounting,
  maintenance,
  tasks,
  services,
  calendar,
  documents,
  listings,
}

class SidebarNav extends StatelessWidget {
  const SidebarNav({
    super.key,
    required this.activeItem,
    required this.onItemTap,
  });

  final NavItem activeItem;
  final ValueChanged<NavItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.sidebarWidth,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // ── Logo area ───────────────────────────────────────────
          const SizedBox(height: AppDimensions.spaceMD),
          _SidebarLogo(),
          const SizedBox(height: AppDimensions.spaceSM),

          // ── Add button ──────────────────────────────────────────
          _AddButton(),
          const SizedBox(height: AppDimensions.spaceSM),

          const Divider(color: AppColors.border, thickness: 1, height: 1),
          const SizedBox(height: AppDimensions.spaceSM),

          // ── Nav items ───────────────────────────────────────────
          _NavIconButton(
            icon: Icons.grid_view_rounded,
            item: NavItem.dashboard,
            active: activeItem == NavItem.dashboard,
            onTap: onItemTap,
            tooltip: 'Dashboard',
          ),
          _NavIconButton(
            icon: Icons.home_outlined,
            item: NavItem.properties,
            active: activeItem == NavItem.properties,
            onTap: onItemTap,
            tooltip: 'Properties',
          ),
          _NavIconButton(
            icon: Icons.bar_chart_rounded,
            item: NavItem.reports,
            active: activeItem == NavItem.reports,
            onTap: onItemTap,
            tooltip: 'Reports',
          ),
          _NavIconButton(
            icon: Icons.people_outline_rounded,
            item: NavItem.tenants,
            active: activeItem == NavItem.tenants,
            onTap: onItemTap,
            tooltip: 'Tenants',
          ),
          _NavIconButton(
            icon: Icons.monetization_on_outlined,
            item: NavItem.accounting,
            active: activeItem == NavItem.accounting,
            onTap: onItemTap,
            tooltip: 'Accounting',
          ),
          _NavIconButton(
            icon: Icons.build_outlined,
            item: NavItem.maintenance,
            active: activeItem == NavItem.maintenance,
            onTap: onItemTap,
            tooltip: 'Maintenance',
          ),
          _NavIconButton(
            icon: Icons.task_alt_outlined,
            item: NavItem.tasks,
            active: activeItem == NavItem.tasks,
            onTap: onItemTap,
            tooltip: 'Tasks',
          ),
          _NavIconButton(
            icon: Icons.home_repair_service_outlined,
            item: NavItem.services,
            active: activeItem == NavItem.services,
            onTap: onItemTap,
            tooltip: 'Services',
          ),
          _NavIconButton(
            icon: Icons.calendar_month_outlined,
            item: NavItem.calendar,
            active: activeItem == NavItem.calendar,
            onTap: onItemTap,
            tooltip: 'Calendar',
          ),
          _NavIconButton(
            icon: Icons.description_outlined,
            item: NavItem.documents,
            active: activeItem == NavItem.documents,
            onTap: onItemTap,
            tooltip: 'Documents',
          ),
          _NavIconButton(
            icon: Icons.language_outlined,
            item: NavItem.listings,
            active: activeItem == NavItem.listings,
            onTap: onItemTap,
            tooltip: 'Listings',
          ),

          const Spacer(),

          // ── Bottom actions ──────────────────────────────────────
          _SidebarIconBtn(
            icon: Icons.cloud_upload_outlined,
            onTap: () {},
            tooltip: 'Sync',
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) => _SidebarIconBtn(
              icon: Icons.logout_outlined,
              onTap: () => auth.signOut(),
              tooltip: 'Sign out',
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMD),
        ],
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────

class _SidebarLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSM),
      child: Icon(
        Icons.cloud_outlined,
        color: AppColors.sidebarIconActive,
        size: AppDimensions.iconLG,
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMD,
        vertical: AppDimensions.spaceXS,
      ),
      child: Material(
        color: AppColors.sidebarAddBtn,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
          onTap: () {},
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: AppDimensions.iconMD,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatefulWidget {
  const _NavIconButton({
    required this.icon,
    required this.item,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final NavItem item;
  final bool active;
  final ValueChanged<NavItem> onTap;
  final String tooltip;

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onTap(widget.item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceSM,
              vertical: 2,
            ),
            width: 44,
            height: 40,
            decoration: BoxDecoration(
              color: widget.active
                  ? AppColors.sidebarItemActive
                  : _hovered
                      ? AppColors.sidebarItemHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Icon(
              widget.icon,
              size: AppDimensions.iconMD,
              color: widget.active
                  ? AppColors.sidebarIconActive
                  : AppColors.sidebarIcon,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarIconBtn extends StatelessWidget {
  const _SidebarIconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceSM),
          child: Icon(icon, color: AppColors.sidebarIcon, size: AppDimensions.iconMD),
        ),
      ),
    );
  }
}
