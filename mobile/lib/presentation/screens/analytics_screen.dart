import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/analytics.dart';
import '../../domain/model/budget.dart';
import '../../domain/model/money.dart';
import '../providers/analytics_providers.dart';
import '../services/pdf_export_service.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(periodAnalyticsProvider);
    final selectedPeriod = ref.watch(selectedAnalyticsPeriodProvider);
    final bootstrap = ref.watch(bootstrapProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Статистика')),
        body: analyticsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Text('Ошибка: $e'),
          ),
          data: (analytics) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildPeriodSelector(context, ref, selectedPeriod),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSummaryCards(context, analytics),
                  ),
                ),
                if (analytics.categoryBreakdown.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildPieChart(context, analytics),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Нет расходов за этот период',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildCategoryBreakdown(context, analytics),
                  ),
                ),
                if (analytics.budgetComparison.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildBudgetComparison(context, analytics),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: () => _exportPdf(
                        context,
                        ref,
                        analytics,
                        selectedPeriod,
                        bootstrap,
                      ),
                      icon: const Icon(Icons.file_download),
                      label: const Text('Экспортировать PDF'),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(
    BuildContext context,
    WidgetRef ref,
    BudgetPeriodType selectedPeriod,
  ) {
    return Center(
      child: SegmentedButton<BudgetPeriodType>(
        segments: const [
          ButtonSegment(
            value: BudgetPeriodType.week,
            label: Text('Неделя'),
          ),
          ButtonSegment(
            value: BudgetPeriodType.month,
            label: Text('Месяц'),
          ),
          ButtonSegment(
            value: BudgetPeriodType.year,
            label: Text('Год'),
          ),
        ],
        selected: {selectedPeriod},
        onSelectionChanged: (selected) {
          ref
              .read(selectedAnalyticsPeriodProvider.notifier)
              .state = selected.first;
        },
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    PeriodAnalytics analytics,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SummaryCard(
              title: 'Доход',
              amount: analytics.totalIncomeKopecks,
              color: Colors.green,
            ),
            _SummaryCard(
              title: 'Расход',
              amount: analytics.totalExpenseKopecks,
              color: Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Остаток',
          amount: analytics.netKopecks,
          color: analytics.netKopecks >= 0 ? Colors.blue : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildPieChart(BuildContext context, PeriodAnalytics analytics) {
    final categorySpends = analytics.categoryBreakdown.values.toList()
      ..sort((a, b) => b.totalKopecks.compareTo(a.totalKopecks));

    if (categorySpends.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = [
      const Color(0xff1f77b4),
      const Color(0xffff7f0e),
      const Color(0xff2ca02c),
      const Color(0xffd62728),
      const Color(0xff9467bd),
      const Color(0xff8c564b),
      const Color(0xffe377c2),
      const Color(0xff7f7f7f),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Расходы по категориям',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections: List.generate(categorySpends.length, (index) {
                final spend = categorySpends[index];
                return PieChartSectionData(
                  value: spend.totalKopecks.toDouble(),
                  title: '${spend.percentageOfTotal.toStringAsFixed(1)}%',
                  radius: 100,
                  color: colors[index % colors.length],
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
              centerSpaceRadius: 50,
              sectionsSpace: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown(
    BuildContext context,
    PeriodAnalytics analytics,
  ) {
    if (analytics.categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final categorySpends = analytics.categoryBreakdown.values.toList()
      ..sort((a, b) => b.totalKopecks.compareTo(a.totalKopecks));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Детализация по категориям',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...categorySpends.map((spend) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(spend.categoryName),
                ),
                Text(
                  Money.formatRub(spend.totalKopecks),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${spend.percentageOfTotal.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBudgetComparison(
    BuildContext context,
    PeriodAnalytics analytics,
  ) {
    if (analytics.budgetComparison.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сравнение с бюджетом',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...analytics.budgetComparison.entries.map((entry) {
          final comp = entry.value;
          final isOverspent = comp.isOverspent;
          final remaining = comp.remainingKopecks;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        comp.categoryName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        isOverspent ? 'Превышено' : 'В норме',
                        style: TextStyle(
                          color: isOverspent ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'План: ${Money.formatRub(comp.plannedKopecks)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Потрачено: ${Money.formatRub(comp.actualKopecks)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: comp.plannedKopecks <= 0
                        ? 0.0
                        : (comp.actualKopecks / comp.plannedKopecks).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverspent ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOverspent
                        ? 'Превышение: ${Money.formatRub(remaining.abs())}'
                        : 'Осталось: ${Money.formatRub(remaining)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    WidgetRef ref,
    PeriodAnalytics analytics,
    BudgetPeriodType period,
    AsyncValue<dynamic> bootstrapAsync,
  ) async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final familyName = bootstrapAsync.maybeWhen(
        data: (session) => 'MyMoney',
        orElse: () => 'MyMoney',
      );

      final service = const PdfExportService();
      final pdfBytes = await service.generateReport(
        analytics: analytics,
        familyName: familyName,
        period: period,
      );

      final filename =
          'MyMoney_Report_${DateFormat('yyyy-MM-dd', 'ru_RU').format(DateTime.now())}.pdf';
      final shared = await service.shareReport(
        pdfBytes: pdfBytes,
        filename: filename,
      );

      if (!shared && context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Экспорт PDF отменён'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при экспорте: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
  });

  final String title;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: color,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  Money.formatRub(amount),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
