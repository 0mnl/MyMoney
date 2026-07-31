import 'package:isar/isar.dart';

import '../../../domain/model/enums.dart';
import '../../../domain/model/transaction.dart';

part 'transaction_entity.g.dart';

/// Persisted by name — never renumber or rename.
enum IsarTransactionType { income, expense, transfer }

@collection
class TransactionEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index(composite: [CompositeIndex('occurredAt')])
  late String familyId;

  @Index()
  late String accountId;
  String? categoryId;

  @enumerated
  late IsarTransactionType type;
  String? targetAccountId;

  late int amountKopecks;
  late String currency;

  @Index()
  late DateTime occurredAt;

  String? comment;
  String? attachmentPhotoPath;

  late String createdBy;
  late DateTime createdAt;
  late DateTime updatedAt;
  late bool isDeleted;

  Transaction toDomain() => Transaction(
        id: id,
        familyId: familyId,
        accountId: accountId,
        categoryId: categoryId,
        type: switch (type) {
          IsarTransactionType.income => TransactionType.income,
          IsarTransactionType.expense => TransactionType.expense,
          IsarTransactionType.transfer => TransactionType.transfer,
        },
        targetAccountId: targetAccountId,
        amountKopecks: amountKopecks,
        currency: currency,
        occurredAt: occurredAt,
        comment: comment,
        attachmentPhotoPath: attachmentPhotoPath,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isDeleted: isDeleted,
      );

  static TransactionEntity fromDomain(Transaction t) => TransactionEntity()
    ..id = t.id
    ..familyId = t.familyId
    ..accountId = t.accountId
    ..categoryId = t.categoryId
    ..type = switch (t.type) {
      TransactionType.income => IsarTransactionType.income,
      TransactionType.expense => IsarTransactionType.expense,
      TransactionType.transfer => IsarTransactionType.transfer,
    }
    ..targetAccountId = t.targetAccountId
    ..amountKopecks = t.amountKopecks
    ..currency = t.currency
    ..occurredAt = t.occurredAt
    ..comment = t.comment
    ..attachmentPhotoPath = t.attachmentPhotoPath
    ..createdBy = t.createdBy
    ..createdAt = t.createdAt
    ..updatedAt = t.updatedAt
    ..isDeleted = t.isDeleted;
}
