import 'package:isar/isar.dart';

import '../../domain/model/debt.dart';
import '../../domain/repository/debt_repository.dart';
import '../local/entities/debt_entity.dart';

class LocalDebtRepository implements DebtRepository {
  LocalDebtRepository(this._isar);
  final Isar _isar;

  @override
  Future<void> create(Debt debt) => _isar.writeTxn(() async {
        await _isar.debtEntitys.put(DebtEntity.fromDomain(debt));
      });

  @override
  Future<Debt?> findById(String id) async {
    final e = await _isar.debtEntitys.filter().idEqualTo(id).findFirst();
    return e?.toDomain();
  }

  @override
  Future<List<Debt>> listByFamily(String familyId, {bool openOnly = false}) async {
    var q = _isar.debtEntitys
        .filter()
        .familyIdEqualTo(familyId)
        .isDeletedEqualTo(false);
    if (openOnly) q = q.statusEqualTo(IsarDebtStatus.open);
    final rows = await q.sortByCreatedAtDesc().findAll();
    return rows.map((e) => e.toDomain()).toList();
  }

  @override
  Future<void> update(Debt debt) => _isar.writeTxn(() async {
        await _isar.debtEntitys.put(DebtEntity.fromDomain(debt));
      });

  @override
  Future<void> softDelete(String id) => _isar.writeTxn(() async {
        final e = await _isar.debtEntitys.filter().idEqualTo(id).findFirst();
        if (e == null) return;
        e.isDeleted = true;
        e.updatedAt = DateTime.now().toUtc();
        await _isar.debtEntitys.put(e);
      });

  @override
  Stream<List<Debt>> watchByFamily(String familyId) => _isar.debtEntitys
      .filter()
      .familyIdEqualTo(familyId)
      .isDeletedEqualTo(false)
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true)
      .map((rows) => rows.map((e) => e.toDomain()).toList());
}
