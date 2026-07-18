import '../model/budget.dart';

abstract class BudgetRepository {
  Future<void> create(Budget budget);
  Future<Budget?> findById(String id);
  Future<List<Budget>> listByFamily(String familyId);
  Future<void> update(Budget budget);
  Future<void> softDelete(String id);
  Stream<List<Budget>> watchByFamily(String familyId);
}
