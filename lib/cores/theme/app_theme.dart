import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Extra semantic colors that ThemeData doesn't have slots for
/// (surface2/3, muted text, gauge track, accent-on-accent, etc).
/// Access anywhere via: `Theme.of(context).extension&lt;AppColorsExt&gt;()`!
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  final Color surface2;
  final Color surface3;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color primaryStrong;
  final Color danger;
  final Color success;
  final Color gaugeTrack;
  final Color borderStrong;

  const AppColorsExt({
    required this.surface2,
    required this.surface3,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.primaryStrong,
    required this.danger,
    required this.success,
    required this.gaugeTrack,
    required this.borderStrong,
  });

  @override
  AppColorsExt copyWith({
    Color? surface2,
    Color? surface3,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? primaryStrong,
    Color? danger,
    Color? success,
    Color? gaugeTrack,
    Color? borderStrong,
  }) {
    return AppColorsExt(
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      gaugeTrack: gaugeTrack ?? this.gaugeTrack,
      borderStrong: borderStrong ?? this.borderStrong,
    );
  }

  @override
  AppColorsExt lerp(ThemeExtension<AppColorsExt>? other, double t) {
    if (other is! AppColorsExt) return this;
    return AppColorsExt(
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      gaugeTrack: Color.lerp(gaugeTrack, other.gaugeTrack, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color text, Color secondary) {
    final display = GoogleFonts.spaceGroteskTextTheme();
    final body = GoogleFonts.interTextTheme();
    return body.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: text,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -0.5,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: text,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: text,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: text,
      ),
      titleMedium: display.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: text,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: text),
      bodyMedium: body.bodyMedium?.copyWith(color: text),
      bodySmall: body.bodySmall?.copyWith(color: secondary),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: text,
      ),
      labelSmall: body.labelSmall?.copyWith(color: secondary),
    );
  }

  static ThemeData get light {
    const primary = AppColors.primaryLight;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: AppColors.onPrimaryLight,
        secondary: AppColors.accentLight,
        onSecondary: AppColors.onAccentLight,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        error: AppColors.danger,
      ),
      textTheme: _textTheme(AppColors.lightText, AppColors.lightTextSecondary),
      dividerColor: AppColors.lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        foregroundColor: AppColors.lightText,
        elevation: 0,
        centerTitle: false,
      ),
      extensions: const [
        AppColorsExt(
          surface2: AppColors.lightSurface2,
          surface3: AppColors.lightSurface3,
          textSecondary: AppColors.lightTextSecondary,
          textMuted: AppColors.lightTextMuted,
          accent: AppColors.accentLight,
          onAccent: AppColors.onAccentLight,
          primaryStrong: AppColors.primaryStrongLight,
          danger: AppColors.danger,
          success: AppColors.success,
          gaugeTrack: AppColors.lightSurface3,
          borderStrong: AppColors.lightBorderStrong,
        ),
      ],
    );
  }

  static ThemeData get dark {
    const primary = AppColors.primaryDark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: AppColors.onPrimaryDark,
        secondary: AppColors.accentDark,
        onSecondary: AppColors.onAccentDark,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        error: AppColors.dangerDark,
      ),
      textTheme: _textTheme(AppColors.darkText, AppColors.darkTextSecondary),
      dividerColor: AppColors.darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: false,
      ),
      extensions: const [
        AppColorsExt(
          surface2: AppColors.darkSurface2,
          surface3: AppColors.darkSurface3,
          textSecondary: AppColors.darkTextSecondary,
          textMuted: AppColors.darkTextMuted,
          accent: AppColors.accentDark,
          onAccent: AppColors.onAccentDark,
          primaryStrong: AppColors.primaryStrongDark,
          danger: AppColors.dangerDark,
          success: AppColors.successDark,
          gaugeTrack: AppColors.darkSurface3,
          borderStrong: AppColors.darkBorderStrong,
        ),
      ],
    );
  }
}

/// Shortcut so screens can write `context.colors.textMuted` instead of
/// the verbose `Theme.of(context).extension<AppColorsExt>()!`
extension BuildContextColors on BuildContext {
  AppColorsExt get colors => Theme.of(this).extension<AppColorsExt>()!;
}
