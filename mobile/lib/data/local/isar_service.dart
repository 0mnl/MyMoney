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
/// closed on app termination (Riverpod handles disposal). The three
/// collections here are the whole Etap 1 offline data model.
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
      inspector: true,
    );
    return IsarService._(instance);
  }

  Future<void> close() => isar.close();
}
