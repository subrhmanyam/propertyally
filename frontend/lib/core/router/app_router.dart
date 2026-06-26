import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounting/presentation/screens/accounting_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/listings/presentation/screens/listing_detail_screen.dart';
import '../../features/listings/presentation/screens/listings_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/services/presentation/screens/admin_services_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';
import '../../features/properties/presentation/screens/leasing_list_screen.dart';
import '../../features/tenant/presentation/screens/tenant_home_screen.dart';
import '../../features/tenant/presentation/screens/tenant_invoices_screen.dart';
import '../../features/tenant/presentation/screens/tenant_maintenance_screen.dart';
import '../../features/tenant/presentation/screens/tenant_messages_screen.dart';
import '../../features/tenant/presentation/screens/tenant_services_screen.dart';
import '../../features/tenants/presentation/screens/tenant_detail_screen.dart';
import '../../features/tenants/presentation/screens/tenant_list_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/tenant_shell.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';

class AppRouter {
  AppRouter._();

  static Page<void> _page(GoRouterState state, Widget child) =>
      NoTransitionPage(key: state.pageKey, child: child);

  static GoRouter build(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: false,
      refreshListenable: authProvider,

      // ── Auth + role redirect ─────────────────────────────────────
      redirect: (context, state) {
        final loggedIn = authProvider.isAuthenticated;
        final isTenant = authProvider.isTenant;
        final loc = state.matchedLocation;
        final goingToLogin = loc == '/login';
        final goingToTenant = loc == '/tenant' || loc.startsWith('/tenant/');
        final goingToAdmin = !goingToLogin && !goingToTenant;

        if (!loggedIn && !goingToLogin) return '/login';
        if (loggedIn && goingToLogin) {
          return isTenant ? '/tenant' : '/';
        }
        // Tenant trying to access admin routes
        if (loggedIn && isTenant && goingToAdmin) return '/tenant';
        // Admin trying to access tenant routes
        if (loggedIn && !isTenant && goingToTenant) return '/';
        return null;
      },

      routes: [
        // ── Login ─────────────────────────────────────────────────
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (_, s) => _page(s, const LoginScreen()),
        ),

        // ── Admin shell ───────────────────────────────────────────
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
              path: '/tasks',
              name: 'tasks',
              pageBuilder: (_, s) => _page(s, const TasksScreen()),
            ),
            GoRoute(
              path: '/services',
              name: 'services',
              pageBuilder: (_, s) => _page(s, const AdminServicesScreen()),
            ),
            GoRoute(
              path: '/reports',
              name: 'reports',
              pageBuilder: (_, s) => _page(s, const ReportsScreen()),
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
              pageBuilder: (_, s) => _page(s, const CalendarScreen()),
            ),
            GoRoute(
              path: '/documents',
              name: 'documents',
              pageBuilder: (_, s) => _page(s,
                  const _ComingSoonScreen(title: 'Documents', icon: Icons.description_outlined)),
            ),
          ],
        ),

        // ── Tenant shell ──────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => TenantShell(child: child),
          routes: [
            GoRoute(
              path: '/tenant',
              name: 'tenant-home',
              pageBuilder: (_, s) => _page(s, const TenantHomeScreen()),
            ),
            GoRoute(
              path: '/tenant/invoices',
              name: 'tenant-invoices',
              pageBuilder: (_, s) => _page(s, const TenantInvoicesScreen()),
            ),
            GoRoute(
              path: '/tenant/services',
              name: 'tenant-services',
              pageBuilder: (_, s) => _page(s, const TenantServicesScreen()),
            ),
            GoRoute(
              path: '/tenant/maintenance',
              name: 'tenant-maintenance',
              pageBuilder: (_, s) =>
                  _page(s, const TenantMaintenanceScreen()),
            ),
            GoRoute(
              path: '/tenant/messages',
              name: 'tenant-messages',
              pageBuilder: (_, s) => _page(s, const TenantMessagesScreen()),
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
