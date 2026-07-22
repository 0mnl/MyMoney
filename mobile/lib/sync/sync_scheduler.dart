import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

import 'sync_manager.dart';

/// Result-status snapshot for the UI. Updated by [SyncScheduler] whenever a
/// sync cycle starts, succeeds or fails; also reflects connectivity changes.
enum SyncPhase { idle, syncing, offline, error }

class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.lastResult,
    this.lastError,
    this.lastSyncedAt,
  });

  final SyncPhase phase;
  final SyncResult? lastResult;
  final Object? lastError;
  final DateTime? lastSyncedAt;

  SyncStatus copyWith({
    SyncPhase? phase,
    SyncResult? lastResult,
    Object? lastError,
    DateTime? lastSyncedAt,
  }) => SyncStatus(
        phase: phase ?? this.phase,
        lastResult: lastResult ?? this.lastResult,
        lastError: lastError,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );

  static const idle = SyncStatus(phase: SyncPhase.idle);
}

/// Drives [SyncManager] automatically:
///  - на старт (когда есть авторизация)
///  - при возврате связи через connectivity_plus
///  - каждые [interval] когда приложение на переднем плане
///  - при возобновлении из фона (WidgetsBindingObserver.resumed)
///
/// Никогда не бросает исключения наружу — все ошибки сохраняются в [status]
/// и логируются. UI видит только состояние.
class SyncScheduler with WidgetsBindingObserver {
  SyncScheduler({
    required SyncManager manager,
    Duration interval = const Duration(minutes: 15),
    Logger? logger,
    Connectivity? connectivity,
  })  : _manager = manager,
        _interval = interval,
        _log = logger ?? Logger(),
        _connectivity = connectivity ?? Connectivity();

  final SyncManager _manager;
  final Duration _interval;
  final Logger _log;
  final Connectivity _connectivity;

  final _statusCtrl = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.idle;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _syncInFlight = false;
  bool _hasNetwork = true;
  bool _started = false;

  Stream<SyncStatus> get statusStream => _statusCtrl.stream;
  SyncStatus get status => _status;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connSub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    _hasNetwork = await _probeConnectivity();
    _timer = Timer.periodic(_interval, (_) => triggerSync(reason: 'timer'));
    triggerSync(reason: 'start');
  }

  Future<void> dispose() async {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    _timer = null;
    await _connSub?.cancel();
    _connSub = null;
    WidgetsBinding.instance.removeObserver(this);
    await _statusCtrl.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      triggerSync(reason: 'resumed');
    }
  }

  Future<bool> _probeConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = _isOnline(results);
    final wasOffline = !_hasNetwork;
    _hasNetwork = online;
    if (!online) {
      _emit(_status.copyWith(phase: SyncPhase.offline));
    } else if (wasOffline) {
      triggerSync(reason: 'connectivity_restored');
    }
  }

  bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
  }

  /// Force a sync cycle. Safe to call from UI (Settings → «Синхронизировать сейчас»).
  /// Returns true if a cycle actually ran, false if skipped (already running or offline).
  Future<bool> triggerSync({String reason = 'manual'}) async {
    if (_syncInFlight) {
      _log.d('Sync skipped: already in-flight (reason=$reason)');
      return false;
    }
    if (!_hasNetwork) {
      _emit(_status.copyWith(phase: SyncPhase.offline));
      _log.d('Sync skipped: offline (reason=$reason)');
      return false;
    }
    _syncInFlight = true;
    _emit(_status.copyWith(phase: SyncPhase.syncing, lastError: null));
    try {
      final result = await _runWithRetry();
      _emit(
        SyncStatus(
          phase: SyncPhase.idle,
          lastResult: result,
          lastSyncedAt: result.serverTime,
        ),
      );
      _log.i('Sync ok (reason=$reason): $result');
      return true;
    } catch (e, st) {
      _log.w('Sync failed (reason=$reason)', error: e, stackTrace: st);
      _emit(_status.copyWith(phase: SyncPhase.error, lastError: e));
      return false;
    } finally {
      _syncInFlight = false;
    }
  }

  /// Retry with jittered exponential backoff for transient errors.
  /// Total budget: 3 attempts, up to ~7s combined — не блокируем UI и не
  /// затягиваем цикл больше периодических триггеров.
  Future<SyncResult> _runWithRetry() async {
    var attempt = 0;
    Object? lastError;
    while (attempt < 3) {
      try {
        return await _manager.sync();
      } catch (e) {
        lastError = e;
        attempt++;
        if (attempt >= 3) rethrow;
        final delayMs = 300 * (1 << (attempt - 1)); // 300, 600, 1200
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw lastError!;
  }

  void _emit(SyncStatus next) {
    _status = next;
    if (!_statusCtrl.isClosed) _statusCtrl.add(next);
  }
}
