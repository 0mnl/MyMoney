import 'package:isar/isar.dart';

import '../../../domain/model/account.dart';

part 'account_entity.g.dart';

@collection
class AccountEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String familyId;

  late String name;
  late String type;
  late String currency;
  late int initialBalanceKopecks;
  late bool isArchived;
  late bool isDeleted;
  late DateTime createdAt;
  late DateTime updatedAt;

  Account toDomain() => Account(
        id: id,
        familyId: familyId,
        name: name,
        type: type,
        currency: currency,
        initialBalanceKopecks: initialBalanceKopecks,
        isArchived: isArchived,
        isDeleted: isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static AccountEntity fromDomain(Account a) => AccountEntity()
    ..id = a.id
    ..familyId = a.familyId
    ..name = a.name
    ..type = a.type
    ..currency = a.currency
    ..initialBalanceKopecks = a.initialBalanceKopecks
    ..isArchived = a.isArchived
    ..isDeleted = a.isDeleted
    ..createdAt = a.createdAt
    ..updatedAt = a.updatedAt;
}
