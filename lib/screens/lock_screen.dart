import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        _error = 'BIOMETRIC MISMATCH OR CANCELLED';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    // Dynamic app name based on active account or default
    final accountName = settings.activeAccount?.accountName.toUpperCase() ?? 'PACE WISP';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep premium dark background
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
                const Color(0xFF0F172A).withOpacity(0.95), 
                const Color(0xFF1E293B).withOpacity(0.7)
              ],
            ),
          ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Profile Logo Container
              Container(
                width: 120, height: 120,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: PaceColors.purple.withOpacity(0.15), blurRadius: 40, spreadRadius: 10),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.security_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                accountName,
                style: GoogleFonts.figtree(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Removed Secured Environment Badge
              const Spacer(),
              
              if (_isAuthenticating)
                Column(
                  children: [
                    const CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 3),
                    const SizedBox(height: 16),
                    Text('SCANNING...', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2)),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: _authenticate,
                          icon: const Icon(Icons.fingerprint_rounded, size: 24),
                          label: Text('UNLOCK TO CONTINUE', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PaceColors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 10,
                            shadowColor: PaceColors.purple.withOpacity(0.4),
                          ),
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _error,
                                  style: GoogleFonts.figtree(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
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
              const SizedBox(height: 56),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
