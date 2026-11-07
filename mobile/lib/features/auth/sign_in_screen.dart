import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/press_effect.dart';
import 'auth_scaffold.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _isSubmitting = false;
  String? _formError;
  Map<String, String> _fieldErrors = const <String, String>{};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _formError = null;
      _fieldErrors = const <String, String>{};
    });

    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _email.text.trim(),
            password: _password.text,
          );
      // The router redirect takes it from here.
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = error.fieldErrors.isEmpty ? error.message : null;
        _fieldErrors = error.fieldErrors;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return AuthScaffold(
      title: 'Welcome back.',
      subtitle: 'Sign in to see who is free near you this week.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        children: <Widget>[
          Text('New here?', style: type.bodySmall.copyWith(color: colors.inkMuted)),
          PressEffect(
            onTap: () => context.pushReplacement(Routes.signUp),
            scale: 0.94,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'Create an account',
                style: type.label.copyWith(color: colors.primary),
              ),
            ),
          ),
        ],
      ),
      children: <Widget>[
        AppTextField(
          controller: _email,
          label: 'Email',
          hint: 'you@example.com',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          errorText: _fieldErrors['email'],
          enabled: !_isSubmitting,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          controller: _password,
          label: 'Password',
          hint: 'Your password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          errorText: _fieldErrors['password'],
          enabled: !_isSubmitting,
          onSubmitted: (_) => _submit(),
        ),
        if (_formError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(color: colors.dangerSoft, borderRadius: AppRadii.mdAll),
            child: Row(
              children: <Widget>[
                Icon(Icons.error_outline_rounded, size: 18, color: colors.danger),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _formError!,
                    style: type.bodySmall.copyWith(color: colors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'Sign in',
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
        // Development only: real builds have no demo account to sign in to.
        if (kDebugMode) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          const _DemoAccountHint(),
        ],
      ],
    );
  }
}

/// The seeded demo account, offered rather than hidden in a README. Debug-only
/// affordance — it fills the form, it does not bypass authentication.
class _DemoAccountHint extends ConsumerStatefulWidget {
  const _DemoAccountHint();

  @override
  ConsumerState<_DemoAccountHint> createState() => _DemoAccountHintState();
}

class _DemoAccountHintState extends ConsumerState<_DemoAccountHint> {
  bool _isLoading = false;

  Future<void> _signInAsDemo() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).login(
            email: 'demo@companion.app',
            password: 'Password123',
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seed the database first: npm run db:seed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: AppRadii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.science_outlined, size: 16, color: colors.inkMuted),
              const SizedBox(width: AppSpacing.sm),
              Text('Exploring the demo?', style: type.label.copyWith(color: colors.ink)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The seeded database ships with a populated account. Everything you send is real — it just talks to your local server.',
            style: type.caption.copyWith(color: colors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.secondary(
            label: 'Sign in as demo@companion.app',
            size: AppButtonSize.small,
            isLoading: _isLoading,
            onPressed: _signInAsDemo,
          ),
        ],
      ),
    );
  }
}
