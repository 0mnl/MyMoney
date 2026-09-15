import 'package:flutter_test/flutter_test.dart';
import 'package:mymoney/domain/model/debt.dart';
import 'package:mymoney/domain/usecase/debt_schedule.dart';

Debt _debt({required int amountKopecks, double interestRate = 0.0}) {
  final now = DateTime.utc(2026, 1, 1);
  return Debt(
    id: 'debt-1',
    familyId: 'fam-1',
    counterpartyName: 'Иван',
    direction: DebtDirection.iOwe,
    amountKopecks: amountKopecks,
    interestRate: interestRate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('buildDebtSchedule без процентов', () {
    test('делит поровну и не теряет копейки на остатке', () {
      // 10 000,00 ₽ на 3 месяца не делится нацело: 333333 = 3 × 111111
      // c остатком 0... берём сумму, где остаток заведомо есть.
      final payments = buildDebtSchedule(
        debt: _debt(amountKopecks: 1000000),
        months: 3,
        firstDueDate: DateTime.utc(2026, 2, 1),
      );

      expect(payments, hasLength(3));
      final total = payments.fold(0, (s, p) => s + p.plannedAmountKopecks);
      expect(total, 1000000, reason: 'сумма графика обязана равняться долгу');
      expect(payments[0].plannedAmountKopecks, 333333);
      expect(payments[1].plannedAmountKopecks, 333333);
      expect(payments[2].plannedAmountKopecks, 333334, reason: 'остаток идёт в последний платёж');
    });

    test('сумма графика равна долгу при любом числе месяцев', () {
      for (final months in [1, 2, 5, 7, 12, 13, 60]) {
        final payments = buildDebtSchedule(
          debt: _debt(amountKopecks: 999999),
          months: months,
          firstDueDate: DateTime.utc(2026, 2, 1),
        );
        final total = payments.fold(0, (s, p) => s + p.plannedAmountKopecks);
        expect(total, 999999, reason: 'месяцев: $months');
        expect(payments, hasLength(months));
      }
    });

    test('один платёж — весь долг целиком', () {
      final payments = buildDebtSchedule(
        debt: _debt(amountKopecks: 123456),
        months: 1,
        firstDueDate: DateTime.utc(2026, 3, 10),
      );
      expect(payments.single.plannedAmountKopecks, 123456);
      expect(payments.single.dueDate, DateTime.utc(2026, 3, 10));
    });
  });

  group('buildDebtSchedule с процентами', () {
    test('аннуитет даёт переплату сверх тела долга', () {
      final payments = buildDebtSchedule(
        debt: _debt(amountKopecks: 1200000, interestRate: 12.0),
        months: 12,
        firstDueDate: DateTime.utc(2026, 2, 1),
      );

      final total = payments.fold(0, (s, p) => s + p.plannedAmountKopecks);
      expect(total, greaterThan(1200000), reason: 'ставка 12% обязана дать переплату');
      // 12% годовых на год примерно 6.6% переплаты — проверяем порядок,
      // а не точное значение, чтобы тест не ломался от округлений.
      expect(total, lessThan(1300000));
    });

    test('все платежи кроме последнего равны между собой', () {
      final payments = buildDebtSchedule(
        debt: _debt(amountKopecks: 5000000, interestRate: 9.5),
        months: 24,
        firstDueDate: DateTime.utc(2026, 2, 1),
      );
      final first = payments.first.plannedAmountKopecks;
      for (final p in payments.take(payments.length - 1)) {
        expect(p.plannedAmountKopecks, first);
      }
    });
  });

  group('даты платежей', () {
    test('идут помесячно', () {
      final payments = buildDebtSchedule(
        debt: _debt(amountKopecks: 300000),
        months: 3,
        firstDueDate: DateTime.utc(2026, 1, 15),
      );
      expect(payments[0].dueDate, DateTime.utc(2026, 1, 15));
      expect(payments[1].dueDate, DateTime.utc(2026, 2, 15));
      expect(payments[2].dueDate, DateTime.utc(2026, 3, 15));
    });

    test('31 января + месяц = 28 февраля, а не 3 марта', () {
      final payments = buildDebtSchedule(
        debt: _debt(amountKopecks: 200000),
        months: 2,
        firstDueDate: DateTime.utc(2026, 1, 31),
      );
      expect(payments[1].dueDate, DateTime.utc(2026, 2, 28));
    });

    test('переходит через границу года', () {
      final payments = buildDebtSchedule(
        debt: _debt(amountKopecks: 300000),
        months: 3,
        firstDueDate: DateTime.utc(2026, 11, 20),
      );
      expect(payments[2].dueDate, DateTime.utc(2027, 1, 20));
    });
  });

  group('валидация', () {
    test('ноль месяцев отвергается', () {
      expect(
        () => buildDebtSchedule(
          debt: _debt(amountKopecks: 100000),
          months: 0,
          firstDueDate: DateTime.utc(2026, 2, 1),
        ),
        throwsArgumentError,
      );
    });

    test('нулевой долг отвергается', () {
      expect(
        () => buildDebtSchedule(
          debt: _debt(amountKopecks: 0),
          months: 3,
          firstDueDate: DateTime.utc(2026, 2, 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
