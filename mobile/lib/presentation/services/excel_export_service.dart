import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import '../../domain/model/analytics.dart';
import '../../domain/model/budget.dart';

/// Экспорт аналитики в `.xlsx`.
///
/// **Почему свой генератор, а не пакет.** Файл `.xlsx` — это ZIP с несколькими
/// XML внутри (Office Open XML, ECMA-376). Нужный здесь объём — три плоские
/// таблицы без формул, диаграмм и картинок — это несколько сотен строк
/// разметки. Тянуть ради этого стороннюю библиотеку с её транзитивными
/// зависимостями и циклом обновлений смысла нет: `archive` уже в дереве
/// зависимостей как транзитивная, всё остальное — конкатенация строк.
///
/// Формат намеренно минимальный, но валидный: открывается Excel, Numbers,
/// LibreOffice и Google Sheets. Строки пишутся как `inlineStr`, чтобы не
/// заводить таблицу общих строк (`sharedStrings.xml`) — она экономит место
/// на больших файлах, а здесь только усложнила бы код.
///
/// Экспорт закрыт `FeatureFlags.fileExport` — см. `feature_flags.dart`.
class ExcelExportService {
  const ExcelExportService();

  /// Собирает книгу из трёх листов: «Сводка», «Категории», «Бюджеты».
  /// Возвращает готовые байты `.xlsx`.
  Future<List<int>> generateReport({
    required PeriodAnalytics analytics,
    required String familyName,
    required BudgetPeriodType period,
  }) async {
    final sheets = <_Sheet>[
      _summarySheet(analytics, familyName, period),
      _categoriesSheet(analytics),
      // Лист бюджетов появляется только когда бюджеты заданы — пустая
      // вкладка в книге выглядит как потерявшиеся данные.
      if (analytics.budgetComparison.isNotEmpty) _budgetsSheet(analytics),
    ];

    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes(sheets.length));
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook(sheets));
    add('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length));
    add('xl/styles.xml', _styles);
    for (var i = 0; i < sheets.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i]));
    }

    // ZipEncoder возвращает null только если архив пуст — здесь он никогда
    // не пуст, но анализатор об этом не знает.
    final encoded = ZipEncoder().encode(archive);
    return encoded;
  }

  /// Имя файла с датой — чтобы несколько выгрузок не перетирали друг друга
  /// в папке «Загрузки».
  String suggestFilename(DateTime now) =>
      'MyMoney_Report_${DateFormat('yyyy-MM-dd').format(now)}.xlsx';

  // ─── Листы ────────────────────────────────────────────────────────────────

  _Sheet _summarySheet(
    PeriodAnalytics analytics,
    String familyName,
    BudgetPeriodType period,
  ) {
    final rows = <List<_Cell>>[
      [_Cell.header('Отчёт MyMoney')],
      [_Cell.text('Семья'), _Cell.text(familyName)],
      [_Cell.text('Период'), _Cell.text(_periodLabel(period, analytics))],
      [
        _Cell.text('С'),
        _Cell.text(_date(analytics.periodStart)),
        _Cell.text('по'),
        _Cell.text(_date(analytics.periodEnd)),
      ],
      [],
      [_Cell.header('Показатель'), _Cell.header('Сумма')],
      [_Cell.text('Доходы'), _Cell.money(analytics.totalIncomeKopecks)],
      [_Cell.text('Расходы'), _Cell.money(analytics.totalExpenseKopecks)],
      [_Cell.text('Итого'), _Cell.money(analytics.netKopecks)],
    ];
    return _Sheet(name: 'Сводка', rows: rows);
  }

  _Sheet _categoriesSheet(PeriodAnalytics analytics) {
    final entries = analytics.categoryBreakdown.values.toList()
      ..sort((a, b) => b.totalKopecks.compareTo(a.totalKopecks));

    final rows = <List<_Cell>>[
      [
        _Cell.header('Категория'),
        _Cell.header('Сумма'),
        _Cell.header('Доля, %'),
      ],
      for (final e in entries)
        [
          _Cell.text(e.categoryName),
          _Cell.money(e.totalKopecks),
          _Cell.number(e.percentageOfTotal),
        ],
    ];
    return _Sheet(name: 'Категории', rows: rows);
  }

  _Sheet _budgetsSheet(PeriodAnalytics analytics) {
    final entries = analytics.budgetComparison.values.toList()
      ..sort((a, b) => b.actualKopecks.compareTo(a.actualKopecks));

    final rows = <List<_Cell>>[
      [
        _Cell.header('Категория'),
        _Cell.header('План'),
        _Cell.header('Факт'),
        _Cell.header('Остаток'),
        _Cell.header('Статус'),
      ],
      for (final e in entries)
        [
          _Cell.text(e.categoryName),
          _Cell.money(e.plannedKopecks),
          _Cell.money(e.actualKopecks),
          _Cell.money(e.remainingKopecks),
          _Cell.text(e.isOverspent ? 'Перерасход' : 'В рамках'),
        ],
    ];
    return _Sheet(name: 'Бюджеты', rows: rows);
  }

  String _periodLabel(BudgetPeriodType period, PeriodAnalytics a) =>
      switch (period) {
        BudgetPeriodType.week =>
          'Неделя с ${DateFormat('d.MM.yyyy').format(a.periodStart.toLocal())}',
        BudgetPeriodType.month =>
          DateFormat('LLLL yyyy', 'ru_RU').format(a.periodStart.toLocal()),
        BudgetPeriodType.year =>
          DateFormat('yyyy').format(a.periodStart.toLocal()),
      };

  String _date(DateTime d) => DateFormat('d.MM.yyyy').format(d.toLocal());

  // ─── OOXML ────────────────────────────────────────────────────────────────

  String _contentTypes(int sheetCount) => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
${List.generate(sheetCount, (i) => '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join('\n')}
</Types>''';

  static const _rootRels = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

  String _workbook(List<_Sheet> sheets) {
    final entries = <String>[
      for (var i = 0; i < sheets.length; i++)
        '<sheet name="${_escape(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
    ];
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
${entries.join('\n')}
</sheets>
</workbook>''';
  }

  String _workbookRels(int sheetCount) => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${List.generate(sheetCount, (i) => '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>').join('\n')}
<Relationship Id="rId${sheetCount + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  /// Стили: индекс 0 — обычный текст, 1 — жирный заголовок, 2 — денежный
  /// формат с рублём. Больше ничего не нужно, и каждый лишний стиль — это
  /// ещё один способ получить «файл повреждён».
  static const _styles = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.00\\ &quot;₽&quot;"/></numFmts>
<fonts count="2">
<font><sz val="11"/><name val="Calibri"/></font>
<font><b/><sz val="11"/><name val="Calibri"/></font>
</fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="3">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
</cellXfs>
</styleSheet>''';

  String _sheetXml(_Sheet sheet) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      )
      ..writeln('<sheetData>');

    for (var r = 0; r < sheet.rows.length; r++) {
      final cells = sheet.rows[r];
      if (cells.isEmpty) continue; // пустая строка-разделитель
      buffer.write('<row r="${r + 1}">');
      for (var c = 0; c < cells.length; c++) {
        buffer.write(cells[c].toXml(_columnName(c), r + 1));
      }
      buffer.writeln('</row>');
    }

    buffer
      ..writeln('</sheetData>')
      ..writeln('</worksheet>');
    return buffer.toString();
  }

  /// 0 → A, 25 → Z, 26 → AA. Столбцов здесь единицы, но правильная
  /// реализация короче, чем таблица исключений.
  static String _columnName(int index) {
    var i = index;
    final out = StringBuffer();
    do {
      out.write(String.fromCharCode(65 + i % 26));
      i = i ~/ 26 - 1;
    } while (i >= 0);
    return String.fromCharCodes(out.toString().codeUnits.reversed);
  }
}

String _escape(String raw) => raw
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

enum _CellKind { text, header, money, number }

class _Cell {
  const _Cell._(this.kind, this.text, this.value);

  final _CellKind kind;
  final String? text;
  final double? value;

  factory _Cell.text(String v) => _Cell._(_CellKind.text, v, null);
  factory _Cell.header(String v) => _Cell._(_CellKind.header, v, null);
  factory _Cell.number(double v) => _Cell._(_CellKind.number, null, v);

  /// Деньги пишутся в рублях с двумя знаками, а не в копейках: файл читает
  /// человек, и `1234,56 ₽` понятнее, чем `123456`.
  factory _Cell.money(int kopecks) =>
      _Cell._(_CellKind.money, null, kopecks / 100.0);

  String toXml(String column, int row) {
    final ref = '$column$row';
    return switch (kind) {
      _CellKind.text =>
        '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_escape(text ?? '')}</t></is></c>',
      _CellKind.header =>
        '<c r="$ref" s="1" t="inlineStr"><is><t xml:space="preserve">${_escape(text ?? '')}</t></is></c>',
      _CellKind.money => '<c r="$ref" s="2"><v>${value!.toStringAsFixed(2)}</v></c>',
      _CellKind.number => '<c r="$ref"><v>${value!.toStringAsFixed(2)}</v></c>',
    };
  }
}

class _Sheet {
  const _Sheet({required this.name, required this.rows});
  final String name;
  final List<List<_Cell>> rows;
}
