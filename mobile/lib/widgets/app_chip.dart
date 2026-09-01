import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'press_effect.dart';

/// A pill. Selectable or static, tinted or neutral — used for interests,
/// filters, availability and status throughout.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.selected = false,
    this.onTap,
    this.tint,
    this.foreground,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;
  final Color? tint;
  final Color? foreground;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    final Color background = selected ? (tint ?? colors.ink) : (tint ?? Colors.transparent);
    final Color textColor = selected
        ? (foreground ?? (tint != null ? colors.ink : colors.inkInverse))
        : (foreground ?? colors.inkMuted);
    final Color borderColor =
        selected ? (tint != null ? Colors.transparent : colors.ink) : colors.border;

    return PressEffect(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AppSpacing.md : AppSpacing.lg - 2,
          vertical: dense ? 6 : AppSpacing.sm + 1,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadii.pillAll,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: AppSpacing.xs + 2),
            ] else if (icon != null) ...<Widget>[
              Icon(icon, size: dense ? 13 : 15, color: textColor),
              const SizedBox(width: AppSpacing.xs + 2),
            ],
            Text(
              label,
              style: (dense ? context.type.caption : context.type.label)
                  .copyWith(color: textColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// A category chip carrying its own hue — the fastest way to read "this is a
/// movie plan" without reading at all.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    this.selected = false,
    this.onTap,
    this.dense = false,
    this.showIcon = true,
  });

  final ActivityCategory category;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final Color hue = category.foreground(context);
    return AppChip(
      label: category.label,
      icon: showIcon ? category.icon : null,
      selected: selected,
      onTap: onTap,
      dense: dense,
      tint: selected ? category.tint(context) : null,
      foreground: selected ? hue : null,
    );
  }
}

/// A small square badge holding a category icon — used as list leading art.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category, this.size = 44, this.radius = 14});

  final ActivityCategory category;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: category.tint(context),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(category.icon, size: size * 0.46, color: category.foreground(context)),
    );
  }
}

/// A status pill for invitations — the colour is the message.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final InvitationStatus status;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final (Color background, Color foreground) = switch (status) {
      InvitationStatus.pending => (colors.surfaceSunken, colors.inkMuted),
      InvitationStatus.accepted => (colors.successSoft, colors.success),
      InvitationStatus.declined => (colors.dangerSoft, colors.danger),
      InvitationStatus.cancelled => (colors.surfaceSunken, colors.inkFaint),
      InvitationStatus.expired => (colors.surfaceSunken, colors.inkFaint),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: AppRadii.pillAll),
      child: Text(
        status.label,
        style: context.type.caption.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The verification tick. A placeholder for a real identity check — the badge
/// and its plumbing exist so switching on the backend later is a data change.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16, this.status = VerificationStatus.verified});

  final double size;
  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.isVerified) return const SizedBox.shrink();
    return Icon(Icons.verified_rounded, size: size, color: context.colors.primary);
  }
}
