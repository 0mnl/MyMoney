class Account {
  final String id;
  final String familyId;
  final String name;
  final String type;
  final String currency;
  final int initialBalanceKopecks;

  /// Лимит кредитной карты в копейках. `null` для не-кредитных счетов.
  /// Bible v2 §7.2, §12.
  final int? creditLimitKopecks;

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
    this.creditLimitKopecks,
    this.isArchived = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Account copyWith({
    String? name,
    String? type,
    int? initialBalanceKopecks,
    int? creditLimitKopecks,
    bool clearCreditLimit = false,
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
        creditLimitKopecks:
            clearCreditLimit ? null : (creditLimitKopecks ?? this.creditLimitKopecks),
        isArchived: isArchived ?? this.isArchived,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
