import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'press_effect.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { large, medium, small }

/// The one button in the product. Four variants, three sizes, no exceptions —
/// which is why a screen never has to decide what a button looks like.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool expand;

  bool get _enabled => onPressed != null && !isLoading;

  double get _height => switch (size) {
        AppButtonSize.large => 54,
        AppButtonSize.medium => 46,
        AppButtonSize.small => 38,
      };

  double get _horizontalPadding => switch (size) {
        AppButtonSize.large => AppSpacing.xxl,
        AppButtonSize.medium => AppSpacing.xl,
        AppButtonSize.small => AppSpacing.lg,
      };

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    final (Color background, Color foreground, Color? border) = switch (variant) {
      AppButtonVariant.primary => (colors.primary, colors.onPrimary, null),
      AppButtonVariant.secondary => (colors.surface, colors.ink, colors.borderStrong),
      AppButtonVariant.ghost => (Colors.transparent, colors.ink, null),
      AppButtonVariant.danger => (colors.dangerSoft, colors.danger, null),
    };

    final double opacity = _enabled ? 1 : 0.4;
    final TextStyle textStyle =
        (size == AppButtonSize.small ? type.label : type.button).copyWith(color: foreground);

    final Widget content = isLoading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: size == AppButtonSize.small ? 16 : 18, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (trailingIcon != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Icon(trailingIcon, size: size == AppButtonSize.small ? 16 : 18, color: foreground),
              ],
            ],
          );

    return PressEffect(
      onTap: _enabled ? onPressed : null,
      enabled: _enabled,
      scale: 0.975,
      child: Opacity(
        opacity: opacity,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: _height,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadii.pillAll,
            border: border == null ? null : Border.all(color: border, width: 1),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// A round icon button — back arrows, overflow menus, the send key.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 42,
    this.iconSize = 20,
    this.background,
    this.foreground,
    this.bordered = true,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;
  final bool bordered;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Widget button = PressEffect(
      onTap: onPressed,
      scale: 0.9,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: background ?? colors.surface,
          shape: BoxShape.circle,
          border: bordered ? Border.all(color: colors.border) : null,
        ),
        child: Icon(icon, size: iconSize, color: foreground ?? colors.ink),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
