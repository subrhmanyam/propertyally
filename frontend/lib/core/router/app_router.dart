import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounting/presentation/screens/accounting_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/properties/presentation/screens/leasing_list_screen.dart';
import '../../features/tenants/presentation/screens/tenant_list_screen.dart';
import '../../features/listings/presentation/screens/listing_detail_screen.dart';
import '../../features/listings/presentation/screens/listings_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_screen.dart';
import '../../features/tenants/presentation/screens/tenant_detail_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';

class AppRouter {
  AppRouter._();

  static Page<void> _page(GoRouterState state, Widget child) =>
      NoTransitionPage(key: state.pageKey, child: child);

  /// Build a router that is aware of authentication state.
  static GoRouter build(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: false,
      refreshListenable: authProvider,

      // ── Auth redirect guard ──────────────────────────────────────
      redirect: (context, state) {
        final loggedIn = authProvider.isAuthenticated;
        final goingToLogin = state.matchedLocation == '/login';

        if (!loggedIn && !goingToLogin) return '/login';
        if (loggedIn && goingToLogin) return '/';
        return null;
      },

      routes: [
        // ── Login (outside shell) ──────────────────────────────────
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (_, s) => _page(s, const LoginScreen()),
        ),

        // ── App shell (all authenticated routes) ───────────────────
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              name: 'dashboard',
              pageBuilder: (_, s) => _page(s, const DashboardScreen()),
            ),
            GoRoute(
              path: '/properties',
              name: 'properties',
              pageBuilder: (_, s) => _page(s, const LeasingListScreen()),
            ),
            GoRoute(
              path: '/tenants',
              name: 'tenants',
              pageBuilder: (_, s) => _page(s, const TenantListScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  name: 'tenant-detail',
                  pageBuilder: (_, s) => _page(
                    s,
                    TenantDetailScreen(tenantId: s.pathParameters['id']!),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/accounting',
              name: 'accounting',
              pageBuilder: (_, s) => _page(s, const AccountingScreen()),
            ),
            GoRoute(
              path: '/maintenance',
              name: 'maintenance',
              pageBuilder: (_, s) => _page(s, const MaintenanceScreen()),
            ),
            GoRoute(
              path: '/reports',
              name: 'reports',
              pageBuilder: (_, s) => _page(s,
                  const _ComingSoonScreen(title: 'Reports', icon: Icons.bar_chart_rounded)),
            ),
            GoRoute(
              path: '/listings',
              name: 'listings',
              pageBuilder: (_, s) => _page(s, const ListingsScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  name: 'listing-detail',
                  pageBuilder: (_, s) => _page(s,
                      ListingDetailScreen(listingId: s.pathParameters['id']!)),
                ),
              ],
            ),
            GoRoute(
              path: '/calendar',
              name: 'calendar',
              pageBuilder: (_, s) => _page(s,
                  const _ComingSoonScreen(title: 'Calendar', icon: Icons.calendar_month_outlined)),
            ),
            GoRoute(
              path: '/documents',
              name: 'documents',
              pageBuilder: (_, s) => _page(s,
                  const _ComingSoonScreen(title: 'Documents', icon: Icons.description_outlined)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Placeholder for unbuilt features ──────────────────────────────────

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.progressCardBg,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            ),
            child: Icon(icon, size: AppDimensions.iconXL, color: AppColors.accentSilver),
          ),
          const SizedBox(height: AppDimensions.spaceLG),
          Text(
            title,
            style: const TextStyle(
              fontSize: AppDimensions.fontH2,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          const Text(
            AppStrings.comingSoonDesc,
            style: TextStyle(
              fontSize: AppDimensions.fontBase,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
