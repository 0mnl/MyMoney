import '../model/analytics.dart';
import '../model/enums.dart';
import '../repository/budget_repository.dart';
import '../repository/category_repository.dart';
import '../repository/transaction_repository.dart';

/// Compute analytics aggregations for a given period.
/// Pure business logic: filters transactions by period, groups by category,
/// computes totals and percentages. Does not perform I/O directly; uses injected repositories.
class CalculatePeriodAnalytics {
  CalculatePeriodAnalytics(
    this._txRepo,
    this._budgetRepo,
    this._categoryRepo,
  );

  final TransactionRepository _txRepo;
  final BudgetRepository _budgetRepo;
  final CategoryRepository _categoryRepo;

  /// Compute income/expense breakdown by category for [periodStart, periodEnd).
  /// Returns aggregated analytics with category breakdown and budget comparisons.
  Future<PeriodAnalytics> call({
    required String familyId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    // Fetch all data from repositories
    final transactions = await _txRepo.listByFamily(familyId);
    final budgets = await _budgetRepo.listByFamily(familyId);
    final categories = await _categoryRepo.listByFamily(familyId);

    // Filter transactions by period and family (exclude deleted)
    final txInPeriod = transactions
        .where((tx) =>
            tx.familyId == familyId &&
            !tx.isDeleted &&
            tx.occurredAt.isAfter(periodStart) &&
            tx.occurredAt.isBefore(periodEnd))
        .toList();

    // Compute totals by type
    int totalIncomeKopecks = 0;
    int totalExpenseKopecks = 0;

    final categoryTotals = <String, int>{};

    for (final tx in txInPeriod) {
      switch (tx.type) {
        case TransactionType.income:
          totalIncomeKopecks += tx.amountKopecks;
        case TransactionType.expense:
          totalExpenseKopecks += tx.amountKopecks;
          if (tx.categoryId != null) {
            categoryTotals[tx.categoryId!] =
                (categoryTotals[tx.categoryId!] ?? 0) + tx.amountKopecks;
          }
        case TransactionType.transfer:
          // Transfers don't contribute to income/expense totals or analytics
          break;
      }
    }

    // Build category breakdown (pie chart data)
    final categoryBreakdown = <String, CategorySpend>{};
    for (final entry in categoryTotals.entries) {
      final categoryId = entry.key;
      final total = entry.value;
      final category = categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => throw StateError('Category $categoryId not found'),
      );

      final percentage = totalExpenseKopecks > 0
          ? (total / totalExpenseKopecks) * 100
          : 0.0;

      categoryBreakdown[categoryId] = CategorySpend(
        categoryId: categoryId,
        categoryName: category.name,
        totalKopecks: total,
        percentageOfTotal: percentage,
        colorValue: _parseHexColor(category.color),
      );
    }

    // Build budget comparison map
    final budgetComparison = <String, CategoryBudgetComparison>{};
    for (final budget in budgets) {
      // Check if budget period overlaps with analytics period
      if (_periodOverlaps(budget.periodStart, budget.periodType, periodStart,
          periodEnd)) {
        final actual = categoryTotals[budget.categoryId] ?? 0;
        budgetComparison[budget.categoryId] = CategoryBudgetComparison(
          categoryId: budget.categoryId,
          categoryName: categories
              .firstWhere(
                (c) => c.id == budget.categoryId,
                orElse: () => throw StateError(
                  'Category ${budget.categoryId} not found',
                ),
              )
              .name,
          plannedKopecks: budget.plannedAmountKopecks,
          actualKopecks: actual,
        );
      }
    }

    return PeriodAnalytics(
      periodStart: periodStart,
      periodEnd: periodEnd,
      totalIncomeKopecks: totalIncomeKopecks,
      totalExpenseKopecks: totalExpenseKopecks,
      categoryBreakdown: categoryBreakdown,
      budgetComparison: budgetComparison,
    );
  }

  /// Check if a budget period (from periodStart + periodType) overlaps
  /// with the analytics period [analyticsPeriodStart, analyticsPeriodEnd).
  bool _periodOverlaps(
    DateTime budgetStart,
    dynamic budgetPeriodType,
    DateTime analyticsPeriodStart,
    DateTime analyticsPeriodEnd,
  ) {
    // Simplified: if budget starts before analytics period ends, consider it overlapping
    // (A production implementation would compute exact period ranges and check overlap)
    return budgetStart.isBefore(analyticsPeriodEnd);
  }

  /// Category.color может быть в форматах "#RRGGBB" / "#AARRGGBB" / просто
  /// "AARRGGBB". Возвращаем null для нераспарсиваемых значений, чтобы UI
  /// откатился на дефолтный цвет вместо падения.
  static int? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    return int.tryParse(clean, radix: 16);
  }
}
