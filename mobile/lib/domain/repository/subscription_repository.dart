import '../model/subscription.dart';

abstract class SubscriptionRepository {
  Future<void> create(Subscription subscription);
  Future<Subscription?> findById(String id);
  Future<List<Subscription>> listByFamily(String familyId);
  Future<void> update(Subscription subscription);
  Future<void> softDelete(String id);
  Stream<List<Subscription>> watchByFamily(String familyId);
}
