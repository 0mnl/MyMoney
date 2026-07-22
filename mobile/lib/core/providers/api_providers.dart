import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/remote/api/auth_api.dart';
import '../../data/remote/api/family_api.dart';
import '../../data/remote/api/sync_api.dart';
import '../../data/remote/auth_store.dart';
import '../../data/remote/dio_client.dart';
import '../../domain/usecase/authenticate_and_sync.dart';
import '../../sync/sync_manager.dart';
import '../../sync/sync_scheduler.dart';
import '../env.dart';
import 'app_providers.dart';

/// Backend URL override. Users type it into the Settings screen and it lands
/// in shared_preferences so the choice survives restart. Falls back to the
/// compile-time default from Env (10.0.2.2:8080 on Android emulator).
final apiBaseUrlProvider = FutureProvider<String>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getString('api.base_url') ?? Env.apiBaseUrl;
});

Future<void> setApiBaseUrl(SharedPreferences prefs, String url) async {
  await prefs.setString('api.base_url', url.trim());
}

final authStoreProvider = Provider<AuthStore>((ref) => AuthStore());

final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final baseUrl = await ref.watch(apiBaseUrlProvider.future);
  final store = ref.watch(authStoreProvider);
  return ApiClient(baseUrl: baseUrl, authStore: store);
});

final authApiProvider = FutureProvider<AuthApi>((ref) async {
  final client = await ref.watch(apiClientProvider.future);
  return AuthApi(client);
});

final familyApiProvider = FutureProvider<FamilyApi>((ref) async {
  final client = await ref.watch(apiClientProvider.future);
  return FamilyApi(client);
});

final syncApiProvider = FutureProvider<SyncApi>((ref) async {
  final client = await ref.watch(apiClientProvider.future);
  return SyncApi(client);
});

final syncManagerProvider = FutureProvider<SyncManager>((ref) async {
  final isar = await ref.watch(isarServiceProvider.future);
  final api = await ref.watch(syncApiProvider.future);
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return SyncManager(
    isarService: isar,
    syncApi: api,
    prefs: prefs,
    logger: Logger(),
  );
});

final authenticateAndSyncProvider = FutureProvider<AuthenticateAndSyncUseCase>((ref) async {
  final authApi = await ref.watch(authApiProvider.future);
  final store = ref.watch(authStoreProvider);
  final isar = await ref.watch(isarServiceProvider.future);
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final syncManager = await ref.watch(syncManagerProvider.future);
  return AuthenticateAndSyncUseCase(
    authApi: authApi,
    authStore: store,
    isarService: isar,
    prefs: prefs,
    syncManager: syncManager,
  );
});

/// Tracks the current auth state so screens can react (login screen vs shell).
/// Populated once at startup by reading AuthStore, then updated by
/// AuthService when the user logs in / out.
final authSnapshotProvider =
    AsyncNotifierProvider<AuthSnapshotNotifier, AuthSnapshot?>(AuthSnapshotNotifier.new);

class AuthSnapshotNotifier extends AsyncNotifier<AuthSnapshot?> {
  @override
  Future<AuthSnapshot?> build() async {
    final store = ref.watch(authStoreProvider);
    return store.load();
  }

  Future<void> setSession(AuthSnapshot snap) async {
    state = AsyncData(snap);
  }

  Future<void> clearSession() async {
    state = const AsyncData(null);
  }
}

/// Long-lived scheduler. Started on app-boot once the session is loaded.
/// Rebuilt (and previous instance disposed) when the base URL or session
/// changes, so subsequent syncs always go to the right backend.
final syncSchedulerProvider = FutureProvider<SyncScheduler>((ref) async {
  final manager = await ref.watch(syncManagerProvider.future);
  final interval = Duration(seconds: Env.syncIntervalSeconds);
  final scheduler = SyncScheduler(
    manager: manager,
    interval: interval,
    logger: Logger(),
  );
  ref.onDispose(() => scheduler.dispose());
  return scheduler;
});

/// Rebroadcasts SyncScheduler.statusStream as a Riverpod stream so widgets
/// can `.watch(syncStatusProvider)` and rebuild on phase changes.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final scheduler = await ref.watch(syncSchedulerProvider.future);
  yield scheduler.status;
  yield* scheduler.statusStream;
});
