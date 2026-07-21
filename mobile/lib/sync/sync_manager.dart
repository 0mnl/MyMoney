import 'package:isar/isar.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/entities/account_entity.dart';
import '../data/local/entities/budget_entity.dart';
import '../data/local/entities/category_entity.dart';
import '../data/local/entities/goal_entity.dart';
import '../data/local/entities/transaction_entity.dart';
import '../data/local/isar_service.dart';
import '../data/remote/api/sync_api.dart';
import '../data/remote/dto/sync_dto.dart';

/// Orchestrates a single push→pull cycle against the backend.
///
/// Rules (ADR-0005):
///  - Push always runs before pull inside a cycle, so freshly-made local
///    changes reach the server before pull can overwrite them.
///  - LWW conflicts returned by push must be applied locally — those rows
///    are already newer on the server and pull would return them anyway
///    (we handle them eagerly to keep the local UI consistent immediately).
///  - After a successful pull, `lastSyncedAt` is bumped to serverTime and
///    persisted, so the next cycle only asks for what changed since.
class SyncManager {
  SyncManager({
    required this.isarService,
    required this.syncApi,
    required this.prefs,
    Logger? logger,
  }) : _log = logger ?? Logger();

  final IsarService isarService;
  final SyncApi syncApi;
  final SharedPreferences prefs;
  final Logger _log;

  static const _kLastSyncedAt = 'sync.last_synced_at';

  DateTime? get lastSyncedAt {
    final raw = prefs.getString(_kLastSyncedAt);
    return raw == null ? null : DateTime.parse(raw).toUtc();
  }

  Future<void> _setLastSyncedAt(DateTime value) =>
      prefs.setString(_kLastSyncedAt, value.toUtc().toIso8601String());

  Future<SyncResult> sync() async {
    final since = lastSyncedAt;
    _log.i('Sync cycle: since=$since');

    // 1. Push local dirty rows (updated after last successful sync).
    final localBundle = await _collectDirty(since);
    var conflicts = 0;
    if (!localBundle.isEmpty) {
      final pushed = await syncApi.push(localBundle);
      conflicts = pushed.conflicts.length;
      if (conflicts > 0) {
        await _applyBundle(_mergeConflicts(pushed.conflicts));
      }
      _log.i('Push: accepted=${pushed.accepted.length} conflicts=$conflicts');
    }

    // 2. Pull server changes since last cursor.
    final pulled = await syncApi.pull(since: since);
    await _applyBundle(pulled.bundle);
    await _setLastSyncedAt(pulled.serverTime);
    _log.i('Pull: applied ${_bundleSize(pulled.bundle)} rows, cursor=${pulled.serverTime}');

    return SyncResult(
      pushed: localBundle.accounts.length +
          localBundle.categories.length +
          localBundle.transactions.length +
          localBundle.budgets.length +
          localBundle.goals.length,
      conflicts: conflicts,
      pulled: _bundleSize(pulled.bundle),
      serverTime: pulled.serverTime,
    );
  }

  Future<SyncBundleDto> _collectDirty(DateTime? since) async {
    final isar = isarService.isar;

    final accounts = since == null
        ? await isar.accountEntitys.where().findAll()
        : await isar.accountEntitys.filter().updatedAtGreaterThan(since).findAll();
    final categories = since == null
        ? await isar.categoryEntitys.where().findAll()
        : await isar.categoryEntitys.filter().updatedAtGreaterThan(since).findAll();
    final transactions = since == null
        ? await isar.transactionEntitys.where().findAll()
        : await isar.transactionEntitys.filter().updatedAtGreaterThan(since).findAll();
    final budgets = since == null
        ? await isar.budgetEntitys.where().findAll()
        : await isar.budgetEntitys.filter().updatedAtGreaterThan(since).findAll();
    final goals = since == null
        ? await isar.goalEntitys.where().findAll()
        : await isar.goalEntitys.filter().updatedAtGreaterThan(since).findAll();

    return SyncBundleDto(
      accounts: accounts.map((e) => e.toDomain()).toList(),
      categories: categories.map((e) => e.toDomain()).toList(),
      transactions: transactions.map((e) => e.toDomain()).toList(),
      budgets: budgets.map((e) => e.toDomain()).toList(),
      goals: goals.map((e) => e.toDomain()).toList(),
    );
  }

  SyncBundleDto _mergeConflicts(List<SyncConflict> conflicts) {
    // A conflict's serverBundle is single-entity — accumulate them.
    var merged = const SyncBundleDto();
    for (final c in conflicts) {
      merged = SyncBundleDto(
        accounts: [...merged.accounts, ...c.serverBundle.accounts],
        categories: [...merged.categories, ...c.serverBundle.categories],
        transactions: [...merged.transactions, ...c.serverBundle.transactions],
        budgets: [...merged.budgets, ...c.serverBundle.budgets],
        goals: [...merged.goals, ...c.serverBundle.goals],
      );
    }
    return merged;
  }

  Future<void> _applyBundle(SyncBundleDto bundle) async {
    final isar = isarService.isar;
    if (bundle.isEmpty) return;
    await isar.writeTxn(() async {
      if (bundle.accounts.isNotEmpty) {
        await isar.accountEntitys.putAll(
          bundle.accounts.map(AccountEntity.fromDomain).toList(),
        );
      }
      if (bundle.categories.isNotEmpty) {
        await isar.categoryEntitys.putAll(
          bundle.categories.map(CategoryEntity.fromDomain).toList(),
        );
      }
      if (bundle.transactions.isNotEmpty) {
        await isar.transactionEntitys.putAll(
          bundle.transactions.map(TransactionEntity.fromDomain).toList(),
        );
      }
      if (bundle.budgets.isNotEmpty) {
        await isar.budgetEntitys.putAll(
          bundle.budgets.map(BudgetEntity.fromDomain).toList(),
        );
      }
      if (bundle.goals.isNotEmpty) {
        await isar.goalEntitys.putAll(
          bundle.goals.map(GoalEntity.fromDomain).toList(),
        );
      }
    });
  }

  int _bundleSize(SyncBundleDto b) =>
      b.accounts.length +
      b.categories.length +
      b.transactions.length +
      b.budgets.length +
      b.goals.length;
}

class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.conflicts,
    required this.pulled,
    required this.serverTime,
  });
  final int pushed;
  final int conflicts;
  final int pulled;
  final DateTime serverTime;

  @override
  String toString() =>
      'SyncResult(pushed=$pushed, conflicts=$conflicts, pulled=$pulled, serverTime=$serverTime)';
}
