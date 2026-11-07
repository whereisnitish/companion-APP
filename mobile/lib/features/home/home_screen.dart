import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/enums.dart';
import '../../models/home_feed.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../services/discovery_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/activity_card.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/entrance.dart';
import '../../widgets/person_card.dart';
import '../../widgets/press_effect.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/state_views.dart';
import '../invitations/invite_sheet.dart';

/// Home answers one question before anything else: **what can I do today?**
///
/// So the categories sit directly under the greeting — the fastest route into
/// the product — and everything below is evidence that the answer is real:
/// what is on tonight, who is free, what is nearby.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeFeedProvider);
    await ref.read(homeFeedProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<HomeFeed> feed = ref.watch(homeFeedProvider);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          color: colors.primary,
          backgroundColor: colors.surface,
          displacement: 28,
          child: feed.when(
            loading: () => const _HomeSkeleton(),
            error: (Object error, _) => ListView(
              children: <Widget>[
                const SizedBox(height: 120),
                StateView.fromError(error, onRetry: () => ref.invalidate(homeFeedProvider)),
              ],
            ),
            data: (HomeFeed data) => _HomeContent(feed: data),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.feed});

  final HomeFeed feed;

  void _openCategory(BuildContext context, WidgetRef ref, ActivityCategory category) {
    ref.read(discoveryFiltersProvider.notifier).state =
        DiscoveryFilters(activities: <ActivityCategory>[category]);
    ref.read(discoverModeProvider.notifier).state = DiscoverMode.people;
    context.go(Routes.discover);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name = ref.watch(currentUserProvider)?.firstName ?? 'there';

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Entrance(child: _Greeting(feed: feed, name: name)),
        ),
        if (feed.pendingInvitations > 0)
          SliverToBoxAdapter(
            child: Entrance(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenX,
                  AppSpacing.xl,
                  AppSpacing.screenX,
                  0,
                ),
                child: _PendingInvitesBanner(count: feed.pendingInvitations),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Entrance(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(
                  title: 'What are you up for?',
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenX,
                    AppSpacing.xxl,
                    AppSpacing.screenX,
                    AppSpacing.lg,
                  ),
                ),
                SizedBox(
                  height: 124,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
                    itemCount: feed.orderedCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                    itemBuilder: (BuildContext context, int index) {
                      final CategoryCount count = feed.orderedCategories[index];
                      return _CategoryTile(
                        count: count,
                        onTap: () => _openCategory(context, ref, count.category),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (feed.tonight.isNotEmpty)
          SliverToBoxAdapter(
            child: Entrance(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SectionHeader(
                    eyebrow: 'Short notice',
                    title: 'Happening today',
                    actionLabel: 'See all',
                    onAction: () {
                      ref.read(discoverModeProvider.notifier).state = DiscoverMode.activities;
                      context.go(Routes.discover);
                    },
                  ),
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
                      itemCount: feed.tonight.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (BuildContext context, int index) {
                        final Activity activity = feed.tonight[index];
                        return ActivityPreviewCard(
                          activity: activity,
                          onTap: () => context.push(Routes.activity(activity.id)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (feed.peopleNearby.isNotEmpty)
          SliverToBoxAdapter(
            child: Entrance(
              index: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SectionHeader(
                    eyebrow: 'Nearby',
                    title: 'Looking for company',
                    subtitle: 'Sorted by what you both want to do.',
                    actionLabel: 'See all',
                    onAction: () {
                      ref.read(discoverModeProvider.notifier).state = DiscoverMode.people;
                      context.go(Routes.discover);
                    },
                  ),
                  SizedBox(
                    height: 372,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
                      itemCount: feed.peopleNearby.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (BuildContext context, int index) {
                        final Profile profile = feed.peopleNearby[index];
                        return PersonPreviewCard(
                          profile: profile,
                          onTap: () => context.push(Routes.person(profile.id)),
                          onInvite: () => showInviteSheet(context, profile: profile),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Entrance(
            index: 5,
            child: SectionHeader(
              eyebrow: 'Open plans',
              title: 'Near you this week',
              actionLabel: 'See all',
              onAction: () {
                ref.read(discoverModeProvider.notifier).state = DiscoverMode.activities;
                context.go(Routes.discover);
              },
            ),
          ),
        ),
        if (feed.activitiesNearby.isEmpty)
          const SliverToBoxAdapter(
            child: StateView.empty(
              icon: Icons.event_available_outlined,
              title: 'Quiet around here',
              message: 'No open plans nearby yet. Be the first to post one.',
              compact: true,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
            sliver: SliverList.separated(
              itemCount: feed.activitiesNearby.length.clamp(0, 4),
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                final Activity activity = feed.activitiesNearby[index];
                return ActivityCard(
                  activity: activity,
                  onTap: () => context.push(Routes.activity(activity.id)),
                  onInvite: () => showInviteSheet(
                    context,
                    profile: activity.host,
                    activity: activity,
                  ),
                );
              },
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenX,
              AppSpacing.xxxl,
              AppSpacing.screenX,
              AppSpacing.giant,
            ),
            child: _CreatePlanPrompt(
              city: feed.city,
              onTap: () => context.push(Routes.createActivity),
            ),
          ),
        ),
      ],
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting({required this.feed, required this.name});

  final HomeFeed feed;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final int unread = ref.watch(unreadNotificationsProvider);
    final Profile? me = ref.watch(currentUserProvider);

    final int freeNow = feed.peopleNearby
        .where((Profile profile) =>
            profile.availability.contains(AvailabilitySlot.tonight) || profile.isOnline)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenX,
        AppSpacing.lg,
        AppSpacing.screenX,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  feed.greeting.label,
                  style: type.bodySmall.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(name, style: type.display),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Icon(Icons.place_outlined, size: 14, color: colors.inkFaint),
                    const SizedBox(width: AppSpacing.xs + 1),
                    Text(
                      feed.city.isEmpty ? 'Nearby' : feed.city,
                      style: type.caption.copyWith(color: colors.inkMuted),
                    ),
                    if (freeNow > 0) ...<Widget>[
                      Text(
                        '  ·  ',
                        style: type.caption.copyWith(color: colors.inkFaint),
                      ),
                      Container(
                        height: 6,
                        width: 6,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '$freeNow free right now',
                        style: type.caption.copyWith(color: colors.inkMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              AppIconButton(
                icon: Icons.notifications_none_rounded,
                onPressed: () => context.push(Routes.notifications),
              ),
              if (unread > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    height: 9,
                    width: 9,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          PressEffect(
            onTap: () => context.go(Routes.me),
            scale: 0.9,
            child: AppAvatar(
              name: me?.displayName ?? 'You',
              imageUrl: me?.avatarUrl,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.count, required this.onTap});

  final CategoryCount count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final ActivityCategory category = count.category;
    final int total = count.openActivities;

    return PressEffect(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: category.tint(context),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, size: 19, color: category.foreground(context)),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: type.label.copyWith(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              total > 0 ? '$total open' : 'Be first',
              style: type.caption.copyWith(
                color: total > 0 ? colors.inkMuted : colors.inkFaint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingInvitesBanner extends StatelessWidget {
  const _PendingInvitesBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return PressEffect(
      onTap: () => context.go(Routes.invites),
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.accentSoft,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: colors.accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: AppRadii.smAll,
              ),
              child: const Icon(Icons.mail_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    count == 1 ? 'Someone invited you' : '$count people invited you',
                    style: type.bodyStrong,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'They are waiting on your answer.',
                    style: type.caption.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

class _CreatePlanPrompt extends StatelessWidget {
  const _CreatePlanPrompt({required this.city, required this.onTap});

  final String city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: AppRadii.xlAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final ActivityCategory category in <ActivityCategory>[
                ActivityCategory.movie,
                ActivityCategory.dinner,
                ActivityCategory.walk,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.12),
                      borderRadius: AppRadii.smAll,
                    ),
                    child: Icon(
                      category.icon,
                      size: 15,
                      color: colors.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Nothing on tonight?',
            style: type.serifTitle.copyWith(color: colors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Post what you want to do and let the right person come to you. It takes about thirty seconds.',
            style: type.body.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.76),
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Create a plan',
            variant: AppButtonVariant.secondary,
            icon: Icons.add_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenX,
          AppSpacing.xl,
          AppSpacing.screenX,
          AppSpacing.giant,
        ),
        children: <Widget>[
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonBox(width: 90, height: 12),
                    SizedBox(height: AppSpacing.md),
                    SkeletonBox(width: 160, height: 30),
                    SizedBox(height: AppSpacing.md),
                    SkeletonBox(width: 130, height: 12),
                  ],
                ),
              ),
              SkeletonBox.circle(size: 42),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          const SkeletonBox(width: 180, height: 20),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, __) =>
                  const SkeletonBox(width: 96, height: 124, radius: AppRadii.lg),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          const SkeletonBox(width: 210, height: 20),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 372,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, __) => const SizedBox(width: 232, child: PersonCardSkeleton()),
            ),
          ),
        ],
      ),
    );
  }
}
