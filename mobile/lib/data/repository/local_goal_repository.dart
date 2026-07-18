import 'package:isar/isar.dart';

import '../../domain/model/goal.dart';
import '../../domain/repository/goal_repository.dart';
import '../local/entities/goal_entity.dart';

class LocalGoalRepository implements GoalRepository {
  LocalGoalRepository(this._isar);
  final Isar _isar;

  @override
  Future<void> create(Goal goal) => _isar.writeTxn(() async {
        await _isar.goalEntitys.put(GoalEntity.fromDomain(goal));
      });

  @override
  Future<Goal?> findById(String id) async {
    final e = await _isar.goalEntitys.filter().idEqualTo(id).findFirst();
    return e?.toDomain();
  }

  @override
  Future<List<Goal>> listByFamily(String familyId) async {
    final rows = await _isar.goalEntitys
        .filter()
        .familyIdEqualTo(familyId)
        .isDeletedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
    return rows.map((e) => e.toDomain()).toList();
  }

  @override
  Future<void> update(Goal goal) => _isar.writeTxn(() async {
        await _isar.goalEntitys.put(GoalEntity.fromDomain(goal));
      });

  @override
  Future<void> softDelete(String id) => _isar.writeTxn(() async {
        final e = await _isar.goalEntitys.filter().idEqualTo(id).findFirst();
        if (e == null) return;
        e.isDeleted = true;
        e.updatedAt = DateTime.now().toUtc();
        await _isar.goalEntitys.put(e);
      });

  @override
  Stream<List<Goal>> watchByFamily(String familyId) => _isar.goalEntitys
      .filter()
      .familyIdEqualTo(familyId)
      .isDeletedEqualTo(false)
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true)
      .map((rows) => rows.map((e) => e.toDomain()).toList());
}
