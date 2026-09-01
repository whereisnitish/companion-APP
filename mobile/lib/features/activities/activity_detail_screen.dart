import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
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
import '../invitations/invite_sheet.dart';

/// One plan, in full.
///
/// The header is coloured by the category so the screen announces what kind of
/// evening this is before a word is read. Everything else answers the four
/// questions that decide a yes: when, where, who with, and who they want.
class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<Activity> activity = ref.watch(activityByIdProvider(activityId));

    return Scaffold(
      backgroundColor: colors.canvas,
      body: activity.when(
        loading: () => const _DetailSkeleton(),
        error: (Object error, _) => SafeArea(
          child: Column(
            children: <Widget>[
              _FloatingBack(onBack: () => context.pop()),
              Expanded(
                child: StateView.fromError(
                  error,
                  onRetry: () => ref.invalidate(activityByIdProvider(activityId)),
                ),
              ),
            ],
          ),
        ),
        data: (Activity data) => _DetailBody(activity: data),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.activity});

  final Activity activity;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await showConfirmSheet(
      context,
      title: 'Cancel this plan?',
      message:
          'Everyone you invited is told it is off, and any pending requests are withdrawn. This cannot be undone.',
      confirmLabel: 'Cancel the plan',
      cancelLabel: 'Keep it',
      isDestructive: true,
      icon: Icons.event_busy_rounded,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(activityServiceProvider).cancel(activity.id);
      ref.invalidate(activityByIdProvider(activity.id));
      ref.invalidate(myActivitiesProvider);
      invalidateSocialGraphFrom(ref);
      if (!context.mounted) return;
      AppSnackbar.show(context, 'Your plan has been cancelled.');
      context.pop();
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final Color hue = activity.category.foreground(context);

    return Stack(
      children: <Widget>[
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                color: activity.category.tint(context),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenX,
                  MediaQuery.paddingOf(context).top + 70,
                  AppSpacing.screenX,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Entrance(
                      child: Row(
                        children: <Widget>[
                          CategoryBadge(category: activity.category, size: 38, radius: 12),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            activity.category.label.toUpperCase(),
                            style: type.overline.copyWith(color: hue),
                          ),
                          const Spacer(),
                          if (!activity.isOpen) _ActivityStatusPill(status: activity.status),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Entrance(index: 1, child: Text(activity.title, style: type.headline)),
                    const SizedBox(height: AppSpacing.lg),
                    Entrance(
                      index: 2,
                      child: Text(
                        Format.whenLabel(activity.startsAt),
                        style: type.subtitle.copyWith(color: hue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenX,
                  AppSpacing.xxl,
                  AppSpacing.screenX,
                  150,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Entrance(
                      index: 3,
                      child: _FactRow(
                        icon: Icons.place_outlined,
                        label: activity.locationName,
                        detail: <String>[
                          if (activity.area != null) activity.area!,
                          if (activity.distanceKm != null) Format.distance(activity.distanceKm),
                        ].join(' · '),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Entrance(
                      index: 4,
                      child: _FactRow(
                        icon: Icons.schedule_rounded,
                        label: Format.fullDate(activity.startsAt),
                        detail: activity.endsAt == null
                            ? 'Starts ${Format.time(activity.startsAt)}'
                            : '${Format.time(activity.startsAt)} – ${Format.time(activity.endsAt!)}',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Entrance(
                      index: 5,
                      child: _FactRow(
                        icon: Icons.people_alt_outlined,
                        label: activity.lookingFor.label == 'Anyone'
                            ? 'Open to anyone'
                            : 'Looking for ${activity.lookingFor.label.toLowerCase()}',
                        detail: '${activity.minAge}–${activity.maxAge} · '
                            '${activity.spotsLeft} ${activity.spotsLeft == 1 ? 'spot' : 'spots'} left',
                      ),
                    ),
                    if (activity.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxxl),
                      Entrance(
                        index: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'THE PLAN',
                              style: type.overline.copyWith(color: colors.inkFaint),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              activity.description,
                              style: type.body.copyWith(height: 1.65),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxxl),
                    Entrance(
                      index: 7,
                      child: Text(
                        activity.isHost ? 'YOUR PLAN' : 'HOSTED BY',
                        style: type.overline.copyWith(color: colors.inkFaint),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Entrance(index: 8, child: _HostCard(activity: activity)),
                    if (activity.isHost) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxxl),
                      Entrance(
                        index: 9,
                        child: Center(
                          child: AppButton.ghost(
                            label: 'Cancel this plan',
                            icon: Icons.event_busy_outlined,
                            size: AppButtonSize.small,
                            onPressed: activity.isOpen ? () => _cancel(context, ref) : null,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        _FloatingBack(onBack: () => context.pop(), floating: true),
        Positioned(left: 0, right: 0, bottom: 0, child: _ActionBar(activity: activity)),
      ],
    );
  }
}

/// Borrows the invitation pill's shape so a closed plan and a settled
/// invitation read the same way at a glance.
class _ActivityStatusPill extends StatelessWidget {
  const _ActivityStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final (String label, Color background, Color foreground) = switch (status) {
      'CANCELLED' => ('Cancelled', colors.dangerSoft, colors.danger),
      'CONFIRMED' => ('Confirmed', colors.successSoft, colors.success),
      'COMPLETED' => ('Done', colors.surfaceSunken, colors.inkMuted),
      _ => ('Closed', colors.surfaceSunken, colors.inkFaint),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: AppRadii.pillAll),
      child: Text(
        label,
        style: context.type.caption.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.label, required this.detail});

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: AppRadii.smAll,
          ),
          child: Icon(icon, size: 17, color: colors.inkMuted),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: type.bodyStrong),
              if (detail.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(detail, style: type.caption.copyWith(color: colors.inkMuted)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return PressEffect(
      onTap: activity.isHost ? null : () => context.push(Routes.person(activity.host.id)),
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: <Widget>[
            AppAvatar(
              name: activity.host.displayName,
              imageUrl: activity.host.avatarUrl,
              size: 52,
              isOnline: activity.host.isOnline,
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
                          activity.isHost ? 'You' : activity.host.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.bodyStrong,
                        ),
                      ),
                      if (activity.host.verification.isVerified) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs + 2),
                        VerifiedBadge(size: 15, status: activity.host.verification),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      if (activity.host.age != null) '${activity.host.age}',
                      if (activity.host.occupation != null) activity.host.occupation!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.caption.copyWith(color: colors.inkMuted),
                  ),
                  if (activity.host.ratingCount > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Icon(Icons.star_rounded, size: 14, color: colors.warning),
                        const SizedBox(width: 3),
                        Text(
                          '${activity.host.ratingAverage.toStringAsFixed(1)} · ${activity.host.ratingCount} meet-ups',
                          style: type.caption.copyWith(color: colors.inkMuted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!activity.isHost) Icon(Icons.chevron_right_rounded, color: colors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _FloatingBack extends StatelessWidget {
  const _FloatingBack({required this.onBack, this.floating = false});

  final VoidCallback onBack;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final Widget button = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppIconButton(icon: Icons.arrow_back_rounded, onPressed: onBack),
    );

    if (!floating) return Align(alignment: Alignment.centerLeft, child: button);

    return Positioned(
      top: MediaQuery.paddingOf(context).top,
      left: 0,
      child: button,
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    final Widget action;
    if (activity.isHost) {
      action = AppButton.secondary(
        label: 'Find people for this',
        icon: Icons.person_search_outlined,
        onPressed: () {
          ref.read(discoverModeProvider.notifier).state = DiscoverMode.people;
          context.go(Routes.discover);
        },
      );
    } else if (activity.viewerInvitationStatus != null) {
      action = Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: AppRadii.pillAll,
        ),
        child: Text(
          switch (activity.viewerInvitationStatus!.wire) {
            'PENDING' => 'Request sent — waiting on ${activity.host.firstName}',
            'ACCEPTED' => 'You are in. See you there.',
            'DECLINED' => '${activity.host.firstName} could not make this one',
            _ => 'This request is closed',
          },
          style: type.label.copyWith(color: colors.inkMuted),
        ),
      );
    } else if (!activity.isOpen) {
      action = Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: AppRadii.pillAll,
        ),
        child: Text(
          'This plan is closed',
          style: type.label.copyWith(color: colors.inkMuted),
        ),
      );
    } else {
      action = AppButton(
        label: 'Ask to join',
        icon: Icons.send_rounded,
        onPressed: () => showInviteSheet(context, profile: activity.host, activity: activity),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenX,
        AppSpacing.lg,
        AppSpacing.screenX,
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: action,
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBox(height: 260, radius: 0),
          Padding(
            padding: EdgeInsets.all(AppSpacing.screenX),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(height: 40),
                SizedBox(height: AppSpacing.lg),
                SkeletonBox(height: 40),
                SizedBox(height: AppSpacing.lg),
                SkeletonBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
