import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Bottom sheets are the product's second surface — filters, pickers,
/// confirmations. They all share this chrome: a grab handle, an optional title
/// row, and content that scrolls without the sheet losing its rounded top.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.screenX,
      0,
      AppSpacing.screenX,
      AppSpacing.xl,
    ),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  /// Presents [builder] as a modal sheet with the product's motion and scrim.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    final AppColors colors = context.colors;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: colors.overlay,
      useSafeArea: true,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 4,
              width: 36,
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: AppRadii.pillAll,
              ),
            ),
            if (title != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(title!, style: type.title),
                          if (subtitle != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              subtitle!,
                              style: type.bodySmall.copyWith(color: colors.inkMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Flexible(child: Padding(padding: padding, child: child)),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenX,
                  AppSpacing.lg,
                  AppSpacing.screenX,
                  AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// A destructive-or-not confirmation. Returns true when the user commits.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  IconData icon = Icons.help_outline_rounded,
}) async {
  final bool? result = await AppSheet.show<bool>(
    context,
    builder: (BuildContext sheetContext) {
      final AppColors colors = sheetContext.colors;
      return AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: isDestructive ? colors.dangerSoft : colors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? colors.danger : colors.ink,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(title, style: sheetContext.type.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: sheetContext.type.body.copyWith(color: colors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: confirmLabel,
              variant: isDestructive ? AppButtonVariant.danger : AppButtonVariant.primary,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.ghost(
              label: cancelLabel,
              expand: true,
              size: AppButtonSize.large,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
