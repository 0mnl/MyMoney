import '../model/budget.dart';
import '../model/enums.dart';
import '../model/transaction.dart';

/// Границы периода [start, end). Одинаковы на клиенте и сервере: WEEK — 7 дней
/// от старта; MONTH — +1 календарный месяц; YEAR — +1 календарный год.
DateTime budgetPeriodEnd(BudgetPeriodType type, DateTime start) {
  switch (type) {
    case BudgetPeriodType.week:
      return start.add(const Duration(days: 7));
    case BudgetPeriodType.month:
      return DateTime.utc(
        start.year,
        start.month + 1,
        start.day,
        start.hour,
        start.minute,
        start.second,
        start.millisecond,
      );
    case BudgetPeriodType.year:
      return DateTime.utc(
        start.year + 1,
        start.month,
        start.day,
        start.hour,
        start.minute,
        start.second,
        start.millisecond,
      );
  }
}

BudgetProgress computeBudgetProgress(Budget budget, Iterable<Transaction> transactions) {
  final end = budgetPeriodEnd(budget.periodType, budget.periodStart);
  final spent = transactions
      .where((t) =>
          !t.isDeleted &&
          t.type == TransactionType.expense &&
          t.familyId == budget.familyId &&
          t.categoryId == budget.categoryId &&
          !t.occurredAt.isBefore(budget.periodStart) &&
          t.occurredAt.isBefore(end))
      .fold<int>(0, (acc, t) => acc + t.amountKopecks);

  final planned = budget.plannedAmountKopecks;
  final remaining = planned - spent;
  final percent = planned <= 0 ? 0 : ((spent * 100 ~/ planned)).clamp(0, 1000000);
  return BudgetProgress(
    budget: budget,
    spentAmountKopecks: spent,
    remainingAmountKopecks: remaining,
    progressPercent: percent,
    isOverspent: spent > planned,
  );
}
