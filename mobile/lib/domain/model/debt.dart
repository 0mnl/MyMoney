enum DebtDirection { iOwe, owedToMe }

enum DebtStatus { open, closed }

extension DebtDirectionX on DebtDirection {
  String get code => switch (this) {
        DebtDirection.iOwe => 'I_OWE',
        DebtDirection.owedToMe => 'OWED_TO_ME',
      };
  String get labelRu => switch (this) {
        DebtDirection.iOwe => 'Я должен',
        DebtDirection.owedToMe => 'Мне должны',
      };
}

extension DebtStatusX on DebtStatus {
  String get code => switch (this) {
        DebtStatus.open => 'OPEN',
        DebtStatus.closed => 'CLOSED',
      };
}

DebtDirection parseDebtDirection(String code) => switch (code) {
      'I_OWE' => DebtDirection.iOwe,
      'OWED_TO_ME' => DebtDirection.owedToMe,
      _ => throw ArgumentError('Unknown DebtDirection: $code'),
    };

DebtStatus parseDebtStatus(String code) => switch (code) {
      'OPEN' => DebtStatus.open,
      'CLOSED' => DebtStatus.closed,
      _ => throw ArgumentError('Unknown DebtStatus: $code'),
    };

class Debt {
  final String id;
  final String familyId;
  final String counterpartyName;
  final DebtDirection direction;
  final int amountKopecks;

  /// Годовая процентная ставка (Bible v2 §7.7). Значение 0.0 == беспроцентный долг.
  final double interestRate;

  final DateTime? dueDate;
  final DebtStatus status;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Debt({
    required this.id,
    required this.familyId,
    required this.counterpartyName,
    required this.direction,
    required this.amountKopecks,
    this.interestRate = 0.0,
    this.dueDate,
    this.status = DebtStatus.open,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Debt copyWith({
    String? counterpartyName,
    int? amountKopecks,
    double? interestRate,
    DateTime? dueDate,
    DebtStatus? status,
    bool? isDeleted,
    DateTime? updatedAt,
    bool clearDueDate = false,
  }) =>
      Debt(
        id: id,
        familyId: familyId,
        counterpartyName: counterpartyName ?? this.counterpartyName,
        direction: direction,
        amountKopecks: amountKopecks ?? this.amountKopecks,
        interestRate: interestRate ?? this.interestRate,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        status: status ?? this.status,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Плановая позиция графика погашения долга. Bible v2 §7.7, §13.
class DebtPayment {
  final String id;
  final String debtId;
  final DateTime dueDate;
  final int plannedAmountKopecks;
  final bool isPaid;
  final DateTime? paidAt;

  /// UUID операции, созданной при погашении этой позиции (может быть null,
  /// пока платёж не отмечен как оплаченный).
  final String? transactionId;

  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.dueDate,
    required this.plannedAmountKopecks,
    this.isPaid = false,
    this.paidAt,
    this.transactionId,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DebtPayment copyWith({
    DateTime? dueDate,
    int? plannedAmountKopecks,
    bool? isPaid,
    DateTime? paidAt,
    String? transactionId,
    bool clearPaidAt = false,
    bool clearTransactionId = false,
    bool? isDeleted,
    DateTime? updatedAt,
  }) =>
      DebtPayment(
        id: id,
        debtId: debtId,
        dueDate: dueDate ?? this.dueDate,
        plannedAmountKopecks: plannedAmountKopecks ?? this.plannedAmountKopecks,
        isPaid: isPaid ?? this.isPaid,
        paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
        transactionId:
            clearTransactionId ? null : (transactionId ?? this.transactionId),
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
