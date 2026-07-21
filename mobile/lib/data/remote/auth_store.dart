import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local storage for the JWT session. Access + refresh live in
/// flutter_secure_storage (keystore/keychain-backed). User/family ids and
/// backend URL are non-secret preferences the caller wires elsewhere.
class AuthStore {
  AuthStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _kAccess = 'auth.access_token';
  static const _kRefresh = 'auth.refresh_token';
  static const _kUserId = 'auth.user_id';
  static const _kFamilyId = 'auth.family_id';

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String familyId,
  }) async {
    await _secure.write(key: _kAccess, value: accessToken);
    await _secure.write(key: _kRefresh, value: refreshToken);
    await _secure.write(key: _kUserId, value: userId);
    await _secure.write(key: _kFamilyId, value: familyId);
  }

  Future<AuthSnapshot?> load() async {
    final access = await _secure.read(key: _kAccess);
    final refresh = await _secure.read(key: _kRefresh);
    final userId = await _secure.read(key: _kUserId);
    final familyId = await _secure.read(key: _kFamilyId);
    if (access == null || refresh == null || userId == null || familyId == null) {
      return null;
    }
    return AuthSnapshot(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
      familyId: familyId,
    );
  }

  Future<void> updateTokens({required String accessToken, required String refreshToken}) async {
    await _secure.write(key: _kAccess, value: accessToken);
    await _secure.write(key: _kRefresh, value: refreshToken);
  }

  Future<void> clear() async {
    await _secure.delete(key: _kAccess);
    await _secure.delete(key: _kRefresh);
    await _secure.delete(key: _kUserId);
    await _secure.delete(key: _kFamilyId);
  }
}

class AuthSnapshot {
  const AuthSnapshot({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.familyId,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String familyId;
}
