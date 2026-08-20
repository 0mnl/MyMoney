import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/isar_service.dart';
import '../../data/remote/api/auth_api.dart';
import '../../data/remote/auth_store.dart';
import '../../sync/sync_manager.dart';

/// Wraps register/login so the caller gets one method that also:
///  - persists tokens into secure storage
///  - resets local Isar and preferences to match the authenticated family
///  - performs the first sync (pulls the server state)
///
/// The reset step is required because in offline-only mode the client
/// generates a random familyId and seeds categories with it. Once the user
/// authenticates, the authoritative familyId is the one the server issued,
/// so we drop the local seed to prevent stale rows carrying a foreign key.
class AuthenticateAndSyncUseCase {
  AuthenticateAndSyncUseCase({
    required this.authApi,
    required this.authStore,
    required this.isarService,
    required this.prefs,
    required this.syncManager,
  });

  final AuthApi authApi;
  final AuthStore authStore;
  final IsarService isarService;
  final SharedPreferences prefs;
  final SyncManager syncManager;

  /// Creates the account and asks the backend to mail a confirmation code.
  /// Returns no session — the account is unusable until [verifyEmail] runs.
  Future<PendingRegistration> register(String email, String password) {
    return authApi.register(email, password);
  }

  Future<PendingRegistration> resendCode(String email) {
    return authApi.resendCode(email);
  }

  /// Trades the emailed code for a session. This is the registration path's
  /// only entry point into an authenticated app.
  Future<AuthSnapshot> verifyEmail(String email, String code) async {
    final result = await authApi.verifyEmail(email, code);
    return _acceptSession(result);
  }

  Future<AuthSnapshot> login(String email, String password) async {
    final result = await authApi.login(email, password);
    return _acceptSession(result);
  }

  Future<AuthSnapshot> _acceptSession(AuthSessionResult result) async {
    await authStore.save(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: result.userId,
      familyId: result.familyId,
    );
    await _resetLocal(result.familyId, result.userId);
    // Reset sync cursor so the initial pull is a full snapshot.
    await prefs.remove('sync.last_synced_at');
    try {
      await syncManager.sync();
    } catch (_) {
      // First sync failure shouldn't kill the login flow — the user is
      // authenticated locally and the app will retry on the next tick.
    }
    return AuthSnapshot(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: result.userId,
      familyId: result.familyId,
    );
  }

  /// Wipe the local DB so it can be re-populated from the server. This
  /// discards any offline-only work that hasn't been pushed — acceptable on
  /// first login because the user hasn't done anything meaningful yet, and
  /// on invite-accept because their data now moves to the inviter's family.
  Future<void> _resetLocal(String familyId, String userId) async {
    final isar = isarService.isar;
    await isar.writeTxn(() async {
      await isar.clear();
    });
    await prefs.setString('userId', userId);
    await prefs.setString('familyId', familyId);
    // Skip local seed — server will provide categories via sync/pull.
    await prefs.setBool('seeded', true);
  }
}
