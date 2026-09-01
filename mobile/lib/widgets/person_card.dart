import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../models/enums.dart';
import '../models/profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_avatar.dart';
import 'app_button.dart';
import 'app_chip.dart';
import 'press_effect.dart';

/// The full-width person card used in Discover.
///
/// Reading order is deliberate: face, then who they are, then what they are up
/// for, then when — and only then the invite button. Someone should be able to
/// decide from the card alone, which is why the bio is here and not hidden
/// behind a tap.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.profile,
    this.onTap,
    this.onInvite,
    this.aspectRatio = 4 / 5,
  });

  final Profile profile;
  final VoidCallback? onTap;
  final VoidCallback? onInvite;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return PressEffect(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.xlAll,
          border: Border.all(color: colors.border),
          boxShadow: AppShadows.resting(colors.ink),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: aspectRatio,
              child: _PhotoHeader(profile: profile),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (profile.bio.isNotEmpty) ...<Widget>[
                    Text(
                      profile.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.body.copyWith(color: colors.inkMuted, height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (profile.preferredActivities.isNotEmpty) ...<Widget>[
                    Text(
                      'UP FOR',
                      style: type.overline.copyWith(color: colors.inkFaint),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final ActivityCategory category in profile.preferredActivities.take(4))
                          CategoryChip(category: category, selected: true, dense: true),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Divider(color: colors.border, height: 1),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(child: _AvailabilityLine(profile: profile)),
                      const SizedBox(width: AppSpacing.md),
                      AppButton(
                        label: 'Invite',
                        size: AppButtonSize.small,
                        expand: false,
                        icon: Icons.send_rounded,
                        onPressed: onInvite,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo, scrim, and the identity line — shared by the card and the profile
/// screen's header so a name never sits differently in two places.
class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final String? photo = profile.gallery.isEmpty ? null : profile.gallery.first;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (photo != null)
          CachedNetworkImage(
            imageUrl: photo,
            fit: BoxFit.cover,
            fadeInDuration: AppMotion.base,
            placeholder: (_, __) => Container(color: colors.shimmerBase),
            errorWidget: (_, __, ___) => _PhotoFallback(profile: profile),
          )
        else
          _PhotoFallback(profile: profile),

        // A scrim only where the text sits, so the photo stays a photo.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.transparent, Color(0xB3000000)],
            ),
          ),
        ),

        if (profile.isOnline)
          Positioned(
            top: AppSpacing.lg,
            left: AppSpacing.lg,
            child: _GlassPill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: 6,
                    width: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5DD39E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Active now',
                    style: type.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (profile.distanceKm != null)
          Positioned(
            top: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _GlassPill(
              child: Text(
                Format.distanceShort(profile.distanceKm),
                style: type.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),

        Positioned(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          bottom: AppSpacing.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.serifTitle.copyWith(color: Colors.white),
                    ),
                  ),
                  if (profile.verification.isVerified) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.verified_rounded, size: 17, color: Colors.white),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                <String>[
                  if (profile.age != null) '${profile.age}',
                  if (profile.area != null && profile.area!.isNotEmpty) profile.area!,
                  if (profile.occupation != null && profile.occupation!.isNotEmpty)
                    profile.occupation!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.82)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surfaceSunken,
      alignment: Alignment.center,
      child: AppAvatar(name: profile.displayName, size: 92),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: child,
    );
  }
}

class _AvailabilityLine extends StatelessWidget {
  const _AvailabilityLine({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    if (profile.availability.isEmpty) {
      return Text(
        Format.lastSeen(profile.lastActiveAt, isOnline: profile.isOnline),
        style: type.caption.copyWith(color: colors.inkFaint),
      );
    }

    return Row(
      children: <Widget>[
        Icon(Icons.schedule_rounded, size: 14, color: colors.inkFaint),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            'Free ${profile.availability.map((AvailabilitySlot slot) => slot.label.toLowerCase()).join(' · ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.caption.copyWith(color: colors.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// The narrow card used in Home's horizontal rails.
class PersonPreviewCard extends StatelessWidget {
  const PersonPreviewCard({
    super.key,
    required this.profile,
    this.onTap,
    this.onInvite,
    this.width = 232,
  });

  final Profile profile;
  final VoidCallback? onTap;
  final VoidCallback? onInvite;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return PressEffect(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: colors.border),
          boxShadow: AppShadows.resting(colors.ink),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: width * 0.92, child: _PhotoHeader(profile: profile)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    height: 36,
                    child: Text(
                      profile.bio.isEmpty ? 'Up for something soon.' : profile.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodySmall.copyWith(color: colors.inkMuted, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      for (final ActivityCategory category in profile.preferredActivities.take(3))
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
                          child: Container(
                            height: 26,
                            width: 26,
                            decoration: BoxDecoration(
                              color: category.tint(context),
                              borderRadius: AppRadii.smAll,
                            ),
                            child: Icon(
                              category.icon,
                              size: 14,
                              color: category.foreground(context),
                            ),
                          ),
                        ),
                      const Spacer(),
                      AppIconButton(
                        icon: Icons.send_rounded,
                        size: 32,
                        iconSize: 15,
                        background: colors.primary,
                        foreground: colors.onPrimary,
                        bordered: false,
                        onPressed: onInvite,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
