import '../model/account.dart';

abstract class AccountRepository {
  Future<void> create(Account account);
  Future<Account?> findById(String id);
  Future<List<Account>> listByFamily(String familyId, {bool includeArchived = false});
  Future<void> update(Account account);
  Future<void> softDelete(String id);
  Stream<List<Account>> watchByFamily(String familyId);
}
