import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../providers/core_providers.dart';
import '../../providers/feed_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/press_effect.dart';
import '../../widgets/success_burst.dart';

/// The invitation composer.
///
/// Two shapes, one sheet: joining a plan somebody already posted (activity is
/// known, so only the note is needed), or proposing something new (pick a
/// category and a rough time). Keeping both here means the moment of asking
/// looks the same wherever it starts.
Future<bool> showInviteSheet(
  BuildContext context, {
  required Profile profile,
  Activity? activity,
}) async {
  final bool? sent = await AppSheet.show<bool>(
    context,
    builder: (BuildContext sheetContext) => _InviteSheet(profile: profile, activity: activity),
  );
  return sent ?? false;
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.profile, this.activity});

  final Profile profile;
  final Activity? activity;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final TextEditingController _message = TextEditingController();

  ActivityCategory? _category;
  DateTime? _proposedAt;
  bool _isSending = false;
  bool _isSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to something they are already up for — one less decision.
    _category = widget.activity?.category ??
        (widget.profile.preferredActivities.isNotEmpty
            ? widget.profile.preferredActivities.first
            : ActivityCategory.coffee);
    _proposedAt = widget.activity?.startsAt;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _isJoiningPlan => widget.activity != null;
  bool get _canSend => _isJoiningPlan || (_category != null && _proposedAt != null);

  List<({String label, DateTime value})> get _quickTimes {
    final DateTime now = DateTime.now();
    final DateTime tonight = DateTime(now.year, now.month, now.day, 20, 0);
    final DateTime tomorrow = DateTime(now.year, now.month, now.day + 1, 19, 30);
    final int daysToSaturday = (DateTime.saturday - now.weekday + 7) % 7;
    final DateTime weekend = DateTime(
      now.year,
      now.month,
      now.day + (daysToSaturday == 0 ? 7 : daysToSaturday),
      11,
      0,
    );

    return <({String label, DateTime value})>[
      if (tonight.isAfter(now)) (label: 'Tonight', value: tonight),
      (label: 'Tomorrow', value: tomorrow),
      (label: 'This weekend', value: weekend),
    ];
  }

  Future<void> _pickCustomTime() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _proposedAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_proposedAt ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _proposedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _send() async {
    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await ref.read(invitationServiceProvider).send(
            recipientId: widget.profile.id,
            activityId: widget.activity?.id,
            category: widget.activity == null ? _category : null,
            proposedAt: widget.activity == null ? _proposedAt : null,
            locationName: widget.activity?.locationName,
            message: _message.text.trim(),
          );

      if (!mounted) return;
      invalidateSocialGraphFrom(ref);
      setState(() {
        _isSending = false;
        _isSent = true;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = 'We could not send that invitation. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSent) return _SentConfirmation(profile: widget.profile);

    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return AppSheet(
      title: _isJoiningPlan ? 'Ask to join' : 'Invite ${widget.profile.firstName}',
      subtitle: _isJoiningPlan ? widget.activity!.title : 'Suggest something, keep it simple.',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_error != null) ...<Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.error_outline_rounded, size: 16, color: colors.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _error!,
                    style: type.caption.copyWith(color: colors.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            label: _isJoiningPlan ? 'Send request' : 'Send invitation',
            icon: Icons.send_rounded,
            isLoading: _isSending,
            onPressed: _canSend ? _send : null,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _RecipientRow(profile: widget.profile),
            const SizedBox(height: AppSpacing.xxl),
            if (_isJoiningPlan)
              _PlanSummary(activity: widget.activity!)
            else ...<Widget>[
              Text('WHAT', style: type.overline.copyWith(color: colors.inkFaint)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final ActivityCategory category in _suggestedCategories)
                    CategoryChip(
                      category: category,
                      selected: _category == category,
                      dense: true,
                      onTap: () => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('WHEN', style: type.overline.copyWith(color: colors.inkFaint)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final ({String label, DateTime value}) option in _quickTimes)
                    AppChip(
                      label: option.label,
                      dense: true,
                      selected: _proposedAt == option.value,
                      onTap: () => setState(() => _proposedAt = option.value),
                    ),
                  AppChip(
                    label: _proposedAt != null && !_isQuickTime(_proposedAt!)
                        ? Format.whenShort(_proposedAt!)
                        : 'Pick a time',
                    icon: Icons.calendar_today_rounded,
                    dense: true,
                    selected: _proposedAt != null && !_isQuickTime(_proposedAt!),
                    onTap: _pickCustomTime,
                  ),
                ],
              ),
              if (_proposedAt != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  Format.whenLabel(_proposedAt!),
                  style: type.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppTextField(
              controller: _message,
              label: 'Add a note',
              hint: _isJoiningPlan
                  ? 'Say why you would be good company.'
                  : 'Keep it short and specific.',
              maxLines: 4,
              minLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  bool _isQuickTime(DateTime value) =>
      _quickTimes.any((({String label, DateTime value}) option) => option.value == value);

  /// Their preferences first, then the everyday ones — never all twelve.
  List<ActivityCategory> get _suggestedCategories {
    final List<ActivityCategory> ordered = <ActivityCategory>[
      ...widget.profile.preferredActivities,
      ActivityCategory.coffee,
      ActivityCategory.dinner,
      ActivityCategory.movie,
      ActivityCategory.walk,
    ];
    return ordered.toSet().take(6).toList(growable: false);
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        children: <Widget>[
          AppAvatar(
            name: profile.displayName,
            imageUrl: profile.avatarUrl,
            size: 40,
            isOnline: profile.isOnline,
            showPresence: true,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.displayName, style: context.type.bodyStrong),
                const SizedBox(height: 1),
                Text(
                  <String>[
                    if (profile.age != null) '${profile.age}',
                    if (profile.area != null) profile.area!,
                    Format.distance(profile.distanceKm),
                  ].where((String part) => part.isNotEmpty).join(' · '),
                  style: context.type.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: activity.category.tint(context),
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        children: <Widget>[
          CategoryBadge(category: activity.category, size: 38, radius: 12),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  Format.whenLabel(activity.startsAt),
                  style: type.label.copyWith(color: activity.category.foreground(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          SuccessBurst(size: 88, color: colors.primary),
          const SizedBox(height: AppSpacing.xxl),
          Text('Invitation sent', style: type.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${profile.firstName} has 3 days to reply. You will get a message the moment they do.',
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: colors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AppButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          PressEffect(
            onTap: () => Navigator.of(context).pop(true),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Keep browsing',
                style: type.label.copyWith(color: colors.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
