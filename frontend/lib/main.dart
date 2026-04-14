import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/accounting/presentation/providers/accounting_provider.dart';
import 'features/properties/presentation/providers/leasing_provider.dart';
import 'features/properties/presentation/providers/properties_provider.dart';
import 'features/tenants/presentation/providers/tenants_provider.dart';

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
        ChangeNotifierProvider(create: (_) => LeasingProvider()),
        ChangeNotifierProvider(create: (_) => PropertiesProvider()),
        ChangeNotifierProvider(create: (_) => TenantsProvider()),
        ChangeNotifierProvider(create: (_) => AccountingProvider()),
      ],
      child: MaterialApp.router(
        title: 'Bogineni Property',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
