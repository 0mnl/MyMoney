enum BudgetPeriodType { week, month, year }

extension BudgetPeriodTypeX on BudgetPeriodType {
  String get code => switch (this) {
        BudgetPeriodType.week => 'WEEK',
        BudgetPeriodType.month => 'MONTH',
        BudgetPeriodType.year => 'YEAR',
      };

  String get labelRu => switch (this) {
        BudgetPeriodType.week => 'Неделя',
        BudgetPeriodType.month => 'Месяц',
        BudgetPeriodType.year => 'Год',
      };
}

/// Плановая сумма расходов на категорию за период [periodStart, +period).
class Budget {
  final String id;
  final String familyId;
  final String categoryId;
  final BudgetPeriodType periodType;
  final DateTime periodStart;
  final int plannedAmountKopecks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const Budget({
    required this.id,
    required this.familyId,
    required this.categoryId,
    required this.periodType,
    required this.periodStart,
    required this.plannedAmountKopecks,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Budget copyWith({
    int? plannedAmountKopecks,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      Budget(
        id: id,
        familyId: familyId,
        categoryId: categoryId,
        periodType: periodType,
        periodStart: periodStart,
        plannedAmountKopecks: plannedAmountKopecks ?? this.plannedAmountKopecks,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}

/// Прогресс — чистое вычисление на клиенте, не хранится.
class BudgetProgress {
  final Budget budget;
  final int spentAmountKopecks;
  final int remainingAmountKopecks;
  final int progressPercent;
  final bool isOverspent;

  const BudgetProgress({
    required this.budget,
    required this.spentAmountKopecks,
    required this.remainingAmountKopecks,
    required this.progressPercent,
    required this.isOverspent,
  });
}
