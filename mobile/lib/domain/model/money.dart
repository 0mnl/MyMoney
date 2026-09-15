import 'package:intl/intl.dart';

/// Money is stored as an integer number of kopecks (see ADR-0002).
/// This helper converts to/from user-facing rubles for input and display.
class Money {
  const Money._();

  /// Formats [kopecks] as `1 234,56 ₽` (Russian locale).
  static String formatRub(int kopecks) {
    final rubles = kopecks / 100.0;
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 2,
    );
    return formatter.format(rubles);
  }

  /// Formats [kopecks] for an *input field*: `123456` → `1234,56`.
  ///
  /// Без символа валюты и без разделителя разрядов — результат должен
  /// скармливаться обратно в [parseToKopecks] без потерь, когда экран
  /// редактирования предзаполняет поле суммы.
  static String formatPlain(int kopecks) {
    final sign = kopecks < 0 ? '-' : '';
    final abs = kopecks.abs();
    final rubles = abs ~/ 100;
    final cents = abs % 100;
    return '$sign$rubles,${cents.toString().padLeft(2, '0')}';
  }

  /// Parses free-form user input (`1234,56`, `1 234.5`, `100`) into kopecks.
  /// Returns null when the input cannot be interpreted as a positive number.
  static int? parseToKopecks(String raw) {
    final normalized = raw
        .replaceAll(' ', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null || value.isNaN || value.isInfinite || value <= 0) return null;
    return (value * 100).round();
  }

  /// Как [parseToKopecks], но принимает ноль и отрицательные значения.
  ///
  /// Нужно для начального баланса: у кредитной карты он в минусе, а ноль —
  /// самый частый ввод для нового счёта. Отдельный метод, чтобы поле суммы
  /// операции по-прежнему отбрасывало `0` и `-100`, где они бессмысленны.
  static int? parseSignedToKopecks(String raw) {
    final normalized = raw
        .replaceAll(' ', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return (value * 100).round();
  }
}
