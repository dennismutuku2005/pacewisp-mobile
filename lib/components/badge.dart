import 'package:flutter/material.dart';

enum BadgeVariant { success, error, secondary, info, standard }

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
    Color bgColor;
    Color textColor;

    switch (variant) {
      case BadgeVariant.success:
        bgColor = const Color(0xFF2CB34A).withOpacity(0.1);
        textColor = const Color(0xFF2CB34A);
        break;
      case BadgeVariant.error:
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case BadgeVariant.secondary:
        bgColor = const Color(0xFF9CA3AF).withOpacity(0.1);
        textColor = const Color(0xFF4B5563);
        break;
      case BadgeVariant.info:
        bgColor = const Color(0xFF3B82F6).withOpacity(0.1);
        textColor = const Color(0xFF3B82F6);
        break;
      case BadgeVariant.standard:
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF4B5563);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
