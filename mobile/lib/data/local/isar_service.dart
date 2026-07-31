import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'entities/account_entity.dart';
import 'entities/budget_entity.dart';
import 'entities/category_entity.dart';
import 'entities/debt_entity.dart';
import 'entities/debt_payment_entity.dart';
import 'entities/goal_entity.dart';
import 'entities/subscription_entity.dart';
import 'entities/transaction_entity.dart';

/// Owns the Isar instance for the entire app. Opened once at startup and
/// closed on app termination (Riverpod handles disposal).
class IsarService {
  IsarService._(this.isar);

  final Isar isar;

  static Future<IsarService> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final instance = await Isar.open(
      [
        AccountEntitySchema,
        CategoryEntitySchema,
        TransactionEntitySchema,
        BudgetEntitySchema,
        GoalEntitySchema,
        DebtEntitySchema,
        DebtPaymentEntitySchema,
        SubscriptionEntitySchema,
      ],
      directory: dir.path,
      name: 'mymoney',
      inspector: kDebugMode,
      compactOnLaunch: const CompactCondition(
        minFileSize: 1 * 1024 * 1024,
        minBytes: 512 * 1024,
        minRatio: 1.3,
      ),
    );
    return IsarService._(instance);
  }

  Future<void> close() => isar.close();

  /// Hard-deletes soft-deleted records older than [days] days.
  /// Called once during bootstrap to keep the DB file small.
  Future<void> purgeOldSoftDeleted({int days = 30}) async {
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
    await isar.writeTxn(() async {
      await isar.transactionEntitys
          .filter()
          .isDeletedEqualTo(true)
          .occurredAtLessThan(cutoff)
          .deleteAll();

      await isar.accountEntitys
          .filter()
          .isDeletedEqualTo(true)
          .updatedAtLessThan(cutoff)
          .deleteAll();

      await isar.budgetEntitys
          .filter()
          .isDeletedEqualTo(true)
          .updatedAtLessThan(cutoff)
          .deleteAll();

      await isar.goalEntitys
          .filter()
          .isDeletedEqualTo(true)
          .updatedAtLessThan(cutoff)
          .deleteAll();

      await isar.debtEntitys
          .filter()
          .isDeletedEqualTo(true)
          .updatedAtLessThan(cutoff)
          .deleteAll();

      await isar.debtPaymentEntitys
          .filter()
          .isDeletedEqualTo(true)
          .updatedAtLessThan(cutoff)
          .deleteAll();

      await isar.subscriptionEntitys
          .filter()
          .isDeletedEqualTo(true)
          .updatedAtLessThan(cutoff)
          .deleteAll();
    });
  }
}
