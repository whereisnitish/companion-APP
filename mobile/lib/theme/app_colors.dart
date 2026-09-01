import 'package:flutter/material.dart';

/// The palette. Two tuned sets — nothing is computed on the fly, so the product
/// looks the same in every screen and in both themes.
///
/// Direction: warm paper, deep pine, a single clay accent used sparingly.
/// Colour carries meaning here; it is never decoration.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.inkInverse,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.border,
    required this.borderStrong,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.danger,
    required this.dangerSoft,
    required this.overlay,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;

  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color inkInverse;

  final Color primary;
  final Color primaryPressed;
  final Color onPrimary;
  final Color primarySoft;

  final Color accent;
  final Color accentSoft;

  final Color border;
  final Color borderStrong;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color danger;
  final Color dangerSoft;

  final Color overlay;
  final Color shimmerBase;
  final Color shimmerHighlight;

  static const AppColors light = AppColors(
    canvas: Color(0xFFF7F5F1),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF0EDE7),
    ink: Color(0xFF16211C),
    inkMuted: Color(0xFF69736E),
    inkFaint: Color(0xFF9BA39F),
    inkInverse: Color(0xFFF7F5F1),
    primary: Color(0xFF14453A),
    primaryPressed: Color(0xFF0D2F27),
    onPrimary: Color(0xFFF7F5F1),
    primarySoft: Color(0xFFE2ECE7),
    accent: Color(0xFFC0603A),
    accentSoft: Color(0xFFF8E9E1),
    border: Color(0xFFE7E2D9),
    borderStrong: Color(0xFFD5CEC2),
    success: Color(0xFF2C7A5B),
    successSoft: Color(0xFFDFF0E7),
    warning: Color(0xFFA97B1F),
    danger: Color(0xFFB03E2E),
    dangerSoft: Color(0xFFF8E4E0),
    overlay: Color(0x33101512),
    shimmerBase: Color(0xFFEDEAE3),
    shimmerHighlight: Color(0xFFF6F4EF),
  );

  static const AppColors dark = AppColors(
    canvas: Color(0xFF0C110F),
    surface: Color(0xFF141A17),
    surfaceRaised: Color(0xFF1A211D),
    surfaceSunken: Color(0xFF0F1512),
    ink: Color(0xFFF0EEE8),
    inkMuted: Color(0xFF9AA49F),
    inkFaint: Color(0xFF6C7671),
    inkInverse: Color(0xFF0C110F),
    primary: Color(0xFF63B598),
    primaryPressed: Color(0xFF4E9C81),
    onPrimary: Color(0xFF07130E),
    primarySoft: Color(0xFF172A23),
    accent: Color(0xFFE0855C),
    accentSoft: Color(0xFF2C1D16),
    border: Color(0xFF232C27),
    borderStrong: Color(0xFF33403A),
    success: Color(0xFF5DBA92),
    successSoft: Color(0xFF14261E),
    warning: Color(0xFFD3A44D),
    danger: Color(0xFFE1705C),
    dangerSoft: Color(0xFF2B1815),
    overlay: Color(0x66000000),
    shimmerBase: Color(0xFF1A211D),
    shimmerHighlight: Color(0xFF232C27),
  );

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? inkInverse,
    Color? primary,
    Color? primaryPressed,
    Color? onPrimary,
    Color? primarySoft,
    Color? accent,
    Color? accentSoft,
    Color? border,
    Color? borderStrong,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? danger,
    Color? dangerSoft,
    Color? overlay,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      inkInverse: inkInverse ?? this.inkInverse,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      overlay: overlay ?? this.overlay,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppColors(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceSunken: mix(surfaceSunken, other.surfaceSunken),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkFaint: mix(inkFaint, other.inkFaint),
      inkInverse: mix(inkInverse, other.inkInverse),
      primary: mix(primary, other.primary),
      primaryPressed: mix(primaryPressed, other.primaryPressed),
      onPrimary: mix(onPrimary, other.onPrimary),
      primarySoft: mix(primarySoft, other.primarySoft),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      success: mix(success, other.success),
      successSoft: mix(successSoft, other.successSoft),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      overlay: mix(overlay, other.overlay),
      shimmerBase: mix(shimmerBase, other.shimmerBase),
      shimmerHighlight: mix(shimmerHighlight, other.shimmerHighlight),
    );
  }
}

/// `context.colors` — the only way screens should reach for colour.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
