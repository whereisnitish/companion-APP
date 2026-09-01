import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/app_notification.dart';
import '../../models/enums.dart';
import '../../providers/core_providers.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/entrance.dart';
import '../../widgets/press_effect.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/state_views.dart';

/// Notifications persist server-side, so this list is the record — the push
/// layer (APNs/FCM) is a delivery detail that can be added without changing
/// anything here.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, AppNotification notification) {
    if (notification.isUnread) {
      ref.read(notificationServiceProvider).markRead(notification.id);
      ref.invalidate(notificationsProvider);
    }

    final Object? conversationId = notification.data['conversationId'];
    if (conversationId is String) {
      context.push(Routes.chat(conversationId));
      return;
    }
    if (notification.type == AppNotificationType.invitationReceived ||
        notification.type == AppNotificationType.invitationAccepted ||
        notification.type == AppNotificationType.invitationDeclined) {
      context.go(Routes.invites);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final AsyncValue<NotificationPage> page = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: AppIconButton(
            icon: Icons.arrow_back_rounded,
            bordered: false,
            background: Colors.transparent,
            onPressed: () => context.pop(),
          ),
        ),
        leadingWidth: 60,
        title: const Text('Notifications'),
        actions: <Widget>[
          if (page.valueOrNull != null && page.value!.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: AppButton.ghost(
                label: 'Mark all read',
                size: AppButtonSize.small,
                onPressed: () async {
                  await ref.read(notificationServiceProvider).markAllRead();
                  ref.invalidate(notificationsProvider);
                },
              ),
            ),
        ],
      ),
      body: page.when(
        loading: () => Shimmer(
          child: ListView.builder(
            itemCount: 6,
            itemBuilder: (_, __) => const ListRowSkeleton(leadingSize: 40),
          ),
        ),
        error: (Object error, _) => StateView.fromError(
          error,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (NotificationPage data) {
          if (data.items.isEmpty) {
            return const StateView.empty(
              icon: Icons.notifications_none_rounded,
              title: 'Nothing yet',
              message: 'Invitations, replies and reminders show up here so nothing slips past you.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            color: colors.primary,
            backgroundColor: colors.surface,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.only(bottom: AppSpacing.giant),
              itemCount: data.items.length,
              separatorBuilder: (BuildContext context, int index) => Padding(
                padding: const EdgeInsets.only(left: 72, right: AppSpacing.screenX),
                child: Divider(color: colors.border, height: 1),
              ),
              itemBuilder: (BuildContext context, int index) {
                final AppNotification notification = data.items[index];
                return Entrance(
                  index: index,
                  child: PressEffect(
                    onTap: () => _open(context, ref, notification),
                    scale: 0.99,
                    child: Container(
                      color: notification.isUnread
                          ? colors.primarySoft.withValues(alpha: 0.35)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenX,
                        vertical: AppSpacing.lg,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              color: notification.isUnread ? colors.primary : colors.surfaceSunken,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              notification.type.icon,
                              size: 17,
                              color: notification.isUnread ? colors.onPrimary : colors.inkMuted,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        notification.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: notification.isUnread ? type.bodyStrong : type.body,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      Format.relative(notification.createdAt),
                                      style: type.caption.copyWith(color: colors.inkFaint),
                                    ),
                                  ],
                                ),
                                if (notification.body.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    notification.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: type.bodySmall
                                        .copyWith(color: colors.inkMuted, height: 1.4),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
