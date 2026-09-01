import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/entrance.dart';

/// Shared chrome for sign-in and sign-up: a back affordance, a serif title,
/// a supporting line, then the form. Keeping this in one place is why both
/// screens feel like the same moment in the product rather than two forms.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Scaffold(
      backgroundColor: colors.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: <Widget>[
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    bordered: false,
                    background: Colors.transparent,
                    onPressed: () => context.canPop() ? context.pop() : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xl,
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
                  for (int index = 0; index < children.length; index += 1)
                    Entrance(index: index + 2, child: children[index]),
                ],
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  0,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
