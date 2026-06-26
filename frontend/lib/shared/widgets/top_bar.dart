import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/search/data/search_repository.dart';

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
          _TopBarIconBtn(icon: Icons.menu_rounded, onTap: onMenuTap ?? () {}),
          const SizedBox(width: AppDimensions.spaceSM),
          _TopBarIconBtn(icon: Icons.notifications_outlined, onTap: () {}),
          const SizedBox(width: AppDimensions.spaceMD),
          const Expanded(child: _SearchField()),
          const SizedBox(width: AppDimensions.spaceMD),
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

// ── Search ────────────────────────────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  final _repo = SearchRepository();
  final _layerLink = LayerLink();

  Timer? _debounce;
  OverlayEntry? _overlay;
  List<SearchResult> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _removeOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _doSearch(value));
  }

  Future<void> _doSearch(String q) async {
    setState(() => _loading = true);
    try {
      final results = await _repo.search(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
      _showOverlay();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    if (_results.isEmpty) return;
    _overlay = OverlayEntry(builder: (_) => _SearchOverlay(
      link: _layerLink,
      results: _results,
      onSelect: (result) {
        _removeOverlay();
        _ctrl.clear();
        _focusNode.unfocus();
        context.go(result.route);
      },
    ));
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
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          onChanged: _onChanged,
          onTap: () {
            if (_results.isNotEmpty) _showOverlay();
          },
          style: const TextStyle(fontSize: AppDimensions.fontBase, color: AppColors.textPrimary),
          decoration: InputDecoration(
            prefixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.accentGold),
                    ),
                  )
                : const Icon(Icons.search_rounded,
                    color: AppColors.topBarIcon, size: AppDimensions.iconMD),
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
              borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchOverlay extends StatelessWidget {
  const _SearchOverlay({
    required this.link,
    required this.results,
    required this.onSelect,
  });

  final LayerLink link;
  final List<SearchResult> results;
  final void Function(SearchResult) onSelect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      width: 400,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        offset: const Offset(0, 40),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 380),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: results.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) => _ResultTile(
                  result: results[i],
                  onTap: () => onSelect(results[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});
  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (result.type) {
      'property' => Icons.domain_rounded,
      'tenant' => Icons.person_outline_rounded,
      _ => Icons.build_outlined,
    };
    final typeLabel = switch (result.type) {
      'property' => 'Property',
      'tenant' => 'Tenant',
      _ => 'Maintenance',
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceMD, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.pageBg,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              ),
              child: Icon(icon, size: 16, color: AppColors.accentGold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  if (result.subtitle.isNotEmpty)
                    Text(result.subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.pageBg,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(typeLabel,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Icon button ───────────────────────────────────────────────────────────────

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

// ── User chip ─────────────────────────────────────────────────────────────────

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
                  Text(email,
                      style: const TextStyle(
                          fontSize: AppDimensions.fontSM,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                  Text(auth.userRole.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5)),
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
              Text(email.split('@').first,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontBase,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
              const SizedBox(width: AppDimensions.spaceSM),
              CircleAvatar(
                radius: AppDimensions.avatarSM / 2,
                backgroundColor: AppColors.accentGold,
                child: Text(initial,
                    style: const TextStyle(
                        color: AppColors.bgOuter,
                        fontSize: AppDimensions.fontSM,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
            ],
          ),
        );
      },
    );
  }
}
