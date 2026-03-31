import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colours
  static const Color background = Color(0xFFFFFEF0);
  static const Color foreground = Color(0xFF1D2B38);
  static const Color primary = Color(0xFFB22030);
  static const Color primaryFg = Color(0xFFFEFEF8);
  static const Color accent = Color(0xFFF5A234);
  static const Color muted = Color(0xFFEDE9DC);
  static const Color mutedFg = Color(0xFF7A8A96);
  static const Color border = Color(0xFFC8D0D8);
  static const Color tileBg = Color(0xFFF5F2E8);
  static const Color slotEmpty = Color(0xFFD8DDE3);
  static const Color slotFilled = Color(0xFF1D2B38);
  static const Color card = Color(0xFFF7F4EC);

  // Typography
  static TextStyle get displayLarge => GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w900,
        fontSize: 32,
        color: foreground,
        letterSpacing: 1.5,
      );

  static TextStyle get displayMedium => GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: foreground,
        letterSpacing: 1.0,
      );

  static TextStyle get displayItalic => GoogleFonts.playfairDisplay(
        fontStyle: FontStyle.italic,
        fontSize: 24,
        color: primary.withValues(alpha: 0.4),
      );

  static TextStyle get condensedBold => GoogleFonts.robotoCondensed(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 1.2,
        color: foreground,
      );

  static TextStyle get condensedLabel => GoogleFonts.robotoCondensed(
        fontWeight: FontWeight.w400,
        fontSize: 10,
        letterSpacing: 3.0,
        color: mutedFg,
      );

  static TextStyle get tileLabel => GoogleFonts.robotoCondensed(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: foreground,
      );

  // ThemeData
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.light(
          surface: background,
          primary: primary,
          onPrimary: primaryFg,
          secondary: accent,
          onSecondary: foreground,
          error: Color(0xFFB22030),
        ),
        textTheme: TextTheme(
          displayLarge: displayLarge,
          displayMedium: displayMedium,
          bodyLarge: condensedBold,
          bodySmall: condensedLabel,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: primaryFg,
            shape: const StadiumBorder(),
            textStyle: condensedBold.copyWith(
              fontSize: 16,
              letterSpacing: 2.0,
            ),
            minimumSize: const Size(200, 56),
          ),
        ),
        dividerColor: border,
      );
}
