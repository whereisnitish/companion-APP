import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Content arrives rather than appearing: a 12px rise and a fade, staggered by
/// position in the list. Deliberately capped — after the sixth item the delay
/// stops growing, so a long list never feels like it is loading slowly.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
    this.delayStep = const Duration(milliseconds: 55),
    this.maxSteps = 6,
    this.enabled = true,
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration delayStep;
  final int maxSteps;
  final bool enabled;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.entrance,
  );

  /// Held so the stagger can be cancelled — a widget scrolled off before its
  /// turn must not leave a timer behind.
  Timer? _stagger;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }

    final int steps = widget.index.clamp(0, widget.maxSteps);
    final Duration delay = widget.delayStep * steps;

    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _stagger = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _stagger?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = AppMotion.emphasized.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Cross-fades between two children with a hair of vertical travel — used for
/// tab bodies and filter results where a hard swap would feel abrupt.
class SoftSwitcher extends StatelessWidget {
  const SoftSwitcher({super.key, required this.child, this.duration = AppMotion.base});

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.standard,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[...previous, if (current != null) current],
      ),
      transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A number that rolls when it changes — invitation counts, spots left.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, axis: Axis.horizontal, child: child),
      ),
      child: Text('$value', key: ValueKey<int>(value), style: style),
    );
  }
}
