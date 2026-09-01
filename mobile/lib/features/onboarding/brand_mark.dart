import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Companion mark: two rings that overlap.
///
/// Not a heart, not a flame, not a chat bubble — two separate circles that
/// choose to intersect. [progress] drives them from apart to together, which is
/// the entire brand argument in one gesture.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 72,
    this.progress = 1,
    this.color,
    this.accentColor,
    this.strokeWidth = 2.4,
  });

  final double size;
  final double progress;
  final Color? color;
  final Color? accentColor;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final Color primary = color ?? Theme.of(context).colorScheme.primary;
    final Color accent = accentColor ?? Theme.of(context).colorScheme.secondary;

    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          progress: progress.clamp(0, 1),
          primary: primary,
          accent: accent,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({
    required this.progress,
    required this.primary,
    required this.accent,
    required this.strokeWidth,
  });

  final double progress;
  final Color primary;
  final Color accent;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double radius = size.width * 0.28;

    // Apart at 0, overlapping by a third of a radius at 1.
    final double separation = ui(radius * 1.6, radius * 0.62, progress);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      centre.translate(-separation, 0),
      radius,
      stroke..color = primary,
    );
    canvas.drawCircle(
      centre.translate(separation, 0),
      radius,
      stroke..color = accent.withValues(alpha: 0.55 + 0.45 * progress),
    );

    // The overlap fills in only once the rings actually meet.
    if (separation < radius) {
      final Path left = Path()
        ..addOval(Rect.fromCircle(center: centre.translate(-separation, 0), radius: radius));
      final Path right = Path()
        ..addOval(Rect.fromCircle(center: centre.translate(separation, 0), radius: radius));
      final Path lens = Path.combine(PathOperation.intersect, left, right);

      canvas.drawPath(
        lens,
        Paint()
          ..style = PaintingStyle.fill
          ..color = primary.withValues(alpha: 0.12 * progress),
      );
    }
  }

  double ui(double from, double to, double t) =>
      from + (to - from) * Curves.easeOutCubic.transform(t);

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primary != primary ||
      oldDelegate.accent != accent;
}

/// The abstract compositions behind each onboarding page.
///
/// Painted rather than shipped as assets: they scale to any screen, they pick
/// up the theme, and they cannot look like stock illustration.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({
    super.key,
    required this.variant,
    required this.progress,
    required this.palette,
  });

  final int variant;
  final double progress;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OnboardingArtPainter(
        variant: variant,
        progress: progress,
        palette: palette,
        surface: Theme.of(context).colorScheme.surface,
      ),
      size: Size.infinite,
    );
  }
}

class _OnboardingArtPainter extends CustomPainter {
  const _OnboardingArtPainter({
    required this.variant,
    required this.progress,
    required this.palette,
    required this.surface,
  });

  final int variant;
  final double progress;
  final List<Color> palette;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    switch (variant % 4) {
      case 0:
        _paintConverging(canvas, size, t);
      case 1:
        _paintTiles(canvas, size, t);
      case 2:
        _paintStack(canvas, size, t);
      default:
        _paintOrbit(canvas, size, t);
    }
  }

  /// Two arcs travelling toward each other — "don't do it alone".
  void _paintConverging(Canvas canvas, Size size, double t) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double radius = size.shortestSide * 0.3;
    final double gap = radius * (1.5 - 0.85 * t);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (int ring = 0; ring < 4; ring += 1) {
      final double scale = 1 + ring * 0.22;
      final double fade = (1 - ring * 0.22) * t;
      canvas.drawCircle(
        centre.translate(-gap, 0),
        radius * scale,
        stroke..color = palette[0].withValues(alpha: 0.32 * fade),
      );
      canvas.drawCircle(
        centre.translate(gap, 0),
        radius * scale,
        stroke..color = palette[1].withValues(alpha: 0.32 * fade),
      );
    }

    canvas.drawCircle(
      centre.translate(-gap, 0),
      radius * 0.24,
      Paint()..color = palette[0].withValues(alpha: 0.85 * t),
    );
    canvas.drawCircle(
      centre.translate(gap, 0),
      radius * 0.24,
      Paint()..color = palette[1].withValues(alpha: 0.85 * t),
    );
  }

  /// A loose grid of rounded tiles — "say what you're up for".
  void _paintTiles(Canvas canvas, Size size, double t) {
    const int columns = 3;
    const int rows = 3;
    final double tile = size.shortestSide * 0.19;
    final double gap = tile * 0.42;
    final double totalWidth = columns * tile + (columns - 1) * gap;
    final double totalHeight = rows * tile + (rows - 1) * gap;
    final Offset origin = Offset(
      (size.width - totalWidth) / 2,
      (size.height - totalHeight) / 2,
    );

    int index = 0;
    for (int row = 0; row < rows; row += 1) {
      for (int column = 0; column < columns; column += 1) {
        final double delay = index * 0.07;
        final double local = ((t - delay) / (1 - delay)).clamp(0, 1);
        final double lift = (1 - local) * tile * 0.5;

        final Rect rect = Rect.fromLTWH(
          origin.dx + column * (tile + gap),
          origin.dy + row * (tile + gap) + lift,
          tile,
          tile,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(tile * 0.3)),
          Paint()..color = palette[index % palette.length].withValues(alpha: 0.16 * local),
        );
        canvas.drawCircle(
          rect.center,
          tile * 0.16,
          Paint()..color = palette[index % palette.length].withValues(alpha: 0.75 * local),
        );
        index += 1;
      }
    }
  }

  /// Cards fanning out of a deck — "find someone who wants to join".
  void _paintStack(Canvas canvas, Size size, double t) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double cardWidth = size.shortestSide * 0.44;
    final double cardHeight = cardWidth * 1.26;

    for (int index = 2; index >= 0; index -= 1) {
      final double local = ((t - index * 0.12) / (1 - index * 0.12)).clamp(0, 1);
      final double angle = (index - 1) * 0.16 * local;
      final double offsetX = (index - 1) * cardWidth * 0.34 * local;

      canvas.save();
      canvas.translate(centre.dx + offsetX, centre.dy);
      canvas.rotate(angle);

      final Rect rect = Rect.fromCenter(
        center: Offset.zero,
        width: cardWidth,
        height: cardHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cardWidth * 0.14)),
        Paint()..color = surface.withValues(alpha: local),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cardWidth * 0.14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = palette[index % palette.length].withValues(alpha: 0.4 * local),
      );
      canvas.drawCircle(
        Offset(0, -cardHeight * 0.18),
        cardWidth * 0.16,
        Paint()..color = palette[index % palette.length].withValues(alpha: 0.5 * local),
      );
      for (int line = 0; line < 2; line += 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, cardHeight * (0.12 + line * 0.14)),
              width: cardWidth * (line == 0 ? 0.56 : 0.36),
              height: 6,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = palette[index % palette.length].withValues(alpha: 0.22 * local),
        );
      }
      canvas.restore();
    }
  }

  /// Dots orbiting a centre — "meet through what you actually want to do".
  void _paintOrbit(Canvas canvas, Size size, double t) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double radius = size.shortestSide * 0.32;

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int index = 0; index < 3; index += 1) {
      canvas.drawCircle(
        centre,
        radius * (0.55 + index * 0.32),
        ring..color = palette[index % palette.length].withValues(alpha: 0.22 * t),
      );
    }

    for (int index = 0; index < 6; index += 1) {
      final double angle = (index / 6) * 2 * math.pi + t * 0.5;
      final double distance = radius * (index.isEven ? 0.87 : 0.55);
      final Offset position = centre.translate(
        math.cos(angle) * distance,
        math.sin(angle) * distance,
      );
      canvas.drawCircle(
        position,
        size.shortestSide * 0.032 * t,
        Paint()..color = palette[index % palette.length].withValues(alpha: 0.8 * t),
      );
    }

    canvas.drawCircle(
      centre,
      size.shortestSide * 0.055 * t,
      Paint()..color = palette[0].withValues(alpha: 0.9 * t),
    );
  }

  @override
  bool shouldRepaint(_OnboardingArtPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.variant != variant;
}
