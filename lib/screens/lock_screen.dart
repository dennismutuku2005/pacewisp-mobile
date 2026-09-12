import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/lock_service.dart';
import '../theme/colors.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LockService _lockService = LockService();
  bool _isAuthenticating = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _error = '';
    });

    final bool success = await _lockService.authenticate();

    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _isAuthenticating = false;
        _error = 'Biometric verification cancelled';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final accountName = settings.activeAccount?.accountName ?? 'Pace WISP';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/sidebar.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F172A).withOpacity(0.92),
                const Color(0xFF1E293B).withOpacity(0.88),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Image.asset(
                  'assets/images/logo.png',
                  height: 56,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    LucideIcons.shieldCheck,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  accountName,
                  style: GoogleFonts.figtree(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Biometric authentication required',
                  style: GoogleFonts.figtree(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (_isAuthenticating)
                  Column(
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Verifying biometric...',
                        style: GoogleFonts.figtree(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _authenticate,
                            icon: const Icon(LucideIcons.fingerprint, size: 18),
                            label: Text(
                              'Unlock to continue',
                              style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PaceColors.purple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.alertCircle, color: Colors.redAccent, size: 14),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _error,
                                    style: GoogleFonts.figtree(color: Colors.red.shade200, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
