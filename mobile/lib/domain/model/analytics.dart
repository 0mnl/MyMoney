import 'enums.dart';

/// Aggregated analytics data for a given time period.
class PeriodAnalytics {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalIncomeKopecks;
  final int totalExpenseKopecks;
  final Map<String, CategorySpend> categoryBreakdown;
  final Map<String, CategoryBudgetComparison> budgetComparison;

  int get netKopecks => totalIncomeKopecks - totalExpenseKopecks;

  const PeriodAnalytics({
    required this.periodStart,
    required this.periodEnd,
    required this.totalIncomeKopecks,
    required this.totalExpenseKopecks,
    required this.categoryBreakdown,
    required this.budgetComparison,
  });
}

/// Spending by single category (for pie chart data).
class CategorySpend {
  final String categoryId;
  final String categoryName;
  final int totalKopecks;
  final double percentageOfTotal;
  final int? colorValue;

  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.totalKopecks,
    required this.percentageOfTotal,
    this.colorValue,
  });
}

/// Budget tracking for a category in a period.
class CategoryBudgetComparison {
  final String categoryId;
  final String categoryName;
  final int plannedKopecks;
  final int actualKopecks;

  bool get isOverspent => actualKopecks > plannedKopecks;
  int get remainingKopecks => plannedKopecks - actualKopecks;

  const CategoryBudgetComparison({
    required this.categoryId,
    required this.categoryName,
    required this.plannedKopecks,
    required this.actualKopecks,
  });
}

/// Report summary for PDF export.
class ReportSummary {
  final String familyName;
  final String periodLabel;
  final int totalIncomeKopecks;
  final int totalExpenseKopecks;
  final int netKopecks;
  final int transactionCount;
  final int categoryCount;

  const ReportSummary({
    required this.familyName,
    required this.periodLabel,
    required this.totalIncomeKopecks,
    required this.totalExpenseKopecks,
    required this.netKopecks,
    required this.transactionCount,
    required this.categoryCount,
  });
}
