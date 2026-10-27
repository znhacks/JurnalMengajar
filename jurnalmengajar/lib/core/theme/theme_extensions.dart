import 'package:flutter/material.dart';

/// Semantic colors for status badges, tags, and states across the app.
/// Automatically adapts based on Light / Dark mode to ensure high contrast,
/// readability, and compliance with anti-slop visual guidelines.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  // Pending / Warning status
  final Color pending;
  final Color pendingContainer;
  final Color onPendingContainer;

  // Verified / Success status
  final Color verified;
  final Color verifiedContainer;
  final Color onVerifiedContainer;

  // Rejected / Error status
  final Color rejected;
  final Color rejectedContainer;
  final Color onRejectedContainer;

  // Info / Neutral / Draft status
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  const AppStatusColors({
    required this.pending,
    required this.pendingContainer,
    required this.onPendingContainer,
    required this.verified,
    required this.verifiedContainer,
    required this.onVerifiedContainer,
    required this.rejected,
    required this.rejectedContainer,
    required this.onRejectedContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  /// Light theme values with soft containers and high-contrast text
  static const light = AppStatusColors(
    pending: Color(0xFFD97706), // Amber 600
    pendingContainer: Color(0xFFFEF3C7), // Amber 100
    onPendingContainer: Color(0xFF92400E), // Amber 800
    verified: Color(0xFF059669), // Emerald 600
    verifiedContainer: Color(0xFFD1FAE5), // Emerald 100
    onVerifiedContainer: Color(0xFF065F46), // Emerald 800
    rejected: Color(0xFFE11D48), // Rose 600
    rejectedContainer: Color(0xFFFFE4E6), // Rose 100
    onRejectedContainer: Color(0xFF9F1239), // Rose 800
    info: Color(0xFF0284C7), // Sky 600
    infoContainer: Color(0xFFE0F2FE), // Sky 100
    onInfoContainer: Color(0xFF0369A1), // Sky 700
  );

  /// Dark theme values with deep containers and vibrant legible foregrounds
  static const dark = AppStatusColors(
    pending: Color(0xFFFBBF24), // Amber 400
    pendingContainer: Color(0xFF451A03), // Amber 950
    onPendingContainer: Color(0xFFFDE68A), // Amber 200
    verified: Color(0xFF34D399), // Emerald 400
    verifiedContainer: Color(0xFF064E3B), // Emerald 900
    onVerifiedContainer: Color(0xFFA7F3D0), // Emerald 200
    rejected: Color(0xFFFB7185), // Rose 400
    rejectedContainer: Color(0xFF4C0519), // Rose 950
    onRejectedContainer: Color(0xFFFECDD3), // Rose 200
    info: Color(0xFF38BDF8), // Sky 400
    infoContainer: Color(0xFF082F49), // Sky 950
    onInfoContainer: Color(0xFFBAE6FD), // Sky 200
  );

  @override
  AppStatusColors copyWith({
    Color? pending,
    Color? pendingContainer,
    Color? onPendingContainer,
    Color? verified,
    Color? verifiedContainer,
    Color? onVerifiedContainer,
    Color? rejected,
    Color? rejectedContainer,
    Color? onRejectedContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return AppStatusColors(
      pending: pending ?? this.pending,
      pendingContainer: pendingContainer ?? this.pendingContainer,
      onPendingContainer: onPendingContainer ?? this.onPendingContainer,
      verified: verified ?? this.verified,
      verifiedContainer: verifiedContainer ?? this.verifiedContainer,
      onVerifiedContainer: onVerifiedContainer ?? this.onVerifiedContainer,
      rejected: rejected ?? this.rejected,
      rejectedContainer: rejectedContainer ?? this.rejectedContainer,
      onRejectedContainer: onRejectedContainer ?? this.onRejectedContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      pending: Color.lerp(pending, other.pending, t)!,
      pendingContainer: Color.lerp(pendingContainer, other.pendingContainer, t)!,
      onPendingContainer: Color.lerp(onPendingContainer, other.onPendingContainer, t)!,
      verified: Color.lerp(verified, other.verified, t)!,
      verifiedContainer: Color.lerp(verifiedContainer, other.verifiedContainer, t)!,
      onVerifiedContainer: Color.lerp(onVerifiedContainer, other.onVerifiedContainer, t)!,
      rejected: Color.lerp(rejected, other.rejected, t)!,
      rejectedContainer: Color.lerp(rejectedContainer, other.rejectedContainer, t)!,
      onRejectedContainer: Color.lerp(onRejectedContainer, other.onRejectedContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

/// Convenience extensions on [BuildContext] so widgets can access colors and
/// text styles cleanly without writing repetitive or hardcoded color logic.
extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Semantic status colors (pending, verified, rejected, info)
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>() ?? AppStatusColors.light;

  /// Surfaces & Backgrounds
  Color get surfaceColor => colorScheme.surface;
  Color get cardColor => theme.cardTheme.color ?? colorScheme.surface;
  Color get scaffoldBg => theme.scaffoldBackgroundColor;
  Color get containerBg => colorScheme.surfaceContainerHighest;

  /// Typography colors
  Color get textPrimary => colorScheme.onSurface;
  Color get textSecondary => colorScheme.onSurfaceVariant;
  Color get textMuted => colorScheme.outline;

  /// Borders & Dividers
  Color get borderOutline => colorScheme.outlineVariant;
}
