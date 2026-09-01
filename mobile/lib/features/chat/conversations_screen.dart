import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/conversation.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/entrance.dart';
import '../../widgets/press_effect.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/state_views.dart';

/// The inbox.
///
/// Every thread here exists because an invitation was accepted, so each row
/// carries the plan it came from. That context is the difference between a
/// message list and a pile of strangers.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final AsyncValue<List<Conversation>> conversations = ref.watch(conversationsProvider);
    final int unread = ref.watch(unreadMessagesProvider);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenX,
                AppSpacing.lg,
                AppSpacing.screenX,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Messages', style: type.headline),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    unread == 0
                        ? 'All caught up.'
                        : '$unread unread ${unread == 1 ? 'message' : 'messages'}.',
                    style: type.bodySmall.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: conversations.when(
                loading: () => Shimmer(
                  child: ListView.builder(
                    itemCount: 6,
                    itemBuilder: (_, __) => const ListRowSkeleton(leadingSize: 52),
                  ),
                ),
                error: (Object error, _) => ListView(
                  children: <Widget>[
                    const SizedBox(height: 40),
                    StateView.fromError(
                      error,
                      onRetry: () => ref.invalidate(conversationsProvider),
                    ),
                  ],
                ),
                data: (List<Conversation> items) {
                  if (items.isEmpty) {
                    return ListView(
                      children: <Widget>[
                        const SizedBox(height: 30),
                        StateView.empty(
                          icon: Icons.forum_outlined,
                          title: 'No conversations yet',
                          message:
                              'A chat opens the moment an invitation is accepted — with the plan already in it.',
                          actionLabel: 'Find someone',
                          onAction: () => context.go(Routes.discover),
                        ),
                      ],
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(conversationsProvider),
                    color: colors.primary,
                    backgroundColor: colors.surface,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.only(bottom: AppSpacing.giant),
                      itemCount: items.length,
                      separatorBuilder: (BuildContext context, int index) => Padding(
                        padding: const EdgeInsets.only(left: 84, right: AppSpacing.screenX),
                        child: Divider(color: colors.border, height: 1),
                      ),
                      itemBuilder: (BuildContext context, int index) => Entrance(
                        index: index,
                        child: _ConversationRow(conversation: items[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final bool hasUnread = conversation.unreadCount > 0;

    return PressEffect(
      onTap: () => context.push(Routes.chat(conversation.id)),
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenX,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppAvatar(
              name: conversation.participant.displayName,
              imageUrl: conversation.participant.avatarUrl,
              size: 52,
              isOnline: conversation.participant.isOnline,
              showPresence: true,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          conversation.participant.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hasUnread ? type.bodyStrong : type.body,
                        ),
                      ),
                      if (conversation.participant.verification.isVerified) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs + 2),
                        VerifiedBadge(
                          size: 13,
                          status: conversation.participant.verification,
                        ),
                      ],
                      const Spacer(),
                      Text(
                        Format.relative(conversation.lastMessageAt),
                        style: type.caption.copyWith(
                          color: hasUnread ? colors.accent : colors.inkFaint,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  if (conversation.activity != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs + 2),
                    Row(
                      children: <Widget>[
                        Icon(
                          conversation.activity!.category.icon,
                          size: 12,
                          color: conversation.activity!.category.foreground(context),
                        ),
                        const SizedBox(width: AppSpacing.xs + 1),
                        Flexible(
                          child: Text(
                            '${conversation.activity!.title} · ${Format.whenShort(conversation.activity!.startsAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.caption.copyWith(
                              color: conversation.activity!.category.foreground(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs + 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          conversation.lastMessagePreview.isEmpty
                              ? 'Say hello'
                              : conversation.lastMessagePreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: type.bodySmall.copyWith(
                            color: hasUnread ? colors.ink : colors.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (hasUnread) ...<Widget>[
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: AppRadii.pillAll,
                          ),
                          child: Text(
                            conversation.unreadCount > 9 ? '9+' : '${conversation.unreadCount}',
                            style: type.caption.copyWith(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
