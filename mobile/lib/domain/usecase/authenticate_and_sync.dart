import 'package:shared_preferences/shared_preferences.dart';

import '../../core/feature_flags.dart';
import '../../data/local/isar_service.dart';
import '../../data/remote/api/auth_api.dart';
import '../../data/remote/auth_store.dart';
import '../../sync/sync_manager.dart';

/// Wraps register/login so the caller gets one method that also:
///  - persists tokens into secure storage
///  - resets local Isar and preferences to match the authenticated family
///  - performs the first sync (pulls the server state) — **только когда
///    `FeatureFlags.cloudSync` включён**; иначе шаг пропускается, а локальная
///    база засевается системными категориями и счётом по умолчанию
///
/// Вход и регистрация работают в обоих режимах: флаг гасит только обмен
/// данными с сервером, а не аутентификацию.
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
    // Reset sync cursors so the initial pull is a full snapshot. Оба: один
    // отвечает за pull (часы сервера), второй за push (часы устройства) —
    // см. комментарий к SyncManager. Забыть второй значило бы, что после
    // входа на новом устройстве push считает уже отправленным всё, что
    // старше прошлой сессии.
    await prefs.remove('sync.last_synced_at');
    await prefs.remove('sync.last_pushed_at');
    if (FeatureFlags.cloudSync) {
      try {
        await syncManager.sync();
      } catch (_) {
        // First sync failure shouldn't kill the login flow — the user is
        // authenticated locally and the app will retry on the next tick.
      }
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
    // При включённой синхронизации локальный сид пропускаем — категории и
    // счёт придут с сервера через sync/pull (их заводит регистрация:
    // SeedSystemCategoriesUseCase + SeedDefaultAccountUseCase). Сеять те же
    // сущности ещё и здесь значило бы получить два «Наличных» с разными id.
    //
    // При выключенной — сид обязателен. Иначе после входа база остаётся
    // пустой навсегда: сервер ничего не пришлёт, а bootstrapProvider сеет
    // только при `seeded == false`. Пользователь не смог бы добавить ни одной
    // операции — экран «Новая операция» требует и счёт, и категорию.
    // Сеем уже с familyId, который выдал сервер, так что при включении
    // синхронизации данные сойдутся без миграции.
    await prefs.setBool('seeded', FeatureFlags.cloudSync);
  }
}
