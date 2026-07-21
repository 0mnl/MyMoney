import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../domain/model/analytics.dart';
import '../../domain/model/budget.dart';
import '../../domain/model/money.dart';

/// Service for generating and exporting PDF reports.
/// Pure business logic: takes analytics data and produces a PDF document.
/// Decoupled from UI; can be tested independently.
class PdfExportService {
  const PdfExportService();

  /// Generate a formatted PDF report from analytics data.
  /// Returns the raw PDF bytes (Uint8List).
  Future<List<int>> generateReport({
    required PeriodAnalytics analytics,
    required String familyName,
    required BudgetPeriodType period,
  }) async {
    final doc = pw.Document();

    // Page setup: A4, landscape for wider tables
    final pageFormat = PdfPageFormat.a4.landscape;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(familyName, period, analytics),
              pw.SizedBox(height: 20),
              _buildSummary(analytics),
              pw.SizedBox(height: 20),
              if (analytics.categoryBreakdown.isNotEmpty)
                _buildCategoryBreakdown(analytics),
              if (analytics.budgetComparison.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                _buildBudgetComparison(analytics),
              ],
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Share PDF via native Android intent (email, cloud storage, etc.).
  /// Returns true if action completed, false if cancelled.
  Future<bool> shareReport({
    required List<int> pdfBytes,
    required String filename,
  }) async {
    final bytes = pdfBytes is Uint8List ? pdfBytes : Uint8List.fromList(pdfBytes);
    return Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  pw.Widget _buildHeader(
    String familyName,
    BudgetPeriodType period,
    PeriodAnalytics analytics,
  ) {
    final periodLabel = switch (period) {
      BudgetPeriodType.week => 'Неделя с '
          '${DateFormat('d.MM.yyyy', 'ru_RU').format(analytics.periodStart.toLocal())}',
      BudgetPeriodType.month =>
        DateFormat('MMMM yyyy', 'ru_RU').format(analytics.periodStart.toLocal()),
      BudgetPeriodType.year =>
        DateFormat('yyyy', 'ru_RU').format(analytics.periodStart.toLocal()),
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Отчёт по расходам',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Семья: $familyName | Период: $periodLabel',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.Text(
          'Дата создания: ${DateFormat('d.MM.yyyy HH:mm', 'ru_RU').format(DateTime.now().toLocal())}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  pw.Widget _buildSummary(PeriodAnalytics analytics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Итого за период',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Доход: ${Money.formatRub(analytics.totalIncomeKopecks)}'),
            pw.Text('Расход: ${Money.formatRub(analytics.totalExpenseKopecks)}'),
            pw.Text(
              'Остаток: ${Money.formatRub(analytics.netKopecks)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildCategoryBreakdown(PeriodAnalytics analytics) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey300,
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('Категория', style: _headerStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('Сумма', style: _headerStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('% от всего', style: _headerStyle),
          ),
        ],
      ),
    ];

    // Sort by amount descending
    final sorted = analytics.categoryBreakdown.values.toList()
      ..sort((a, b) => b.totalKopecks.compareTo(a.totalKopecks));

    for (final spend in sorted) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(spend.categoryName),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(Money.formatRub(spend.totalKopecks)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                '${spend.percentageOfTotal.toStringAsFixed(1)}%',
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Расходы по категориям',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black),
          children: rows,
        ),
      ],
    );
  }

  pw.Widget _buildBudgetComparison(PeriodAnalytics analytics) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey300,
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('Категория', style: _headerStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('План', style: _headerStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('Потрачено', style: _headerStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('Статус', style: _headerStyle),
          ),
        ],
      ),
    ];

    for (final entry in analytics.budgetComparison.entries) {
      final comp = entry.value;
      final status = comp.isOverspent ? 'Превышено' : 'В норме';

      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(comp.categoryName),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(Money.formatRub(comp.plannedKopecks)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(Money.formatRub(comp.actualKopecks)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(status),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Сравнение с бюджетом',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black),
          children: rows,
        ),
      ],
    );
  }

  static final _headerStyle = pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
  );
}
