import 'package:flutter/material.dart';

/// Design tokens taken directly from ESTATE_REGISTRY_SPEC.md §8.
///
/// Font note: the spec asks for a serif display font (e.g. Source Serif 4)
/// for headings and a monospace font for numeric/ID data, for a deliberate
/// "official ledger" feel. This app uses Android's built-in generic
/// `serif` / `monospace` font families instead of bundling Google Fonts,
/// so the app never needs to fetch anything from the internet at runtime
/// (staff phones are only guaranteed to be on the office LAN, not the
/// open internet). If you want the exact Source Serif 4 face, drop the
/// .ttf files into assets/fonts/ and register them in pubspec.yaml's
/// `flutter.fonts` section, then swap the family names below.
class AppColors {
  AppColors._();

  static const inkNavy = Color(0xFF1B2A44);
  static const paper = Color(0xFFF3EFE6);
  static const card = Color(0xFFFCFAF5);
  static const brass = Color(0xFFA9792C);
  static const allottedGreen = Color(0xFF3F6B4A);
  static const vacantGray = Color(0xFF6B6F76);
  static const dueRed = Color(0xFFA23B3B);

  static const onInkNavy = Color(0xFFF3EFE6);
  static const divider = Color(0xFFE1DACB);
}

class AppFonts {
  AppFonts._();

  static const serifDisplay = 'serif';
  static const monospaceData = 'monospace';
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.inkNavy,
        brightness: Brightness.light,
        primary: AppColors.inkNavy,
        secondary: AppColors.brass,
        surface: AppColors.card,
        error: AppColors.dueRed,
      ),
      scaffoldBackgroundColor: AppColors.paper,
      dividerColor: AppColors.divider,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.inkNavy,
        foregroundColor: AppColors.onInkNavy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.serifDisplay,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.onInkNavy,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontFamily: AppFonts.serifDisplay,
          fontWeight: FontWeight.w700,
          color: AppColors.inkNavy,
        ),
        headlineMedium: const TextStyle(
          fontFamily: AppFonts.serifDisplay,
          fontWeight: FontWeight.w700,
          color: AppColors.inkNavy,
        ),
        titleLarge: const TextStyle(
          fontFamily: AppFonts.serifDisplay,
          fontWeight: FontWeight.w600,
          color: AppColors.inkNavy,
        ),
        titleMedium: const TextStyle(
          fontFamily: AppFonts.serifDisplay,
          fontWeight: FontWeight.w600,
          color: AppColors.inkNavy,
        ),
        bodyLarge: const TextStyle(color: AppColors.inkNavy),
        bodyMedium: const TextStyle(color: AppColors.inkNavy),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brass,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.brass),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brass, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brass,
        foregroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  /// Reusable style for unit numbers, amounts, CNIC — anything that should
  /// read like a ledger entry rather than prose.
  static const TextStyle numericData = TextStyle(
    fontFamily: AppFonts.monospaceData,
    fontWeight: FontWeight.w600,
    color: AppColors.inkNavy,
  );
}