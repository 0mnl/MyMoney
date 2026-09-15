import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../model/debt.dart';

/// Строит график погашения долга (Bible v2 §7.7).
///
/// Две схемы, выбор зависит от ставки:
///
/// * **Ставка 0** — тело долга делится поровну. Остаток от деления
///   добавляется к последнему платежу, поэтому сумма позиций всегда в
///   точности равна долгу: 10 000 ₽ на 3 месяца — это 3333,33 + 3333,33 +
///   3333,34, а не три раза по 3333,33 с потерянной копейкой.
///
/// * **Ставка > 0** — аннуитет: равные платежи, включающие проценты.
///   `A = P · i / (1 − (1 + i)^−n)`, где `i` — месячная ставка
///   (годовая / 12 / 100). Последний платёж так же добирает остаток,
///   накопленный округлением каждого аннуитета до копейки.
///
/// Деньги считаются в копейках целыми числами (ADR-0002); `double`
/// используется только внутри формулы аннуитета, результат сразу
/// округляется обратно в копейки.
List<DebtPayment> buildDebtSchedule({
  required Debt debt,
  required int months,
  required DateTime firstDueDate,
  DateTime? now,
}) {
  if (months <= 0) {
    throw ArgumentError.value(months, 'months', 'Должно быть больше нуля');
  }
  if (debt.amountKopecks <= 0) {
    throw ArgumentError.value(
      debt.amountKopecks,
      'debt.amountKopecks',
      'Долг должен быть положительным',
    );
  }

  final createdAt = now ?? DateTime.now().toUtc();
  const uuid = Uuid();

  final perMonth = debt.interestRate > 0
      ? _annuityKopecks(debt.amountKopecks, debt.interestRate, months)
      : debt.amountKopecks ~/ months;

  final payments = <DebtPayment>[];
  var allocated = 0;

  for (var i = 0; i < months; i++) {
    final isLast = i == months - 1;
    // Последняя позиция забирает всё, что осталось после округлений, —
    // иначе сумма графика разошлась бы с долгом на копейки.
    final amount = isLast
        ? _totalToRepay(debt, perMonth, months) - allocated
        : perMonth;
    allocated += amount;

    payments.add(DebtPayment(
      id: uuid.v4(),
      debtId: debt.id,
      dueDate: _addMonths(firstDueDate, i),
      plannedAmountKopecks: amount,
      createdAt: createdAt,
      updatedAt: createdAt,
    ));
  }

  return payments;
}

/// Сколько всего предстоит выплатить: тело долга при нулевой ставке или
/// сумма всех аннуитетов при ненулевой.
int _totalToRepay(Debt debt, int perMonth, int months) =>
    debt.interestRate > 0 ? perMonth * months : debt.amountKopecks;

int _annuityKopecks(int principalKopecks, double annualRatePercent, int months) {
  final monthlyRate = annualRatePercent / 100.0 / 12.0;
  final factor = 1 - math.pow(1 + monthlyRate, -months);
  // При исчезающе малой ставке формула вырождается в деление 0/0 —
  // отдаём простое деление, чтобы не получить NaN.
  if (factor.abs() < 1e-12) return principalKopecks ~/ months;
  return (principalKopecks * monthlyRate / factor).round();
}

/// Прибавляет [months] месяцев, удерживая день месяца в допустимых
/// границах: 31 января + 1 месяц — это 28 (или 29) февраля, а не 3 марта,
/// как получилось бы при наивном сложении дней.
DateTime _addMonths(DateTime from, int months) {
  final totalMonth = from.month - 1 + months;
  final year = from.year + totalMonth ~/ 12;
  final month = totalMonth % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, math.min(from.day, lastDay));
}
