import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Three-step strength read-out shown under the password field on
/// "Создайте аккаунт" (красный -> жёлтый -> зелёный).
enum PasswordStrength { none, weak, medium, strong }

/// Mirrors the backend rule (`isValidPassword`: min 8 chars) as the floor, then
/// grades what is above it. [PasswordStrength.weak] is rejected by the form, so
/// anything the server would refuse can never reach submit.
PasswordStrength computePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.none;
  if (password.length < 8) return PasswordStrength.weak;

  var score = 0;
  if (password.length >= 12) score++;
  if (RegExp(r'[A-ZА-ЯЁ]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[^a-zA-Zа-яА-ЯёЁ0-9]').hasMatch(password)) score++;

  if (score <= 1) return PasswordStrength.weak;
  if (score <= 2) return PasswordStrength.medium;
  return PasswordStrength.strong;
}

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.strength});

  final PasswordStrength strength;

  Color get _color {
    switch (strength) {
      case PasswordStrength.none:
        return AppColors.inkFaint;
      case PasswordStrength.weak:
        return AppColors.danger;
      case PasswordStrength.medium:
        return AppColors.warning;
      case PasswordStrength.strong:
        return AppColors.success;
    }
  }

  int get _filledSegments {
    switch (strength) {
      case PasswordStrength.none:
        return 0;
      case PasswordStrength.weak:
        return 1;
      case PasswordStrength.medium:
        return 2;
      case PasswordStrength.strong:
        return 3;
    }
  }

  String get _label {
    switch (strength) {
      case PasswordStrength.none:
        return 'Минимум 8 символов, буквы и цифры';
      case PasswordStrength.weak:
        return 'Слабый пароль — добавьте цифры или заглавные буквы';
      case PasswordStrength.medium:
        return 'Средняя надёжность';
      case PasswordStrength.strong:
        return 'Надёжный пароль';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (index) {
            final filled = index < _filledSegments;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                height: 4,
                decoration: BoxDecoration(
                  color: filled ? _color : AppColors.fieldIdle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(_label, style: TextStyle(fontSize: 12, color: _color)),
      ],
    );
  }
}
