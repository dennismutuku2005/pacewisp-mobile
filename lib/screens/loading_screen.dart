import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Attempt to get isDark through Provider, fallback to light
    bool isDark = false;
    try {
      isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    } catch (_) {}

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logoc.png',
              height: 100,
              errorBuilder: (_, __, ___) => const Icon(Icons.wifi_tethering, color: PaceColors.purple, size: 64),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: PaceColors.purple,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SECURE CONNECTION...',
              style: TextStyle(
                color: PaceColors.getDimText(isDark),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
