import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/accounting/presentation/providers/accounting_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/listings/presentation/providers/listings_provider.dart';
import 'features/maintenance/presentation/providers/maintenance_provider.dart';
import 'features/services/presentation/providers/services_provider.dart';
import 'features/properties/presentation/providers/leasing_provider.dart';
import 'features/tenant/presentation/providers/tenant_provider.dart';
import 'features/properties/presentation/providers/properties_provider.dart';
import 'features/tenants/presentation/providers/tenants_provider.dart';
import 'features/invoices/providers/invoice_settings_provider.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const BogiPropertyApp());
}

class BogiPropertyApp extends StatelessWidget {
  const BogiPropertyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LeasingProvider()),
        ChangeNotifierProvider(create: (_) => PropertiesProvider()),
        ChangeNotifierProvider(create: (_) => TenantsProvider()),
        ChangeNotifierProvider(create: (_) => AccountingProvider()),
        ChangeNotifierProvider(create: (_) => ListingsProvider()),
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
        ChangeNotifierProvider(create: (_) => TenantProvider()),
        ChangeNotifierProvider(create: (_) => ServicesProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceSettingsProvider()..load()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp.router(
            title: 'Bogineni Property',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.build(authProvider),
          );
        },
      ),
    );
  }
}
