import 'package:flutter/material.dart';

// ============================================================
// Navy Blue & Gold premium theme + design-token foundation.
//
// Design-system layers:
//  - AppColors     : raw brand palette (stable, brightness-agnostic accents).
//  - AppSpacing/Radius/Duration : layout + motion tokens (use these instead of
//    magic numbers so spacing/rounding/animation stay consistent app-wide).
//  - AppSemantic   : the surface/text/badge colors that DIFFER between light
//    and dark, exposed as a ThemeExtension. New/updated screens should read
//    `context.semantic.cardBg` etc. instead of the static AppColors so that
//    enabling dark mode becomes a one-line switch (see the note on themeMode
//    in main.dart). Screens not yet migrated keep using AppColors and stay
//    light — which is why themeMode is pinned to light for now.
// ============================================================

class AppColors {
  // Primary - Deep Navy
  static const Color navy = Color(0xFF0D1B3E);
  static const Color navyLight = Color(0xFF1A2D5A);
  static const Color navyDark = Color(0xFF081028);

  // Accent - Gold/Amber
  static const Color gold = Color(0xFFFFB300);
  static const Color goldLight = Color(0xFFFFCC40);
  static const Color goldDark = Color(0xFFE6A000);

  // Surface colors (light)
  static const Color surface = Color(0xFFF5F6FA);
  static const Color cardBg = Colors.white;
  static const Color cardBgDark = Color(0xFF1E2F54);

  // Status colors
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Colors.white;
  static const Color textOnGold = Color(0xFF1A1A2E);

  // Air / Sea badges
  static const Color airBg = Color(0xFFE8F0FE);
  static const Color airText = Color(0xFF1A73E8);
  static const Color seaBg = Color(0xFFE6F7F1);
  static const Color seaText = Color(0xFF0D7F56);
}

/// Spacing scale on a 4pt grid. Use instead of literal EdgeInsets numbers.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner-radius scale.
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 100;
}

/// Motion durations for consistent transitions/animations.
class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

/// Brightness-dependent surface/text/badge colors. Read via `context.semantic`.
@immutable
class AppSemantic extends ThemeExtension<AppSemantic> {
  final Color scaffold;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color airBg;
  final Color airText;
  final Color seaBg;
  final Color seaText;

  const AppSemantic({
    required this.scaffold,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.airBg,
    required this.airText,
    required this.seaBg,
    required this.seaText,
  });

  static const light = AppSemantic(
    scaffold: AppColors.surface,
    cardBg: Colors.white,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    border: Color(0xFFE5E7EB),
    airBg: AppColors.airBg,
    airText: AppColors.airText,
    seaBg: AppColors.seaBg,
    seaText: AppColors.seaText,
  );

  static const dark = AppSemantic(
    scaffold: Color(0xFF0B1428),
    cardBg: Color(0xFF16244A),
    textPrimary: Color(0xFFF3F5FB),
    textSecondary: Color(0xFF9AA6C0),
    border: Color(0xFF24345F),
    airBg: Color(0xFF16294D),
    airText: Color(0xFF7FB0FF),
    seaBg: Color(0xFF10352A),
    seaText: Color(0xFF57D6A6),
  );

  @override
  AppSemantic copyWith({
    Color? scaffold,
    Color? cardBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? airBg,
    Color? airText,
    Color? seaBg,
    Color? seaText,
  }) {
    return AppSemantic(
      scaffold: scaffold ?? this.scaffold,
      cardBg: cardBg ?? this.cardBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      airBg: airBg ?? this.airBg,
      airText: airText ?? this.airText,
      seaBg: seaBg ?? this.seaBg,
      seaText: seaText ?? this.seaText,
    );
  }

  @override
  AppSemantic lerp(ThemeExtension<AppSemantic>? other, double t) {
    if (other is! AppSemantic) return this;
    return AppSemantic(
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      airBg: Color.lerp(airBg, other.airBg, t)!,
      airText: Color.lerp(airText, other.airText, t)!,
      seaBg: Color.lerp(seaBg, other.seaBg, t)!,
      seaText: Color.lerp(seaText, other.seaText, t)!,
    );
  }
}

/// Sugar so migrated screens can write `context.semantic.cardBg`.
extension AppSemanticContext on BuildContext {
  AppSemantic get semantic => Theme.of(this).extension<AppSemantic>()!;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    extensions: const [AppSemantic.light],
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.gold,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSecondary: AppColors.textOnGold,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs + 2),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.textOnGold,
      elevation: 4,
      shape: CircleBorder(),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.navy,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.textOnGold,
        elevation: 2,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.md + 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy, width: 1.5),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.md + 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.navy, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade200,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.navy,
      labelStyle: const TextStyle(fontSize: 13),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl - 4)),
    ),
  );
}

/// Dark theme — foundation for a future dark mode. NOT yet active: it becomes
/// live once screens read colors from `context.semantic`/the colorScheme
/// instead of the static (light) AppColors, at which point main.dart can flip
/// `themeMode` to `ThemeMode.system`. Kept in sync with buildAppTheme's shape.
ThemeData buildDarkTheme() {
  const scaffold = Color(0xFF0B1428);
  const card = Color(0xFF16244A);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    extensions: const [AppSemantic.dark],
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
      primary: AppColors.gold,
      secondary: AppColors.goldLight,
      surface: card,
      onPrimary: AppColors.textOnGold,
      onSecondary: AppColors.textOnGold,
    ),
    scaffoldBackgroundColor: scaffold,
    appBarTheme: const AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs + 2),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.textOnGold,
      elevation: 4,
      shape: CircleBorder(),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: card,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: Color(0xFF9AA6C0),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.textOnGold,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.md + 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1C2C52),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Color(0xFF24345F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Color(0xFF24345F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.gold, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF9AA6C0)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF24345F),
      thickness: 1,
    ),
  );
}
