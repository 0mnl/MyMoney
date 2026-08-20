import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme for the onboarding flow only.
///
/// It is *not* installed on MaterialApp: the authenticated shell has its own
/// look, so each onboarding screen opts in via [OnboardingPage], which wraps
/// its subtree in a `Theme`. That keeps the beige palette from leaking into
/// the 16 existing screens.
///
/// No `fontFamily` is set on purpose — the designs call for Inter, but no font
/// asset is declared in pubspec.yaml, and naming a missing family only makes
/// Flutter fall back to the system font while hiding the omission. Declare the
/// asset first, then set it here.
abstract final class OnboardingTheme {
  /// Built once. Screens read this directly rather than `Theme.of(context)`,
  /// because their own build method is what installs the theme — so it is not
  /// yet in their context. `ColorScheme.fromSeed` runs colour science on every
  /// call, which is far too costly to repeat on each keystroke.
  static final ThemeData data = _build();

  static ThemeData _build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
        surface: AppColors.background,
        error: AppColors.danger,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          height: 1.2,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.inkMuted,
        ),
        labelLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.onButtonPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          foregroundColor: AppColors.onButtonPrimary,
          disabledBackgroundColor: AppColors.buttonPrimaryDisabled,
          disabledForegroundColor: AppColors.onButtonPrimary,
          minimumSize: const Size.fromHeight(53),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.fieldIdle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.fieldIdle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.fieldActive, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
    );
  }
}

/// Scaffold shared by every onboarding screen: installs [OnboardingTheme],
/// the beige background and the 20/24 padding from the designs.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: OnboardingTheme.data,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
