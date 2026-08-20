import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/remote/auth_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/onboarding_theme.dart';
import '../../widgets/primary_button.dart';

/// "Аккаунт успешно создан". The tokens are already in secure storage — this
/// screen publishes the session, which is what flips the app-wide auth gate to
/// the shell. Publishing earlier would tear this screen down before it showed.
class AccountCreatedScreen extends ConsumerWidget {
  const AccountCreatedScreen({super.key, required this.session});

  final AuthSnapshot session;

  Future<void> _enterApp(WidgetRef ref) async {
    await ref.read(authSnapshotProvider.notifier).setSession(session);
    // Registration rewrote userId/familyId in prefs and cleared Isar; the
    // cached bootstrap still holds the pre-login family.
    ref.invalidate(bootstrapProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = OnboardingTheme.data.textTheme;

    return PopScope(
      // Nothing behind this screen is reachable any more — the account exists.
      canPop: false,
      child: OnboardingPage(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 32),
            Text(
              'Аккаунт успешно создан',
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Теперь вы можете добавить свои счета и начать отслеживать бюджет.',
              style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Перейти в приложение',
              onPressed: () => _enterApp(ref),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
