import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum SnackTone { neutral, success, danger }

/// One-line feedback. Floating, inked, and short — anything that needs more
/// than a sentence belongs in a sheet, not here.
abstract final class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    SnackTone tone = SnackTone.neutral,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    final (Color background, Color foreground, IconData defaultIcon) = switch (tone) {
      SnackTone.neutral => (colors.ink, colors.inkInverse, Icons.info_outline_rounded),
      SnackTone.success => (colors.success, Colors.white, Icons.check_rounded),
      SnackTone.danger => (colors.danger, Colors.white, Icons.error_outline_rounded),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(icon ?? defaultIcon, size: 18, color: foreground),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(message, style: type.bodySmall.copyWith(color: foreground)),
              ),
            ],
          ),
          backgroundColor: background,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, tone: SnackTone.success);

  static void error(BuildContext context, String message) =>
      show(context, message, tone: SnackTone.danger);
}
