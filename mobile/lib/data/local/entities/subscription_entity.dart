import 'package:isar/isar.dart';

import '../../../domain/model/subscription.dart';

part 'subscription_entity.g.dart';

/// Persisted by name — never renumber or rename.
enum IsarSubscriptionPeriod { weekly, monthly, yearly }

@collection
class SubscriptionEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String familyId;

  late String name;
  late int amountKopecks;

  @enumerated
  late IsarSubscriptionPeriod billingPeriod;

  late DateTime nextChargeDate;
  String? categoryId;

  late bool isDeleted;
  late DateTime createdAt;
  late DateTime updatedAt;

  Subscription toDomain() => Subscription(
        id: id,
        familyId: familyId,
        name: name,
        amountKopecks: amountKopecks,
        billingPeriod: switch (billingPeriod) {
          IsarSubscriptionPeriod.weekly => SubscriptionPeriod.weekly,
          IsarSubscriptionPeriod.monthly => SubscriptionPeriod.monthly,
          IsarSubscriptionPeriod.yearly => SubscriptionPeriod.yearly,
        },
        nextChargeDate: nextChargeDate,
        categoryId: categoryId,
        isDeleted: isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static SubscriptionEntity fromDomain(Subscription s) => SubscriptionEntity()
    ..id = s.id
    ..familyId = s.familyId
    ..name = s.name
    ..amountKopecks = s.amountKopecks
    ..billingPeriod = switch (s.billingPeriod) {
      SubscriptionPeriod.weekly => IsarSubscriptionPeriod.weekly,
      SubscriptionPeriod.monthly => IsarSubscriptionPeriod.monthly,
      SubscriptionPeriod.yearly => IsarSubscriptionPeriod.yearly,
    }
    ..nextChargeDate = s.nextChargeDate
    ..categoryId = s.categoryId
    ..isDeleted = s.isDeleted
    ..createdAt = s.createdAt
    ..updatedAt = s.updatedAt;
}
