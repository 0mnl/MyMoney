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
    this.dueDate,
    this.status = DebtStatus.open,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Debt copyWith({
    String? counterpartyName,
    int? amountKopecks,
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
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        status: status ?? this.status,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
