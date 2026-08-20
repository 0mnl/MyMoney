import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_providers.dart';
import '../../core/providers/app_providers.dart';
import '../../data/remote/api/auth_api.dart';
import 'auth_error_messages.dart';

class SignInState {
  const SignInState({
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.isSubmitting = false,
    this.submitError,
    this.unverifiedEmail,
  });

  final String email;
  final String password;
  final bool isPasswordVisible;
  final bool isSubmitting;
  final String? submitError;

  /// Set when the backend answered EMAIL_NOT_VERIFIED — the screen routes to
  /// confirmation instead of showing an error.
  final String? unverifiedEmail;

  bool get isEmailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  bool get canSubmit => isEmailValid && password.isNotEmpty && !isSubmitting;

  SignInState copyWith({
    String? email,
    String? password,
    bool? isPasswordVisible,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
    String? unverifiedEmail,
    bool clearUnverified = false,
  }) {
    return SignInState(
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      unverifiedEmail: clearUnverified ? null : (unverifiedEmail ?? this.unverifiedEmail),
    );
  }
}

class SignInController extends AutoDisposeNotifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  void emailChanged(String value) =>
      state = state.copyWith(email: value, clearSubmitError: true, clearUnverified: true);

  void passwordChanged(String value) =>
      state = state.copyWith(password: value, clearSubmitError: true);

  void togglePasswordVisibility() =>
      state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);

  /// Signs in and publishes the session, which flips the app-wide auth gate
  /// straight to the shell. Returns true on success; when the account exists
  /// but is unconfirmed, returns false with [SignInState.unverifiedEmail] set
  /// so the caller can send the user to the confirmation screen.
  Future<bool> submit() async {
    if (!state.canSubmit) return false;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true, clearUnverified: true);
    try {
      final usecase = await ref.read(authenticateAndSyncProvider.future);
      final snap = await usecase.login(state.email.trim(), state.password);
      await ref.read(authSnapshotProvider.notifier).setSession(snap);
      // login() rewrote userId/familyId in prefs and cleared Isar — the cached
      // bootstrap still points at the previous family.
      ref.invalidate(bootstrapProvider);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      if (e is AuthApiException && e.isEmailNotVerified) {
        state = state.copyWith(isSubmitting: false, unverifiedEmail: state.email.trim());
        return false;
      }
      state = state.copyWith(isSubmitting: false, submitError: authErrorMessage(e));
      return false;
    }
  }
}

final signInControllerProvider =
    NotifierProvider.autoDispose<SignInController, SignInState>(SignInController.new);
