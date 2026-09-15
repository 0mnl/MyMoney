import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mymoney/domain/model/analytics.dart';
import 'package:mymoney/domain/model/budget.dart';
import 'package:mymoney/presentation/services/excel_export_service.dart';

PeriodAnalytics _analytics({bool withBudgets = true}) => PeriodAnalytics(
      periodStart: DateTime.utc(2026, 8, 1),
      periodEnd: DateTime.utc(2026, 8, 31),
      totalIncomeKopecks: 15000000,
      totalExpenseKopecks: 9876543,
      categoryBreakdown: {
        'c1': const CategorySpend(
          categoryId: 'c1',
          // Кавычки и амперсанд — проверка экранирования XML.
          categoryName: 'Еда & «рестораны»',
          totalKopecks: 5000000,
          percentageOfTotal: 50.6,
        ),
        'c2': const CategorySpend(
          categoryId: 'c2',
          categoryName: 'Транспорт <город>',
          totalKopecks: 4876543,
          percentageOfTotal: 49.4,
        ),
      },
      budgetComparison: withBudgets
          ? {
              'c1': const CategoryBudgetComparison(
                categoryId: 'c1',
                categoryName: 'Еда',
                plannedKopecks: 4000000,
                actualKopecks: 5000000,
              ),
            }
          : {},
    );

Archive _unzip(List<int> bytes) => ZipDecoder().decodeBytes(bytes);

String _read(Archive a, String path) {
  final file = a.files.firstWhere(
    (f) => f.name == path,
    orElse: () => throw StateError('В книге нет части $path'),
  );
  return utf8.decode(file.content as List<int>);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
  });

  const service = ExcelExportService();

  test('на выходе распаковываемый ZIP со всеми обязательными частями', () async {
    final bytes = await service.generateReport(
      analytics: _analytics(),
      familyName: 'Семья',
      period: BudgetPeriodType.month,
    );

    final archive = _unzip(bytes);
    final names = archive.files.map((f) => f.name).toSet();

    expect(names, contains('[Content_Types].xml'));
    expect(names, contains('_rels/.rels'));
    expect(names, contains('xl/workbook.xml'));
    expect(names, contains('xl/_rels/workbook.xml.rels'));
    expect(names, contains('xl/styles.xml'));
    expect(names, contains('xl/worksheets/sheet1.xml'));
    expect(names, contains('xl/worksheets/sheet2.xml'));
    expect(names, contains('xl/worksheets/sheet3.xml'));
  });

  test('лист бюджетов отсутствует, когда бюджетов нет', () async {
    final bytes = await service.generateReport(
      analytics: _analytics(withBudgets: false),
      familyName: 'Семья',
      period: BudgetPeriodType.month,
    );

    final archive = _unzip(bytes);
    final names = archive.files.map((f) => f.name).toSet();

    expect(names, contains('xl/worksheets/sheet2.xml'));
    expect(names, isNot(contains('xl/worksheets/sheet3.xml')));
    // Объявленных листов тоже должно стать два, иначе Excel сообщит о
    // повреждённом файле: ссылка на несуществующую часть.
    expect(_read(archive, 'xl/workbook.xml'), isNot(contains('sheetId="3"')));
  });

  test('каждый лист объявлен и в workbook, и в Content_Types', () async {
    final bytes = await service.generateReport(
      analytics: _analytics(),
      familyName: 'Семья',
      period: BudgetPeriodType.month,
    );
    final archive = _unzip(bytes);

    final workbook = _read(archive, 'xl/workbook.xml');
    final types = _read(archive, '[Content_Types].xml');
    final rels = _read(archive, 'xl/_rels/workbook.xml.rels');

    for (var i = 1; i <= 3; i++) {
      expect(workbook, contains('r:id="rId$i"'));
      expect(rels, contains('worksheets/sheet$i.xml'));
      expect(types, contains('/xl/worksheets/sheet$i.xml'));
    }
    // Стили — отдельная связь после листов.
    expect(rels, contains('Target="styles.xml"'));
  });

  test('спецсимволы в названиях категорий экранируются', () async {
    final bytes = await service.generateReport(
      analytics: _analytics(),
      familyName: 'Семья',
      period: BudgetPeriodType.month,
    );
    final sheet = _read(_unzip(bytes), 'xl/worksheets/sheet2.xml');

    expect(sheet, contains('Еда &amp; «рестораны»'));
    expect(sheet, contains('Транспорт &lt;город&gt;'));
    // Голый амперсанд сломал бы XML-парсер Excel.
    expect(sheet.contains('Еда & '), isFalse);
  });

  test('деньги записаны в рублях с двумя знаками, а не в копейках', () async {
    final bytes = await service.generateReport(
      analytics: _analytics(),
      familyName: 'Семья',
      period: BudgetPeriodType.month,
    );
    final summary = _read(_unzip(bytes), 'xl/worksheets/sheet1.xml');

    expect(summary, contains('<v>150000.00</v>'), reason: 'доходы 15 000 000 коп.');
    expect(summary, contains('<v>98765.43</v>'), reason: 'расходы 9 876 543 коп.');
    expect(summary, contains('<v>51234.57</v>'), reason: 'итого');
  });

  test('имя файла содержит дату', () {
    expect(
      service.suggestFilename(DateTime(2026, 8, 28)),
      'MyMoney_Report_2026-08-28.xlsx',
    );
  });
}
