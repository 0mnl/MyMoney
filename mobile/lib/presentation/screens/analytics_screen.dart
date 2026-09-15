import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/feature_flags.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/model/analytics.dart';
import '../../domain/model/budget.dart';
import '../../domain/model/money.dart';
import '../providers/analytics_providers.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_ui.dart';
import '../widgets/under_development.dart';

/// Статистика за период: сводка, диаграмма расходов, детализация по
/// категориям, сравнение с бюджетом и выгрузка отчёта.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(periodAnalyticsProvider);
    final period = ref.watch(selectedAnalyticsPeriodProvider);
    final bootstrap = ref.watch(bootstrapProvider);

    return MmScreen(
      title: 'Статистика',
      headerBottom: MmSegmented<BudgetPeriodType>(
        items: [
          for (final p in BudgetPeriodType.values) (p, p.labelRu),
        ],
        selected: period,
        onChanged: (v) =>
            ref.read(selectedAnalyticsPeriodProvider.notifier).state = v,
      ),
      child: analyticsAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (analytics) {
          final spends = analytics.categoryBreakdown.values.toList()
            ..sort((a, b) => b.totalKopecks.compareTo(a.totalKopecks));

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SummaryCard(analytics: analytics),
              ),
              const SizedBox(height: 24),
              const MmSectionHeader(title: 'Расходы по категориям'),
              const SizedBox(height: 12),
              if (spends.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Text(
                    'Нет расходов за этот период',
                    textAlign: TextAlign.center,
                    style: MmType.subhead,
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DonutChart(
                    spends: spends,
                    totalKopecks: analytics.totalExpenseKopecks,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: MmCard(
                    radius: 24,
                    shadows: MmShadows.tile,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Column(
                      children: [
                        for (var i = 0; i < spends.length; i++)
                          _BreakdownRow(
                            spend: spends[i],
                            color:
                                MmColors.chart[i % MmColors.chart.length],
                            isLast: i == spends.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (analytics.budgetComparison.isNotEmpty) ...[
                const SizedBox(height: 28),
                const MmSectionHeader(title: 'Сравнение с бюджетом'),
                const SizedBox(height: 12),
                for (final comp in analytics.budgetComparison.values)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _BudgetComparisonCard(comparison: comp),
                  ),
              ],
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                // Кнопка остаётся видимой намеренно: пользователь должен
                // знать, что выгрузка планируется. Тап показывает
                // «в разработке» вместо генерации файла.
                child: MmPrimaryButton(
                  label: FeatureFlags.fileExport
                      ? 'Экспортировать отчёт'
                      : 'Экспортировать отчёт — скоро',
                  icon: Icons.file_download_outlined,
                  onPressed: FeatureFlags.fileExport
                      ? () => _chooseExportFormat(
                            context,
                            analytics,
                            period,
                            bootstrap,
                          )
                      : () => showUnderDevelopment(context, 'Экспорт отчёта'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Спрашивает формат перед выгрузкой. Отдельный шаг, а не две кнопки:
  /// экспорт — редкое действие, и две одинаковые кнопки внизу отчёта
  /// занимали бы место постоянно ради выбора, который делают раз в месяц.
  Future<void> _chooseExportFormat(
    BuildContext context,
    PeriodAnalytics analytics,
    BudgetPeriodType period,
    AsyncValue<dynamic> bootstrapAsync,
  ) async {
    final format = await mmShowSheet<String>(
      context,
      child: MmSheet(
        title: 'Формат отчёта',
        children: [
          MmGroupCard(
            margin: EdgeInsets.zero,
            children: [
              MmMenuRow(
                icon: Icons.picture_as_pdf,
                iconBg: MmColors.tintRed,
                iconColor: MmColors.red,
                title: 'PDF',
                subtitle: 'Готовый к печати отчёт',
                showChevron: false,
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              MmMenuRow(
                icon: Icons.table_chart,
                iconBg: MmColors.tintGreen,
                iconColor: MmColors.green,
                title: 'Excel (.xlsx)',
                subtitle: 'Три листа: сводка, категории, бюджеты',
                showChevron: false,
                isLast: true,
                onTap: () => Navigator.pop(context, 'xlsx'),
              ),
            ],
          ),
        ],
      ),
    );
    if (format == null || !context.mounted) return;

    if (format == 'pdf') {
      await _exportPdf(context, analytics, period, bootstrapAsync);
    } else {
      await _exportExcel(context, analytics, period);
    }
  }

  Future<void> _exportExcel(
    BuildContext context,
    PeriodAnalytics analytics,
    BudgetPeriodType period,
  ) async {
    try {
      const service = ExcelExportService();
      final bytes = await service.generateReport(
        analytics: analytics,
        familyName: 'MyMoney',
        period: period,
      );

      // Printing.sharePdf отдаёт произвольные байты в системный «Поделиться»
      // под указанным именем — тип файла платформа определяет по расширению.
      // Отдельная зависимость ради share-листа тут не нужна.
      final shared = await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: service.suggestFilename(DateTime.now()),
      );

      if (!shared && context.mounted) {
        mmSnack(context, 'Экспорт в Excel отменён');
      }
    } catch (e) {
      if (context.mounted) mmSnack(context, 'Ошибка при экспорте: $e');
    }
  }

  Future<void> _exportPdf(
    BuildContext context,
    PeriodAnalytics analytics,
    BudgetPeriodType period,
    AsyncValue<dynamic> bootstrapAsync,
  ) async {
    try {
      const service = PdfExportService();
      final pdfBytes = await service.generateReport(
        analytics: analytics,
        familyName: 'MyMoney',
        period: period,
      );

      final filename = 'MyMoney_Report_'
          '${DateFormat('yyyy-MM-dd', 'ru_RU').format(DateTime.now())}.pdf';
      final shared = await service.shareReport(
        pdfBytes: pdfBytes,
        filename: filename,
      );

      if (!shared && context.mounted) {
        mmSnack(context, 'Экспорт PDF отменён');
      }
    } catch (e) {
      if (context.mounted) mmSnack(context, 'Ошибка при экспорте: $e');
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.analytics});
  final PeriodAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final net = analytics.netKopecks;
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Остаток за период', style: MmType.subhead),
          const SizedBox(height: 4),
          Text(
            Money.formatRub(net),
            style: MmType.largeTitle.copyWith(
              color: net >= 0 ? MmColors.label : MmColors.red,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Доходы',
                  value: Money.formatRub(analytics.totalIncomeKopecks),
                  color: MmColors.green,
                ),
              ),
              Container(width: 1, height: 40, color: MmColors.divider),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  label: 'Расходы',
                  value: Money.formatRub(analytics.totalExpenseKopecks),
                  color: MmColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: MmType.caption),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MmType.headline.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Кольцевая диаграмма с суммой расходов в центре — то же кольцо, что и на
/// «Главной», но с реальными секторами.
class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.spends, required this.totalKopecks});

  final List<CategorySpend> spends;
  final int totalKopecks;

  @override
  Widget build(BuildContext context) {
    final top = spends.take(6).toList();
    final restKopecks = spends
        .skip(6)
        .fold<int>(0, (s, c) => s + c.totalKopecks);

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: 62,
              sectionsSpace: 2,
              sections: [
                for (var i = 0; i < top.length; i++)
                  PieChartSectionData(
                    value: top[i].totalKopecks.toDouble(),
                    color: MmColors.chart[i % MmColors.chart.length],
                    radius: 34,
                    showTitle: false,
                  ),
                if (restKopecks > 0)
                  PieChartSectionData(
                    value: restKopecks.toDouble(),
                    color: MmColors.grey,
                    radius: 34,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Расходы', style: MmType.subhead),
              Text(Money.formatRub(totalKopecks), style: MmType.section),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.spend,
    required this.color,
    required this.isLast,
  });

  final CategorySpend spend;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: MmColors.divider, width: 1),
              ),
            ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              spend.categoryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MmType.body,
            ),
          ),
          const SizedBox(width: 8),
          Text(Money.formatRub(spend.totalKopecks), style: MmType.bodyStrong),
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            child: Text(
              '${spend.percentageOfTotal.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: MmType.footnote.copyWith(color: MmColors.labelTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetComparisonCard extends StatelessWidget {
  const _BudgetComparisonCard({required this.comparison});
  final CategoryBudgetComparison comparison;

  @override
  Widget build(BuildContext context) {
    final over = comparison.isOverspent;
    final value = comparison.plannedKopecks <= 0
        ? 0.0
        : comparison.actualKopecks / comparison.plannedKopecks;

    return MmCard(
      radius: 24,
      shadows: MmShadows.tile,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comparison.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.bodyStrong,
                ),
              ),
              Text(
                over ? 'Превышено' : 'В норме',
                style: MmType.footnote.copyWith(
                  color: over ? MmColors.red : MmColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MmProgressBar(
            value: value,
            color: over ? MmColors.red : MmColors.green,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Money.formatRub(comparison.actualKopecks)} '
                  'из ${Money.formatRub(comparison.plannedKopecks)}',
                  style: MmType.subhead.copyWith(color: MmColors.label),
                ),
              ),
              Text(
                over
                    ? '+${Money.formatRub(comparison.remainingKopecks.abs())}'
                    : Money.formatRub(comparison.remainingKopecks),
                style: MmType.footnote.copyWith(
                  color: over ? MmColors.red : MmColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
