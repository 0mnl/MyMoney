// Placeholder test — real integration tests will be added once the sync
// layer lands (Etap 4). Full app boot requires Isar/SharedPreferences and
// belongs in `integration_test/`, not in this widget-level suite.

import 'package:flutter_test/flutter_test.dart';

import 'package:mymoney/domain/model/budget.dart';
import 'package:mymoney/domain/model/enums.dart';
import 'package:mymoney/domain/model/goal.dart';
import 'package:mymoney/domain/model/transaction.dart';
import 'package:mymoney/domain/usecase/budget_progress.dart';

void main() {
  test('budget progress counts only in-window expenses of the same category', () {
    final start = DateTime.utc(2026, 7, 1);
    final budget = Budget(
      id: 'b',
      familyId: 'f',
      categoryId: 'c',
      periodType: BudgetPeriodType.month,
      periodStart: start,
      plannedAmountKopecks: 100000,
      createdAt: start,
      updatedAt: start,
    );
    final txs = [
      Transaction(
        id: 't1',
        familyId: 'f',
        accountId: 'a',
        categoryId: 'c',
        type: TransactionType.expense,
        amountKopecks: 40000,
        occurredAt: DateTime.utc(2026, 7, 10),
        createdBy: 'u',
        createdAt: start,
        updatedAt: start,
      ),
      // wrong category
      Transaction(
        id: 't2',
        familyId: 'f',
        accountId: 'a',
        categoryId: 'other',
        type: TransactionType.expense,
        amountKopecks: 999999,
        occurredAt: DateTime.utc(2026, 7, 10),
        createdBy: 'u',
        createdAt: start,
        updatedAt: start,
      ),
      // out of window
      Transaction(
        id: 't3',
        familyId: 'f',
        accountId: 'a',
        categoryId: 'c',
        type: TransactionType.expense,
        amountKopecks: 999999,
        occurredAt: DateTime.utc(2026, 8, 5),
        createdBy: 'u',
        createdAt: start,
        updatedAt: start,
      ),
    ];

    final progress = computeBudgetProgress(budget, txs);
    expect(progress.spentAmountKopecks, 40000);
    expect(progress.remainingAmountKopecks, 60000);
    expect(progress.progressPercent, 40);
    expect(progress.isOverspent, false);
  });

  test('goal progress percent clamps to 100 when reached', () {
    final now = DateTime.utc(2026, 7, 1);
    final goal = Goal(
      id: 'g',
      familyId: 'f',
      name: 'Vacation',
      targetAmountKopecks: 100,
      currentAmountKopecks: 150,
      createdAt: now,
      updatedAt: now,
    );
    expect(goal.progressPercent, 100);
    expect(goal.isCompleted, true);
  });
}
