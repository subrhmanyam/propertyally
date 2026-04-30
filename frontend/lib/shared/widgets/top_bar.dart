import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, this.onMenuTap});

  final VoidCallback? onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimensions.topBarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.topBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.topBarBg,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
      child: Row(
        children: [
          // ── Left: menu + bell ──────────────────────────────────
          _TopBarIconBtn(
            icon: Icons.menu_rounded,
            onTap: onMenuTap ?? () {},
          ),
          const SizedBox(width: AppDimensions.spaceSM),
          _TopBarIconBtn(
            icon: Icons.notifications_outlined,
            onTap: () {},
          ),
          const SizedBox(width: AppDimensions.spaceMD),

          // ── Center: search ────────────────────────────────────
          Expanded(
            child: _SearchField(),
          ),
          const SizedBox(width: AppDimensions.spaceMD),

          // ── Right: actions + user ─────────────────────────────
          _TopBarIconBtn(icon: Icons.chat_bubble_outline_rounded, onTap: () {}),
          const SizedBox(width: AppDimensions.spaceXS),
          _TopBarIconBtn(icon: Icons.help_outline_rounded, onTap: () {}),
          const SizedBox(width: AppDimensions.spaceMD),

          _UserChip(),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        style: const TextStyle(
          fontSize: AppDimensions.fontBase,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.topBarIcon,
            size: AppDimensions.iconMD,
          ),
          hintText: AppStrings.searchHint,
          filled: true,
          fillColor: AppColors.searchBg,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            borderSide: const BorderSide(color: AppColors.searchBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            borderSide: const BorderSide(color: AppColors.searchBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            borderSide: const BorderSide(color: AppColors.accentGreen, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _TopBarIconBtn extends StatelessWidget {
  const _TopBarIconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXS),
          child: Icon(icon, color: AppColors.topBarIcon, size: AppDimensions.iconMD),
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final email = auth.userEmail;
        final initial = email.isNotEmpty ? email[0].toUpperCase() : 'A';

        return PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'signout') auth.signOut();
          },
          color: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
            side: const BorderSide(color: AppColors.border),
          ),
          offset: const Offset(0, 40),
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    auth.userRole.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'signout',
              child: Row(
                children: [
                  Icon(Icons.logout_outlined,
                      size: AppDimensions.iconMD, color: AppColors.textMuted),
                  SizedBox(width: AppDimensions.spaceSM),
                  Text('Sign out',
                      style: TextStyle(
                          fontSize: AppDimensions.fontBase,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
          child: Row(
            children: [
              Text(
                email.split('@').first,
                style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSM),
              CircleAvatar(
                radius: AppDimensions.avatarSM / 2,
                backgroundColor: AppColors.accentGold,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.bgOuter,
                    fontSize: AppDimensions.fontSM,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        );
      },
    );
  }
}
