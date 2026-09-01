import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../models/activity.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_avatar.dart';
import 'app_button.dart';
import 'app_chip.dart';
import 'press_effect.dart';

/// A posted plan.
///
/// The when is the loudest thing on the card — it is what decides whether the
/// plan is relevant at all — followed by what it is, then who is hosting.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.onInvite,
    this.showHost = true,
  });

  final Activity activity;
  final VoidCallback? onTap;
  final VoidCallback? onInvite;
  final bool showHost;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final Color hue = activity.category.foreground(context);
    final bool alreadyInvited = activity.viewerInvitationStatus != null;

    return PressEffect(
      onTap: onTap,
      scale: 0.99,
      child: Container(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CategoryBadge(category: activity.category),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          Format.whenLabel(activity.startsAt).toUpperCase(),
                          style: type.overline.copyWith(color: hue),
                        ),
                        const SizedBox(height: AppSpacing.xs + 2),
                        Text(
                          activity.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: type.subtitle.copyWith(height: 1.35),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.place_outlined,
                              size: 13,
                              color: colors.inkFaint,
                            ),
                            const SizedBox(width: AppSpacing.xs + 1),
                            Flexible(
                              child: Text(
                                <String>[
                                  activity.locationName,
                                  if (activity.distanceKm != null)
                                    Format.distanceShort(activity.distanceKm),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.caption.copyWith(color: colors.inkMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (activity.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(
                  activity.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall.copyWith(color: colors.inkMuted, height: 1.5),
                ),
              ),
            if (showHost)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSunken.withValues(alpha: 0.6),
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: <Widget>[
                    AppAvatar(
                      name: activity.host.displayName,
                      imageUrl: activity.host.avatarUrl,
                      size: 30,
                      isOnline: activity.host.isOnline,
                      showPresence: activity.host.isOnline,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              activity.isHost ? 'You' : activity.host.firstName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.label,
                            ),
                          ),
                          if (activity.host.verification.isVerified) ...<Widget>[
                            const SizedBox(width: AppSpacing.xs),
                            VerifiedBadge(size: 13, status: activity.host.verification),
                          ],
                          if (activity.host.age != null) ...<Widget>[
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${activity.host.age}',
                              style: type.caption.copyWith(color: colors.inkFaint),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (activity.isHost)
                      Text(
                        'Your plan',
                        style: type.caption.copyWith(color: colors.inkFaint),
                      )
                    else if (alreadyInvited)
                      StatusPill(status: activity.viewerInvitationStatus!)
                    else
                      AppButton(
                        label: 'Join',
                        size: AppButtonSize.small,
                        expand: false,
                        onPressed: onInvite,
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

/// The compact activity tile used in Home's "Happening tonight" rail.
class ActivityPreviewCard extends StatelessWidget {
  const ActivityPreviewCard({
    super.key,
    required this.activity,
    this.onTap,
    this.width = 260,
  });

  final Activity activity;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final Color hue = activity.category.foreground(context);

    return PressEffect(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: colors.border),
          boxShadow: AppShadows.resting(colors.ink),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CategoryBadge(category: activity.category, size: 32, radius: 10),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    Format.whenShort(activity.startsAt).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.overline.copyWith(color: hue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 44,
              child: Text(
                activity.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: type.bodyStrong.copyWith(height: 1.4),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                AppAvatar(
                  name: activity.host.displayName,
                  imageUrl: activity.host.avatarUrl,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    activity.isHost ? 'Your plan' : activity.host.firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.caption.copyWith(color: colors.inkMuted),
                  ),
                ),
                if (activity.distanceKm != null)
                  Text(
                    Format.distanceShort(activity.distanceKm),
                    style: type.caption.copyWith(color: colors.inkFaint),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
