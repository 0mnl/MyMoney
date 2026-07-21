import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/analytics.dart';
import '../../domain/model/budget.dart';
import '../../domain/usecase/calculate_period_analytics.dart';

/// Selected period type for analytics display (week/month/year).
/// User can change this via segmented control, which triggers analytics recalculation.
final selectedAnalyticsPeriodProvider =
    StateProvider<BudgetPeriodType>((ref) => BudgetPeriodType.month);

/// Computed period range based on selected period type and current date.
/// Returns (periodStart, periodEnd) tuple where end is exclusive.
final analyticsPeriodRangeProvider =
    Provider<(DateTime, DateTime)>((ref) {
  final period = ref.watch(selectedAnalyticsPeriodProvider);
  final now = DateTime.now().toUtc();

  final (start, end) = switch (period) {
    BudgetPeriodType.week => (
      now.subtract(Duration(days: now.weekday - 1)),
      now.add(Duration(days: 8 - now.weekday))
    ),
    BudgetPeriodType.month => (
      DateTime.utc(now.year, now.month, 1),
      now.month == 12
          ? DateTime.utc(now.year + 1, 1, 1)
          : DateTime.utc(now.year, now.month + 1, 1)
    ),
    BudgetPeriodType.year => (
      DateTime.utc(now.year, 1, 1),
      DateTime.utc(now.year + 1, 1, 1)
    ),
  };
  return (start, end);
});

/// Use case provider: dependency injection for CalculatePeriodAnalytics.
/// Assembles repositories into the use case instance.
final calculatePeriodAnalyticsProvider = FutureProvider((ref) async {
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final budgetRepo = await ref.watch(budgetRepositoryProvider.future);
  final catRepo = await ref.watch(categoryRepositoryProvider.future);
  return CalculatePeriodAnalytics(txRepo, budgetRepo, catRepo);
});

/// Main analytics computation result.
/// Watches: period selection, current date, repositories.
/// Triggers recalculation whenever period changes.
final periodAnalyticsProvider = FutureProvider<PeriodAnalytics>((ref) async {
  final session = await ref.watch(bootstrapProvider.future);
  final (start, end) = ref.watch(analyticsPeriodRangeProvider);
  final usecase = await ref.watch(calculatePeriodAnalyticsProvider.future);

  return usecase(
    familyId: session.familyId,
    periodStart: start,
    periodEnd: end,
  );
});
