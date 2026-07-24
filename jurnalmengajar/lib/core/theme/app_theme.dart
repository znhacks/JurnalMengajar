import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Modern Clean Academic Design System ───────────────────────────────
  static const Color primaryColor = Color(0xFF2563EB); // Vibrant Solid Blue
  static const Color primaryAccent = Color(0xFF3B82F6); // Bright Blue Accent
  static const Color secondaryColor = Color(0xFF475569); // Slate Gray
  static const Color tertiaryColor = Color(0xFFD97706); // Amber/Warning
  static const Color errorColor = Color(0xFFE11D48); // Rose Red

  // Surfaces
  static const Color background = Color(0xFFF8FAFC); // Clean Light Slate BG
  static const Color surfaceColor = Color(0xFFFFFFFF); // Solid White
  static const Color surfaceContainer = Color(0xFFF1F5F9);
  static const Color surfaceContainerLow = Color(0xFFF8FAFC);

  // On-colors
  static const Color onBackground = Color(0xFF0F172A);
  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF64748B);
  static const Color outline = Color(0xFF94A3B8);
  static const Color outlineVariant = Color(0xFFE2E8F0);

  // Tonal surface for primary
  static const Color primaryContainer = Color(0xFFEFF6FF);
  static const Color onPrimaryContainer = Color(0xFF1E40AF);

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.hankenGroteskTextTheme().copyWith(
      displayLarge: GoogleFonts.hankenGrotesk(
          fontSize: 28, fontWeight: FontWeight.w800, color: onBackground),
      headlineMedium: GoogleFonts.hankenGrotesk(
          fontSize: 18, fontWeight: FontWeight.w800, color: onBackground),
      headlineSmall: GoogleFonts.hankenGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700, color: onBackground),
      titleMedium: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w700, color: onBackground),
      bodyLarge: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
      bodyMedium: GoogleFonts.hankenGrotesk(
          fontSize: 13, fontWeight: FontWeight.w500, color: onSurfaceVariant),
      labelSmall: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
          color: onSurfaceVariant),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFF1F5F9),
        onSecondaryContainer: const Color(0xFF475569),
        tertiary: tertiaryColor,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFFEF3C7),
        onTertiaryContainer: const Color(0xFFB45309),
        error: errorColor,
        onError: Colors.white,
        errorContainer: const Color(0xFFFFE4E6),
        onErrorContainer: const Color(0xFFE11D48),
        surface: surfaceColor,
        onSurface: onSurface,
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        inverseSurface: const Color(0xFF0F172A),
        onInverseSurface: const Color(0xFFF8FAFC),
        inversePrimary: const Color(0xFF93C5FD),
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: const Color(0xFF2563EB),
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,

      // ─── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          color: const Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),

      // ─── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outlineVariant, width: 1),
        ),
        color: surfaceColor,
        margin: EdgeInsets.zero,
      ),

      // ─── Buttons ──────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.hankenGrotesk(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onBackground,
          side: const BorderSide(color: outlineVariant, width: 1.5),
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.hankenGrotesk(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ─── Input Fields ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.hankenGrotesk(
            color: onSurfaceVariant, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.hankenGrotesk(color: outline, fontSize: 13),
      ),

      // ─── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 11, fontWeight: FontWeight.w700),
      ),

      // ─── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ─── NavigationBar ────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primaryColor.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: primaryColor);
          }
          return GoogleFonts.hankenGrotesk(
              fontSize: 11, fontWeight: FontWeight.w500, color: outline);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor, size: 24);
          }
          return const IconThemeData(color: Color(0xFF6D7A77), size: 24);
        }),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),

      // ─── TabBar ───────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: outline,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
