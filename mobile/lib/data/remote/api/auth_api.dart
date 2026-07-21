import '../dio_client.dart';

/// Thin wrapper over Dio for the /v1/auth/* endpoints. Returns plain maps —
/// the caller decides which pieces to persist (AuthStore, LocalSession, etc).
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  Future<AuthSessionResult> register(String email, String password) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {'email': email, 'password': password},
    );
    _requireOk(resp.statusCode, resp.data);
    return AuthSessionResult.fromJson(resp.data!);
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
      throw AuthApiException(
        status: status ?? 0,
        code: err?['code']?.toString() ?? 'UNKNOWN',
        message: err?['message']?.toString() ?? 'Auth request failed',
      );
    }
  }
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
  AuthApiException({required this.status, required this.code, required this.message});
  final int status;
  final String code;
  final String message;

  @override
  String toString() => 'AuthApiException($status, $code): $message';
}
