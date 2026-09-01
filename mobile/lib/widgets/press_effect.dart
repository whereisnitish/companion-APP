import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Touch feedback for the whole product: a 2% scale-down and a whisper of
/// opacity. We disabled Material's ink splash in the theme because a ripple
/// crossing a photo card looks cheap; this reads as physical instead.
class PressEffect extends StatefulWidget {
  const PressEffect({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.98,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<PressEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.instant,
    reverseDuration: AppMotion.fast,
    lowerBound: 0,
    upperBound: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _interactive => widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool pressed) {
    if (!_interactive) return;
    if (pressed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // With no handler we register nothing, so an inert wrapper never enters the
    // gesture arena and steal a tap meant for a button nested inside it.
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _interactive ? (_) => _setPressed(true) : null,
      onTapUp: _interactive ? (_) => _setPressed(false) : null,
      onTapCancel: _interactive ? () => _setPressed(false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeOut.transform(_controller.value);
          return Transform.scale(
            scale: 1 - (1 - widget.scale) * t,
            child: Opacity(opacity: 1 - 0.06 * t, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}
