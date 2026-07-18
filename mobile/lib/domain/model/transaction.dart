import 'enums.dart';

class Transaction {
  final String id;
  final String familyId;
  final String accountId;
  final String? categoryId;
  final TransactionType type;
  final String? targetAccountId;
  final int amountKopecks;
  final String currency;
  final DateTime occurredAt;
  final String? comment;
  final String? attachmentPhotoPath;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const Transaction({
    required this.id,
    required this.familyId,
    required this.accountId,
    this.categoryId,
    required this.type,
    this.targetAccountId,
    required this.amountKopecks,
    this.currency = 'RUB',
    required this.occurredAt,
    this.comment,
    this.attachmentPhotoPath,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });
}
