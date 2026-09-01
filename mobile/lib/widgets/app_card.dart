import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import 'press_effect.dart';

/// The surface every piece of content sits on: hairline border, a shadow you
/// have to look for, generous radius. Depth comes from the border, not the blur.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadii.lg,
    this.color,
    this.borderColor,
    this.elevated = true,
    this.clip = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool elevated;
  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return PressEffect(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? colors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? colors.border),
          boxShadow: elevated ? AppShadows.resting(colors.ink) : null,
        ),
        clipBehavior: clip,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A flat, borderless grouping used inside sheets and settings lists.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return PressEffect(
      onTap: onTap,
      scale: 0.99,
      child: Padding(padding: padding, child: child),
    );
  }
}
