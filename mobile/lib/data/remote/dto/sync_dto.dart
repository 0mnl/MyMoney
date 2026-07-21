import '../../../domain/model/account.dart';
import '../../../domain/model/budget.dart';
import '../../../domain/model/category.dart';
import '../../../domain/model/enums.dart';
import '../../../domain/model/goal.dart';
import '../../../domain/model/transaction.dart';

/// Wire-level bundle exchanged with /v1/sync/pull and /v1/sync/push.
///
/// Field order and JSON shape must stay lock-step with the Kotlin
/// SyncBundleDto (see backend/.../delivery/http/dto/SyncDto.kt). If either
/// side drifts, sync silently corrupts data.
class SyncBundleDto {
  const SyncBundleDto({
    this.accounts = const [],
    this.categories = const [],
    this.transactions = const [],
    this.budgets = const [],
    this.goals = const [],
  });

  final List<Account> accounts;
  final List<Category> categories;
  final List<Transaction> transactions;
  final List<Budget> budgets;
  final List<Goal> goals;

  bool get isEmpty =>
      accounts.isEmpty &&
      categories.isEmpty &&
      transactions.isEmpty &&
      budgets.isEmpty &&
      goals.isEmpty;

  Map<String, dynamic> toJson() => {
        'accounts': accounts.map(accountToJson).toList(),
        'categories': categories.map(categoryToJson).toList(),
        'transactions': transactions.map(transactionToJson).toList(),
        'budgets': budgets.map(budgetToJson).toList(),
        'goals': goals.map(goalToJson).toList(),
        'families': const <Map<String, dynamic>>[],
        'familyMembers': const <Map<String, dynamic>>[],
      };

  static SyncBundleDto fromJson(Map<String, dynamic> json) => SyncBundleDto(
        accounts: (json['accounts'] as List<dynamic>? ?? const [])
            .map((e) => accountFromJson(e as Map<String, dynamic>))
            .toList(),
        categories: (json['categories'] as List<dynamic>? ?? const [])
            .map((e) => categoryFromJson(e as Map<String, dynamic>))
            .toList(),
        transactions: (json['transactions'] as List<dynamic>? ?? const [])
            .map((e) => transactionFromJson(e as Map<String, dynamic>))
            .toList(),
        budgets: (json['budgets'] as List<dynamic>? ?? const [])
            .map((e) => budgetFromJson(e as Map<String, dynamic>))
            .toList(),
        goals: (json['goals'] as List<dynamic>? ?? const [])
            .map((e) => goalFromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SyncPullResponse {
  const SyncPullResponse({required this.serverTime, required this.bundle});
  final DateTime serverTime;
  final SyncBundleDto bundle;

  static SyncPullResponse fromJson(Map<String, dynamic> json) => SyncPullResponse(
        serverTime: DateTime.parse(json['serverTime'] as String).toUtc(),
        bundle: SyncBundleDto.fromJson(json['bundle'] as Map<String, dynamic>),
      );
}

class SyncPushResponse {
  const SyncPushResponse({
    required this.serverTime,
    required this.accepted,
    required this.conflicts,
  });
  final DateTime serverTime;
  final List<AcceptedRef> accepted;
  final List<SyncConflict> conflicts;

  static SyncPushResponse fromJson(Map<String, dynamic> json) => SyncPushResponse(
        serverTime: DateTime.parse(json['serverTime'] as String).toUtc(),
        accepted: (json['accepted'] as List<dynamic>? ?? const [])
            .map((e) => AcceptedRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        conflicts: (json['conflicts'] as List<dynamic>? ?? const [])
            .map((e) => SyncConflict.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AcceptedRef {
  const AcceptedRef({required this.table, required this.id});
  final String table;
  final String id;
  static AcceptedRef fromJson(Map<String, dynamic> json) =>
      AcceptedRef(table: json['table'] as String, id: json['id'] as String);
}

class SyncConflict {
  const SyncConflict({
    required this.table,
    required this.id,
    required this.serverBundle,
  });
  final String table;
  final String id;
  final SyncBundleDto serverBundle;
  static SyncConflict fromJson(Map<String, dynamic> json) => SyncConflict(
        table: json['table'] as String,
        id: json['id'] as String,
        serverBundle: SyncBundleDto.fromJson(json['serverBundle'] as Map<String, dynamic>),
      );
}

// --- Per-entity conversions -------------------------------------------------

Map<String, dynamic> accountToJson(Account a) => {
      'id': a.id,
      'familyId': a.familyId,
      'name': a.name,
      'type': a.type,
      'currency': a.currency,
      'initialBalanceKopecks': a.initialBalanceKopecks,
      'isArchived': a.isArchived,
      'isDeleted': a.isDeleted,
      'createdAt': _iso(a.createdAt),
      'updatedAt': _iso(a.updatedAt),
    };

Account accountFromJson(Map<String, dynamic> j) => Account(
      id: j['id'] as String,
      familyId: j['familyId'] as String,
      name: j['name'] as String,
      type: j['type'] as String,
      currency: j['currency'] as String? ?? 'RUB',
      initialBalanceKopecks: (j['initialBalanceKopecks'] as num).toInt(),
      isArchived: j['isArchived'] as bool? ?? false,
      isDeleted: j['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
    );

Map<String, dynamic> categoryToJson(Category c) => {
      'id': c.id,
      'familyId': c.familyId,
      'parentCategoryId': c.parentCategoryId,
      'name': c.name,
      'type': c.type.code,
      'isMandatory': c.isMandatory,
      'isSystem': c.isSystem,
      'icon': c.icon,
      'color': c.color,
      'isArchived': c.isArchived,
      'isDeleted': c.isDeleted,
      'createdAt': _iso(c.createdAt),
      'updatedAt': _iso(c.updatedAt),
    };

Category categoryFromJson(Map<String, dynamic> j) => Category(
      id: j['id'] as String,
      familyId: j['familyId'] as String,
      parentCategoryId: j['parentCategoryId'] as String?,
      name: j['name'] as String,
      type: _parseCategoryType(j['type'] as String),
      isMandatory: j['isMandatory'] as bool? ?? false,
      isSystem: j['isSystem'] as bool? ?? false,
      icon: j['icon'] as String?,
      color: j['color'] as String?,
      isArchived: j['isArchived'] as bool? ?? false,
      isDeleted: j['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
    );

Map<String, dynamic> transactionToJson(Transaction t) => {
      'id': t.id,
      'familyId': t.familyId,
      'accountId': t.accountId,
      'categoryId': t.categoryId,
      'type': t.type.code,
      'targetAccountId': t.targetAccountId,
      'amountKopecks': t.amountKopecks,
      'currency': t.currency,
      'occurredAt': _iso(t.occurredAt),
      'comment': t.comment,
      'attachmentPhotoPath': t.attachmentPhotoPath,
      'createdBy': t.createdBy,
      'createdAt': _iso(t.createdAt),
      'updatedAt': _iso(t.updatedAt),
      'isDeleted': t.isDeleted,
    };

Transaction transactionFromJson(Map<String, dynamic> j) => Transaction(
      id: j['id'] as String,
      familyId: j['familyId'] as String,
      accountId: j['accountId'] as String,
      categoryId: j['categoryId'] as String?,
      type: _parseTransactionType(j['type'] as String),
      targetAccountId: j['targetAccountId'] as String?,
      amountKopecks: (j['amountKopecks'] as num).toInt(),
      currency: j['currency'] as String? ?? 'RUB',
      occurredAt: DateTime.parse(j['occurredAt'] as String).toUtc(),
      comment: j['comment'] as String?,
      attachmentPhotoPath: j['attachmentPhotoPath'] as String?,
      createdBy: j['createdBy'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
      isDeleted: j['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> budgetToJson(Budget b) => {
      'id': b.id,
      'familyId': b.familyId,
      'categoryId': b.categoryId,
      'periodType': b.periodType.code,
      'periodStart': _iso(b.periodStart),
      'plannedAmountKopecks': b.plannedAmountKopecks,
      'isDeleted': b.isDeleted,
      'createdAt': _iso(b.createdAt),
      'updatedAt': _iso(b.updatedAt),
    };

Budget budgetFromJson(Map<String, dynamic> j) => Budget(
      id: j['id'] as String,
      familyId: j['familyId'] as String,
      categoryId: j['categoryId'] as String,
      periodType: _parseBudgetPeriodType(j['periodType'] as String),
      periodStart: DateTime.parse(j['periodStart'] as String).toUtc(),
      plannedAmountKopecks: (j['plannedAmountKopecks'] as num).toInt(),
      createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
      isDeleted: j['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> goalToJson(Goal g) => {
      'id': g.id,
      'familyId': g.familyId,
      'name': g.name,
      'targetAmountKopecks': g.targetAmountKopecks,
      'currentAmountKopecks': g.currentAmountKopecks,
      'targetDate': g.targetDate == null ? null : _iso(g.targetDate!),
      'isDeleted': g.isDeleted,
      'createdAt': _iso(g.createdAt),
      'updatedAt': _iso(g.updatedAt),
    };

Goal goalFromJson(Map<String, dynamic> j) => Goal(
      id: j['id'] as String,
      familyId: j['familyId'] as String,
      name: j['name'] as String,
      targetAmountKopecks: (j['targetAmountKopecks'] as num).toInt(),
      currentAmountKopecks: (j['currentAmountKopecks'] as num).toInt(),
      targetDate: j['targetDate'] == null
          ? null
          : DateTime.parse(j['targetDate'] as String).toUtc(),
      createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
      isDeleted: j['isDeleted'] as bool? ?? false,
    );

String _iso(DateTime dt) => dt.toUtc().toIso8601String();

CategoryType _parseCategoryType(String s) => switch (s) {
      'INCOME' => CategoryType.income,
      'EXPENSE' => CategoryType.expense,
      _ => throw ArgumentError('Unknown CategoryType: $s'),
    };

TransactionType _parseTransactionType(String s) => switch (s) {
      'INCOME' => TransactionType.income,
      'EXPENSE' => TransactionType.expense,
      'TRANSFER' => TransactionType.transfer,
      _ => throw ArgumentError('Unknown TransactionType: $s'),
    };

BudgetPeriodType _parseBudgetPeriodType(String s) => switch (s) {
      'WEEK' => BudgetPeriodType.week,
      'MONTH' => BudgetPeriodType.month,
      'YEAR' => BudgetPeriodType.year,
      _ => throw ArgumentError('Unknown BudgetPeriodType: $s'),
    };
