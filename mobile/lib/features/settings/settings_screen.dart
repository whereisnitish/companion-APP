import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_sheet.dart';
import 'settings_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await showConfirmSheet(
      context,
      title: 'Sign out?',
      message: 'Your plans and conversations stay exactly where they are.',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (!confirmed) return;
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final CurrentUser? me = ref.watch(currentUserProvider);

    return SettingsScaffold(
      title: 'Settings',
      children: <Widget>[
        SettingsGroup(
          label: 'Account',
          children: <Widget>[
            SettingsRow(
              icon: Icons.person_outline_rounded,
              label: 'Edit profile',
              description: 'Photo, bio, interests and availability',
              onTap: () => context.push(Routes.editProfile),
            ),
            SettingsRow(
              icon: Icons.alternate_email_rounded,
              label: me?.email ?? me?.phone ?? 'Your account',
              description: 'Sign-in details',
            ),
            SettingsRow(
              icon: Icons.verified_outlined,
              label: 'Get verified',
              description: me?.verification.isVerified ?? false
                  ? 'Your profile is verified'
                  : 'Coming soon — a badge people can trust',
              trailing: Text(
                me?.verification.isVerified ?? false ? 'Verified' : 'Soon',
                style: type.caption.copyWith(color: colors.inkFaint),
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Privacy and safety',
          children: <Widget>[
            SettingsRow(
              icon: Icons.lock_outline_rounded,
              label: 'Privacy',
              description: 'Who can find you, and what they see',
              onTap: () => context.push(Routes.privacy),
            ),
            SettingsRow(
              icon: Icons.shield_outlined,
              label: 'Safety centre',
              description: 'Meeting someone new, sensibly',
              onTap: () => context.push(Routes.safety),
            ),
            SettingsRow(
              icon: Icons.block_rounded,
              label: 'Blocked people',
              description: 'Manage who you have blocked',
              onTap: () => context.push(Routes.blocked),
            ),
            SettingsRow(
              icon: Icons.menu_book_outlined,
              label: 'Community guidelines',
              description: 'What we expect from everyone here',
              onTap: () => context.push(Routes.guidelines),
            ),
          ],
        ),
        const SettingsGroup(
          label: 'Notifications',
          children: <Widget>[
            _NotificationToggle(
              icon: Icons.mail_outline_rounded,
              label: 'New invitations',
              settingKey: 'invitations',
            ),
            _NotificationToggle(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Messages',
              settingKey: 'messages',
            ),
            _NotificationToggle(
              icon: Icons.schedule_rounded,
              label: 'Plan reminders',
              settingKey: 'reminders',
            ),
          ],
        ),
        SettingsGroup(
          label: 'About',
          children: <Widget>[
            const SettingsRow(
              icon: Icons.info_outline_rounded,
              label: 'About Companion',
              description: 'Version 0.1.0 · MVP',
            ),
            const SettingsRow(
              icon: Icons.mail_outline_rounded,
              label: 'Contact us',
              description: AppConfig.supportEmail,
            ),
            SettingsRow(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              tone: colors.danger,
              onTap: () => _signOut(context, ref),
            ),
          ],
        ),
        Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'Companion is an MVP. Verification, photo uploads and push delivery are stubbed — everything else here is real, and talks to your own server.',
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: colors.inkFaint, height: 1.6),
          ),
        ),
      ],
    );
  }
}

/// Local-only for the MVP: the switch is real, the delivery channel is not yet.
/// Wiring it to a `/users/me/notification-preferences` endpoint later is a
/// change to this widget alone.
class _NotificationToggle extends StatefulWidget {
  const _NotificationToggle({
    required this.icon,
    required this.label,
    required this.settingKey,
  });

  final IconData icon;
  final String label;
  final String settingKey;

  @override
  State<_NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<_NotificationToggle> {
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      icon: widget.icon,
      label: widget.label,
      trailing: Switch(
        value: _enabled,
        onChanged: (bool value) => setState(() => _enabled = value),
      ),
      onTap: () => setState(() => _enabled = !_enabled),
    );
  }
}
