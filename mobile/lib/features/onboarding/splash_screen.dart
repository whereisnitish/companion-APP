import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'brand_mark.dart';

/// The mark draws itself together, the wordmark settles under it. Roughly a
/// second — long enough to register, short enough that nobody waits for it.
/// Routing happens independently, so a fast session restore is never blocked.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  late final Animation<double> _markProgress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.05, 0.62, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.42, 0.9, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _tagline = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.6, 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BrandMark(
                  size: 96,
                  progress: _markProgress.value,
                  color: colors.primary,
                  accentColor: colors.accent,
                  strokeWidth: 2.6,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                Opacity(
                  opacity: _wordmark.value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - _wordmark.value)),
                    child: Text('Companion', style: type.headline),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Opacity(
                  opacity: _tagline.value * 0.9,
                  child: Text(
                    'Never do it alone.',
                    style: type.body.copyWith(color: colors.inkMuted),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
