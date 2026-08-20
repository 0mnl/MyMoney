import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/api/auth_api.dart';
import '../../providers/email_verification_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/onboarding_theme.dart';
import '../../widgets/otp_code_field.dart';
import 'account_created_screen.dart';

/// "Подтвердите почту" — the OTP grid, the wrong-code state, the verifying
/// spinner and the resend countdown.
///
/// The cooldown is seeded from the server's `resendAvailableAt` rather than a
/// hardcoded 30 s, so the client's countdown and the backend's rate limit
/// cannot drift apart.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, required this.pending});

  final PendingRegistration pending;

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  late final _provider = emailVerificationControllerProvider(widget.pending.email);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(_provider.notifier).startCooldown(widget.pending.resendCooldownSeconds);
    });
  }

  Future<void> _verify(String code) async {
    final ok = await ref.read(_provider.notifier).verify(code);
    if (!ok || !mounted) return;

    final session = ref.read(_provider).session;
    if (session == null) return;

    // Replace: after confirmation there is nothing to go back to.
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => AccountCreatedScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);
    final textTheme = OnboardingTheme.data.textTheme;

    return OnboardingPage(
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
          Text('Подтвердите почту', style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
              children: [
                const TextSpan(text: 'Мы прислали 6-значный код на '),
                TextSpan(
                  text: state.email,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OtpCodeField(
            length: 6,
            enabled: !state.isVerifying,
            hasError: state.hasError,
            onCompleted: _verify,
          ),
          const SizedBox(height: 16),
          if (state.isVerifying)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else if (state.errorMessage != null)
            Text(
              state.errorMessage!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            )
          else if (state.infoMessage != null)
            Text(
              state.infoMessage!,
              style: const TextStyle(color: AppColors.success, fontSize: 13),
            ),
          const Spacer(),
          Center(
            child: state.isResending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : state.canResend
                    ? TextButton(
                        onPressed: controller.resendCode,
                        child: const Text(
                          'Отправить код повторно',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Text(
                        'Повторная отправка через ${state.resendCooldown} с',
                        style: const TextStyle(color: AppColors.inkFaint),
                      ),
          ),
        ],
      ),
    );
  }
}
