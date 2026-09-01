import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Two faces, used with discipline.
///
///  * **Fraunces** — a soft-contrast serif, reserved for the few moments that
///    should feel like a masthead: the home greeting, screen titles, a person's
///    name on their profile. Nothing smaller than 20pt.
///  * **Inter** — everything else. It is the voice of the interface.
///
/// Mixing a serif display with a neutral UI face is what stops the product
/// reading like a template. Used everywhere it would read like a magazine, so
/// it is used in exactly four places.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.display,
    required this.headline,
    required this.title,
    required this.serifTitle,
    required this.subtitle,
    required this.body,
    required this.bodyStrong,
    required this.bodySmall,
    required this.label,
    required this.caption,
    required this.overline,
    required this.button,
    required this.numeric,
  });

  /// Serif. 34/40 — one per screen at most.
  final TextStyle display;

  /// Serif. 28/34 — screen titles.
  final TextStyle headline;

  /// Sans. 20/26 — section leads and card titles.
  final TextStyle title;

  /// Serif. 22/28 — names on profile and activity detail.
  final TextStyle serifTitle;

  /// Sans. 17/24.
  final TextStyle subtitle;

  /// Sans. 15/22 — the default reading size.
  final TextStyle body;
  final TextStyle bodyStrong;

  /// Sans. 13/19.
  final TextStyle bodySmall;

  /// Sans. 13/16, semibold — chips, tabs, metadata.
  final TextStyle label;

  /// Sans. 12/16 — timestamps, helper text.
  final TextStyle caption;

  /// Sans. 11/14, tracked and uppercase — section eyebrows.
  final TextStyle overline;

  final TextStyle button;

  /// Tabular figures, for counts and distances that must not jitter.
  final TextStyle numeric;

  static AppTypography build(Color ink) {
    TextStyle serif(double size, double height, FontWeight weight, double tracking) {
      return GoogleFonts.fraunces(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: tracking,
        color: ink,
      );
    }

    TextStyle sans(double size, double height, FontWeight weight, double tracking) {
      return GoogleFonts.inter(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: tracking,
        color: ink,
      );
    }

    return AppTypography(
      display: serif(34, 40, FontWeight.w600, -0.6),
      headline: serif(28, 34, FontWeight.w600, -0.4),
      serifTitle: serif(22, 28, FontWeight.w600, -0.2),
      title: sans(20, 26, FontWeight.w600, -0.3),
      subtitle: sans(17, 24, FontWeight.w600, -0.2),
      body: sans(15, 22, FontWeight.w400, -0.1),
      bodyStrong: sans(15, 22, FontWeight.w600, -0.1),
      bodySmall: sans(13, 19, FontWeight.w400, 0),
      label: sans(13, 16, FontWeight.w600, -0.05),
      caption: sans(12, 16, FontWeight.w400, 0),
      overline: sans(11, 14, FontWeight.w700, 0.9),
      button: sans(15, 20, FontWeight.w600, -0.1),
      numeric: GoogleFonts.inter(
        fontSize: 13,
        height: 16 / 13,
        fontWeight: FontWeight.w600,
        color: ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? serifTitle,
    TextStyle? subtitle,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? bodySmall,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? overline,
    TextStyle? button,
    TextStyle? numeric,
  }) {
    return AppTypography(
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      serifTitle: serifTitle ?? this.serifTitle,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      bodySmall: bodySmall ?? this.bodySmall,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      overline: overline ?? this.overline,
      button: button ?? this.button,
      numeric: numeric ?? this.numeric,
    );
  }

  @override
  AppTypography lerp(covariant AppTypography? other, double t) {
    if (other == null) return this;
    return AppTypography(
      display: TextStyle.lerp(display, other.display, t) ?? display,
      headline: TextStyle.lerp(headline, other.headline, t) ?? headline,
      title: TextStyle.lerp(title, other.title, t) ?? title,
      serifTitle: TextStyle.lerp(serifTitle, other.serifTitle, t) ?? serifTitle,
      subtitle: TextStyle.lerp(subtitle, other.subtitle, t) ?? subtitle,
      body: TextStyle.lerp(body, other.body, t) ?? body,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t) ?? bodyStrong,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t) ?? bodySmall,
      label: TextStyle.lerp(label, other.label, t) ?? label,
      caption: TextStyle.lerp(caption, other.caption, t) ?? caption,
      overline: TextStyle.lerp(overline, other.overline, t) ?? overline,
      button: TextStyle.lerp(button, other.button, t) ?? button,
      numeric: TextStyle.lerp(numeric, other.numeric, t) ?? numeric,
    );
  }
}

/// `context.type` — the only way screens should reach for a text style.
extension AppTypographyX on BuildContext {
  AppTypography get type =>
      Theme.of(this).extension<AppTypography>() ?? AppTypography.build(const Color(0xFF16211C));
}
