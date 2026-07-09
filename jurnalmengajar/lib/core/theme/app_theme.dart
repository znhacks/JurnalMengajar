import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Stitch "Serene Academic" Design Tokens ───────────────────────────────
  static const Color primaryColor = Color(0xFF1E40AF); // Premium Royal Blue
  static const Color primaryAccent = Color(0xFF2563EB); // Vibrant Blue Accent
  static const Color secondaryColor = Color(0xFF4F607A); // Slate Blue
  static const Color tertiaryColor = Color(0xFFB45309); // Amber/Warning
  static const Color errorColor = Color(0xFFBA1A1A);

  // Surfaces
  static const Color background = Color(0xFFF7F9FB);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFECEEF0);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);

  // On-colors
  static const Color onBackground = Color(0xFF191C1E);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF43474E);
  static const Color outline = Color(0xFF72777F);
  static const Color outlineVariant = Color(0xFFC2C7D0);

  // Tonal surface for primary
  static const Color primaryContainer = Color(0xFFDBE2FF);
  static const Color onPrimaryContainer = Color(0xFF00154B);

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.hankenGroteskTextTheme().copyWith(
      displayLarge: GoogleFonts.hankenGrotesk(
          fontSize: 28, fontWeight: FontWeight.w800, color: onBackground),
      headlineMedium: GoogleFonts.hankenGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700, color: onBackground),
      headlineSmall: GoogleFonts.hankenGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700, color: onBackground),
      titleMedium: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w600, color: onBackground),
      bodyLarge: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
      bodyMedium: GoogleFonts.hankenGrotesk(
          fontSize: 13, fontWeight: FontWeight.w400, color: onSurfaceVariant),
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
        secondaryContainer: const Color(0xFFDAE2FD),
        onSecondaryContainer: const Color(0xFF5C647A),
        tertiary: tertiaryColor,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFA36700),
        onTertiaryContainer: const Color(0xFFFFFBFF),
        error: errorColor,
        onError: Colors.white,
        errorContainer: const Color(0xFFFFDAD6),
        onErrorContainer: const Color(0xFF93000A),
        surface: surfaceColor,
        onSurface: onSurface,
        surfaceContainerHighest: const Color(0xFFE0E3E5),
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        inverseSurface: const Color(0xFF2D3133),
        onInverseSurface: const Color(0xFFEFF1F3),
        inversePrimary: const Color(0xFFBAC3FF),
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: const Color(0xFF1E40AF),
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,

      // ─── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: onBackground,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: outlineVariant,
        centerTitle: true,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          color: onBackground,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: onBackground),
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
