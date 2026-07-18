enum CategoryType { income, expense }

enum TransactionType { income, expense, transfer }

extension CategoryTypeX on CategoryType {
  String get code => switch (this) {
        CategoryType.income => 'INCOME',
        CategoryType.expense => 'EXPENSE',
      };
}

extension TransactionTypeX on TransactionType {
  String get code => switch (this) {
        TransactionType.income => 'INCOME',
        TransactionType.expense => 'EXPENSE',
        TransactionType.transfer => 'TRANSFER',
      };
}
