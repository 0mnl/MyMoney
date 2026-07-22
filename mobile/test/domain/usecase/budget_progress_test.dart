import 'package:flutter_test/flutter_test.dart';
import 'package:mymoney/domain/model/budget.dart';
import 'package:mymoney/domain/model/enums.dart';
import 'package:mymoney/domain/model/transaction.dart';
import 'package:mymoney/domain/usecase/budget_progress.dart';

Budget _budget({
  int planned = 100000,
  BudgetPeriodType period = BudgetPeriodType.month,
  DateTime? start,
}) =>
    Budget(
      id: 'b1',
      familyId: 'f1',
      categoryId: 'c1',
      periodType: period,
      periodStart: start ?? DateTime.utc(2026, 7, 1),
      plannedAmountKopecks: planned,
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );

Transaction _tx({
  required int amount,
  DateTime? at,
  TransactionType type = TransactionType.expense,
  String category = 'c1',
  bool deleted = false,
}) =>
    Transaction(
      id: 't${amount}_${at?.millisecondsSinceEpoch ?? 0}',
      familyId: 'f1',
      accountId: 'a1',
      categoryId: category,
      type: type,
      amountKopecks: amount,
      occurredAt: at ?? DateTime.utc(2026, 7, 10),
      createdBy: 'u1',
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
      isDeleted: deleted,
    );

void main() {
  group('computeBudgetProgress', () {
    test('без транзакций — прогресс 0, не перерасход', () {
      final p = computeBudgetProgress(_budget(), const []);
      expect(p.spentAmountKopecks, 0);
      expect(p.progressPercent, 0);
      expect(p.isOverspent, false);
    });

    test('расход в периоде — считает spent и процент', () {
      final p = computeBudgetProgress(_budget(planned: 100000), [
        _tx(amount: 25000),
        _tx(amount: 25000, at: DateTime.utc(2026, 7, 20)),
      ]);
      expect(p.spentAmountKopecks, 50000);
      expect(p.remainingAmountKopecks, 50000);
      expect(p.progressPercent, 50);
      expect(p.isOverspent, false);
    });

    test('перерасход — isOverspent=true, remaining < 0', () {
      final p = computeBudgetProgress(_budget(planned: 30000), [
        _tx(amount: 40000),
      ]);
      expect(p.spentAmountKopecks, 40000);
      expect(p.remainingAmountKopecks, -10000);
      expect(p.isOverspent, true);
    });

    test('игнорирует другую категорию', () {
      final p = computeBudgetProgress(_budget(), [
        _tx(amount: 50000, category: 'other'),
      ]);
      expect(p.spentAmountKopecks, 0);
    });

    test('игнорирует удалённые и доходы', () {
      final p = computeBudgetProgress(_budget(), [
        _tx(amount: 10000, deleted: true),
        _tx(amount: 10000, type: TransactionType.income),
      ]);
      expect(p.spentAmountKopecks, 0);
    });

    test('игнорирует транзакции вне периода', () {
      final p = computeBudgetProgress(
        _budget(period: BudgetPeriodType.month, start: DateTime.utc(2026, 7, 1)),
        [
          _tx(amount: 10000, at: DateTime.utc(2026, 6, 30, 23)),
          _tx(amount: 10000, at: DateTime.utc(2026, 8, 1, 1)),
        ],
      );
      expect(p.spentAmountKopecks, 0);
    });

    test('budgetPeriodEnd для недели = +7 дней', () {
      final end = budgetPeriodEnd(BudgetPeriodType.week, DateTime.utc(2026, 7, 1));
      expect(end, DateTime.utc(2026, 7, 8));
    });

    test('budgetPeriodEnd для месяца = +1 месяц', () {
      final end = budgetPeriodEnd(BudgetPeriodType.month, DateTime.utc(2026, 7, 1));
      expect(end, DateTime.utc(2026, 8, 1));
    });

    test('budgetPeriodEnd для года = +1 год', () {
      final end = budgetPeriodEnd(BudgetPeriodType.year, DateTime.utc(2026, 7, 1));
      expect(end, DateTime.utc(2027, 7, 1));
    });
  });
}
