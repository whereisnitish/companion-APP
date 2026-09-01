import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../providers/core_providers.dart';
import '../../providers/feed_providers.dart';
import '../../services/safety_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/state_views.dart';
import 'settings_widgets.dart';

final FutureProvider<List<BlockedUser>> _blockedUsersProvider = FutureProvider<List<BlockedUser>>(
  (Ref ref) => ref.watch(safetyServiceProvider).listBlocked(),
);

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(BuildContext context, WidgetRef ref, BlockedUser user) async {
    final bool confirmed = await showConfirmSheet(
      context,
      title: 'Unblock ${user.displayName}?',
      message: 'They will be able to see you in discovery again and send you invitations. '
          'They are not told anything.',
      confirmLabel: 'Unblock',
      icon: Icons.lock_open_rounded,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(safetyServiceProvider).unblock(user.id);
      ref.invalidate(_blockedUsersProvider);
      ref.invalidate(discoverPeopleProvider);
      if (context.mounted) {
        AppSnackbar.show(context, '${user.displayName} has been unblocked.');
      }
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final AsyncValue<List<BlockedUser>> blocked = ref.watch(_blockedUsersProvider);

    return SettingsScaffold(
      title: 'Blocked people',
      subtitle: 'Blocking is silent and reversible. Nobody is ever told.',
      children: <Widget>[
        blocked.when(
          loading: () => const Shimmer(
            child: Column(
              children: <Widget>[
                ListRowSkeleton(leadingSize: 44),
                ListRowSkeleton(leadingSize: 44),
              ],
            ),
          ),
          error: (Object error, _) => StateView.fromError(
            error,
            onRetry: () => ref.invalidate(_blockedUsersProvider),
          ),
          data: (List<BlockedUser> users) {
            if (users.isEmpty) {
              return const StateView.empty(
                icon: Icons.block_rounded,
                title: 'Nobody blocked',
                message: 'When you block someone they disappear from your app entirely.',
                compact: true,
              );
            }

            return Column(
              children: <Widget>[
                for (final BlockedUser user in users)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: AppSpacing.screenPadding,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: AppRadii.mdAll,
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: <Widget>[
                            AppAvatar(
                              name: user.displayName,
                              imageUrl: user.avatarUrl,
                              size: 42,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(user.displayName, style: type.body),
                            ),
                            AppButton.secondary(
                              label: 'Unblock',
                              size: AppButtonSize.small,
                              expand: false,
                              onPressed: () => _unblock(context, ref, user),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
