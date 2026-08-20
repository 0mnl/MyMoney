import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/registration_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/onboarding_theme.dart';
import '../../widgets/auth_text_field.dart';
import '../../widgets/password_strength_bar.dart';
import '../../widgets/primary_button.dart';
import 'email_verification_screen.dart';

/// "Создайте аккаунт". Covers every state from the designs: empty fields,
/// email focus/fill/error, password focus, strength colour, visibility toggle
/// and the submit/loading state.
///
/// On success the backend has mailed a code but issued no tokens — the user is
/// still unauthenticated until the confirmation screen accepts that code.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        ref.read(registrationControllerProvider.notifier).validateEmailOnBlur();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pending = await ref.read(registrationControllerProvider.notifier).submit();
    if (pending == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmailVerificationScreen(pending: pending),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    final controller = ref.read(registrationControllerProvider.notifier);
    final textTheme = OnboardingTheme.data.textTheme;

    return OnboardingPage(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: AppColors.ink),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: 8),
            Text('Создайте аккаунт', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Введите email и придумайте пароль, чтобы начать вести бюджет.',
              style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 32),
            AuthTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              label: 'Электронная почта',
              errorText: state.emailError,
              enabled: !state.isSubmitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: controller.emailChanged,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: 'Пароль',
              obscureText: !state.isPasswordVisible,
              enabled: !state.isSubmitting,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              suffixIcon: IconButton(
                onPressed: controller.togglePasswordVisibility,
                icon: Icon(
                  state.isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.inkMuted,
                ),
              ),
              onChanged: controller.passwordChanged,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            PasswordStrengthBar(strength: state.passwordStrength),
            if (state.submitError != null) ...[
              const SizedBox(height: 16),
              Text(
                state.submitError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Зарегистрироваться',
              loading: state.isSubmitting,
              onPressed: state.canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
