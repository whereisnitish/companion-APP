import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'settings_widgets.dart';

/// Safety advice written as advice, not as a liability disclaimer.
class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return SettingsScaffold(
      title: 'Safety centre',
      subtitle: 'Meeting a stranger should be exciting, not risky. A few habits '
          'make almost all of the difference.',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenX,
            0,
            AppSpacing.screenX,
            AppSpacing.xxl,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.dangerSoft,
              borderRadius: AppRadii.lgAll,
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.emergency_outlined, size: 20, color: colors.danger),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    'If you feel unsafe right now, leave first and report afterwards. '
                    'Nothing here is more important than that.',
                    style: type.bodySmall.copyWith(color: colors.danger, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Passage(
          icon: Icons.storefront_outlined,
          title: 'Meet somewhere public, the first few times',
          body: 'A cafe, a cinema foyer, a busy park. Save the quiet places for when '
              'you already know each other. Arrange to arrive and leave separately.',
        ),
        const Passage(
          icon: Icons.share_outlined,
          title: 'Tell one person where you are going',
          body: 'A friend, a flatmate, a sibling. Share the plan, the place and roughly '
              'when you expect to be done. It costs one message.',
        ),
        const Passage(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Keep the conversation in the app',
          body: 'Moving to another app early removes the record, and the record is what '
              'lets us act if something goes wrong. There is no rush.',
        ),
        const Passage(
          icon: Icons.directions_car_outlined,
          title: 'Make your own way there and back',
          body: 'Being able to leave whenever you want is the single most useful thing '
              'you can arrange in advance.',
        ),
        const Passage(
          icon: Icons.psychology_outlined,
          title: 'Trust the feeling before the evidence',
          body: 'If something is off, you do not owe anyone an explanation or a polite '
              'goodbye. Leave, block, and tell us. We would rather hear about ten '
              'things that turned out fine than miss one that did not.',
        ),
        SettingsGroup(
          label: 'If something goes wrong',
          children: <Widget>[
            const SettingsRow(
              icon: Icons.flag_outlined,
              label: 'Report someone',
              description: 'Open their profile and tap the ⋯ menu.',
            ),
            SettingsRow(
              icon: Icons.block_rounded,
              label: 'Blocked people',
              description: 'Review or undo a block',
              onTap: () => context.push(Routes.blocked),
            ),
            SettingsRow(
              icon: Icons.menu_book_outlined,
              label: 'Community guidelines',
              description: 'What gets someone removed',
              onTap: () => context.push(Routes.guidelines),
            ),
          ],
        ),
      ],
    );
  }
}
