import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'settings_widgets.dart';

/// Short, specific rules. A long policy nobody reads protects nobody.
class GuidelinesScreen extends ConsumerWidget {
  const GuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return SettingsScaffold(
      title: 'Community guidelines',
      subtitle: 'Companion is for doing things with people. Five rules keep it '
          'that way.',
      children: <Widget>[
        const Passage(
          icon: Icons.event_available_outlined,
          title: '1. Show up',
          body: 'If you accept an invitation, go. If your plans change, say so as early '
              'as you can. Repeatedly leaving people waiting is the fastest way to '
              'lose your account.',
        ),
        const Passage(
          icon: Icons.face_outlined,
          title: '2. Be who you say you are',
          body: 'Your real name, your real age, a recent photo of you. Impersonation and '
              'catfishing get removed on the first report.',
        ),
        const Passage(
          icon: Icons.handshake_outlined,
          title: '3. This is not a dating app',
          body: 'People are here for the activity. Anyone can say yes to a film and no to '
              'anything else. Sexual, aggressive or persistent messages after a clear '
              'no are grounds for removal.',
        ),
        const Passage(
          icon: Icons.currency_rupee_rounded,
          title: '4. No selling, no soliciting',
          body: 'No promotion, no recruiting, no asking for money, no crypto, no '
              '"investment opportunities". Every account doing this gets removed.',
        ),
        const Passage(
          icon: Icons.diversity_3_outlined,
          title: '5. Everyone is welcome',
          body: 'Harassment or hate on the basis of gender, caste, religion, sexuality, '
              'disability, race or anything else is not tolerated once.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenX,
            AppSpacing.sm,
            AppSpacing.screenX,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: AppRadii.lgAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('How we enforce this', style: type.bodyStrong),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Every report is read by a person. Depending on what happened we warn, '
                  'restrict, or remove the account — and we tell you what we did with '
                  'your report. Serious cases are escalated to the authorities.',
                  style: type.bodySmall.copyWith(color: colors.inkMuted, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
