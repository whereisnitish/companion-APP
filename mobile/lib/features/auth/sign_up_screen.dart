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

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _isSubmitting = false;
  String? _formError;
  Map<String, String> _fieldErrors = const <String, String>{};
  String _passwordValue = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Live requirements beat a rejected form. Each rule is checkable at a glance.
  bool get _hasLength => _passwordValue.length >= 8;
  bool get _hasLetter => RegExp('[a-zA-Z]').hasMatch(_passwordValue);
  bool get _hasNumber => RegExp('[0-9]').hasMatch(_passwordValue);
  bool get _canSubmit => _hasLength && _hasLetter && _hasNumber && _email.text.contains('@');

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _formError = null;
      _fieldErrors = const <String, String>{};
    });

    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _email.text.trim(),
            password: _password.text,
          );
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
      title: 'Let’s get you\nsome company.',
      subtitle: 'Two fields now, the interesting part next.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        children: <Widget>[
          Text(
            'Already have an account?',
            style: type.bodySmall.copyWith(color: colors.inkMuted),
          ),
          PressEffect(
            onTap: () => context.pushReplacement(Routes.signIn),
            scale: 0.94,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Sign in', style: type.label.copyWith(color: colors.primary)),
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
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          controller: _password,
          label: 'Password',
          hint: 'At least 8 characters',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          errorText: _fieldErrors['password'],
          enabled: !_isSubmitting,
          onChanged: (String value) => setState(() => _passwordValue = value),
          onSubmitted: (_) => _canSubmit ? _submit() : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Requirement(label: '8+ characters', met: _hasLength),
            _Requirement(label: 'A letter', met: _hasLetter),
            _Requirement(label: 'A number', met: _hasNumber),
          ],
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
          label: 'Continue',
          isLoading: _isSubmitting,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: AppMotion.fast,
          height: 16,
          width: 16,
          decoration: BoxDecoration(
            color: met ? colors.success : colors.surfaceSunken,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 11,
            color: met ? Colors.white : colors.inkFaint,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: context.type.caption.copyWith(color: met ? colors.ink : colors.inkFaint),
        ),
      ],
    );
  }
}
