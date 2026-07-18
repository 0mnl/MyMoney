import '../model/transaction.dart';

abstract class TransactionRepository {
  Future<void> create(Transaction transaction);
  Future<Transaction?> findById(String id);
  Future<List<Transaction>> listByFamily(
    String familyId, {
    String? accountId,
    int limit = 200,
  });
  Future<void> update(Transaction transaction);
  Future<void> softDelete(String id);
  Stream<List<Transaction>> watchByFamily(String familyId);
}
