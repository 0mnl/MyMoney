import 'package:isar/isar.dart';

import '../../domain/model/debt.dart';
import '../../domain/repository/debt_payment_repository.dart';
import '../local/entities/debt_payment_entity.dart';

class LocalDebtPaymentRepository implements DebtPaymentRepository {
  LocalDebtPaymentRepository(this._isar);
  final Isar _isar;

  @override
  Future<void> create(DebtPayment payment) => _isar.writeTxn(() async {
        await _isar.debtPaymentEntitys.put(DebtPaymentEntity.fromDomain(payment));
      });

  @override
  Future<void> createAll(List<DebtPayment> payments) => _isar.writeTxn(() async {
        // Одна транзакция на весь график: иначе прерывание посередине
        // оставило бы долг с половиной платежей.
        await _isar.debtPaymentEntitys.putAll(
          payments.map(DebtPaymentEntity.fromDomain).toList(),
        );
      });

  @override
  Future<DebtPayment?> findById(String id) async {
    final e = await _isar.debtPaymentEntitys.filter().idEqualTo(id).findFirst();
    return e?.toDomain();
  }

  @override
  Future<List<DebtPayment>> listByDebt(String debtId) async {
    final rows = await _isar.debtPaymentEntitys
        .filter()
        .debtIdEqualTo(debtId)
        .isDeletedEqualTo(false)
        .sortByDueDate()
        .findAll();
    return rows.map((e) => e.toDomain()).toList();
  }

  @override
  Future<void> update(DebtPayment payment) => _isar.writeTxn(() async {
        await _isar.debtPaymentEntitys.put(DebtPaymentEntity.fromDomain(payment));
      });

  @override
  Future<void> softDelete(String id) => _isar.writeTxn(() async {
        final e = await _isar.debtPaymentEntitys.filter().idEqualTo(id).findFirst();
        if (e == null) return;
        e.isDeleted = true;
        e.updatedAt = DateTime.now().toUtc();
        await _isar.debtPaymentEntitys.put(e);
      });

  @override
  Future<void> softDeleteByDebt(String debtId) => _isar.writeTxn(() async {
        final rows = await _isar.debtPaymentEntitys
            .filter()
            .debtIdEqualTo(debtId)
            .isDeletedEqualTo(false)
            .findAll();
        if (rows.isEmpty) return;
        final now = DateTime.now().toUtc();
        for (final e in rows) {
          e.isDeleted = true;
          e.updatedAt = now;
        }
        await _isar.debtPaymentEntitys.putAll(rows);
      });

  @override
  Stream<List<DebtPayment>> watchByDebt(String debtId) => _isar.debtPaymentEntitys
      .filter()
      .debtIdEqualTo(debtId)
      .isDeletedEqualTo(false)
      .sortByDueDate()
      .watch(fireImmediately: true)
      .map((rows) => rows.map((e) => e.toDomain()).toList());
}
