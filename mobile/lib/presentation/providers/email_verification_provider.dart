import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_providers.dart';
import '../../data/remote/api/auth_api.dart';
import '../../data/remote/auth_store.dart';
import 'auth_error_messages.dart';

/// Drives "Подтвердите почту": code entry, the wrong-code state, the verifying
/// spinner and the resend cooldown.
class EmailVerificationState {
  const EmailVerificationState({
    required this.email,
    this.isVerifying = false,
    this.isResending = false,
    this.errorMessage,
    this.infoMessage,
    this.session,
    this.resendCooldown = 0,
  });

  final String email;
  final bool isVerifying;
  final bool isResending;
  final String? errorMessage;
  final String? infoMessage;

  /// Set once the code was accepted. Held here rather than published to
  /// [authSnapshotProvider] straight away: publishing flips the app-wide auth
  /// gate, which would tear down this flow before the user ever sees the
  /// "Аккаунт успешно создан" screen. AccountCreatedScreen publishes it.
  final AuthSnapshot? session;
  final int resendCooldown;

  bool get isVerified => session != null;

  bool get hasError => errorMessage != null;
  bool get canResend => resendCooldown == 0 && !isVerifying && !isResending;

  EmailVerificationState copyWith({
    bool? isVerifying,
    bool? isResending,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
    AuthSnapshot? session,
    int? resendCooldown,
  }) {
    return EmailVerificationState(
      email: email,
      isVerifying: isVerifying ?? this.isVerifying,
      isResending: isResending ?? this.isResending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      session: session ?? this.session,
      resendCooldown: resendCooldown ?? this.resendCooldown,
    );
  }
}

/// autoDispose so the countdown Timer dies with the screen. A plain family
/// provider would keep ticking for the rest of the session.
class EmailVerificationController
    extends AutoDisposeFamilyNotifier<EmailVerificationState, String> {
  Timer? _cooldownTimer;

  @override
  EmailVerificationState build(String arg) {
    ref.onDispose(() => _cooldownTimer?.cancel());
    return EmailVerificationState(email: arg);
  }

  /// Starts the countdown the server dictated in its PendingRegistration.
  void startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    if (seconds <= 0) {
      state = state.copyWith(resendCooldown: 0);
      return;
    }
    state = state.copyWith(resendCooldown: seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.resendCooldown - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(resendCooldown: 0);
      } else {
        state = state.copyWith(resendCooldown: next);
      }
    });
  }

  /// Exchanges the code for a session. The tokens are already in secure
  /// storage and the local DB has been reset by the use case; the session is
  /// parked in state until the user leaves the final screen.
  Future<bool> verify(String code) async {
    if (state.isVerifying) return false;
    state = state.copyWith(isVerifying: true, clearError: true, clearInfo: true);
    try {
      final usecase = await ref.read(authenticateAndSyncProvider.future);
      final snap = await usecase.verifyEmail(state.email, code);
      state = state.copyWith(isVerifying: false, session: snap);
      return true;
    } catch (e) {
      state = state.copyWith(isVerifying: false, errorMessage: authErrorMessage(e));
      return false;
    }
  }

  Future<void> resendCode() async {
    if (!state.canResend) return;
    state = state.copyWith(isResending: true, clearError: true, clearInfo: true);
    try {
      final usecase = await ref.read(authenticateAndSyncProvider.future);
      final pending = await usecase.resendCode(state.email);
      state = state.copyWith(
        isResending: false,
        infoMessage: 'Новый код отправлен на ${state.email}',
      );
      startCooldown(pending.resendCooldownSeconds);
    } catch (e) {
      state = state.copyWith(isResending: false, errorMessage: authErrorMessage(e));
      // The server tells us how long it wants us to wait — honour it so the
      // button doesn't invite another rejected request.
      if (e is AuthApiException && e.retryAfterSeconds != null) {
        startCooldown(e.retryAfterSeconds!);
      }
    }
  }
}

final emailVerificationControllerProvider = NotifierProvider.autoDispose
    .family<EmailVerificationController, EmailVerificationState, String>(
  EmailVerificationController.new,
);
