import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/invitation.dart';
import '../../providers/core_providers.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/entrance.dart';
import '../../widgets/press_effect.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/state_views.dart';
import '../../widgets/success_burst.dart';

/// Received and sent, in that order — what people came here to answer sits
/// first, and the pending ones float to the top of each list.
class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final InvitationCounts counts = ref.watch(invitationCountsProvider).maybeWhen(
          data: (InvitationCounts value) => value,
          orElse: () => InvitationCounts.empty,
        );

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
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
                  Text('Invitations', style: type.headline),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    counts.pendingReceived == 0
                        ? 'Nothing waiting on you right now.'
                        : '${counts.pendingReceived} waiting on your answer.',
                    style: type.bodySmall.copyWith(color: colors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Tabs(
                    controller: _tabs,
                    receivedBadge: counts.pendingReceived,
                    sentBadge: counts.pendingSent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const <Widget>[
                  _InvitationList(direction: InvitationDirection.received),
                  _InvitationList(direction: InvitationDirection.sent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.controller,
    required this.receivedBadge,
    required this.sentBadge,
  });

  final TabController controller;
  final int receivedBadge;
  final int sentBadge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    Widget label(String text, int badge) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (badge > 0) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: AppRadii.pillAll,
                ),
                child: Text(
                  '$badge',
                  style: type.caption.copyWith(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ],
        );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: AppRadii.pillAll,
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.pillAll,
          border: Border.all(color: colors.border),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: colors.ink,
        unselectedLabelColor: colors.inkFaint,
        labelStyle: type.label,
        unselectedLabelStyle: type.label,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        padding: EdgeInsets.zero,
        tabs: <Widget>[
          Tab(height: 38, child: label('Received', receivedBadge)),
          Tab(height: 38, child: label('Sent', sentBadge)),
        ],
      ),
    );
  }
}

class _InvitationList extends ConsumerWidget {
  const _InvitationList({required this.direction});

  final InvitationDirection direction;

  bool get _isReceived => direction == InvitationDirection.received;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Invitation>> invitations =
        ref.watch(_isReceived ? receivedInvitationsProvider : sentInvitationsProvider);

    return invitations.when(
      loading: () => Shimmer(
        child: ListView.builder(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          itemCount: 4,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
              child: SkeletonBox(height: 148, radius: AppRadii.lg),
            ),
          ),
        ),
      ),
      error: (Object error, _) => ListView(
        children: <Widget>[
          const SizedBox(height: 40),
          StateView.fromError(
            error,
            onRetry: () => ref.invalidate(
              _isReceived ? receivedInvitationsProvider : sentInvitationsProvider,
            ),
          ),
        ],
      ),
      data: (List<Invitation> items) {
        if (items.isEmpty) {
          return ListView(
            children: <Widget>[
              const SizedBox(height: 30),
              StateView.empty(
                icon: _isReceived ? Icons.mark_email_unread_outlined : Icons.send_outlined,
                title: _isReceived ? 'No invitations yet' : 'You have not invited anyone',
                message: _isReceived
                    ? 'When someone asks you to join them, it lands here. Posting a plan is the fastest way to get one.'
                    : 'Find someone who is up for the same thing and send the first invitation.',
                actionLabel: _isReceived ? 'Post a plan' : 'Discover people',
                onAction: () => context.go(_isReceived ? Routes.home : Routes.discover),
              ),
            ],
          );
        }

        // Pending first — everything else is history.
        final List<Invitation> pending =
            items.where((Invitation i) => i.status.isOpen).toList(growable: false);
        final List<Invitation> settled =
            items.where((Invitation i) => !i.status.isOpen).toList(growable: false);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_isReceived ? receivedInvitationsProvider : sentInvitationsProvider);
            ref.invalidate(invitationCountsProvider);
          },
          color: context.colors.primary,
          backgroundColor: context.colors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenX,
              AppSpacing.sm,
              AppSpacing.screenX,
              AppSpacing.giant,
            ),
            children: <Widget>[
              for (int index = 0; index < pending.length; index += 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Entrance(
                    index: index,
                    child: InvitationCard(invitation: pending[index]),
                  ),
                ),
              if (settled.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.xl,
                    0,
                    AppSpacing.md,
                  ),
                  child: Text(
                    'EARLIER',
                    style: context.type.overline.copyWith(color: context.colors.inkFaint),
                  ),
                ),
                for (int index = 0; index < settled.length; index += 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: InvitationCard(invitation: settled[index]),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// One invitation, with its answer built in.
///
/// Accept and Decline live on the card itself: making someone open a detail
/// screen to say yes is the surest way to lose the yes.
class InvitationCard extends ConsumerStatefulWidget {
  const InvitationCard({super.key, required this.invitation});

  final Invitation invitation;

  @override
  ConsumerState<InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<InvitationCard> {
  bool _isBusy = false;

  Invitation get invitation => widget.invitation;

  Future<void> _accept() async {
    setState(() => _isBusy = true);
    try {
      final Invitation updated = await ref.read(invitationServiceProvider).accept(invitation.id);
      if (!mounted) return;
      invalidateSocialGraphFrom(ref);

      final String? conversationId = updated.conversationId;
      await AppSheet.show<void>(
        context,
        isDismissible: false,
        builder: (_) => _ConnectedSheet(
          invitation: updated,
          onOpenChat: conversationId == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  context.push(Routes.chat(conversationId));
                },
        ),
      );
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _decline() async {
    final bool confirmed = await showConfirmSheet(
      context,
      title: 'Decline this invitation?',
      message:
          '${invitation.counterpart.firstName} is told you are not free for this one. Nothing else is shared.',
      confirmLabel: 'Decline',
      cancelLabel: 'Not yet',
      icon: Icons.do_not_disturb_alt_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref.read(invitationServiceProvider).decline(invitation.id);
      if (!mounted) return;
      invalidateSocialGraphFrom(ref);
      AppSnackbar.show(context, 'Invitation declined.');
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _withdraw() async {
    final bool confirmed = await showConfirmSheet(
      context,
      title: 'Withdraw this invitation?',
      message: 'It disappears from ${invitation.counterpart.firstName}’s list.',
      confirmLabel: 'Withdraw',
      isDestructive: true,
      icon: Icons.undo_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref.read(invitationServiceProvider).cancel(invitation.id);
      if (!mounted) return;
      invalidateSocialGraphFrom(ref);
      AppSnackbar.show(context, 'Invitation withdrawn.');
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final ActivityCategory category = invitation.resolvedCategory;
    final bool isPending = invitation.status.isOpen;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.lgAll,
        border: Border.all(
          color: isPending && invitation.isReceived
              ? colors.accent.withValues(alpha: 0.35)
              : colors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    PressEffect(
                      onTap: () => context.push(Routes.person(invitation.counterpart.id)),
                      scale: 0.94,
                      child: AppAvatar(
                        name: invitation.counterpart.displayName,
                        imageUrl: invitation.counterpart.avatarUrl,
                        size: 44,
                        isOnline: invitation.counterpart.isOnline,
                        showPresence: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  invitation.counterpart.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.bodyStrong,
                                ),
                              ),
                              if (invitation.counterpart.verification.isVerified) ...<Widget>[
                                const SizedBox(width: AppSpacing.xs + 2),
                                VerifiedBadge(
                                  size: 14,
                                  status: invitation.counterpart.verification,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${invitation.isReceived ? 'Invited you' : 'You invited them'} · ${Format.relative(invitation.createdAt)}',
                            style: type.caption.copyWith(color: colors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    if (!isPending) StatusPill(status: invitation.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: category.tint(context),
                    borderRadius: AppRadii.mdAll,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(category.icon, size: 17, color: category.foreground(context)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              invitation.headline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: type.label.copyWith(color: colors.ink),
                            ),
                            if (invitation.proposedAt != null ||
                                invitation.locationName != null) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                <String>[
                                  if (invitation.proposedAt != null)
                                    Format.whenLabel(invitation.proposedAt!),
                                  if (invitation.locationName != null) invitation.locationName!,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.caption.copyWith(color: colors.inkMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (invitation.activity != null)
                        PressEffect(
                          onTap: () => context.push(Routes.activity(invitation.activity!.id)),
                          scale: 0.9,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: category.foreground(context),
                          ),
                        ),
                    ],
                  ),
                ),
                if (invitation.message.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '“${invitation.message}”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: type.body.copyWith(color: colors.inkMuted, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          if (isPending && invitation.isReceived)
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Decline',
                      size: AppButtonSize.medium,
                      onPressed: _isBusy ? null : _decline,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Accept',
                      size: AppButtonSize.medium,
                      icon: Icons.check_rounded,
                      isLoading: _isBusy,
                      onPressed: _isBusy ? null : _accept,
                    ),
                  ),
                ],
              ),
            )
          else if (isPending && !invitation.isReceived)
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.schedule_rounded, size: 15, color: colors.inkFaint),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Waiting on ${invitation.counterpart.firstName}',
                      style: type.caption.copyWith(color: colors.inkMuted),
                    ),
                  ),
                  AppButton.ghost(
                    label: 'Withdraw',
                    size: AppButtonSize.small,
                    onPressed: _isBusy ? null : _withdraw,
                  ),
                ],
              ),
            )
          else if (invitation.status == InvitationStatus.accepted &&
              invitation.conversationId != null)
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, size: 15, color: colors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'You are connected',
                      style: type.caption.copyWith(color: colors.inkMuted),
                    ),
                  ),
                  AppButton(
                    label: 'Open chat',
                    size: AppButtonSize.small,
                    expand: false,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.push(Routes.chat(invitation.conversationId!)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The payoff moment. Both faces, the plan, and one obvious next step.
class _ConnectedSheet extends StatelessWidget {
  const _ConnectedSheet({required this.invitation, this.onOpenChat});

  final Invitation invitation;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          SuccessBurst(size: 88, color: colors.success),
          const SizedBox(height: AppSpacing.xxl),
          Text('You’re connected', style: type.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You and ${invitation.counterpart.firstName} are in for ${invitation.headline.toLowerCase()}. The chat is open — sort out the details.',
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: colors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AppAvatar(
                name: invitation.counterpart.displayName,
                imageUrl: invitation.counterpart.avatarUrl,
                size: 56,
                ring: colors.surface,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          if (onOpenChat != null)
            AppButton(
              label: 'Say hello',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: onOpenChat,
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton.ghost(
            label: 'Later',
            expand: true,
            size: AppButtonSize.large,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
