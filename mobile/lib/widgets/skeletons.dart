import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A hand-rolled shimmer. One controller drives every child through an
/// InheritedWidget, so a screen full of placeholders costs a single ticker.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  /// The shared ticker, or null when no [Shimmer] is above [context].
  static AnimationController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.state.controller;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ShimmerScope(state: this, child: widget.child);
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.state, required super.child});

  final _ShimmerState state;

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) => false;
}

/// A single grey block that breathes. Compose these into screen-shaped
/// placeholders so a loading screen has the same silhouette as the real one.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadii.xs,
    this.shape = BoxShape.rectangle,
  });

  const SkeletonBox.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AnimationController? shimmer = Shimmer.of(context);

    final Widget box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.shimmerBase,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );

    if (shimmer == null) return box;

    return AnimatedBuilder(
      animation: shimmer,
      builder: (BuildContext context, Widget? child) {
        // A soft pulse rather than a sweeping highlight — quieter, and it does
        // not fight the warm canvas.
        // Ping-pong the 0→1 ticker into a 0→1→0 pulse.
        final double raw = shimmer.value * 2;
        final double t = Curves.easeInOut.transform(raw <= 1 ? raw : 2 - raw);
        return Opacity(opacity: 0.55 + 0.45 * t, child: child);
      },
      child: box,
    );
  }
}

/// The loading silhouette for a person card in Discover.
class PersonCardSkeleton extends StatelessWidget {
  const PersonCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBox(height: 190, radius: 0),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 130, height: 16),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 90, height: 12),
                SizedBox(height: AppSpacing.lg),
                SkeletonBox(height: 12),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 180, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The loading silhouette for a horizontal list row.
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key, this.leadingSize = 48});

  final double leadingSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenX,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          SkeletonBox.circle(size: leadingSize),
          const SizedBox(width: AppSpacing.lg),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 120, height: 14),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
