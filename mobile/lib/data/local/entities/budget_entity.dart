import 'package:isar/isar.dart';

import '../../../domain/model/budget.dart';

part 'budget_entity.g.dart';

/// Persisted by name — never renumber or rename.
enum IsarBudgetPeriodType { week, month, year }

@collection
class BudgetEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String familyId;

  @Index()
  late String categoryId;

  @enumerated
  late IsarBudgetPeriodType periodType;

  late DateTime periodStart;
  late int plannedAmountKopecks;

  late DateTime createdAt;
  late DateTime updatedAt;
  late bool isDeleted;

  Budget toDomain() => Budget(
        id: id,
        familyId: familyId,
        categoryId: categoryId,
        periodType: switch (periodType) {
          IsarBudgetPeriodType.week => BudgetPeriodType.week,
          IsarBudgetPeriodType.month => BudgetPeriodType.month,
          IsarBudgetPeriodType.year => BudgetPeriodType.year,
        },
        periodStart: periodStart,
        plannedAmountKopecks: plannedAmountKopecks,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isDeleted: isDeleted,
      );

  static BudgetEntity fromDomain(Budget b) => BudgetEntity()
    ..id = b.id
    ..familyId = b.familyId
    ..categoryId = b.categoryId
    ..periodType = switch (b.periodType) {
      BudgetPeriodType.week => IsarBudgetPeriodType.week,
      BudgetPeriodType.month => IsarBudgetPeriodType.month,
      BudgetPeriodType.year => IsarBudgetPeriodType.year,
    }
    ..periodStart = b.periodStart
    ..plannedAmountKopecks = b.plannedAmountKopecks
    ..createdAt = b.createdAt
    ..updatedAt = b.updatedAt
    ..isDeleted = b.isDeleted;
}
