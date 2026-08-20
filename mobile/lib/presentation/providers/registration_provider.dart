import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_providers.dart';
import '../../data/remote/api/auth_api.dart';
import '../widgets/password_strength_bar.dart';
import 'auth_error_messages.dart';

/// Drives every state on "Создайте аккаунт": empty fields, email focus/fill/
/// error, password strength colour, visibility toggle and the submit/loading
/// states.
class RegistrationState {
  const RegistrationState({
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.emailError,
    this.isSubmitting = false,
    this.submitError,
  });

  final String email;
  final String password;
  final bool isPasswordVisible;
  final String? emailError;
  final bool isSubmitting;
  final String? submitError;

  PasswordStrength get passwordStrength => computePasswordStrength(password);

  bool get isEmailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  /// Mirrors the backend contract: a password shorter than 8 chars grades as
  /// [PasswordStrength.weak], so refusing weak here means the server never
  /// sees a request it would reject.
  bool get canSubmit =>
      isEmailValid &&
      passwordStrength != PasswordStrength.none &&
      passwordStrength != PasswordStrength.weak &&
      !isSubmitting;

  RegistrationState copyWith({
    String? email,
    String? password,
    bool? isPasswordVisible,
    String? emailError,
    bool clearEmailError = false,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return RegistrationState(
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      emailError: clearEmailError ? null : (emailError ?? this.emailError),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

class RegistrationController extends AutoDisposeNotifier<RegistrationState> {
  @override
  RegistrationState build() => const RegistrationState();

  void emailChanged(String value) {
    state = state.copyWith(email: value, clearEmailError: true, clearSubmitError: true);
  }

  void passwordChanged(String value) {
    state = state.copyWith(password: value, clearSubmitError: true);
  }

  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }

  /// Validates the email field on blur, mirroring the "Ошибка" state.
  void validateEmailOnBlur() {
    if (state.email.isEmpty || state.isEmailValid) return;
    state = state.copyWith(emailError: 'Проверьте адрес электронной почты');
  }

  /// Creates the account and asks the backend to mail a code. Returns the
  /// pending registration so the screen can route to confirmation with the
  /// resend countdown already known; null means the attempt failed and
  /// [RegistrationState.submitError] holds the reason.
  Future<PendingRegistration?> submit() async {
    if (!state.canSubmit) return null;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      final usecase = await ref.read(authenticateAndSyncProvider.future);
      final pending = await usecase.register(state.email.trim(), state.password);
      state = state.copyWith(isSubmitting: false);
      return pending;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, submitError: authErrorMessage(e));
      return null;
    }
  }
}

final registrationControllerProvider =
    NotifierProvider.autoDispose<RegistrationController, RegistrationState>(
  RegistrationController.new,
);
