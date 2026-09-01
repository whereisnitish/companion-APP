import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The moment an invitation lands.
///
/// A ring draws itself, a tick strokes on, and a few motes drift outward. It
/// runs once, for well under a second — celebration, not a cutscene.
class SuccessBurst extends StatefulWidget {
  const SuccessBurst({super.key, this.size = 84, this.color, this.onCompleted});

  final double size;
  final Color? color;
  final VoidCallback? onCompleted;

  @override
  State<SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<SuccessBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() => widget.onCompleted?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) => CustomPaint(
          painter: _SuccessPainter(progress: _controller.value, color: color),
        ),
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  const _SuccessPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double radius = size.width * 0.34;

    final double ring = Curves.easeOutCubic.transform((progress / 0.45).clamp(0.0, 1.0));
    final double tick = Curves.easeOutCubic.transform(
      ((progress - 0.32) / 0.38).clamp(0.0, 1.0),
    );
    final double motes = Curves.easeOutCubic.transform(
      ((progress - 0.28) / 0.72).clamp(0.0, 1.0),
    );

    // Soft halo.
    canvas.drawCircle(
      centre,
      radius * (1 + 0.45 * motes),
      Paint()..color = color.withValues(alpha: 0.12 * (1 - motes)),
    );

    // The ring strokes on from the top.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * ring,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // The tick, drawn as two strokes revealed in sequence.
    if (tick > 0) {
      final Offset start = centre + Offset(-radius * 0.38, radius * 0.02);
      final Offset elbow = centre + Offset(-radius * 0.08, radius * 0.34);
      final Offset end = centre + Offset(radius * 0.42, -radius * 0.3);

      final Path path = Path()..moveTo(start.dx, start.dy);
      if (tick <= 0.5) {
        final double t = tick / 0.5;
        path.lineTo(start.dx + (elbow.dx - start.dx) * t, start.dy + (elbow.dy - start.dy) * t);
      } else {
        final double t = (tick - 0.5) / 0.5;
        path
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(elbow.dx + (end.dx - elbow.dx) * t, elbow.dy + (end.dy - elbow.dy) * t);
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }

    // Six motes drifting out and fading.
    for (int index = 0; index < 6; index += 1) {
      final double angle = (index / 6) * 2 * math.pi - math.pi / 3;
      final double distance = radius * (1.15 + 0.75 * motes);
      final Offset position = centre.translate(
        math.cos(angle) * distance,
        math.sin(angle) * distance,
      );
      canvas.drawCircle(
        position,
        2.4 * (1 - motes),
        Paint()..color = color.withValues(alpha: 0.55 * (1 - motes)),
      );
    }
  }

  @override
  bool shouldRepaint(_SuccessPainter oldDelegate) => oldDelegate.progress != progress;
}
