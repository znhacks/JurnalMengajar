import 'package:flutter/material.dart';

/// Reusable action button for admin headers to trigger mass selection.
/// 
/// Follows the design style from Dashboard Jurnal Mengajar:
/// - Clean checklist icon ([Icons.checklist_rounded])
/// - No square background container
/// - Strictly circular interaction shape ([CircleBorder]) for hover, splash, and focus
/// - Adaptive colors for Light Mode and Dark Mode with graceful disabled opacity
class AdminSelectionActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;

  const AdminSelectionActionButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Pilih Massal',
    this.icon = Icons.checklist_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultColor = theme.appBarTheme.iconTheme?.color ??
        (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A));

    return IconButton(
      icon: Icon(icon),
      iconSize: 24,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        foregroundColor: defaultColor,
        disabledForegroundColor: defaultColor.withValues(alpha: 0.38),
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}
