import '../model/debt.dart';

abstract class DebtRepository {
  Future<void> create(Debt debt);
  Future<Debt?> findById(String id);
  Future<List<Debt>> listByFamily(String familyId, {bool openOnly = false});
  Future<void> update(Debt debt);
  Future<void> softDelete(String id);
  Stream<List<Debt>> watchByFamily(String familyId);
}
