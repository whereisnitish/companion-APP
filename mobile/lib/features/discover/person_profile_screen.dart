import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../providers/feed_providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/entrance.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/state_views.dart';
import '../invitations/invite_sheet.dart';
import '../settings/safety_actions.dart';

/// A person, at full size.
///
/// The photo gets real estate because it is what people look at first, but the
/// screen is organised around the question that matters here: *would I spend an
/// evening with them, doing what?* So "Up for" and "Free" sit above the bio.
class PersonProfileScreen extends ConsumerWidget {
  const PersonProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<Profile> profile = ref.watch(profileByIdProvider(userId));

    return Scaffold(
      backgroundColor: colors.canvas,
      body: profile.when(
        loading: () => const _ProfileSkeleton(),
        error: (Object error, _) => SafeArea(
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
              Expanded(
                child: StateView.fromError(
                  error,
                  onRetry: () => ref.invalidate(profileByIdProvider(userId)),
                ),
              ),
            ],
          ),
        ),
        data: (Profile person) => _ProfileBody(person: person),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.person});

  final Profile person;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  final PageController _photos = PageController();
  int _photoIndex = 0;

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  Profile get person => widget.person;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final List<String> gallery = person.gallery;
    final double photoHeight = MediaQuery.sizeOf(context).height * 0.52;

    return Stack(
      children: <Widget>[
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: SizedBox(
                height: photoHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (gallery.isEmpty)
                      Container(
                        color: colors.surfaceSunken,
                        alignment: Alignment.center,
                        child: AppAvatar(name: person.displayName, size: 128),
                      )
                    else
                      PageView.builder(
                        controller: _photos,
                        itemCount: gallery.length,
                        onPageChanged: (int index) => setState(() => _photoIndex = index),
                        itemBuilder: (BuildContext context, int index) => CachedNetworkImage(
                          imageUrl: gallery[index],
                          fit: BoxFit.cover,
                          fadeInDuration: AppMotion.base,
                          placeholder: (_, __) => Container(color: colors.shimmerBase),
                          errorWidget: (_, __, ___) => Container(
                            color: colors.surfaceSunken,
                            alignment: Alignment.center,
                            child: AppAvatar(name: person.displayName, size: 110),
                          ),
                        ),
                      ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: <double>[0, 0.28, 0.72, 1],
                            colors: <Color>[
                              Color(0x66000000),
                              Colors.transparent,
                              Colors.transparent,
                              Color(0x40000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (gallery.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: AppSpacing.xxxl,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            for (int index = 0; index < gallery.length; index += 1)
                              AnimatedContainer(
                                duration: AppMotion.fast,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                height: 3,
                                width: index == _photoIndex ? 20 : 8,
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: index == _photoIndex ? 0.95 : 0.45),
                                  borderRadius: AppRadii.pillAll,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -AppSpacing.xxl),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.canvas,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.xl),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenX,
                    AppSpacing.xxl,
                    AppSpacing.screenX,
                    140,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Entrance(child: _Identity(person: person)),
                      const SizedBox(height: AppSpacing.xl),
                      Entrance(index: 1, child: _MetaRow(person: person)),
                      if (person.preferredActivities.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxxl),
                        Entrance(
                          index: 2,
                          child: _Block(
                            label: 'Up for',
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: <Widget>[
                                for (final ActivityCategory category in person.preferredActivities)
                                  CategoryChip(category: category, selected: true),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (person.availability.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxl),
                        Entrance(
                          index: 3,
                          child: _Block(
                            label: 'Usually free',
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: <Widget>[
                                for (final AvailabilitySlot slot in person.availability)
                                  AppChip(
                                    label: slot.label,
                                    icon: Icons.schedule_rounded,
                                    tint: colors.primarySoft,
                                    foreground: colors.primary,
                                    selected: true,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (person.bio.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxl),
                        Entrance(
                          index: 4,
                          child: _Block(
                            label: 'About',
                            child: Text(
                              person.bio,
                              style: type.body.copyWith(height: 1.65, color: colors.ink),
                            ),
                          ),
                        ),
                      ],
                      if (person.interests.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxl),
                        Entrance(
                          index: 5,
                          child: _Block(
                            label: 'Into',
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: <Widget>[
                                for (final Interest interest in person.interests)
                                  AppChip(
                                    label: interest.label,
                                    dense: true,
                                    leading: interest.emoji.isEmpty
                                        ? null
                                        : Text(
                                            interest.emoji,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxxl),
                      Entrance(index: 6, child: _TrustPanel(person: person)),
                      const SizedBox(height: AppSpacing.xxl),
                      Entrance(
                        index: 7,
                        child: Center(
                          child: AppButton.ghost(
                            label: 'Report or block ${person.firstName}',
                            icon: Icons.shield_outlined,
                            size: AppButtonSize.small,
                            onPressed: () => showSafetyActionsSheet(
                              context,
                              userId: person.id,
                              displayName: person.displayName,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Floating chrome, so the photo is never covered by a solid bar.
        Positioned(
          top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          child: Row(
            children: <Widget>[
              AppIconButton(
                icon: Icons.arrow_back_rounded,
                background: Colors.black.withValues(alpha: 0.36),
                foreground: Colors.white,
                bordered: false,
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              AppIconButton(
                icon: Icons.more_horiz_rounded,
                background: Colors.black.withValues(alpha: 0.36),
                foreground: Colors.white,
                bordered: false,
                onPressed: () => showSafetyActionsSheet(
                  context,
                  userId: person.id,
                  displayName: person.displayName,
                ),
              ),
            ],
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _InviteBar(person: person),
        ),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                person.age == null ? person.displayName : '${person.displayName}, ${person.age}',
                style: type.headline,
              ),
            ),
            if (person.verification.isVerified) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: VerifiedBadge(size: 20, status: person.verification),
              ),
            ],
          ],
        ),
        if (person.occupation != null && person.occupation!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            person.occupation!,
            style: type.body.copyWith(color: colors.inkMuted),
          ),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    Widget item(IconData icon, String label, {Color? tint}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: tint ?? colors.inkFaint),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(label, style: type.caption.copyWith(color: tint ?? colors.inkMuted)),
          ],
        );

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        if (person.area != null && person.area!.isNotEmpty)
          item(Icons.place_outlined, person.area!),
        if (person.distanceKm != null)
          item(Icons.near_me_outlined, Format.distance(person.distanceKm)),
        item(
          person.isOnline ? Icons.circle : Icons.schedule_rounded,
          Format.lastSeen(person.lastActiveAt, isOnline: person.isOnline),
          tint: person.isOnline ? colors.success : null,
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: context.type.overline.copyWith(color: context.colors.inkFaint),
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

/// Reputation and verification, shown together because that is how someone
/// actually decides whether to meet a stranger. Both are read-only placeholders
/// in the MVP; the shape is what a real trust system would fill in.
class _TrustPanel extends StatelessWidget {
  const _TrustPanel({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.star_rounded, size: 17, color: colors.warning),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      person.ratingCount == 0
                          ? 'New here'
                          : person.ratingAverage.toStringAsFixed(1),
                      style: type.bodyStrong,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  person.ratingCount == 0
                      ? 'No meet-ups yet'
                      : 'from ${person.ratingCount} meet-ups',
                  style: type.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 34, color: colors.border),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      person.verification.isVerified
                          ? Icons.verified_rounded
                          : Icons.shield_outlined,
                      size: 17,
                      color: person.verification.isVerified ? colors.primary : colors.inkFaint,
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      person.verification.isVerified ? 'Verified' : 'Unverified',
                      style: type.bodyStrong,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  person.verification.isVerified ? 'Photo and ID checked' : 'Meet somewhere public',
                  style: type.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteBar extends StatelessWidget {
  const _InviteBar({required this.person});

  final Profile person;

  /// The one next step that makes sense given how you already stand with them.
  Widget _action(BuildContext context) {
    final PersonConnection? connection = person.connection;
    final String? conversationId = connection?.conversationId;

    return switch (connection?.status) {
      ConnectionStatus.connected when conversationId != null => AppButton(
          label: 'Open chat',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () => context.push(Routes.chat(conversationId)),
        ),
      ConnectionStatus.invitedByMe => const AppButton(
          label: 'Invitation sent',
          icon: Icons.schedule_rounded,
          onPressed: null,
        ),
      ConnectionStatus.invitedMe => AppButton(
          label: 'Answer their invitation',
          icon: Icons.mail_outline_rounded,
          onPressed: () => context.go(Routes.invites),
        ),
      _ => AppButton(
          label: 'Invite ${person.firstName}',
          icon: Icons.send_rounded,
          onPressed: () => showInviteSheet(context, profile: person),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Container(
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
      child: _action(context),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBox(height: MediaQuery.sizeOf(context).height * 0.5, radius: 0),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.screenX),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 200, height: 28),
                SizedBox(height: AppSpacing.md),
                SkeletonBox(width: 130, height: 14),
                SizedBox(height: AppSpacing.xxl),
                SkeletonBox(height: 14),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 240, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
