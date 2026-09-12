import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

enum BadgeVariant { success, error, destructive, danger, secondary, info, standard, primary, warning }

class PaceBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;

  const PaceBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color textColor;

    switch (variant) {
      case BadgeVariant.success:
        bgColor = PaceColors.getGreenLight(isDark);
        textColor = PaceColors.getGreen(isDark);
        break;
      case BadgeVariant.error:
      case BadgeVariant.destructive:
      case BadgeVariant.danger:
        bgColor = PaceColors.getRedLight(isDark);
        textColor = PaceColors.getRed(isDark);
        break;
      case BadgeVariant.secondary:
        bgColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF3F4F6);
        textColor = PaceColors.getDimText(isDark);
        break;
      case BadgeVariant.info:
        bgColor = const Color(0xFF3B82F6).withOpacity(0.1);
        textColor = const Color(0xFF3B82F6);
        break;
      case BadgeVariant.primary:
        bgColor = PaceColors.getPurpleLight(isDark);
        textColor = PaceColors.getPurple(isDark);
        break;
      case BadgeVariant.warning:
        bgColor = const Color(0xFFF59E0B).withOpacity(0.1);
        textColor = const Color(0xFFF59E0B);
        break;
      case BadgeVariant.standard:
      default:
        bgColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF9FAFB);
        textColor = PaceColors.getSecondaryText(isDark);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.2), width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.figtree(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
