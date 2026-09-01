import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../models/enums.dart';
import '../../models/invitation.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/entrance.dart';
import '../../widgets/press_effect.dart';
import '../../widgets/skeletons.dart';

/// Your own profile, plus your plans and the way out to settings.
///
/// Deliberately less photographic than someone else's profile — this is a
/// control surface, not a pitch. The one thing it borrows is the same "up for"
/// and "free" language, so what you edit is visibly what others read.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final CurrentUser? me = ref.watch(currentUserProvider);

    if (me == null) {
      return Scaffold(
        backgroundColor: colors.canvas,
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(authControllerProvider.notifier).refreshUser();
            ref.invalidate(myActivitiesProvider);
          },
          color: colors.primary,
          backgroundColor: colors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(bottom: AppSpacing.giant),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenX,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text('You', style: type.headline)),
                    AppIconButton(
                      icon: Icons.settings_outlined,
                      onPressed: () => context.push(Routes.settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Entrance(child: _ProfileHeader(me: me)),
              const SizedBox(height: AppSpacing.xxl),
              Entrance(index: 1, child: _StatsRow(me: me)),
              const SizedBox(height: AppSpacing.xxxl),
              const Entrance(index: 2, child: _MyPlansSection()),
              if (me.preferredActivities.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xxxl),
                Entrance(
                  index: 3,
                  child: _Section(
                    label: 'Up for',
                    onEdit: () => context.push(Routes.editProfile),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final ActivityCategory category in me.preferredActivities)
                          CategoryChip(category: category, selected: true),
                      ],
                    ),
                  ),
                ),
              ],
              if (me.availability.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xxl),
                Entrance(
                  index: 4,
                  child: _Section(
                    label: 'Usually free',
                    onEdit: () => context.push(Routes.editProfile),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final AvailabilitySlot slot in me.availability)
                          AppChip(
                            label: slot.label,
                            icon: Icons.schedule_rounded,
                            selected: true,
                            tint: colors.primarySoft,
                            foreground: colors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (me.bio.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xxl),
                Entrance(
                  index: 5,
                  child: _Section(
                    label: 'About',
                    onEdit: () => context.push(Routes.editProfile),
                    child: Text(me.bio, style: type.body.copyWith(height: 1.65)),
                  ),
                ),
              ],
              if (me.interests.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xxl),
                Entrance(
                  index: 6,
                  child: _Section(
                    label: 'Into',
                    onEdit: () => context.push(Routes.editProfile),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final Interest interest in me.interests)
                          AppChip(
                            label: interest.label,
                            dense: true,
                            leading: interest.emoji.isEmpty
                                ? null
                                : Text(interest.emoji, style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxxl),
              Padding(
                padding: AppSpacing.screenPadding,
                child: Entrance(
                  index: 7,
                  child: AppButton.secondary(
                    label: 'Edit profile',
                    icon: Icons.edit_outlined,
                    onPressed: () => context.push(Routes.editProfile),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.me});

  final CurrentUser me;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Row(
        children: <Widget>[
          AppAvatar(
            name: me.displayName,
            imageUrl: me.avatarUrl,
            size: 84,
            ring: colors.primary,
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        me.age == null ? me.displayName : '${me.displayName}, ${me.age}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.serifTitle,
                      ),
                    ),
                    if (me.verification.isVerified) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      VerifiedBadge(size: 17, status: me.verification),
                    ],
                  ],
                ),
                if (me.occupation != null && me.occupation!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    me.occupation!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.bodySmall.copyWith(color: colors.inkMuted),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Icon(Icons.place_outlined, size: 13, color: colors.inkFaint),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        <String>[
                          if (me.area != null && me.area!.isNotEmpty) me.area!,
                          me.city,
                        ].join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.caption.copyWith(color: colors.inkMuted),
                      ),
                    ),
                  ],
                ),
                if (!me.isDiscoverable) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  AppChip(
                    label: 'Hidden from discovery',
                    icon: Icons.visibility_off_outlined,
                    dense: true,
                    tint: colors.accentSoft,
                    foreground: colors.accent,
                    selected: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.me});

  final CurrentUser me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final int accepted = ref.watch(invitationCountsProvider).maybeWhen(
          data: (InvitationCounts counts) => counts.accepted,
          orElse: () => 0,
        );

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: <Widget>[
              Text(value, style: type.title),
              const SizedBox(height: 2),
              Text(label, style: type.caption.copyWith(color: colors.inkMuted)),
            ],
          ),
        );

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: <Widget>[
            stat(
              me.ratingCount == 0 ? '—' : me.ratingAverage.toStringAsFixed(1),
              'Rating',
            ),
            Container(width: 1, height: 30, color: colors.border),
            stat('$accepted', 'Connections'),
            Container(width: 1, height: 30, color: colors.border),
            stat(
              me.createdAt == null ? '—' : Format.relative(me.createdAt!),
              'Member for',
            ),
          ],
        ),
      ),
    );
  }
}

class _MyPlansSection extends ConsumerWidget {
  const _MyPlansSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final AsyncValue<List<Activity>> plans = ref.watch(myActivitiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: AppSpacing.screenPadding,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'YOUR PLANS',
                  style: type.overline.copyWith(color: colors.inkFaint),
                ),
              ),
              AppButton.ghost(
                label: 'New plan',
                icon: Icons.add_rounded,
                size: AppButtonSize.small,
                onPressed: () => context.push(Routes.createActivity),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        plans.when(
          loading: () => const Shimmer(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: SkeletonBox(height: 76, radius: AppRadii.lg),
            ),
          ),
          error: (_, __) => Padding(
            padding: AppSpacing.screenPadding,
            child: Text(
              'We could not load your plans.',
              style: type.bodySmall.copyWith(color: colors.inkMuted),
            ),
          ),
          data: (List<Activity> items) {
            final List<Activity> upcoming = items
                .where((Activity activity) => activity.status != 'CANCELLED')
                .toList(growable: false);

            if (upcoming.isEmpty) {
              return Padding(
                padding: AppSpacing.screenPadding,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: AppRadii.lgAll,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.event_outlined, size: 20, color: colors.inkMuted),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Nothing posted yet. A plan takes thirty seconds and does the finding for you.',
                          style: type.bodySmall.copyWith(color: colors.inkMuted, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: <Widget>[
                for (final Activity activity in upcoming.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: AppSpacing.screenPadding,
                      child: _PlanRow(activity: activity),
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

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return PressEffect(
      onTap: () => context.push(Routes.activity(activity.id)),
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: <Widget>[
            CategoryBadge(category: activity.category, size: 38, radius: 12),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.label,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Format.whenShort(activity.startsAt),
                    style: type.caption.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.onEdit});

  final String label;
  final Widget child;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: context.type.overline.copyWith(color: colors.inkFaint),
                ),
              ),
              if (onEdit != null)
                PressEffect(
                  onTap: onEdit,
                  scale: 0.9,
                  child: Icon(Icons.edit_outlined, size: 16, color: colors.inkFaint),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
