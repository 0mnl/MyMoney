import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/onboarding_theme.dart';
import 'brand_mark.dart';

/// Splash. Purely a loading state — it navigates nowhere.
///
/// The original design drove navigation from a fixed `Future.delayed`, which
/// races whatever is actually loading. Here the auth gate in main.dart decides
/// what comes next and shows this screen while it works, so the splash lasts
/// exactly as long as there is something to wait for.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPage(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(),
            SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
