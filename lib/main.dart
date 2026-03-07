import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const PaceWispApp(),
    ),
  );
}

class PaceWispApp extends StatelessWidget {
  const PaceWispApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'PaceWISP',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _getInitialScreen(settings),
    );
  }

  Widget _getInitialScreen(SettingsProvider settings) {
    if (settings.subdomain == null) {
      return const LandingScreen();
    }
    if (settings.token == null) {
      return const LoginScreen();
    }
    return const MainScaffold();
  }
}
