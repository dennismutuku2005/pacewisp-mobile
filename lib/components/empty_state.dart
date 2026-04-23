import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/colors.dart';

class PaceEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onRetry;
  final bool isDark;

  const PaceEmptyState({
    super.key,
    this.title = 'NO DATA FOUND',
    this.subtitle = 'We couldn\'t find any records matching your request.',
    this.icon = LucideIcons.layers,
    required this.onRetry,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PaceColors.purple.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: PaceColors.purple.withOpacity(0.2)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.figtree(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PaceColors.getPrimaryText(isDark),
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.figtree(
                fontSize: 11,
                color: PaceColors.getDimText(isDark),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: Text(
                  'RETRY AGAIN',
                  style: GoogleFonts.figtree(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PaceColors.purple,
                  side: BorderSide(color: PaceColors.purple.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
