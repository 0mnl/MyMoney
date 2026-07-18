import 'package:isar/isar.dart';

import '../../domain/model/transaction.dart';
import '../../domain/repository/transaction_repository.dart';
import '../local/entities/transaction_entity.dart';

class LocalTransactionRepository implements TransactionRepository {
  LocalTransactionRepository(this._isar);
  final Isar _isar;

  @override
  Future<void> create(Transaction transaction) => _isar.writeTxn(() async {
        await _isar.transactionEntitys.put(TransactionEntity.fromDomain(transaction));
      });

  @override
  Future<Transaction?> findById(String id) async {
    final e = await _isar.transactionEntitys.filter().idEqualTo(id).findFirst();
    return e?.toDomain();
  }

  @override
  Future<List<Transaction>> listByFamily(
    String familyId, {
    String? accountId,
    int limit = 200,
  }) async {
    var q = _isar.transactionEntitys
        .filter()
        .familyIdEqualTo(familyId)
        .isDeletedEqualTo(false);
    if (accountId != null) {
      q = q.group((it) => it.accountIdEqualTo(accountId).or().targetAccountIdEqualTo(accountId));
    }
    final rows = await q.sortByOccurredAtDesc().limit(limit).findAll();
    return rows.map((e) => e.toDomain()).toList();
  }

  @override
  Future<void> update(Transaction transaction) => _isar.writeTxn(() async {
        await _isar.transactionEntitys.put(TransactionEntity.fromDomain(transaction));
      });

  @override
  Future<void> softDelete(String id) => _isar.writeTxn(() async {
        final e = await _isar.transactionEntitys.filter().idEqualTo(id).findFirst();
        if (e == null) return;
        e.isDeleted = true;
        e.updatedAt = DateTime.now().toUtc();
        await _isar.transactionEntitys.put(e);
      });

  @override
  Stream<List<Transaction>> watchByFamily(String familyId) => _isar.transactionEntitys
      .filter()
      .familyIdEqualTo(familyId)
      .isDeletedEqualTo(false)
      .sortByOccurredAtDesc()
      .watch(fireImmediately: true)
      .map((rows) => rows.map((e) => e.toDomain()).toList());
}
