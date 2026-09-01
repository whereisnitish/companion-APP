import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../services/discovery_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/activity_card.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/entrance.dart';
import '../../widgets/person_card.dart';
import '../../widgets/press_effect.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/state_views.dart';
import '../invitations/invite_sheet.dart';
import 'filters_sheet.dart';

/// Discover is a browse surface, not a game.
///
/// No swiping, no scarcity, no artificial "you have 3 left". A search field, a
/// segmented switch between people and plans, a filter sheet, and a list you
/// can scroll back up in.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(discoveryFiltersProvider).query;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Typing should not fire a request per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final DiscoveryFilters current = ref.read(discoveryFiltersProvider);
      if (current.query == value.trim()) return;
      ref.read(discoveryFiltersProvider.notifier).state = current.copyWith(query: value.trim());
    });
  }

  Future<void> _refresh() async {
    final DiscoverMode mode = ref.read(discoverModeProvider);
    if (mode == DiscoverMode.people) {
      ref.invalidate(discoverPeopleProvider);
      await ref.read(discoverPeopleProvider.future);
    } else {
      ref.invalidate(discoverActivitiesProvider);
      await ref.read(discoverActivitiesProvider.future);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final DiscoverMode mode = ref.watch(discoverModeProvider);
    final DiscoveryFilters filters = ref.watch(discoveryFiltersProvider);

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(child: Text('Discover', style: type.headline)),
                      _FilterButton(
                        count: filters.activeCount,
                        onTap: () => showFiltersSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _search,
                    hint: mode == DiscoverMode.people
                        ? 'Search names, bios, areas'
                        : 'Search plans and places',
                    prefixIcon: Icons.search_rounded,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    suffix: _search.text.isEmpty
                        ? null
                        : PressEffect(
                            onTap: () {
                              _search.clear();
                              _onSearchChanged('');
                              setState(() {});
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colors.inkFaint,
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ModeSwitch(
                    mode: mode,
                    onChanged: (DiscoverMode next) =>
                        ref.read(discoverModeProvider.notifier).state = next,
                  ),
                  if (filters.activeCount > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    _ActiveFilterSummary(filters: filters),
                  ],
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: colors.primary,
                backgroundColor: colors.surface,
                child: SoftSwitcher(
                  child: mode == DiscoverMode.people
                      ? const _PeopleList(key: ValueKey<String>('people'))
                      : const _ActivitiesList(key: ValueKey<String>('activities')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final DiscoverMode mode;
  final ValueChanged<DiscoverMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    Widget segment(DiscoverMode value, String label, IconData icon) {
      final bool isSelected = mode == value;
      return Expanded(
        child: PressEffect(
          onTap: () => onChanged(value),
          scale: 0.97,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected ? colors.surface : Colors.transparent,
              borderRadius: AppRadii.pillAll,
              border: Border.all(
                color: isSelected ? colors.border : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 15, color: isSelected ? colors.ink : colors.inkFaint),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: type.label.copyWith(
                    color: isSelected ? colors.ink : colors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: AppRadii.pillAll,
      ),
      child: Row(
        children: <Widget>[
          segment(DiscoverMode.people, 'People', Icons.people_alt_outlined),
          segment(DiscoverMode.activities, 'Plans', Icons.event_outlined),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool isActive = count > 0;

    return PressEffect(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: isActive ? colors.ink : colors.surface,
          borderRadius: AppRadii.pillAll,
          border: Border.all(color: isActive ? colors.ink : colors.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.tune_rounded,
              size: 17,
              color: isActive ? colors.inkInverse : colors.ink,
            ),
            if (isActive) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$count',
                style: context.type.numeric.copyWith(color: colors.inkInverse),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterSummary extends ConsumerWidget {
  const _ActiveFilterSummary({required this.filters});

  final DiscoveryFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> chips = <Widget>[
      for (final ActivityCategory category in filters.activities)
        CategoryChip(
          category: category,
          dense: true,
          selected: true,
          onTap: () {
            final List<ActivityCategory> next = List<ActivityCategory>.of(filters.activities)
              ..remove(category);
            ref.read(discoveryFiltersProvider.notifier).state = filters.copyWith(activities: next);
          },
        ),
      for (final AvailabilitySlot slot in filters.availability)
        AppChip(
          label: slot.label,
          dense: true,
          selected: true,
          onTap: () {
            final List<AvailabilitySlot> next = List<AvailabilitySlot>.of(filters.availability)
              ..remove(slot);
            ref.read(discoveryFiltersProvider.notifier).state =
                filters.copyWith(availability: next);
          },
        ),
      for (final Gender gender in filters.genders)
        AppChip(
          label: gender.label,
          dense: true,
          selected: true,
          onTap: () {
            final List<Gender> next = List<Gender>.of(filters.genders)..remove(gender);
            ref.read(discoveryFiltersProvider.notifier).state = filters.copyWith(genders: next);
          },
        ),
      if (filters.minAge != 18 || filters.maxAge != 99)
        AppChip(
          label: '${filters.minAge}–${filters.maxAge}',
          dense: true,
          selected: true,
          onTap: () => ref.read(discoveryFiltersProvider.notifier).state =
              filters.copyWith(minAge: 18, maxAge: 99),
        ),
      if (filters.radiusKm != 25)
        AppChip(
          label: 'Within ${filters.radiusKm.round()} km',
          dense: true,
          selected: true,
          onTap: () =>
              ref.read(discoveryFiltersProvider.notifier).state = filters.copyWith(radiusKm: 25),
        ),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) => chips[index],
      ),
    );
  }
}

class _PeopleList extends ConsumerWidget {
  const _PeopleList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Profile>> people = ref.watch(discoverPeopleProvider);

    return people.when(
      loading: () => Shimmer(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenX,
            AppSpacing.sm,
            AppSpacing.screenX,
            AppSpacing.giant,
          ),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xl),
          itemBuilder: (_, __) => const PersonCardSkeleton(),
        ),
      ),
      error: (Object error, _) => ListView(
        children: <Widget>[
          const SizedBox(height: 60),
          StateView.fromError(error, onRetry: () => ref.invalidate(discoverPeopleProvider)),
        ],
      ),
      data: (List<Profile> items) {
        if (items.isEmpty) {
          return ListView(
            children: <Widget>[
              const SizedBox(height: 40),
              StateView.empty(
                icon: Icons.person_search_outlined,
                title: 'Nobody matches that yet',
                message:
                    'Try widening the distance or clearing a filter. New people join every day.',
                actionLabel: 'Clear filters',
                onAction: () =>
                    ref.read(discoveryFiltersProvider.notifier).state = DiscoveryFilters.none,
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenX,
            AppSpacing.sm,
            AppSpacing.screenX,
            AppSpacing.giant,
          ),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xl),
          itemBuilder: (BuildContext context, int index) {
            final Profile profile = items[index];
            return Entrance(
              index: index,
              child: PersonCard(
                profile: profile,
                onTap: () => context.push(Routes.person(profile.id)),
                onInvite: () => showInviteSheet(context, profile: profile),
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivitiesList extends ConsumerWidget {
  const _ActivitiesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Activity>> activities = ref.watch(discoverActivitiesProvider);

    return activities.when(
      loading: () => Shimmer(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenX,
            AppSpacing.sm,
            AppSpacing.screenX,
            AppSpacing.giant,
          ),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, __) => const SkeletonBox(height: 132, radius: AppRadii.lg),
        ),
      ),
      error: (Object error, _) => ListView(
        children: <Widget>[
          const SizedBox(height: 60),
          StateView.fromError(error, onRetry: () => ref.invalidate(discoverActivitiesProvider)),
        ],
      ),
      data: (List<Activity> items) {
        if (items.isEmpty) {
          return ListView(
            children: <Widget>[
              const SizedBox(height: 40),
              StateView.empty(
                icon: Icons.event_busy_outlined,
                title: 'No open plans right now',
                message: 'Nothing matches these filters. Post your own and see who joins.',
                actionLabel: 'Create a plan',
                onAction: () => context.push(Routes.createActivity),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenX,
            AppSpacing.sm,
            AppSpacing.screenX,
            AppSpacing.giant,
          ),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (BuildContext context, int index) {
            final Activity activity = items[index];
            return Entrance(
              index: index,
              child: ActivityCard(
                activity: activity,
                onTap: () => context.push(Routes.activity(activity.id)),
                onInvite: () =>
                    showInviteSheet(context, profile: activity.host, activity: activity),
              ),
            );
          },
        );
      },
    );
  }
}
