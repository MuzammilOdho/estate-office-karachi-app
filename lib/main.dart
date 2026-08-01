import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/colonies_screen.dart';
import 'screens/login_screen.dart';
import 'services/pocketbase_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final serverUrl = await SettingsService.instance.getServerUrl();
  await PocketBaseService.instance.init(serverUrl);

  runApp(const EstateRegistryApp());
}

class EstateRegistryApp extends StatelessWidget {
  const EstateRegistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..attach(),
        ),
      ],
      child: MaterialApp(
        title: 'Estate Registry',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _RootRouter(),
      ),
    );
  }
}

/// Switches between Login and the home screen purely based on PocketBase's
/// own auth state — no separate "is logged in" flag anywhere.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    return isLoggedIn ? const ColoniesScreen() : const LoginScreen();
  }
}