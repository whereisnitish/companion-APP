import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/locations.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feed_providers.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/entrance.dart';
import '../../widgets/press_effect.dart';
import '../profile/profile_photo_picker.dart';

/// Profile setup as a conversation, not a form.
///
/// One question per screen, each answerable in a tap or two, with a progress
/// rule at the top so the end is always in sight. The whole profile is sent in
/// a single request at the end — no half-built profiles in the database.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  static const int _stepCount = 7;

  final PageController _pages = PageController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _occupation = TextEditingController();

  int _step = 0;
  bool _isSubmitting = false;

  ProfileDraft _draft = const ProfileDraft();
  Place _place = Places.fallback;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _bio.dispose();
    _occupation.dispose();
    super.dispose();
  }

  /// Each step gates "Continue" on its own answer being present.
  bool get _canContinue => switch (_step) {
        0 => _name.text.trim().length >= 2 && _draft.birthDate != null && _draft.gender != null,
        1 => true,
        2 => true,
        3 => _draft.preferredActivities.isNotEmpty,
        4 => _draft.availability.isNotEmpty,
        5 => true,
        _ => true,
      };

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == _stepCount - 1) {
      _submit();
      return;
    }
    _pages.nextPage(duration: AppMotion.base, curve: AppMotion.standard);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) return;
    _pages.previousPage(duration: AppMotion.base, curve: AppMotion.standard);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final ProfileDraft draft = _draft.copyWith(
      displayName: _name.text.trim(),
      bio: _bio.text.trim(),
      occupation: _occupation.text.trim(),
      city: _place.city,
      area: _place.name,
      latitude: _place.latitude,
      longitude: _place.longitude,
    );

    try {
      final CurrentUser user = await ref.read(profileServiceProvider).createProfile(draft);
      ref.read(authControllerProvider.notifier).setUser(user);
      ref.invalidate(homeFeedProvider);
      // The router redirect moves us into the app.
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackbar.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackbar.error(context, 'We could not save your profile. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _SetupHeader(
              step: _step,
              stepCount: _stepCount,
              onBack: _step == 0 ? null : _back,
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int index) => setState(() => _step = index),
                children: <Widget>[
                  _StepShell(
                    title: 'First, the basics.',
                    subtitle: 'This is what people see before anything else.',
                    child: _BasicsStep(
                      nameController: _name,
                      draft: _draft,
                      onChanged: (ProfileDraft draft) => setState(() => _draft = draft),
                      onNameChanged: () => setState(() {}),
                    ),
                  ),
                  _StepShell(
                    title: 'Add a photo.',
                    subtitle: 'Profiles with a face get roughly three times the replies.',
                    child: _PhotoStep(
                      name: _name.text,
                      selected: _draft.avatarUrl,
                      onSelected: (String url) =>
                          setState(() => _draft = _draft.copyWith(avatarUrl: url)),
                    ),
                  ),
                  _StepShell(
                    title: 'Where are you based?',
                    subtitle: 'We only ever show an approximate distance, never an address.',
                    child: _PlaceStep(
                      selected: _place,
                      onSelected: (Place place) => setState(() => _place = place),
                    ),
                  ),
                  _StepShell(
                    title: 'What are you up for?',
                    subtitle: 'Pick everything that sounds like a good evening.',
                    child: _ActivitiesStep(
                      selected: _draft.preferredActivities,
                      onChanged: (List<ActivityCategory> value) =>
                          setState(() => _draft = _draft.copyWith(preferredActivities: value)),
                    ),
                  ),
                  _StepShell(
                    title: 'When are you free?',
                    subtitle: 'Rough is fine. You can change it any time.',
                    child: _AvailabilityStep(
                      selected: _draft.availability,
                      onChanged: (List<AvailabilitySlot> value) =>
                          setState(() => _draft = _draft.copyWith(availability: value)),
                    ),
                  ),
                  _StepShell(
                    title: 'What are you into?',
                    subtitle: 'Shared interests are how we sort who you see first.',
                    child: _InterestsStep(
                      selected: _draft.interests,
                      onChanged: (List<String> value) =>
                          setState(() => _draft = _draft.copyWith(interests: value)),
                    ),
                  ),
                  _StepShell(
                    title: 'Say hello.',
                    subtitle: 'A line or two. The specific ones always do better.',
                    child: _AboutStep(
                      bioController: _bio,
                      occupationController: _occupation,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: _step == _stepCount - 1 ? 'Finish' : 'Continue',
                isLoading: _isSubmitting,
                onPressed: _canContinue ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({required this.step, required this.stepCount, this.onBack});

  final int step;
  final int stepCount;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.xxl, 0),
      child: Row(
        children: <Widget>[
          AnimatedOpacity(
            duration: AppMotion.fast,
            opacity: onBack == null ? 0 : 1,
            child: AppIconButton(
              icon: Icons.arrow_back_rounded,
              bordered: false,
              background: Colors.transparent,
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadii.pillAll,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: (step + 1) / stepCount),
                duration: AppMotion.base,
                curve: AppMotion.standard,
                builder: (BuildContext context, double value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  backgroundColor: colors.surfaceSunken,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Text(
            '${step + 1}/$stepCount',
            style: context.type.numeric.copyWith(color: colors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        Entrance(child: Text(title, style: type.headline)),
        const SizedBox(height: AppSpacing.md),
        Entrance(
          index: 1,
          child: Text(
            subtitle,
            style: type.body.copyWith(color: colors.inkMuted, height: 1.55),
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Entrance(index: 2, child: child),
      ],
    );
  }
}

// --------------------------------------------------------------- the steps

class _BasicsStep extends StatelessWidget {
  const _BasicsStep({
    required this.nameController,
    required this.draft,
    required this.onChanged,
    required this.onNameChanged,
  });

  final TextEditingController nameController;
  final ProfileDraft draft;
  final ValueChanged<ProfileDraft> onChanged;
  final VoidCallback onNameChanged;

  Future<void> _pickBirthDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initial = draft.birthDate ?? DateTime(now.year - 25, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 99),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Your date of birth',
      builder: (BuildContext context, Widget? child) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (picked != null) onChanged(draft.copyWith(birthDate: picked));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final DateTime? birthDate = draft.birthDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextField(
          controller: nameController,
          label: 'Your name',
          hint: 'What people should call you',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          onChanged: (_) => onNameChanged(),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Date of birth', style: type.label.copyWith(color: colors.inkMuted)),
        const SizedBox(height: AppSpacing.sm),
        PressEffect(
          onTap: () => _pickBirthDate(context),
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
                Icon(Icons.cake_outlined, size: 19, color: colors.inkFaint),
                const SizedBox(width: AppSpacing.md),
                Text(
                  birthDate == null
                      ? 'Select your birthday'
                      : '${_monthName(birthDate.month)} ${birthDate.day}, ${birthDate.year}',
                  style: type.body.copyWith(
                    color: birthDate == null ? colors.inkFaint : colors.ink,
                  ),
                ),
                const Spacer(),
                if (birthDate != null)
                  Text(
                    '${_ageFrom(birthDate)} years old',
                    style: type.caption.copyWith(color: colors.inkMuted),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('You are', style: type.label.copyWith(color: colors.inkMuted)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final Gender gender in Gender.values)
              AppChip(
                label: gender.label,
                selected: draft.gender == gender,
                onTap: () => onChanged(draft.copyWith(gender: gender)),
              ),
          ],
        ),
      ],
    );
  }

  static int _ageFrom(DateTime birthDate) {
    final DateTime now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age -= 1;
    }
    return age;
  }

  static String _monthName(int month) => const <String>[
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];
}

class _PhotoStep extends StatelessWidget {
  const _PhotoStep({required this.name, required this.selected, required this.onSelected});

  final String name;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Center(
          child: ProfilePhotoPicker(
            name: name,
            imageUrl: selected,
            size: 116,
            showButton: true,
            onUploaded: onSelected,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Choose one from your gallery or take one now, or skip for the moment. You can change it any time from your profile.',
          textAlign: TextAlign.center,
          style: context.type.caption.copyWith(color: context.colors.inkFaint, height: 1.5),
        ),
      ],
    );
  }
}

class _PlaceStep extends StatefulWidget {
  const _PlaceStep({required this.selected, required this.onSelected});

  final Place selected;
  final ValueChanged<Place> onSelected;

  @override
  State<_PlaceStep> createState() => _PlaceStepState();
}

class _PlaceStepState extends State<_PlaceStep> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Place> results = Places.search(_query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextField(
          controller: _search,
          hint: 'Search your area',
          prefixIcon: Icons.search_rounded,
          onChanged: (String value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final Place place in results)
              AppChip(
                label: place.name,
                icon: Icons.place_outlined,
                selected: widget.selected == place,
                onTap: () => widget.onSelected(place),
              ),
          ],
        ),
        if (results.isEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No match. The MVP covers ${Places.all.length} Chandigarh neighbourhoods.',
            style: context.type.bodySmall.copyWith(color: context.colors.inkMuted),
          ),
        ],
      ],
    );
  }
}

class _ActivitiesStep extends StatelessWidget {
  const _ActivitiesStep({required this.selected, required this.onChanged});

  final List<ActivityCategory> selected;
  final ValueChanged<List<ActivityCategory>> onChanged;

  void _toggle(ActivityCategory category) {
    final List<ActivityCategory> next = List<ActivityCategory>.of(selected);
    next.contains(category) ? next.remove(category) : next.add(category);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ActivityCategory.values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (BuildContext context, int index) {
        final ActivityCategory category = ActivityCategory.values[index];
        return _SelectableTile(
          label: category.label,
          icon: category.icon,
          hue: category.foreground(context),
          tint: category.tint(context),
          selected: selected.contains(category),
          onTap: () => _toggle(category),
        );
      },
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.label,
    required this.icon,
    required this.hue,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color hue;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return PressEffect(
      onTap: onTap,
      scale: 0.96,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? tint : colors.surface,
          borderRadius: AppRadii.mdAll,
          border: Border.all(
            color: selected ? hue.withValues(alpha: 0.45) : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: selected ? hue : colors.inkMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.label.copyWith(
                  color: selected ? colors.ink : colors.inkMuted,
                ),
              ),
            ),
            AnimatedScale(
              duration: AppMotion.fast,
              curve: AppMotion.spring,
              scale: selected ? 1 : 0,
              child: Icon(Icons.check_circle_rounded, size: 18, color: hue),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityStep extends StatelessWidget {
  const _AvailabilityStep({required this.selected, required this.onChanged});

  final List<AvailabilitySlot> selected;
  final ValueChanged<List<AvailabilitySlot>> onChanged;

  static const Map<AvailabilitySlot, String> _hints = <AvailabilitySlot, String>{
    AvailabilitySlot.tonight: 'Free in the next few hours',
    AvailabilitySlot.tomorrow: 'Something planned for tomorrow',
    AvailabilitySlot.thisWeek: 'Any evening this week works',
    AvailabilitySlot.weekend: 'Saturdays and Sundays',
    AvailabilitySlot.flexible: 'Ask me — my schedule moves',
  };

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      children: <Widget>[
        for (final AvailabilitySlot slot in AvailabilitySlot.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: PressEffect(
              onTap: () {
                final List<AvailabilitySlot> next = List<AvailabilitySlot>.of(selected);
                next.contains(slot) ? next.remove(slot) : next.add(slot);
                onChanged(next);
              },
              scale: 0.98,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: selected.contains(slot) ? colors.primarySoft : colors.surface,
                  borderRadius: AppRadii.mdAll,
                  border: Border.all(
                    color: selected.contains(slot) ? colors.primary : colors.border,
                    width: selected.contains(slot) ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(slot.label, style: context.type.bodyStrong),
                          const SizedBox(height: 2),
                          Text(
                            _hints[slot] ?? '',
                            style: context.type.caption.copyWith(color: colors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    AnimatedScale(
                      duration: AppMotion.fast,
                      curve: AppMotion.spring,
                      scale: selected.contains(slot) ? 1 : 0,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InterestsStep extends ConsumerWidget {
  const _InterestsStep({required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Interest>> catalog = ref.watch(interestCatalogProvider);

    return catalog.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxxl),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (Object error, _) => Text(
        'We could not load interests. You can add them later from your profile.',
        style: context.type.bodySmall.copyWith(color: context.colors.inkMuted),
      ),
      data: (List<Interest> interests) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${selected.length} of 12 selected',
            style: context.type.caption.copyWith(color: context.colors.inkFaint),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final Interest interest in interests)
                AppChip(
                  label: interest.label,
                  leading: interest.emoji.isEmpty
                      ? null
                      : Text(interest.emoji, style: const TextStyle(fontSize: 13)),
                  selected: selected.contains(interest.slug),
                  onTap: () {
                    final List<String> next = List<String>.of(selected);
                    if (next.contains(interest.slug)) {
                      next.remove(interest.slug);
                    } else if (next.length < 12) {
                      next.add(interest.slug);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutStep extends StatelessWidget {
  const _AboutStep({
    required this.bioController,
    required this.occupationController,
    required this.onChanged,
  });

  final TextEditingController bioController;
  final TextEditingController occupationController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextField(
          controller: bioController,
          label: 'About you',
          hint: 'Chronically early to films. Will debate the ending over coffee.',
          maxLines: 5,
          minLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          helper: '${bioController.text.length}/500',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          controller: occupationController,
          label: 'What you do (optional)',
          hint: 'Product designer',
          prefixIcon: Icons.work_outline_rounded,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}
