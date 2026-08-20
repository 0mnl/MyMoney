import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/api_providers.dart';
import '../../../data/remote/api/auth_api.dart';
import '../../providers/sign_in_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/onboarding_theme.dart';
import '../../widgets/auth_text_field.dart';
import '../../widgets/primary_button.dart';
import 'email_verification_screen.dart';

/// "Вход" — same visual language as "Создайте аккаунт".
///
/// Replaces the old segmented login/register form: registration now has its
/// own multi-step flow, so this screen only signs existing users in.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(signInControllerProvider.notifier);
    final ok = await controller.submit();
    if (ok || !mounted) return;

    // The account exists but was never confirmed — resend a code and finish
    // the flow instead of leaving the user stuck on a login error.
    final unverified = ref.read(signInControllerProvider).unverifiedEmail;
    if (unverified == null) return;

    try {
      final usecase = await ref.read(authenticateAndSyncProvider.future);
      final pending = await usecase.resendCode(unverified);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EmailVerificationScreen(pending: pending)),
      );
    } on AuthApiException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подтвердите почту — код уже отправлен ранее')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInControllerProvider);
    final controller = ref.read(signInControllerProvider.notifier);
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
            Text('С возвращением', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Войдите, чтобы синхронизировать данные на всех устройствах.',
              style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 32),
            AuthTextField(
              controller: _emailController,
              label: 'Электронная почта',
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
              autofillHints: const [AutofillHints.password],
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
            if (state.submitError != null) ...[
              const SizedBox(height: 16),
              Text(
                state.submitError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Войти',
              loading: state.isSubmitting,
              onPressed: state.canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
