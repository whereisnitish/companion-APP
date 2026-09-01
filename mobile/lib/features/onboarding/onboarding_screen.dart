import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import 'brand_mark.dart';

class _Page {
  const _Page({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.palette,
  });

  final String eyebrow;
  final String title;
  final String body;
  final List<Color> palette;
}

const List<_Page> _pages = <_Page>[
  _Page(
    eyebrow: 'The idea',
    title: 'Don’t do it alone.',
    body:
        'The film you keep postponing. The restaurant you never book. Most plans die because nobody wants to go by themselves.',
    palette: <Color>[Color(0xFF14453A), Color(0xFFC0603A), Color(0xFF4B5BA6)],
  ),
  _Page(
    eyebrow: 'Say it out loud',
    title: 'Post what you’re up for.',
    body:
        'Movies. Dinner. Coffee. A 6am walk. Put the plan out there with a time and a place, and let the right person find it.',
    palette: <Color>[Color(0xFF4B5BA6), Color(0xFF2F7A5E), Color(0xFFB0821F), Color(0xFF8C4A70)],
  ),
  _Page(
    eyebrow: 'Find your company',
    title: 'Someone nearby is free too.',
    body:
        'Browse people by what they actually want to do and when they’re actually free. Send an invitation, not a pick-up line.',
    palette: <Color>[Color(0xFFC0603A), Color(0xFF14453A), Color(0xFF2B7683)],
  ),
  _Page(
    eyebrow: 'Then go',
    title: 'Meet through the thing itself.',
    body:
        'When they accept, a conversation opens with the plan already in it. No small talk about the weather — you have somewhere to be.',
    palette: <Color>[Color(0xFF2F7A5E), Color(0xFFA43F5F), Color(0xFF6A4FA3), Color(0xFFB0821F)],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  /// Fractional page position, so the art can respond to a half-swipe.
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final double page = _controller.hasClients ? (_controller.page ?? 0) : 0;
      if ((page - _page).abs() > 0.001) setState(() => _page = page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    await ref.read(authControllerProvider.notifier).completeOnboarding();
    if (mounted) context.go(Routes.welcome);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(duration: AppMotion.base, curve: AppMotion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenX,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  BrandMark(size: 26, color: colors.primary, accentColor: colors.accent),
                  const SizedBox(width: AppSpacing.md),
                  Text('Companion', style: type.label),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: AppMotion.fast,
                    opacity: _isLast ? 0 : 1,
                    child: AppButton.ghost(
                      label: 'Skip',
                      size: AppButtonSize.small,
                      onPressed: _isLast ? null : _finish,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (int index) => setState(() => _index = index),
                itemBuilder: (BuildContext context, int index) {
                  final _Page page = _pages[index];
                  // 1 when this page is centred, falling off as it slides away.
                  final double focus = (1 - (_page - index).abs()).clamp(0.0, 1.0);

                  return Column(
                    children: <Widget>[
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: OnboardingArt(
                            variant: index,
                            progress: focus,
                            palette: page.palette,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Opacity(
                          opacity: focus,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - focus)),
                            // Scrollable so the longest page still fits on a
                            // small phone with the text scale turned up.
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxxl,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    page.eyebrow.toUpperCase(),
                                    style: type.overline.copyWith(color: colors.accent),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(page.title, style: type.headline),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    page.body,
                                    style: type.body.copyWith(
                                      color: colors.inkMuted,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl,
                AppSpacing.lg,
                AppSpacing.xxxl,
                AppSpacing.xxl,
              ),
              child: Row(
                children: <Widget>[
                  for (int index = 0; index < _pages.length; index += 1)
                    AnimatedContainer(
                      duration: AppMotion.base,
                      curve: AppMotion.standard,
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      height: 4,
                      width: index == _index ? 22 : 6,
                      decoration: BoxDecoration(
                        color: index == _index ? colors.ink : colors.borderStrong,
                        borderRadius: AppRadii.pillAll,
                      ),
                    ),
                  const Spacer(),
                  AppButton(
                    label: _isLast ? 'Get started' : 'Next',
                    onPressed: _next,
                    expand: false,
                    trailingIcon: _isLast ? null : Icons.arrow_forward_rounded,
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
