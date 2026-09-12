import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/colors.dart';

class PaceEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onRetry;
  final bool isDark;

  const PaceEmptyState({
    super.key,
    this.title = 'No Records Found',
    this.subtitle = 'We couldn\'t find any records matching your request.',
    this.icon = LucideIcons.layers,
    required this.onRetry,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PaceColors.purple.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: PaceColors.purple.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.figtree(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PaceColors.getPrimaryText(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.figtree(
                fontSize: 12,
                color: PaceColors.getDimText(isDark),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 13),
                label: Text(
                  'Refresh Data',
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PaceColors.purple,
                  side: BorderSide(color: PaceColors.purple.withOpacity(0.25)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
