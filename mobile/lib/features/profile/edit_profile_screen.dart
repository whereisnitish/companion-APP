import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/locations.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feed_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/press_effect.dart';

/// Everything from setup, on one screen, with a Save that only lights up when
/// something has actually changed.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _occupation;

  late List<ActivityCategory> _activities;
  late List<AvailabilitySlot> _availability;
  late List<String> _interests;
  late String? _avatarUrl;
  late Place _place;

  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final CurrentUser? me = ref.read(currentUserProvider);
    _name = TextEditingController(text: me?.displayName ?? '');
    _bio = TextEditingController(text: me?.bio ?? '');
    _occupation = TextEditingController(text: me?.occupation ?? '');
    _activities = List<ActivityCategory>.of(me?.preferredActivities ?? const <ActivityCategory>[]);
    _availability = List<AvailabilitySlot>.of(me?.availability ?? const <AvailabilitySlot>[]);
    _interests = (me?.interests ?? const <Interest>[]).map((Interest i) => i.slug).toList();
    _avatarUrl = me?.avatarUrl;
    _place = Places.byName(me?.area) ?? Places.fallback;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _occupation.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final CurrentUser updated =
          await ref.read(profileServiceProvider).updateProfile(<String, dynamic>{
        'displayName': _name.text.trim(),
        'bio': _bio.text.trim(),
        'occupation': _occupation.text.trim(),
        'avatarUrl': _avatarUrl,
        'city': _place.city,
        'area': _place.name,
        'latitude': _place.latitude,
        'longitude': _place.longitude,
        'preferredActivities':
            _activities.map((ActivityCategory c) => c.wire).toList(growable: false),
        'availability': _availability.map((AvailabilitySlot a) => a.wire).toList(growable: false),
        'interests': _interests,
      });

      if (!mounted) return;
      ref.read(authControllerProvider.notifier).setUser(updated);
      ref.invalidate(homeFeedProvider);
      ref.invalidate(discoverPeopleProvider);
      AppSnackbar.success(context, 'Profile updated.');
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, error.message);
    }
  }

  Future<void> _pickAvatar() async {
    final String? picked = await AppSheet.show<String>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: 'Choose a photo',
        subtitle: 'Uploads land in a later release.',
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: StockPortraits.options.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
          ),
          itemBuilder: (BuildContext context, int index) {
            final String url = StockPortraits.options[index];
            return PressEffect(
              onTap: () => Navigator.of(sheetContext).pop(url),
              scale: 0.92,
              child: ClipRRect(
                borderRadius: AppRadii.smAll,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: sheetContext.colors.surfaceSunken),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _avatarUrl = picked;
        _isDirty = true;
      });
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
            icon: Icons.arrow_back_rounded,
            bordered: false,
            background: Colors.transparent,
            onPressed: () => context.pop(),
          ),
        ),
        leadingWidth: 60,
        title: const Text('Edit profile'),
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
          label: 'Save changes',
          isLoading: _isSaving,
          onPressed: _isDirty ? _save : null,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenX,
          AppSpacing.lg,
          AppSpacing.screenX,
          AppSpacing.giant,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: <Widget>[
          Center(
            child: PressEffect(
              onTap: _pickAvatar,
              scale: 0.94,
              child: Stack(
                children: <Widget>[
                  AppAvatar(
                    name: _name.text.isEmpty ? 'You' : _name.text,
                    imageUrl: _avatarUrl,
                    size: 96,
                    ring: colors.primary,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.canvas, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AppTextField(
            controller: _name,
            label: 'Name',
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _occupation,
            label: 'What you do',
            hint: 'Optional',
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _bio,
            label: 'About you',
            maxLines: 5,
            minLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text('AREA', style: type.overline.copyWith(color: colors.inkFaint)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final Place place in Places.all)
                AppChip(
                  label: place.name,
                  dense: true,
                  selected: place == _place,
                  onTap: () => setState(() {
                    _place = place;
                    _isDirty = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text('UP FOR', style: type.overline.copyWith(color: colors.inkFaint)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final ActivityCategory category in ActivityCategory.values)
                CategoryChip(
                  category: category,
                  dense: true,
                  selected: _activities.contains(category),
                  onTap: () => setState(() {
                    _activities.contains(category)
                        ? _activities.remove(category)
                        : _activities.add(category);
                    _isDirty = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text('USUALLY FREE', style: type.overline.copyWith(color: colors.inkFaint)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final AvailabilitySlot slot in AvailabilitySlot.values)
                AppChip(
                  label: slot.label,
                  dense: true,
                  selected: _availability.contains(slot),
                  onTap: () => setState(() {
                    _availability.contains(slot)
                        ? _availability.remove(slot)
                        : _availability.add(slot);
                    _isDirty = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text('INTERESTS', style: type.overline.copyWith(color: colors.inkFaint)),
          const SizedBox(height: AppSpacing.md),
          _InterestPicker(
            selected: _interests,
            onChanged: (List<String> value) => setState(() {
              _interests = value;
              _isDirty = true;
            }),
          ),
        ],
      ),
    );
  }
}

class _InterestPicker extends ConsumerWidget {
  const _InterestPicker({required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(interestCatalogProvider).maybeWhen(
          data: (List<Interest> interests) => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final Interest interest in interests)
                AppChip(
                  label: interest.label,
                  dense: true,
                  leading: interest.emoji.isEmpty
                      ? null
                      : Text(interest.emoji, style: const TextStyle(fontSize: 12)),
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
          orElse: () => const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
  }
}
