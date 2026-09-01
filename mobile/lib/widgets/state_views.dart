import 'package:flutter/material.dart';

import '../core/network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Nothing here is ever a blank screen.
///
/// Empty, error and offline states all get the same treatment: a quiet mark, a
/// sentence that says what happened in plain words, and exactly one way forward.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.tone = StateTone.neutral,
  });

  /// Nothing to show yet — not a failure.
  const StateView.empty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  }) : tone = StateTone.neutral;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final StateTone tone;

  /// Turns any thrown object into a state a person can act on.
  factory StateView.fromError(Object error, {VoidCallback? onRetry}) {
    if (error is ApiException) {
      if (error.isNetworkError) {
        return StateView(
          icon: Icons.wifi_off_rounded,
          title: 'No connection',
          message: 'We could not reach Companion. Check your network and try again.',
          actionLabel: onRetry == null ? null : 'Try again',
          onAction: onRetry,
          tone: StateTone.warning,
        );
      }
      return StateView(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        message: error.message,
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
        tone: StateTone.danger,
      );
    }

    return StateView(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      message: 'An unexpected error occurred. Please try again.',
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
      tone: StateTone.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    final (Color tint, Color mark) = switch (tone) {
      StateTone.neutral => (colors.surfaceSunken, colors.inkMuted),
      StateTone.warning => (colors.accentSoft, colors.accent),
      StateTone.danger => (colors.dangerSoft, colors.danger),
    };

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: compact ? AppSpacing.xxl : AppSpacing.giant,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: compact ? 52 : 64,
              width: compact ? 52 : 64,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: compact ? 24 : 28, color: mark),
            ),
            SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
            Text(title, style: type.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: type.body.copyWith(color: colors.inkMuted),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxl),
              AppButton.secondary(
                label: actionLabel!,
                onPressed: onAction,
                size: AppButtonSize.medium,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum StateTone { neutral, warning, danger }

/// A slim inline error for the top of a list that already has content.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.dangerSoft,
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 18, color: colors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: context.type.bodySmall.copyWith(color: colors.danger),
            ),
          ),
          if (onRetry != null)
            AppButton.ghost(
              label: 'Retry',
              onPressed: onRetry,
              size: AppButtonSize.small,
            ),
        ],
      ),
    );
  }
}
