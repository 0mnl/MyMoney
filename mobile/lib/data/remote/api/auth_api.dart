import '../dio_client.dart';

/// Thin wrapper over Dio for the /v1/auth/* endpoints. Returns plain maps —
/// the caller decides which pieces to persist (AuthStore, LocalSession, etc).
///
/// Registration is a two-step exchange: [register] creates the account and
/// mails a 6-digit code but issues no tokens; [verifyEmail] trades that code
/// for a real session. See backend RegisterUserUseCase / VerifyEmailUseCase.
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  Future<PendingRegistration> register(String email, String password) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {'email': email, 'password': password},
    );
    _requireOk(resp.statusCode, resp.data);
    return PendingRegistration.fromJson(resp.data!);
  }

  Future<AuthSessionResult> verifyEmail(String email, String code) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/v1/auth/verify-email',
      data: {'email': email, 'code': code},
    );
    _requireOk(resp.statusCode, resp.data);
    return AuthSessionResult.fromJson(resp.data!);
  }

  Future<PendingRegistration> resendCode(String email) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/v1/auth/resend-code',
      data: {'email': email},
    );
    _requireOk(resp.statusCode, resp.data);
    return PendingRegistration.fromJson(resp.data!);
  }

  Future<AuthSessionResult> login(String email, String password) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    _requireOk(resp.statusCode, resp.data);
    return AuthSessionResult.fromJson(resp.data!);
  }

  Future<void> logoutAll() async {
    await _client.dio.post<void>('/v1/auth/logout-all');
  }

  void _requireOk(int? status, Map<String, dynamic>? data) {
    if (status == null || status >= 400) {
      final err = data?['error'] as Map<String, dynamic>?;
      final rawDetails = err?['details'];
      throw AuthApiException(
        status: status ?? 0,
        code: err?['code']?.toString() ?? 'UNKNOWN',
        message: err?['message']?.toString() ?? 'Auth request failed',
        details: rawDetails is Map
            ? rawDetails.map((k, v) => MapEntry(k.toString(), v.toString()))
            : const {},
      );
    }
  }
}

/// Result of /auth/register and /auth/resend-code — an account awaiting
/// email confirmation. No tokens: the app cannot proceed on this alone.
class PendingRegistration {
  const PendingRegistration({
    required this.email,
    required this.codeExpiresAt,
    required this.resendAvailableAt,
  });

  final String email;
  final DateTime codeExpiresAt;
  final DateTime resendAvailableAt;

  /// Seconds the confirmation screen must keep the resend button disabled.
  int get resendCooldownSeconds {
    final remaining = resendAvailableAt.difference(DateTime.now().toUtc()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  static PendingRegistration fromJson(Map<String, dynamic> json) => PendingRegistration(
        email: json['email'] as String,
        codeExpiresAt: DateTime.parse(json['codeExpiresAt'] as String).toUtc(),
        resendAvailableAt: DateTime.parse(json['resendAvailableAt'] as String).toUtc(),
      );
}

class AuthSessionResult {
  const AuthSessionResult({
    required this.userId,
    required this.familyId,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String familyId;
  final String accessToken;
  final String refreshToken;

  static AuthSessionResult fromJson(Map<String, dynamic> json) => AuthSessionResult(
        userId: json['userId'] as String,
        familyId: json['familyId'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

class AuthApiException implements Exception {
  AuthApiException({
    required this.status,
    required this.code,
    required this.message,
    this.details = const {},
  });

  final int status;
  final String code;
  final String message;
  final Map<String, String> details;

  /// Login was rejected because the address still needs confirming — the
  /// caller should route to the confirmation screen, not show an error.
  bool get isEmailNotVerified => code == 'EMAIL_NOT_VERIFIED';

  /// Seconds to wait before retrying, when the server threw a cooldown.
  int? get retryAfterSeconds => int.tryParse(details['retryAfterSeconds'] ?? '');

  @override
  String toString() => 'AuthApiException($status, $code): $message';
}
