import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enums.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/entrance.dart';
import '../onboarding/brand_mark.dart';

/// The doorway. One promise, one primary action, one quiet alternative.
/// The drifting category tiles do the selling so the copy does not have to.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        // Spacers give the layout its air on a tall phone; the scroll view and
        // IntrinsicHeight keep it intact on a short one instead of overflowing.
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Spacer(flex: 2),
                    const Entrance(child: _DriftingCategories()),
                    const Spacer(flex: 2),
                    Entrance(
                      index: 1,
                      child: BrandMark(size: 40, color: colors.primary, accentColor: colors.accent),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Entrance(
                      index: 2,
                      child: Text('Never do\nit alone.', style: type.display),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Entrance(
                      index: 3,
                      child: Text(
                        'Find someone nearby who wants to do the same thing, at the same time.',
                        style: type.body.copyWith(color: colors.inkMuted, height: 1.6),
                      ),
                    ),
                    const Spacer(),
                    Entrance(
                      index: 4,
                      child: AppButton(
                        label: 'Create an account',
                        onPressed: () => context.push(Routes.signUp),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Entrance(
                      index: 5,
                      child: AppButton.secondary(
                        label: 'I already have one',
                        onPressed: () => context.push(Routes.signIn),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Entrance(
                      index: 6,
                      child: Center(
                        child: SizedBox(
                          width: 300,
                          child: Text(
                            'By continuing you agree to our Community Guidelines and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: type.caption.copyWith(color: colors.inkFaint, height: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two rows of category pills scrolling slowly in opposite directions — the
/// product's vocabulary, shown rather than listed.
class _DriftingCategories extends StatefulWidget {
  const _DriftingCategories();

  @override
  State<_DriftingCategories> createState() => _DriftingCategoriesState();
}

class _DriftingCategoriesState extends State<_DriftingCategories>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const List<ActivityCategory> top = <ActivityCategory>[
      ActivityCategory.movie,
      ActivityCategory.dinner,
      ActivityCategory.coffee,
      ActivityCategory.concert,
      ActivityCategory.walk,
      ActivityCategory.travel,
    ];
    const List<ActivityCategory> bottom = <ActivityCategory>[
      ActivityCategory.sports,
      ActivityCategory.shopping,
      ActivityCategory.gaming,
      ActivityCategory.study,
      ActivityCategory.event,
      ActivityCategory.other,
    ];

    return SizedBox(
      height: 116,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Column(
            children: <Widget>[
              _Marquee(categories: top, offset: _controller.value, reverse: false),
              const SizedBox(height: AppSpacing.md),
              _Marquee(categories: bottom, offset: _controller.value, reverse: true),
            ],
          );
        },
      ),
    );
  }
}

class _Marquee extends StatelessWidget {
  const _Marquee({required this.categories, required this.offset, required this.reverse});

  final List<ActivityCategory> categories;
  final double offset;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    const double itemWidth = 132;
    final double span = categories.length * itemWidth;
    final double shift = (reverse ? -offset : offset) * span;

    return SizedBox(
      height: 50,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: Offset(reverse ? shift : -shift, 0),
            child: Row(
              children: <Widget>[
                // Two copies make the loop seamless at any offset.
                for (int copy = 0; copy < 2; copy += 1)
                  for (final ActivityCategory category in categories)
                    _CategoryPill(category: category, width: itemWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, required this.width});

  final ActivityCategory category;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      width: width - AppSpacing.md,
      height: 46,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(category.icon, size: 17, color: category.foreground(context)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.label.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
