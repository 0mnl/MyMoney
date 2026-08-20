import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/onboarding_theme.dart';
import '../../widgets/primary_button.dart';
import 'brand_mark.dart';
import 'create_account_screen.dart';
import 'sign_in_screen.dart';

class _WelcomeSlide {
  const _WelcomeSlide({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

const _slides = [
  _WelcomeSlide(
    title: 'Все финансы\nв одном месте',
    subtitle: 'Считайте доходы, расходы и накопления без таблиц и лишних приложений.',
  ),
  _WelcomeSlide(
    title: 'Понятная\nаналитика',
    subtitle: 'Графики и отчёты покажут, куда уходят деньги каждый месяц.',
  ),
];

/// "Добро пожаловать" — the root of the unauthenticated flow. Two intro slides
/// ending in the "Создать аккаунт" / "Войти" choice.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = OnboardingTheme.data.textTheme;

    return OnboardingPage(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          const BrandMark(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slide.title, style: textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(
                      slide.subtitle,
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (index) {
              final isActive = index == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.brand : AppColors.fieldIdle,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Создать аккаунт',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CreateAccountScreen()),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
            ),
            child: const Text(
              'У меня уже есть аккаунт',
              style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
