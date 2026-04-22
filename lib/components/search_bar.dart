import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/colors.dart';

class PaceSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final VoidCallback? onFilterTap;

  const PaceSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    required this.isDark,
    this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PaceColors.getBorder(isDark),
          width: 1.2,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: PaceColors.getPrimaryText(isDark),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: PaceColors.getDimText(isDark),
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 18,
            color: PaceColors.getDimText(isDark),
          ),
          suffixIcon: onFilterTap != null 
            ? InkWell(
                onTap: onFilterTap,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: PaceColors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.sliders,
                    size: 14,
                    color: PaceColors.purple,
                  ),
                ),
              )
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
