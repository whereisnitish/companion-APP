import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../providers/core_providers.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../services/safety_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/press_effect.dart';

/// The safety menu behind every "…" on a person.
///
/// Kept one tap from anywhere someone appears — a profile, a chat, an
/// invitation — because a safety control that is hard to find is not one.
Future<void> showSafetyActionsSheet(
  BuildContext context, {
  required String userId,
  required String displayName,
}) {
  return AppSheet.show<void>(
    context,
    builder: (BuildContext sheetContext) => _SafetyActionsSheet(
      userId: userId,
      displayName: displayName,
    ),
  );
}

class _SafetyActionsSheet extends ConsumerWidget {
  const _SafetyActionsSheet({required this.userId, required this.displayName});

  final String userId;
  final String displayName;

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await showConfirmSheet(
      context,
      title: 'Block $displayName?',
      message:
          'They will not see you in discovery, cannot invite or message you, and any pending invitations between you are withdrawn. They are not told.',
      confirmLabel: 'Block $displayName',
      isDestructive: true,
      icon: Icons.block_rounded,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(safetyServiceProvider).block(userId);
      invalidateSocialGraphFrom(ref);
      ref.invalidate(discoverPeopleProvider);
      ref.invalidate(discoverActivitiesProvider);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.success(context, '$displayName has been blocked.');
      // Their profile no longer exists for us; step back to somewhere real.
      if (context.canPop()) context.pop();
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    await AppSheet.show<void>(
      context,
      builder: (_) => _ReportSheet(userId: userId, displayName: displayName),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return AppSheet(
      title: displayName,
      subtitle: 'Your safety comes before anyone’s feelings.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ActionRow(
            icon: Icons.flag_outlined,
            label: 'Report $displayName',
            description: 'Tell our team something is wrong here.',
            onTap: () => _report(context, ref),
          ),
          Divider(color: colors.border, height: AppSpacing.xxl),
          _ActionRow(
            icon: Icons.block_rounded,
            label: 'Block $displayName',
            description: 'Remove them from your app entirely.',
            tone: colors.danger,
            onTap: () => _block(context, ref),
          ),
          Divider(color: colors.border, height: AppSpacing.xxl),
          _ActionRow(
            icon: Icons.menu_book_outlined,
            label: 'Safety tips',
            description: 'How to meet someone new sensibly.',
            onTap: () {
              Navigator.of(context).pop();
              context.push(Routes.safety);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Reports are confidential. Blocking is silent — nobody is told.',
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: colors.inkFaint, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final Color foreground = tone ?? colors.ink;

    return PressEffect(
      onTap: onTap,
      scale: 0.99,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: type.bodyStrong.copyWith(color: foreground)),
                const SizedBox(height: 1),
                Text(
                  description,
                  style: type.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: colors.inkFaint),
        ],
      ),
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.userId, required this.displayName});

  final String userId;
  final String displayName;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final TextEditingController _details = TextEditingController();
  ReportReason? _reason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ReportReason? reason = _reason;
    if (reason == null) return;

    setState(() => _isSubmitting = true);
    try {
      final String message =
          await ref.read(safetyServiceProvider).report(widget.userId, reason, _details.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.show(context, message, icon: Icons.shield_outlined);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return AppSheet(
      title: 'Report ${widget.displayName}',
      subtitle: 'What happened? This goes straight to our safety team.',
      footer: AppButton(
        label: 'Submit report',
        variant: AppButtonVariant.danger,
        isLoading: _isSubmitting,
        onPressed: _reason == null ? null : _submit,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final ReportReason reason in ReportReason.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PressEffect(
                  onTap: () => setState(() => _reason = reason),
                  scale: 0.99,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md + 2,
                    ),
                    decoration: BoxDecoration(
                      color: _reason == reason ? colors.dangerSoft : colors.surface,
                      borderRadius: AppRadii.mdAll,
                      border: Border.all(
                        color: _reason == reason ? colors.danger : colors.border,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(reason.label, style: context.type.body),
                        ),
                        AnimatedScale(
                          duration: AppMotion.fast,
                          scale: _reason == reason ? 1 : 0,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: colors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _details,
              label: 'Anything else? (optional)',
              hint: 'Details help us act faster.',
              maxLines: 4,
              minLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
