import 'package:isar/isar.dart';

import '../../../domain/model/debt.dart';

part 'debt_payment_entity.g.dart';

/// Isar-коллекция графика погашения долга (Bible v2 §7.7, §13).
/// Родительский `Debt.id` хранится в поле [debtId] в виде строки —
/// связи через IsarLink не используем, чтобы не усложнять sync.
@collection
class DebtPaymentEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String debtId;

  late DateTime dueDate;
  late int plannedAmountKopecks;
  late bool isPaid;
  DateTime? paidAt;

  /// UUID операции погашения, если позиция уже оплачена.
  String? transactionId;

  late bool isDeleted;
  late DateTime createdAt;
  late DateTime updatedAt;

  DebtPayment toDomain() => DebtPayment(
        id: id,
        debtId: debtId,
        dueDate: dueDate,
        plannedAmountKopecks: plannedAmountKopecks,
        isPaid: isPaid,
        paidAt: paidAt,
        transactionId: transactionId,
        isDeleted: isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static DebtPaymentEntity fromDomain(DebtPayment p) => DebtPaymentEntity()
    ..id = p.id
    ..debtId = p.debtId
    ..dueDate = p.dueDate
    ..plannedAmountKopecks = p.plannedAmountKopecks
    ..isPaid = p.isPaid
    ..paidAt = p.paidAt
    ..transactionId = p.transactionId
    ..isDeleted = p.isDeleted
    ..createdAt = p.createdAt
    ..updatedAt = p.updatedAt;
}
