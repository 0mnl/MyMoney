import 'package:flutter/material.dart';

/// Full-width rounded CTA button used across the onboarding flow
/// (Создать аккаунт / Зарегистрироваться / Перейти в приложение).
///
/// Shows a spinner in place of [label] while [loading] is true, and disables
/// itself automatically whenever [onPressed] is null or [loading] is true.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !loading;

    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Text(label),
    );
  }
}
