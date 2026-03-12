import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Graphic charter: green #7BC18F, blue #48A1D9; Poppins for typography.
abstract class AppTheme {
  // Charter palette
  static const Color _primary = Color(0xFF7BC18F); // charter green
  static const Color _primaryDark = Color(0xFF5A9E6E);
  static const Color _secondary = Color(0xFF48A1D9); // charter blue
  static const Color _surface = Color(0xFFF8FAF8);
  static const Color _surfaceVariant = Color(0xFFE8F0EA);
  static const Color _onSurface = Color(0xFF1D1D1B);
  static const Color _onSurfaceVariant = Color(0xFF3C3C43);
  static const Color _outline = Color(0xFFC6C6C8);
  static const Color _success = Color(0xFF7BC18F);
  static const Color _warning = Color(0xFFFF9500);
  static const Color _danger = Color(0xFFFF3B30);

  /// Corner radius for cards/sheets (HIG: ~13pt)
  static const double cardRadius = 12.0;
  /// Corner radius for buttons (HIG: 10pt)
  static const double buttonRadius = 10.0;

  static ThemeData get light {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.poppins(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.41,
        color: _onSurface,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        color: _onSurface,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        color: _onSurface,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.24,
        color: _onSurface,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.24,
        color: _onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
        color: _onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        color: Colors.white,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.08,
        color: _onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: _surfaceVariant,
        onPrimaryContainer: _primaryDark,
        secondary: _secondary,
        onSecondary: Colors.white,
        surface: _surface,
        onSurface: _onSurface,
        surfaceContainerHighest: _surfaceVariant,
        onSurfaceVariant: _onSurfaceVariant,
        outline: _outline,
        error: _danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: _surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.3,
        backgroundColor: _surface,
        foregroundColor: _onSurface,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
          color: _onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: _surface,
          systemNavigationBarDividerColor: _outline,
        ),
      ),
      textTheme: textTheme,
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        color: Colors.white,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: _surfaceVariant,
        circularTrackColor: _surfaceVariant,
      ),
    );
  }

  static Color dangerColor(int score) {
    if (score >= 70) return _danger;
    if (score >= 40) return _warning;
    return _success;
  }
}
