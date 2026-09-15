import 'package:isar/isar.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/entities/account_entity.dart';
import '../data/local/entities/budget_entity.dart';
import '../data/local/entities/category_entity.dart';
import '../data/local/entities/debt_entity.dart';
import '../data/local/entities/debt_payment_entity.dart';
import '../data/local/entities/goal_entity.dart';
import '../data/local/entities/subscription_entity.dart';
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
///
/// ## Почему курсоров два
///
/// Изначально курсор был один: время сервера из ответа `pull` служило и
/// границей «что отдать серверу» для локальной выборки. Это молча теряло
/// данные. `updatedAt` у локальных строк ставят часы **устройства**, а
/// курсор приходил с часов **сервера**; стоило телефону отставать хотя бы на
/// минуту — и всё, что пользователь успевал записать в этот промежуток,
/// оказывалось «старее курсора» и не попадало в push никогда. Ошибки при
/// этом не было: операция спокойно лежала на устройстве и исчезала при
/// переустановке приложения.
///
/// Поэтому курсора два, каждый в своей системе отсчёта:
///  - [lastPushedAt] — часы устройства, граница для выборки локальных
///    изменений;
///  - [lastSyncedAt] — часы сервера, параметр `since` для `pull`.
///
/// Сравнение времени из разных источников больше нигде не происходит.
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

  /// Часы сервера. Ключ прежний — его чистит `AuthenticateAndSyncUseCase`,
  /// чтобы первый после входа pull пришёл полным снимком.
  static const _kLastSyncedAt = 'sync.last_synced_at';

  /// Часы устройства. Отдельно от [_kLastSyncedAt] — см. комментарий к классу.
  static const _kLastPushedAt = 'sync.last_pushed_at';

  DateTime? get lastSyncedAt => _readInstant(_kLastSyncedAt);

  DateTime? get lastPushedAt => _readInstant(_kLastPushedAt);

  DateTime? _readInstant(String key) {
    final raw = prefs.getString(key);
    return raw == null ? null : DateTime.parse(raw).toUtc();
  }

  Future<void> _setLastSyncedAt(DateTime value) =>
      prefs.setString(_kLastSyncedAt, value.toUtc().toIso8601String());

  Future<void> _setLastPushedAt(DateTime value) =>
      prefs.setString(_kLastPushedAt, value.toUtc().toIso8601String());

  Future<SyncResult> sync() async {
    final pullSince = lastSyncedAt;
    final pushSince = lastPushedAt;
    // Засекаем ДО выборки, а не после отправки: всё, что пользователь успеет
    // записать за время сетевого запроса, останется новее курсора и уедет
    // следующим циклом. Ставить курсор по времени завершения push значило бы
    // проглотить эти записи.
    final cycleStart = DateTime.now().toUtc();
    _log.i('Sync cycle: pullSince=$pullSince pushSince=$pushSince');

    // 1. Push local dirty rows (updated after last successful push).
    final localBundle = await _collectDirty(pushSince);
    var conflicts = 0;
    if (!localBundle.isEmpty) {
      final pushed = await syncApi.push(localBundle);
      conflicts = pushed.conflicts.length;
      if (conflicts > 0) {
        await _applyBundle(_mergeConflicts(pushed.conflicts));
      }
      _log.i('Push: accepted=${pushed.accepted.length} conflicts=$conflicts');
    }
    // Двигаем курсор только после успешного push: любое исключение выше
    // оставит его на месте, и те же строки уйдут повторно. Push идемпотентен
    // (LWW по updatedAt), так что повтор безопаснее пропуска.
    await _setLastPushedAt(cycleStart);

    // 2. Pull server changes since last cursor.
    final pulled = await syncApi.pull(since: pullSince);
    await _applyBundle(pulled.bundle);
    await _setLastSyncedAt(pulled.serverTime);
    _log.i('Pull: applied ${_bundleSize(pulled.bundle)} rows, cursor=${pulled.serverTime}');

    return SyncResult(
      pushed: _bundleSize(localBundle),
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
    final debts = since == null
        ? await isar.debtEntitys.where().findAll()
        : await isar.debtEntitys.filter().updatedAtGreaterThan(since).findAll();
    // График платежей уезжал бы в никуда: сервер его принимает и отдаёт с
    // самого начала, а клиент не собирал и не применял — при переходе на
    // другое устройство долг приезжал без расписания погашения.
    final debtPayments = since == null
        ? await isar.debtPaymentEntitys.where().findAll()
        : await isar.debtPaymentEntitys.filter().updatedAtGreaterThan(since).findAll();
    final subs = since == null
        ? await isar.subscriptionEntitys.where().findAll()
        : await isar.subscriptionEntitys.filter().updatedAtGreaterThan(since).findAll();

    return SyncBundleDto(
      accounts: accounts.map((e) => e.toDomain()).toList(),
      categories: categories.map((e) => e.toDomain()).toList(),
      transactions: transactions.map((e) => e.toDomain()).toList(),
      budgets: budgets.map((e) => e.toDomain()).toList(),
      goals: goals.map((e) => e.toDomain()).toList(),
      debts: debts.map((e) => e.toDomain()).toList(),
      debtPayments: debtPayments.map((e) => e.toDomain()).toList(),
      subscriptions: subs.map((e) => e.toDomain()).toList(),
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
        debts: [...merged.debts, ...c.serverBundle.debts],
        debtPayments: [...merged.debtPayments, ...c.serverBundle.debtPayments],
        subscriptions: [...merged.subscriptions, ...c.serverBundle.subscriptions],
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
      if (bundle.debts.isNotEmpty) {
        await isar.debtEntitys.putAll(
          bundle.debts.map(DebtEntity.fromDomain).toList(),
        );
      }
      if (bundle.debtPayments.isNotEmpty) {
        await isar.debtPaymentEntitys.putAll(
          bundle.debtPayments.map(DebtPaymentEntity.fromDomain).toList(),
        );
      }
      if (bundle.subscriptions.isNotEmpty) {
        await isar.subscriptionEntitys.putAll(
          bundle.subscriptions.map(SubscriptionEntity.fromDomain).toList(),
        );
      }
    });
  }

  int _bundleSize(SyncBundleDto b) =>
      b.accounts.length +
      b.categories.length +
      b.transactions.length +
      b.budgets.length +
      b.goals.length +
      b.debts.length +
      b.debtPayments.length +
      b.subscriptions.length;
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
