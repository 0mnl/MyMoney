import 'package:isar/isar.dart';

import '../../domain/model/subscription.dart';
import '../../domain/repository/subscription_repository.dart';
import '../local/entities/subscription_entity.dart';

class LocalSubscriptionRepository implements SubscriptionRepository {
  LocalSubscriptionRepository(this._isar);
  final Isar _isar;

  @override
  Future<void> create(Subscription subscription) => _isar.writeTxn(() async {
        await _isar.subscriptionEntitys.put(SubscriptionEntity.fromDomain(subscription));
      });

  @override
  Future<Subscription?> findById(String id) async {
    final e = await _isar.subscriptionEntitys.filter().idEqualTo(id).findFirst();
    return e?.toDomain();
  }

  @override
  Future<List<Subscription>> listByFamily(String familyId) async {
    final rows = await _isar.subscriptionEntitys
        .filter()
        .familyIdEqualTo(familyId)
        .isDeletedEqualTo(false)
        .sortByNextChargeDate()
        .findAll();
    return rows.map((e) => e.toDomain()).toList();
  }

  @override
  Future<void> update(Subscription subscription) => _isar.writeTxn(() async {
        await _isar.subscriptionEntitys.put(SubscriptionEntity.fromDomain(subscription));
      });

  @override
  Future<void> softDelete(String id) => _isar.writeTxn(() async {
        final e = await _isar.subscriptionEntitys.filter().idEqualTo(id).findFirst();
        if (e == null) return;
        e.isDeleted = true;
        e.updatedAt = DateTime.now().toUtc();
        await _isar.subscriptionEntitys.put(e);
      });

  @override
  Stream<List<Subscription>> watchByFamily(String familyId) => _isar.subscriptionEntitys
      .filter()
      .familyIdEqualTo(familyId)
      .isDeletedEqualTo(false)
      .sortByNextChargeDate()
      .watch(fireImmediately: true)
      .map((rows) => rows.map((e) => e.toDomain()).toList());
}
