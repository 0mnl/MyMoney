import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../data/remote/api/auth_api.dart';
import '../../data/remote/api/family_api.dart';
import '../../data/remote/api/sync_api.dart';
import '../../data/remote/auth_store.dart';
import '../../data/remote/dio_client.dart';
import '../../domain/usecase/authenticate_and_sync.dart';
import '../../sync/sync_manager.dart';
import '../../sync/sync_scheduler.dart';
import '../env.dart';
import '../feature_flags.dart';
import 'app_providers.dart';

final authStoreProvider = Provider<AuthStore>((ref) => AuthStore());

/// Адрес бэкенда. Берётся только из [Env] — задаётся на сборке и не
/// меняется на устройстве.
///
/// Раньше значение можно было переопределить через SharedPreferences с
/// экрана «Подключение к серверу». Экран убран: пользователь не должен
/// видеть хостинг вообще, а возможность подменить адрес на произвольный —
/// ещё и готовый способ увести чужие учётные данные на чужой сервер.
final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(authStoreProvider);
  return ApiClient(baseUrl: Env.apiBaseUrl, authStore: store);
});

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

final familyApiProvider = Provider<FamilyApi>((ref) => FamilyApi(ref.watch(apiClientProvider)));

final syncApiProvider = Provider<SyncApi>((ref) => SyncApi(ref.watch(apiClientProvider)));

final syncManagerProvider = FutureProvider<SyncManager>((ref) async {
  final isar = await ref.watch(isarServiceProvider.future);
  final api = ref.watch(syncApiProvider);
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return SyncManager(
    isarService: isar,
    syncApi: api,
    prefs: prefs,
    logger: Logger(),
  );
});

final authenticateAndSyncProvider = FutureProvider<AuthenticateAndSyncUseCase>((ref) async {
  final authApi = ref.watch(authApiProvider);
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
  const interval = Duration(seconds: Env.syncIntervalSeconds);
  final scheduler = SyncScheduler(
    manager: manager,
    interval: interval,
    logger: Logger(),
  );
  ref.onDispose(() => scheduler.dispose());
  return scheduler;
});

/// Запускает планировщик синхронизации, когда есть сессия.
///
/// Планировщик существовал и раньше, но `start()` не вызывался ниоткуда:
/// провайдер создавал объект, объект молчал, и обмен с сервером происходил
/// ровно один раз — в момент входа. Данные, добавленные потом, не уезжали
/// никуда до следующего логина.
///
/// Провайдер намеренно возвращает `void` и не входит в критический путь
/// отрисовки: интерфейс не должен ждать сеть. Оболочка просто «касается» его
/// (`ref.watch`), чтобы он ожил и остался жить, пока жива сессия.
final syncBootstrapProvider = FutureProvider<void>((ref) async {
  if (!FeatureFlags.cloudSync) return;

  final session = await ref.watch(authSnapshotProvider.future);
  if (session == null) return;

  final scheduler = await ref.watch(syncSchedulerProvider.future);
  await scheduler.start();
});

/// Rebroadcasts SyncScheduler.statusStream as a Riverpod stream so widgets
/// can `.watch(syncStatusProvider)` and rebuild on phase changes.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final scheduler = await ref.watch(syncSchedulerProvider.future);
  yield scheduler.status;
  yield* scheduler.statusStream;
});
