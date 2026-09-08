import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brightness-independent accent colours. These read well on both the light and
/// dark surfaces, so they stay compile-time constants and can be used from
/// anywhere (including context-free colour helpers).
abstract final class AppColors {
  static const purple = Color(0xFF7C5CFF);
  static const purpleDeep = Color(0xFF4B2FA8);
  static const purpleGlow = Color(0x337C5CFF);

  static const green = Color(0xFF2FBF71);
  static const greenDeep = Color(0xFF1B6B41);
  static const greenGlow = Color(0x332FBF71);

  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFCB8A1E);

  static const info = Color(0xFF3B9EFF);

  /// A muted neutral for context-free colour helpers (switch fallbacks/badges)
  /// where no BuildContext is available. Legible on both light and dark chips.
  static const neutral = Color(0xFF8C86A0);
}

/// Theme-aware neutral palette (backgrounds, borders, text). Read it from a
/// widget with `context.c.surface`, `context.c.textMuted`, etc.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  static const dark = AppPalette(
    canvas: Color(0xFF08060D),
    surface: Color(0xFF12101A),
    surfaceRaised: Color(0xFF1A1725),
    border: Color(0xFF262233),
    borderStrong: Color(0xFF35304A),
    textPrimary: Color(0xFFF4F2FA),
    textSecondary: Color(0xFFA9A3BF),
    textMuted: Color(0xFF6F6885),
  );

  static const light = AppPalette(
    canvas: Color(0xFFF5F4FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFECEAF3),
    border: Color(0xFFE3E0EC),
    borderStrong: Color(0xFFCFCADF),
    textPrimary: Color(0xFF15121F),
    textSecondary: Color(0xFF565073),
    textMuted: Color(0xFF847E99),
  );

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) =>
      AppPalette(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        border: border ?? this.border,
        borderStrong: borderStrong ?? this.borderStrong,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get c => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
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

const double kMinTouchTarget = 44.0;

ThemeData buildAppTheme([Brightness brightness = Brightness.dark]) {
  final isDark = brightness == Brightness.dark;
  final p = isDark ? AppPalette.dark : AppPalette.light;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: AppColors.purple,
    onPrimary: Colors.white,
    primaryContainer: AppColors.purpleDeep,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.green,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.greenDeep,
    onSecondaryContainer: Colors.white,
    surface: p.surface,
    onSurface: p.textPrimary,
    error: AppColors.danger,
    onError: Colors.white,
    outline: p.border,
  );

  final bodyFont = GoogleFonts.firaSans().fontFamily!;
  final monoFont = GoogleFonts.firaCode().fontFamily!;

  final baseTextTheme = (isDark ? ThemeData.dark() : ThemeData.light()).textTheme;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.canvas,
    fontFamily: bodyFont,
    textTheme: baseTextTheme
        .copyWith(
          displaySmall: baseTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),

          bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        )
        .apply(
          bodyColor: p.textPrimary,
          displayColor: p.textPrimary,
          fontFamily: bodyFont,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: bodyFont,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: p.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      labelStyle: TextStyle(color: p.textSecondary),
      hintStyle: TextStyle(color: p.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: p.border),
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
        disabledBackgroundColor: p.surfaceRaised,
        disabledForegroundColor: p.textMuted,
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
        foregroundColor: p.textSecondary,
        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.purpleGlow,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? p.textPrimary : p.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? AppColors.purple : p.textMuted,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.purple,
      linearTrackColor: p.surfaceRaised,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.surfaceRaised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.purpleDeep,
      headerForegroundColor: Colors.white,
      todayBorder: const BorderSide(color: AppColors.purple, width: 1.5),
      todayForegroundColor: const WidgetStatePropertyAll(AppColors.purple),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : p.textPrimary,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? AppColors.purple : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceRaised,
      contentTextStyle: TextStyle(color: p.textPrimary, fontFamily: bodyFont),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    extensions: [p, AppTypography(monoFamily: monoFont)],
  );
}

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
