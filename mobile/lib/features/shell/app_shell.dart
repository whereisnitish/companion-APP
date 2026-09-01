import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/invitation.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/press_effect.dart';

/// Five destinations, in the order the product is actually used:
/// what's on → who's around → who asked → who you're talking to → you.
///
/// A stock BottomNavigationBar was tempting; it also looks like every other
/// app. This one is a hairline bar with an animated icon swap and badges that
/// count real things, which is the only decoration it gets.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const List<_Destination> _destinations = <_Destination>[
    _Destination(
      label: 'Home',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      route: Routes.home,
    ),
    _Destination(
      label: 'Discover',
      icon: Icons.search_rounded,
      activeIcon: Icons.saved_search_rounded,
      route: Routes.discover,
    ),
    _Destination(
      label: 'Invites',
      icon: Icons.mail_outline_rounded,
      activeIcon: Icons.mail_rounded,
      route: Routes.invites,
    ),
    _Destination(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      route: Routes.messages,
    ),
    _Destination(
      label: 'You',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      route: Routes.me,
    ),
  ];

  void _onTap(int index) {
    // Tapping the tab you are on pops that branch back to its root.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;

    final int pendingInvites = ref.watch(invitationCountsProvider).maybeWhen(
          data: (InvitationCounts counts) => counts.pendingReceived,
          orElse: () => 0,
        );
    final int unreadMessages = ref.watch(unreadMessagesProvider);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: <Widget>[
                for (int index = 0; index < _destinations.length; index += 1)
                  Expanded(
                    child: _NavItem(
                      destination: _destinations[index],
                      isSelected: shell.currentIndex == index,
                      badgeCount: switch (index) {
                        2 => pendingInvites,
                        3 => unreadMessages,
                        _ => 0,
                      },
                      onTap: () => _onTap(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final _Destination destination;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final Color tint = isSelected ? colors.ink : colors.inkFaint;

    return PressEffect(
      onTap: onTap,
      scale: 0.9,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              AnimatedSwitcher(
                duration: AppMotion.fast,
                transitionBuilder: (Widget child, Animation<double> animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isSelected ? destination.activeIcon : destination.icon,
                  key: ValueKey<bool>(isSelected),
                  size: 23,
                  color: tint,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: AppRadii.pillAll,
                      border: Border.all(color: colors.surface, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: type.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            style: type.caption.copyWith(
              color: tint,
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            child: Text(destination.label),
          ),
        ],
      ),
    );
  }
}
