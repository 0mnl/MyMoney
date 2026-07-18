import '../model/goal.dart';

abstract class GoalRepository {
  Future<void> create(Goal goal);
  Future<Goal?> findById(String id);
  Future<List<Goal>> listByFamily(String familyId);
  Future<void> update(Goal goal);
  Future<void> softDelete(String id);
  Stream<List<Goal>> watchByFamily(String familyId);
}
