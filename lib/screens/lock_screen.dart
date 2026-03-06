import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  String _error = '';

  void _verifyPin() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (_pinController.text == settings.appPin) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'Incorrect Pin';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: PaceColors.purple),
              const SizedBox(height: 24),
              Text(
                'APP LOCKED',
                style: TextStyle(
                  color: PaceColors.getPrimaryText(isDark),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter security pin to continue',
                style: TextStyle(color: PaceColors.getSecondaryText(isDark), fontSize: 13),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: PaceColors.getPrimaryText(isDark),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: PaceColors.getCard(isDark),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: PaceColors.getBorder(isDark))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PaceColors.purple, width: 2)),
                ),
                onChanged: (val) {
                  if (val.length == 4) _verifyPin();
                },
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_error, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
