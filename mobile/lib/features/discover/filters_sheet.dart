import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../providers/feed_providers.dart';
import '../../services/discovery_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_sheet.dart';

/// Filters as a single sheet with a live result count and one "Reset".
///
/// Nothing is applied until "Show results" — half-typed filters should never
/// make the list flicker underneath the sheet.
Future<void> showFiltersSheet(BuildContext context) {
  return AppSheet.show<void>(context, builder: (_) => const _FiltersSheet());
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet();

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late DiscoveryFilters _draft = ref.read(discoveryFiltersProvider);

  void _apply() {
    ref.read(discoveryFiltersProvider.notifier).state = _draft;
    Navigator.of(context).pop();
  }

  void _reset() => setState(() => _draft = DiscoveryFilters.none);

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return AppSheet(
      title: 'Filters',
      subtitle: 'Narrow it down to the plans you would actually say yes to.',
      trailing: _draft.isDefault
          ? null
          : AppButton.ghost(label: 'Reset', size: AppButtonSize.small, onPressed: _reset),
      footer: AppButton(label: 'Show results', onPressed: _apply),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Group(
              label: 'Activity',
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final ActivityCategory category in ActivityCategory.values)
                    CategoryChip(
                      category: category,
                      dense: true,
                      selected: _draft.activities.contains(category),
                      onTap: () => setState(() {
                        final List<ActivityCategory> next =
                            List<ActivityCategory>.of(_draft.activities);
                        next.contains(category) ? next.remove(category) : next.add(category);
                        _draft = _draft.copyWith(activities: next);
                      }),
                    ),
                ],
              ),
            ),
            _Group(
              label: 'When they’re free',
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final AvailabilitySlot slot in AvailabilitySlot.values)
                    AppChip(
                      label: slot.label,
                      dense: true,
                      selected: _draft.availability.contains(slot),
                      onTap: () => setState(() {
                        final List<AvailabilitySlot> next =
                            List<AvailabilitySlot>.of(_draft.availability);
                        next.contains(slot) ? next.remove(slot) : next.add(slot);
                        _draft = _draft.copyWith(availability: next);
                      }),
                    ),
                ],
              ),
            ),
            _Group(
              label: 'Show me',
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final Gender gender in <Gender>[
                    Gender.female,
                    Gender.male,
                    Gender.nonBinary,
                  ])
                    AppChip(
                      label: gender.label,
                      dense: true,
                      selected: _draft.genders.contains(gender),
                      onTap: () => setState(() {
                        final List<Gender> next = List<Gender>.of(_draft.genders);
                        next.contains(gender) ? next.remove(gender) : next.add(gender);
                        _draft = _draft.copyWith(genders: next);
                      }),
                    ),
                ],
              ),
            ),
            _Group(
              label: 'Age',
              trailing: '${_draft.minAge} – ${_draft.maxAge}',
              child: RangeSlider(
                values: RangeValues(_draft.minAge.toDouble(), _draft.maxAge.toDouble()),
                min: 18,
                max: 99,
                divisions: 81,
                onChanged: (RangeValues values) => setState(() {
                  _draft = _draft.copyWith(
                    minAge: values.start.round(),
                    maxAge: values.end.round(),
                  );
                }),
              ),
            ),
            _Group(
              label: 'Distance',
              trailing: '${_draft.radiusKm.round()} km',
              child: Slider(
                value: _draft.radiusKm,
                min: 1,
                max: 100,
                divisions: 99,
                onChanged: (double value) =>
                    setState(() => _draft = _draft.copyWith(radiusKm: value)),
              ),
            ),
            _InterestGroup(
              selected: _draft.interests,
              onChanged: (List<String> value) =>
                  setState(() => _draft = _draft.copyWith(interests: value)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Filters only affect who you see. They never tell the other person anything about you.',
              style: type.caption.copyWith(color: colors.inkFaint, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: type.overline.copyWith(color: colors.inkFaint),
              ),
              const Spacer(),
              if (trailing != null)
                Text(trailing!, style: type.numeric.copyWith(color: colors.ink)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InterestGroup extends ConsumerWidget {
  const _InterestGroup({required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Interest>> catalog = ref.watch(interestCatalogProvider);

    return catalog.maybeWhen(
      data: (List<Interest> interests) => _Group(
        label: 'Interests',
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final Interest interest in interests.take(24))
              AppChip(
                label: interest.label,
                dense: true,
                leading: interest.emoji.isEmpty
                    ? null
                    : Text(interest.emoji, style: const TextStyle(fontSize: 12)),
                selected: selected.contains(interest.slug),
                onTap: () {
                  final List<String> next = List<String>.of(selected);
                  next.contains(interest.slug)
                      ? next.remove(interest.slug)
                      : next.add(interest.slug);
                  onChanged(next);
                },
              ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
