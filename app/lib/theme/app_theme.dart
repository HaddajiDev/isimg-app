import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the app's dark aesthetic: deep OLED base with a dark
/// purple primary and dark green accent used for positive/valid indicators.
abstract final class AppColors {
  // Surfaces, darkest to lightest.
  static const canvas = Color(0xFF08060D);
  static const surface = Color(0xFF12101A);
  static const surfaceRaised = Color(0xFF1A1725);
  static const border = Color(0xFF262233);
  static const borderStrong = Color(0xFF35304A);

  // Dark purple — primary brand.
  static const purple = Color(0xFF7C5CFF);
  static const purpleDeep = Color(0xFF4B2FA8);
  static const purpleGlow = Color(0x337C5CFF);

  // Dark green — success / passing grades.
  static const green = Color(0xFF2FBF71);
  static const greenDeep = Color(0xFF1B6B41);
  static const greenGlow = Color(0x332FBF71);

  // Status.
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFE0A030);

  /// Neutral-informational accent. Needed a third colour distinct from both
  /// brand hues to tell the timetable's Cours / TD / TP apart.
  static const info = Color(0xFF3B9EFF);

  // Text.
  static const textPrimary = Color(0xFFF4F2FA);
  static const textSecondary = Color(0xFFA9A3BF);
  static const textMuted = Color(0xFF6F6885);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

/// Minimum size for any tappable control (accessibility).
const double kMinTouchTarget = 44.0;

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.purple,
    onPrimary: Colors.white,
    primaryContainer: AppColors.purpleDeep,
    secondary: AppColors.green,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.greenDeep,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.border,
  );

  // Fira Sans / Fira Code per the design system's dashboard pairing.
  final bodyFont = GoogleFonts.firaSans().fontFamily!;
  final monoFont = GoogleFonts.firaCode().fontFamily!;

  final baseTextTheme = ThemeData.dark().textTheme;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: bodyFont,
    textTheme: baseTextTheme
        .copyWith(
          displaySmall: baseTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          // 16px minimum for body text on mobile.
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        )
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
          fontFamily: bodyFont,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: bodyFont,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.purple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceRaised,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size.fromHeight(52),
        textStyle: TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.purple,
        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.purpleGlow,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? AppColors.purple : AppColors.textMuted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.purple,
      linearTrackColor: AppColors.surfaceRaised,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surfaceRaised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.purpleDeep,
      headerForegroundColor: Colors.white,
      todayBorder: const BorderSide(color: AppColors.purple, width: 1.5),
      todayForegroundColor: const WidgetStatePropertyAll(AppColors.purple),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.textPrimary,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? AppColors.purple : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: TextStyle(color: AppColors.textPrimary, fontFamily: bodyFont),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    extensions: [AppTypography(monoFamily: monoFont)],
  );
}

/// Exposes the monospace family for numeric/tabular values (grades, averages).
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  final String monoFamily;

  const AppTypography({required this.monoFamily});

  @override
  AppTypography copyWith({String? monoFamily}) =>
      AppTypography(monoFamily: monoFamily ?? this.monoFamily);

  @override
  AppTypography lerp(AppTypography? other, double t) => other ?? this;
}
