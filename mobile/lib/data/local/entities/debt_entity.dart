import 'package:isar/isar.dart';

import '../../../domain/model/debt.dart';

part 'debt_entity.g.dart';

/// Persisted by name — never renumber or rename.
enum IsarDebtDirection { iOwe, owedToMe }

enum IsarDebtStatus { open, closed }

@collection
class DebtEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String familyId;

  late String counterpartyName;

  @enumerated
  late IsarDebtDirection direction;

  late int amountKopecks;
  DateTime? dueDate;

  @enumerated
  late IsarDebtStatus status;

  late bool isDeleted;
  late DateTime createdAt;
  late DateTime updatedAt;

  Debt toDomain() => Debt(
        id: id,
        familyId: familyId,
        counterpartyName: counterpartyName,
        direction: switch (direction) {
          IsarDebtDirection.iOwe => DebtDirection.iOwe,
          IsarDebtDirection.owedToMe => DebtDirection.owedToMe,
        },
        amountKopecks: amountKopecks,
        dueDate: dueDate,
        status: switch (status) {
          IsarDebtStatus.open => DebtStatus.open,
          IsarDebtStatus.closed => DebtStatus.closed,
        },
        isDeleted: isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static DebtEntity fromDomain(Debt d) => DebtEntity()
    ..id = d.id
    ..familyId = d.familyId
    ..counterpartyName = d.counterpartyName
    ..direction = switch (d.direction) {
      DebtDirection.iOwe => IsarDebtDirection.iOwe,
      DebtDirection.owedToMe => IsarDebtDirection.owedToMe,
    }
    ..amountKopecks = d.amountKopecks
    ..dueDate = d.dueDate
    ..status = switch (d.status) {
      DebtStatus.open => IsarDebtStatus.open,
      DebtStatus.closed => IsarDebtStatus.closed,
    }
    ..isDeleted = d.isDeleted
    ..createdAt = d.createdAt
    ..updatedAt = d.updatedAt;
}
