import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'screens/landing_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';
import 'services/widget_service.dart';
import 'package:workmanager/workmanager.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await WidgetService.refreshDataFromApi();
    return Future.value(true);
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Workmanager
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false
  );
  
  // Register periodic task (min 15 mins)
  Workmanager().registerPeriodicTask(
    "1",
    "sync_widget_data",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  HomeWidget.registerBackgroundCallback(WidgetService.backgroundCallback);
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
    if (settings.isLoading) {
      return const LoadingScreen();
    }
    if (settings.subdomain == null) {
      return const LandingScreen();
    }
    if (settings.token == null) {
      return const LoginScreen();
    }
    return const MainScaffold();
  }
}
