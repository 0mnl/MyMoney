class Account {
  final String id;
  final String familyId;
  final String name;
  final String type;
  final String currency;
  final int initialBalanceKopecks;
  final bool isArchived;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    required this.id,
    required this.familyId,
    required this.name,
    required this.type,
    this.currency = 'RUB',
    this.initialBalanceKopecks = 0,
    this.isArchived = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Account copyWith({
    String? name,
    String? type,
    int? initialBalanceKopecks,
    bool? isArchived,
    bool? isDeleted,
    DateTime? updatedAt,
  }) =>
      Account(
        id: id,
        familyId: familyId,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency,
        initialBalanceKopecks: initialBalanceKopecks ?? this.initialBalanceKopecks,
        isArchived: isArchived ?? this.isArchived,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
