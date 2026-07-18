import 'package:isar/isar.dart';

import '../../domain/model/budget.dart';
import '../../domain/repository/budget_repository.dart';
import '../local/entities/budget_entity.dart';

class LocalBudgetRepository implements BudgetRepository {
  LocalBudgetRepository(this._isar);
  final Isar _isar;

  @override
  Future<void> create(Budget budget) => _isar.writeTxn(() async {
        await _isar.budgetEntitys.put(BudgetEntity.fromDomain(budget));
      });

  @override
  Future<Budget?> findById(String id) async {
    final e = await _isar.budgetEntitys.filter().idEqualTo(id).findFirst();
    return e?.toDomain();
  }

  @override
  Future<List<Budget>> listByFamily(String familyId) async {
    final rows = await _isar.budgetEntitys
        .filter()
        .familyIdEqualTo(familyId)
        .isDeletedEqualTo(false)
        .sortByPeriodStartDesc()
        .findAll();
    return rows.map((e) => e.toDomain()).toList();
  }

  @override
  Future<void> update(Budget budget) => _isar.writeTxn(() async {
        await _isar.budgetEntitys.put(BudgetEntity.fromDomain(budget));
      });

  @override
  Future<void> softDelete(String id) => _isar.writeTxn(() async {
        final e = await _isar.budgetEntitys.filter().idEqualTo(id).findFirst();
        if (e == null) return;
        e.isDeleted = true;
        e.updatedAt = DateTime.now().toUtc();
        await _isar.budgetEntitys.put(e);
      });

  @override
  Stream<List<Budget>> watchByFamily(String familyId) => _isar.budgetEntitys
      .filter()
      .familyIdEqualTo(familyId)
      .isDeletedEqualTo(false)
      .sortByPeriodStartDesc()
      .watch(fireImmediately: true)
      .map((rows) => rows.map((e) => e.toDomain()).toList());
}
