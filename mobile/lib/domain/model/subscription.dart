enum SubscriptionPeriod { weekly, monthly, yearly }

extension SubscriptionPeriodX on SubscriptionPeriod {
  String get code => switch (this) {
        SubscriptionPeriod.weekly => 'WEEKLY',
        SubscriptionPeriod.monthly => 'MONTHLY',
        SubscriptionPeriod.yearly => 'YEARLY',
      };
  String get labelRu => switch (this) {
        SubscriptionPeriod.weekly => 'Раз в неделю',
        SubscriptionPeriod.monthly => 'Раз в месяц',
        SubscriptionPeriod.yearly => 'Раз в год',
      };
}

SubscriptionPeriod parseSubscriptionPeriod(String code) => switch (code) {
      'WEEKLY' => SubscriptionPeriod.weekly,
      'MONTHLY' => SubscriptionPeriod.monthly,
      'YEARLY' => SubscriptionPeriod.yearly,
      _ => throw ArgumentError('Unknown SubscriptionPeriod: $code'),
    };

class Subscription {
  final String id;
  final String familyId;
  final String name;
  final int amountKopecks;
  final SubscriptionPeriod billingPeriod;
  final DateTime nextChargeDate;
  final String? categoryId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Subscription({
    required this.id,
    required this.familyId,
    required this.name,
    required this.amountKopecks,
    required this.billingPeriod,
    required this.nextChargeDate,
    this.categoryId,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Subscription copyWith({
    String? name,
    int? amountKopecks,
    SubscriptionPeriod? billingPeriod,
    DateTime? nextChargeDate,
    String? categoryId,
    bool? isDeleted,
    DateTime? updatedAt,
    bool clearCategoryId = false,
  }) =>
      Subscription(
        id: id,
        familyId: familyId,
        name: name ?? this.name,
        amountKopecks: amountKopecks ?? this.amountKopecks,
        billingPeriod: billingPeriod ?? this.billingPeriod,
        nextChargeDate: nextChargeDate ?? this.nextChargeDate,
        categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
