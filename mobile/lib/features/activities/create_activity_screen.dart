import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/locations.dart';
import '../../models/activity.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../services/activity_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/entrance.dart';
import '../../widgets/press_effect.dart';
import '../../widgets/success_burst.dart';

/// Posting a plan is the other half of the product, so it gets the same care
/// as discovery: four questions on one screen, a live preview of the card
/// other people will see, and a single commit.
class CreateActivityScreen extends ConsumerStatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  ConsumerState<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends ConsumerState<CreateActivityScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _location = TextEditingController();

  ActivityDraft _draft = const ActivityDraft();
  Place _place = Places.fallback;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final String? area = ref.read(currentUserProvider)?.area;
    _place = Places.byName(area) ?? Places.fallback;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _draft.category != null &&
      _title.text.trim().length >= 3 &&
      _draft.startsAt != null &&
      _location.text.trim().length >= 2;

  Future<void> _pickWhen() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _draft.startsAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'When is it?',
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _draft.startsAt ?? now.add(const Duration(hours: 3)),
      ),
      helpText: 'What time?',
    );
    if (time == null || !mounted) return;

    setState(() {
      _draft = _draft.copyWith(
        startsAt: DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    });
  }

  Future<void> _pickPlace() async {
    final Place? picked = await AppSheet.show<Place>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: 'Which area?',
        subtitle: 'People nearby see your plan first.',
        child: SingleChildScrollView(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final Place place in Places.all)
                AppChip(
                  label: place.name,
                  icon: Icons.place_outlined,
                  selected: place == _place,
                  onTap: () => Navigator.of(sheetContext).pop(place),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _place = picked);
  }

  Future<void> _post() async {
    setState(() => _isSubmitting = true);

    final ActivityDraft draft = _draft.copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      locationName: _location.text.trim(),
      area: _place.name,
      city: _place.city,
      latitude: _place.latitude,
      longitude: _place.longitude,
    );

    try {
      final Activity created = await ref.read(activityServiceProvider).create(draft);
      if (!mounted) return;
      ref.invalidate(myActivitiesProvider);
      invalidateSocialGraphFrom(ref);
      ref.invalidate(discoverActivitiesProvider);

      await AppSheet.show<void>(
        context,
        isDismissible: false,
        builder: (_) => _PostedConfirmation(activity: created),
      );
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackbar.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackbar.error(context, 'We could not post that plan. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: AppIconButton(
            icon: Icons.close_rounded,
            bordered: false,
            background: Colors.transparent,
            onPressed: () => context.pop(),
          ),
        ),
        leadingWidth: 60,
        title: const Text('New plan'),
      ),
      bottomNavigationBar: Container(
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
        child: AppButton(
          label: 'Post this plan',
          isLoading: _isSubmitting,
          onPressed: _canPost ? _post : null,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenX,
          AppSpacing.md,
          AppSpacing.screenX,
          AppSpacing.giant,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: <Widget>[
          Entrance(child: Text('What do you\nwant to do?', style: type.headline)),
          const SizedBox(height: AppSpacing.xl),
          Entrance(
            index: 1,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final ActivityCategory category in ActivityCategory.values)
                  CategoryChip(
                    category: category,
                    selected: _draft.category == category,
                    onTap: () => setState(() => _draft = _draft.copyWith(category: category)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Entrance(
            index: 2,
            child: AppTextField(
              controller: _title,
              label: 'Give it a title',
              hint: 'The late show at PVR Orion',
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Entrance(
            index: 3,
            child: _PickerRow(
              label: 'When',
              icon: Icons.schedule_rounded,
              value: _draft.startsAt == null
                  ? 'Pick a date and time'
                  : Format.whenLabel(_draft.startsAt!),
              isPlaceholder: _draft.startsAt == null,
              onTap: _pickWhen,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Entrance(
            index: 4,
            child: AppTextField(
              controller: _location,
              label: 'Where',
              hint: 'PVR Orion Mall',
              prefixIcon: Icons.place_outlined,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Entrance(
            index: 5,
            child: _PickerRow(
              label: 'Area',
              icon: Icons.map_outlined,
              value: '${_place.name}, ${_place.city}',
              isPlaceholder: false,
              onTap: _pickPlace,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Entrance(
            index: 6,
            child: Text(
              'WHO ARE YOU LOOKING FOR?',
              style: type.overline.copyWith(color: colors.inkFaint),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Entrance(
            index: 7,
            child: Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                for (final GenderPreference preference in GenderPreference.values)
                  AppChip(
                    label: preference.label,
                    selected: _draft.lookingFor == preference,
                    onTap: () => setState(() => _draft = _draft.copyWith(lookingFor: preference)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Entrance(
            index: 8,
            child: _SpotsStepper(
              value: _draft.capacity,
              onChanged: (int value) => setState(() => _draft = _draft.copyWith(capacity: value)),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Entrance(
            index: 9,
            child: AppTextField(
              controller: _description,
              label: 'Tell people about it',
              hint:
                  'Booked two tickets for the 9:40 screening and my friend bailed. I do not talk during films, I promise.',
              maxLines: 5,
              minLines: 4,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Entrance(
            index: 10,
            child: Text(
              'PREVIEW',
              style: type.overline.copyWith(color: colors.inkFaint),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Entrance(
            index: 11,
            child: _PlanPreview(
              category: _draft.category,
              title: _title.text.trim(),
              description: _description.text.trim(),
              startsAt: _draft.startsAt,
              locationName: _location.text.trim(),
              area: _place.name,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: type.label.copyWith(color: colors.inkMuted)),
        const SizedBox(height: AppSpacing.sm),
        PressEffect(
          onTap: onTap,
          scale: 0.99,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 19, color: colors.inkFaint),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.body.copyWith(
                      color: isPlaceholder ? colors.inkFaint : colors.ink,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: colors.inkFaint),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotsStepper extends StatelessWidget {
  const _SpotsStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.groups_outlined, size: 19, color: colors.inkFaint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value == 1 ? 'Space for one person' : 'Space for $value people',
              style: type.body,
            ),
          ),
          AppIconButton(
            icon: Icons.remove_rounded,
            size: 32,
            iconSize: 16,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          AppIconButton(
            icon: Icons.add_rounded,
            size: 32,
            iconSize: 16,
            onPressed: value < 10 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// The card exactly as it will appear in other people's feeds. Seeing it while
/// writing is what stops the vague one-word plans nobody replies to.
class _PlanPreview extends StatelessWidget {
  const _PlanPreview({
    required this.category,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.locationName,
    required this.area,
  });

  final ActivityCategory? category;
  final String title;
  final String description;
  final DateTime? startsAt;
  final String locationName;
  final String area;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final ActivityCategory resolved = category ?? ActivityCategory.other;
    final Color hue = resolved.foreground(context);

    return AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CategoryBadge(category: resolved),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  startsAt == null ? 'WHEN?' : Format.whenLabel(startsAt!).toUpperCase(),
                  style: type.overline.copyWith(
                    color: startsAt == null ? colors.inkFaint : hue,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  title.isEmpty ? 'Your title appears here' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.subtitle.copyWith(
                    height: 1.35,
                    color: title.isEmpty ? colors.inkFaint : colors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  locationName.isEmpty ? area : '$locationName · $area',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.caption.copyWith(color: colors.inkMuted),
                ),
                if (description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.bodySmall.copyWith(color: colors.inkMuted, height: 1.5),
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

class _PostedConfirmation extends StatelessWidget {
  const _PostedConfirmation({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          SuccessBurst(size: 88, color: colors.primary),
          const SizedBox(height: AppSpacing.xxl),
          Text('Your plan is live', style: type.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'People nearby who are up for ${activity.category.label.toLowerCase()} can see it now. You will hear the moment someone asks to join.',
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: colors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AppButton(
            label: 'See the plan',
            onPressed: () {
              Navigator.of(context).pop();
              context.push(Routes.activity(activity.id));
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.ghost(
            label: 'Back to home',
            expand: true,
            size: AppButtonSize.large,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
