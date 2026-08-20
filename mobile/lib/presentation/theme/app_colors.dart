import 'package:flutter/material.dart';

/// Palette extracted from the MyMoney onboarding designs
/// (Splash, Добро пожаловать, Создайте аккаунт, Подтверждение почты).
///
/// Scoped to the onboarding flow — the authenticated shell keeps its own
/// blue/white design (see HomeShell). Applied via [OnboardingTheme].
abstract final class AppColors {
  static const background = Color(0xFFF4EDE3);
  static const surface = Colors.white;

  static const ink = Color(0xFF000000);
  static const inkMuted = Color(0xFF4D4D4D);
  static const inkFaint = Color(0xFF8C8C8C);

  static const brand = Color(0xFF892029);

  static const fieldIdle = Color(0xFFE3DACB);
  static const fieldActive = Color(0xFF000000);

  static const success = Color(0xFF2E7D46);
  static const warning = Color(0xFFC98A1F);
  static const danger = Color(0xFFB3261E);

  static const buttonPrimary = Color(0xFF000000);
  static const buttonPrimaryDisabled = Color(0xFFBEB6A9);
  static const onButtonPrimary = Color(0xFFFFFFFF);
}
