import 'package:isar/isar.dart';

import '../../domain/model/account.dart';
import '../../domain/repository/account_repository.dart';
import '../local/entities/account_entity.dart';

class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository(this._isar);
  final Isar _isar;

  @override
  Future<void> create(Account account) => _isar.writeTxn(() async {
        await _isar.accountEntitys.put(AccountEntity.fromDomain(account));
      });

  @override
  Future<Account?> findById(String id) async {
    final e = await _isar.accountEntitys.filter().idEqualTo(id).findFirst();
    return e?.toDomain();
  }

  @override
  Future<List<Account>> listByFamily(String familyId, {bool includeArchived = false}) async {
    final q = _isar.accountEntitys
        .filter()
        .familyIdEqualTo(familyId)
        .isDeletedEqualTo(false);
    final rows = includeArchived
        ? await q.sortByCreatedAt().findAll()
        : await q.isArchivedEqualTo(false).sortByCreatedAt().findAll();
    return rows.map((e) => e.toDomain()).toList();
  }

  @override
  Future<void> update(Account account) => _isar.writeTxn(() async {
        await _isar.accountEntitys.put(AccountEntity.fromDomain(account));
      });

  @override
  Future<void> softDelete(String id) => _isar.writeTxn(() async {
        final e = await _isar.accountEntitys.filter().idEqualTo(id).findFirst();
        if (e == null) return;
        e.isDeleted = true;
        e.updatedAt = DateTime.now().toUtc();
        await _isar.accountEntitys.put(e);
      });

  @override
  Stream<List<Account>> watchByFamily(String familyId) => _isar.accountEntitys
      .filter()
      .familyIdEqualTo(familyId)
      .isDeletedEqualTo(false)
      .isArchivedEqualTo(false)
      .sortByCreatedAt()
      .watch(fireImmediately: true)
      .map((rows) => rows.map((e) => e.toDomain()).toList());
}
