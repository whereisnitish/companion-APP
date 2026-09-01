import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../models/conversation.dart';
import '../../providers/chat_provider.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/press_effect.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/state_views.dart';
import '../settings/safety_actions.dart';

/// The conversation.
///
/// Two things make this feel different from a generic chat: the plan is pinned
/// to the top of the thread, so neither person forgets what they agreed to; and
/// the composer sits on its own surface with a send key that only appears when
/// there is something to send.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The list is reversed, so "near the end" means the oldest messages.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      ref.read(chatControllerProvider(widget.conversationId).notifier).loadMore();
    }
  }

  Future<void> _send() async {
    final String body = _composer.text.trim();
    if (body.isEmpty) return;
    _composer.clear();
    setState(() {});

    await ref.read(chatControllerProvider(widget.conversationId).notifier).send(body);
    if (!mounted) return;
    ref.invalidate(conversationsProvider);

    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: AppMotion.base, curve: AppMotion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final ChatState state = ref.watch(chatControllerProvider(widget.conversationId));
    final AsyncValue<Conversation> conversation =
        ref.watch(conversationByIdProvider(widget.conversationId));

    return Scaffold(
      backgroundColor: colors.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _ChatHeader(
              conversation: conversation.valueOrNull,
              isPeerTyping: state.isPeerTyping,
            ),
            if (conversation.valueOrNull?.activity != null)
              _ActivityBanner(activity: conversation.valueOrNull!.activity!),
            Expanded(
              child: _MessageList(
                state: state,
                scrollController: _scroll,
                onRetry: (Message message) =>
                    ref.read(chatControllerProvider(widget.conversationId).notifier).retry(message),
                onReload: () =>
                    ref.read(chatControllerProvider(widget.conversationId).notifier).load(),
              ),
            ),
            _Composer(
              controller: _composer,
              focusNode: _focus,
              onChanged: (String value) {
                ref
                    .read(chatControllerProvider(widget.conversationId).notifier)
                    .onComposerChanged(value);
                setState(() {});
              },
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.conversation, required this.isPeerTyping});

  final Conversation? conversation;
  final bool isPeerTyping;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: <Widget>[
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            bordered: false,
            background: Colors.transparent,
            onPressed: () => context.pop(),
          ),
          if (conversation == null)
            const Expanded(
              child: Shimmer(
                child: Row(
                  children: <Widget>[
                    SkeletonBox.circle(size: 38),
                    SizedBox(width: AppSpacing.md),
                    SkeletonBox(width: 120, height: 14),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: PressEffect(
                onTap: () => context.push(Routes.person(conversation!.participant.id)),
                scale: 0.98,
                child: Row(
                  children: <Widget>[
                    AppAvatar(
                      name: conversation!.participant.displayName,
                      imageUrl: conversation!.participant.avatarUrl,
                      size: 38,
                      isOnline: conversation!.participant.isOnline,
                      showPresence: true,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            conversation!.participant.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.subtitle,
                          ),
                          AnimatedSwitcher(
                            duration: AppMotion.fast,
                            child: isPeerTyping
                                ? Text(
                                    'typing…',
                                    key: const ValueKey<String>('typing'),
                                    style: type.caption.copyWith(color: colors.primary),
                                  )
                                : Text(
                                    Format.lastSeen(
                                      conversation!.participant.lastActiveAt,
                                      isOnline: conversation!.participant.isOnline,
                                    ),
                                    key: const ValueKey<String>('presence'),
                                    style: type.caption.copyWith(color: colors.inkMuted),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (conversation != null)
            AppIconButton(
              icon: Icons.more_horiz_rounded,
              bordered: false,
              background: Colors.transparent,
              onPressed: () => showSafetyActionsSheet(
                context,
                userId: conversation!.participant.id,
                displayName: conversation!.participant.displayName,
              ),
            ),
        ],
      ),
    );
  }
}

/// The plan, pinned. Tapping it opens the activity so the details are never
/// more than one hop away mid-conversation.
class _ActivityBanner extends StatelessWidget {
  const _ActivityBanner({required this.activity});

  final ActivityContext activity;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return PressEffect(
      onTap: () => context.push(Routes.activity(activity.id)),
      scale: 0.995,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenX,
          vertical: AppSpacing.md,
        ),
        color: activity.category.tint(context),
        child: Row(
          children: <Widget>[
            Icon(activity.category.icon, size: 16, color: activity.category.foreground(context)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '${activity.title} · ${Format.whenShort(activity.startsAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.caption.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: activity.category.foreground(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.scrollController,
    required this.onRetry,
    required this.onReload,
  });

  final ChatState state;
  final ScrollController scrollController;
  final ValueChanged<Message> onRetry;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return Shimmer(
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(AppSpacing.screenX),
          itemCount: 6,
          itemBuilder: (BuildContext context, int index) => Align(
            alignment: index.isEven ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SkeletonBox(
                width: index.isEven ? 200 : 150,
                height: 40,
                radius: AppRadii.lg,
              ),
            ),
          ),
        ),
      );
    }

    if (state.error != null && state.messages.isEmpty) {
      return StateView.fromError(state.error!, onRetry: onReload);
    }

    if (state.messages.isEmpty) {
      return const StateView.empty(
        icon: Icons.waving_hand_outlined,
        title: 'Say the first thing',
        message: 'You matched on a plan — the hard part is done. Ask about the details.',
      );
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenX,
        AppSpacing.lg,
        AppSpacing.screenX,
        AppSpacing.lg,
      ),
      itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= state.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final Message message = state.messages[index];
        // The list is reversed, so "next" is the older message.
        final Message? older = index + 1 < state.messages.length ? state.messages[index + 1] : null;
        final Message? newer = index > 0 ? state.messages[index - 1] : null;

        final bool showDayDivider = older == null || !_sameDay(older.createdAt, message.createdAt);
        final bool isLastOfGroup =
            newer == null || newer.isMine != message.isMine || newer.isSystem;

        return Column(
          children: <Widget>[
            if (showDayDivider) _DayDivider(when: message.createdAt),
            _MessageBubble(
              message: message,
              isLastOfGroup: isLastOfGroup,
              onRetry: () => onRetry(message),
            ),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.when});

  final DateTime when;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: colors.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              Format.messageDay(when),
              style: context.type.caption.copyWith(color: colors.inkFaint),
            ),
          ),
          Expanded(child: Divider(color: colors.border, height: 1)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isLastOfGroup,
    required this.onRetry,
  });

  final Message message;
  final bool isLastOfGroup;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: AppRadii.pillAll,
            ),
            child: Text(
              message.body,
              textAlign: TextAlign.center,
              style: type.caption.copyWith(color: colors.inkMuted),
            ),
          ),
        ),
      );
    }

    final bool isMine = message.isMine;
    final Color background = isMine ? colors.primary : colors.surface;
    final Color foreground = isMine ? colors.onPrimary : colors.ink;

    return Padding(
      padding: EdgeInsets.only(bottom: isLastOfGroup ? AppSpacing.md : AppSpacing.xs + 1),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: <Widget>[
              if (message.hasFailed) ...<Widget>[
                PressEffect(
                  onTap: onRetry,
                  scale: 0.9,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: colors.danger,
                    ),
                  ),
                ),
              ],
              Flexible(
                child: AnimatedOpacity(
                  duration: AppMotion.fast,
                  opacity: message.isPending ? 0.62 : 1,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.74,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      border: isMine ? null : Border.all(color: colors.border),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(AppRadii.lg),
                        topRight: const Radius.circular(AppRadii.lg),
                        bottomLeft: Radius.circular(isMine ? AppRadii.lg : AppRadii.xs),
                        bottomRight: Radius.circular(isMine ? AppRadii.xs : AppRadii.lg),
                      ),
                    ),
                    child: Text(
                      message.body,
                      style: type.body.copyWith(color: foreground, height: 1.45),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isLastOfGroup) ...<Widget>[
            const SizedBox(height: AppSpacing.xs + 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    message.hasFailed ? 'Not sent — tap to retry' : Format.time(message.createdAt),
                    style: type.caption.copyWith(
                      color: message.hasFailed ? colors.danger : colors.inkFaint,
                      fontSize: 11,
                    ),
                  ),
                  if (isMine && !message.hasFailed) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs + 1),
                    Icon(
                      message.isPending
                          ? Icons.schedule_rounded
                          : message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                      size: 13,
                      color: message.isRead ? colors.primary : colors.inkFaint,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final bool canSend = controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom > 0
            ? AppSpacing.md
            : MediaQuery.paddingOf(context).bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 132),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: AppRadii.xlAll,
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                cursorColor: colors.primary,
                cursorWidth: 1.6,
                style: type.body,
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  border: InputBorder.none,
                  hintText: 'Message',
                  hintStyle: type.body.copyWith(color: colors.inkFaint),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AnimatedScale(
            duration: AppMotion.fast,
            curve: AppMotion.spring,
            scale: canSend ? 1 : 0.82,
            child: AnimatedOpacity(
              duration: AppMotion.fast,
              opacity: canSend ? 1 : 0.4,
              child: AppIconButton(
                icon: Icons.arrow_upward_rounded,
                size: 44,
                iconSize: 19,
                background: colors.primary,
                foreground: colors.onPrimary,
                bordered: false,
                onPressed: canSend ? onSend : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
