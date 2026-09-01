import 'package:companion/models/enums.dart';
import 'package:companion/theme/app_colors.dart';
import 'package:companion/theme/app_typography.dart';
import 'package:companion/widgets/app_button.dart';
import 'package:companion/widgets/app_chip.dart';
import 'package:companion/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('theme', () {
    testWidgets('exposes the colour and type extensions in both brightnesses',
        (WidgetTester tester) async {
      for (final Brightness brightness in Brightness.values) {
        late BuildContext captured;
        await pumpHarness(
          tester,
          Builder(
            builder: (BuildContext context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
          brightness: brightness,
        );

        expect(Theme.of(captured).extension<AppColors>(), isNotNull);
        expect(Theme.of(captured).extension<AppTypography>(), isNotNull);
        expect(captured.colors.primary, isNot(captured.colors.canvas));
      }
    });

    testWidgets('disables Material ink so photo cards do not ripple', (WidgetTester tester) async {
      late BuildContext captured;
      await pumpHarness(
        tester,
        Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      );
      expect(Theme.of(captured).splashFactory, NoSplash.splashFactory);
    });

    test('light and dark palettes define every token distinctly', () {
      expect(AppColors.light.canvas, isNot(AppColors.dark.canvas));
      expect(AppColors.light.ink, isNot(AppColors.dark.ink));
      // Text must not be painted on a same-value ground in either theme.
      expect(AppColors.light.ink, isNot(AppColors.light.surface));
      expect(AppColors.dark.ink, isNot(AppColors.dark.surface));
    });

    test('lerp interpolates rather than snapping', () {
      final AppColors mid = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(mid.canvas, isNot(AppColors.light.canvas));
      expect(mid.canvas, isNot(AppColors.dark.canvas));
    });
  });

  group('AppButton', () {
    testWidgets('fires onPressed and shows its label', (WidgetTester tester) async {
      int taps = 0;
      await pumpHarness(
        tester,
        AppButton(label: 'Send invitation', onPressed: () => taps += 1),
      );

      expect(find.text('Send invitation'), findsOneWidget);
      await tester.tap(find.text('Send invitation'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
    });

    testWidgets('is inert while loading', (WidgetTester tester) async {
      int taps = 0;
      await pumpHarness(
        tester,
        AppButton(label: 'Send', isLoading: true, onPressed: () => taps += 1),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Send'), findsNothing);
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('is inert when disabled', (WidgetTester tester) async {
      await pumpHarness(tester, const AppButton(label: 'Continue'));
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      // No exception is the assertion — a null callback must never be invoked.
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('renders every variant without overflowing', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        Column(
          children: <Widget>[
            for (final AppButtonVariant variant in AppButtonVariant.values)
              for (final AppButtonSize size in AppButtonSize.values)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: AppButton(
                    label: '${variant.name} ${size.name}',
                    variant: variant,
                    size: size,
                    icon: Icons.send_rounded,
                    onPressed: () {},
                  ),
                ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('chips', () {
    testWidgets('CategoryChip shows the label and toggles', (WidgetTester tester) async {
      bool selected = false;
      await tester.pumpWidget(
        harness(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => CategoryChip(
              category: ActivityCategory.movie,
              selected: selected,
              onTap: () => setState(() => selected = !selected),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Movie'), findsOneWidget);
      await tester.tap(find.text('Movie'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected, isTrue);
    });

    testWidgets('every category renders its own icon', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        Wrap(
          children: <Widget>[
            for (final ActivityCategory category in ActivityCategory.values)
              CategoryChip(category: category),
          ],
        ),
      );

      for (final ActivityCategory category in ActivityCategory.values) {
        expect(find.byIcon(category.icon), findsWidgets, reason: '${category.wire} icon');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('StatusPill carries the right words per status', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        Wrap(
          children: <Widget>[
            for (final InvitationStatus status in InvitationStatus.values)
              StatusPill(status: status),
          ],
        ),
      );
      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
    });

    testWidgets('VerifiedBadge is invisible unless verified', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        const Column(
          children: <Widget>[
            VerifiedBadge(status: VerificationStatus.unverified),
            VerifiedBadge(status: VerificationStatus.pending),
            VerifiedBadge(),
          ],
        ),
      );
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('reports changes and shows an error', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      String seen = '';

      await pumpHarness(
        tester,
        AppTextField(
          controller: controller,
          label: 'Email',
          hint: 'you@example.com',
          errorText: 'Enter a valid email address.',
          onChanged: (String value) => seen = value,
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello@companion.app');
      await tester.pump();
      expect(seen, 'hello@companion.app');
      controller.dispose();
    });

    testWidgets('obscured fields offer a reveal toggle', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        const AppTextField(label: 'Password', obscureText: true),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });
}
