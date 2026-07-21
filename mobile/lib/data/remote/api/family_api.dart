import '../dio_client.dart';

class FamilyApi {
  FamilyApi(this._client);
  final ApiClient _client;

  Future<InviteResult> invite(String email) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/v1/family/invite',
      data: {'email': email},
    );
    _requireOk(resp.statusCode, resp.data);
    return InviteResult(
      inviteToken: resp.data!['inviteToken'] as String,
      expiresAt: DateTime.parse(resp.data!['expiresAt'] as String).toUtc(),
    );
  }

  /// Returns the family_id the acceptor now belongs to. The caller must
  /// re-login afterwards because their old access token still carries the
  /// previous family_id claim.
  Future<String> accept(String inviteToken) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/v1/family/accept',
      data: {'inviteToken': inviteToken},
    );
    _requireOk(resp.statusCode, resp.data);
    return resp.data!['familyId'] as String;
  }

  Future<List<FamilyMemberDto>> listMembers() async {
    final resp = await _client.dio.get<Map<String, dynamic>>('/v1/family/members');
    _requireOk(resp.statusCode, resp.data);
    final rows = (resp.data!['members'] as List<dynamic>? ?? const []);
    return rows
        .map((e) => FamilyMemberDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _requireOk(int? status, Map<String, dynamic>? data) {
    if (status == null || status >= 400) {
      final err = data?['error'] as Map<String, dynamic>?;
      throw FamilyApiException(
        status: status ?? 0,
        code: err?['code']?.toString() ?? 'UNKNOWN',
        message: err?['message']?.toString() ?? 'Family request failed',
      );
    }
  }
}

class InviteResult {
  const InviteResult({required this.inviteToken, required this.expiresAt});
  final String inviteToken;
  final DateTime expiresAt;
}

class FamilyMemberDto {
  const FamilyMemberDto({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });
  final String id;
  final String familyId;
  final String userId;
  final String role;
  final DateTime joinedAt;

  static FamilyMemberDto fromJson(Map<String, dynamic> j) => FamilyMemberDto(
        id: j['id'] as String,
        familyId: j['familyId'] as String,
        userId: j['userId'] as String,
        role: j['role'] as String,
        joinedAt: DateTime.parse(j['joinedAt'] as String).toUtc(),
      );
}

class FamilyApiException implements Exception {
  FamilyApiException({required this.status, required this.code, required this.message});
  final int status;
  final String code;
  final String message;
  @override
  String toString() => 'FamilyApiException($status, $code): $message';
}
