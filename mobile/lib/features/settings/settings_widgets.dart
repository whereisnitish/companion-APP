import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/press_effect.dart';

/// Chrome shared by every settings-family screen: a back button, a serif
/// title, and a body that scrolls under it. Written once so Privacy, Safety and
/// Guidelines cannot drift apart.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.screenX,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PressEffect(
                      onTap: () => Navigator.of(context).maybePop(),
                      scale: 0.9,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Icon(Icons.arrow_back_rounded, color: colors.ink),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Text(title, style: type.headline),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: Text(
                          subtitle!,
                          style: type.body.copyWith(color: colors.inkMuted, height: 1.55),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
            SliverList(delegate: SliverChildListDelegate(children)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.giant)),
          ],
        ),
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.screenX,
              bottom: AppSpacing.md,
            ),
            child: Text(
              label.toUpperCase(),
              style: context.type.overline.copyWith(color: colors.inkFaint),
            ),
          ),
          Container(
            margin: AppSpacing.screenPadding,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadii.lgAll,
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < children.length; index += 1) ...<Widget>[
                  children[index],
                  if (index != children.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.giant),
                      child: Divider(color: colors.border, height: 1),
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

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    this.trailing,
    this.onTap,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String? description;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final Color foreground = tone ?? colors.ink;

    return PressEffect(
      onTap: onTap,
      scale: 0.995,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg - 2,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: type.body.copyWith(color: foreground)),
                  if (description != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: type.caption.copyWith(color: colors.inkMuted, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 20, color: colors.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// A prose block for the guidelines and safety screens.
class Passage extends StatelessWidget {
  const Passage({super.key, required this.title, required this.body, this.icon});

  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenX,
        0,
        AppSpacing.screenX,
        AppSpacing.xxl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: AppRadii.smAll,
              ),
              child: Icon(icon, size: 16, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: type.bodyStrong),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body,
                  style: type.body.copyWith(color: colors.inkMuted, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
