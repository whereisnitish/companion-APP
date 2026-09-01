import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feed_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_snackbar.dart';
import 'settings_widgets.dart';

/// Three switches, each one an honest description of what changes for other
/// people. Privacy copy that says "manage your preferences" says nothing.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _isSaving = false;

  Future<void> _update(String field, bool value) async {
    setState(() => _isSaving = true);
    try {
      final CurrentUser updated =
          await ref.read(profileServiceProvider).updateProfile(<String, dynamic>{field: value});
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).setUser(updated);
      ref.invalidate(discoverPeopleProvider);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final CurrentUser? me = ref.watch(currentUserProvider);

    return SettingsScaffold(
      title: 'Privacy',
      subtitle: 'You decide how much of you is visible, and to whom.',
      children: <Widget>[
        SettingsGroup(
          label: 'Discovery',
          children: <Widget>[
            SettingsRow(
              icon: Icons.explore_outlined,
              label: 'Show me in discovery',
              description: 'Turn this off and nobody new can find you. '
                  'Existing conversations keep working.',
              trailing: Switch(
                value: me?.isDiscoverable ?? true,
                onChanged: _isSaving ? null : (bool value) => _update('isDiscoverable', value),
              ),
            ),
            SettingsRow(
              icon: Icons.near_me_outlined,
              label: 'Show my distance',
              description: 'Others see roughly how far away you are, never where.',
              trailing: Switch(
                value: me?.showDistance ?? true,
                onChanged: _isSaving ? null : (bool value) => _update('showDistance', value),
              ),
            ),
            SettingsRow(
              icon: Icons.cake_outlined,
              label: 'Show my age',
              description: 'Your age still counts towards other people’s filters.',
              trailing: Switch(
                value: me?.showAge ?? true,
                onChanged: _isSaving ? null : (bool value) => _update('showAge', value),
              ),
            ),
          ],
        ),
        const Passage(
          icon: Icons.place_outlined,
          title: 'What we know about where you are',
          body: 'Companion stores the neighbourhood you picked, not a live location. '
              'We never track you in the background and never show anyone an address. '
              'Distances are calculated from area centres, so "2.4 km away" means '
              'roughly, not exactly.',
        ),
        const Passage(
          icon: Icons.visibility_off_outlined,
          title: 'What other people never see',
          body: 'Your email address, your phone number, your filters, and every profile '
              'you looked at but did not invite. Blocking is silent — the other '
              'person is never told.',
        ),
        Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'A full data export and account deletion are planned for the next release.',
            style: type.caption.copyWith(color: colors.inkFaint, height: 1.6),
          ),
        ),
      ],
    );
  }
}
