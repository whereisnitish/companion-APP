import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'press_effect.dart';

/// The rhythm of every scrolling screen: an eyebrow, a title, an optional
/// action. Consistent vertical spacing here is most of what makes the app feel
/// like one product rather than a pile of screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.screenX,
      AppSpacing.xxxl,
      AppSpacing.screenX,
      AppSpacing.lg,
    ),
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (eyebrow != null) ...<Widget>[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: type.overline.copyWith(color: colors.inkFaint),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(title, style: type.title),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: type.bodySmall.copyWith(color: colors.inkMuted)),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            PressEffect(
              onTap: onAction,
              scale: 0.94,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md, bottom: 2),
                child: Row(
                  children: <Widget>[
                    Text(
                      actionLabel!,
                      style: type.label.copyWith(color: colors.primary),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 18, color: colors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
