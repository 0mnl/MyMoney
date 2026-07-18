import 'account.dart';
import 'enums.dart';
import 'transaction.dart';

/// Computes per-account current balance in kopecks. Handles all three
/// transaction types including transfers (source loses, target gains).
Map<String, int> computeAccountBalances(
  List<Account> accounts,
  List<Transaction> transactions,
) {
  final balances = <String, int>{};
  for (final a in accounts) {
    balances[a.id] = a.initialBalanceKopecks;
  }
  for (final t in transactions) {
    if (t.isDeleted) continue;
    switch (t.type) {
      case TransactionType.income:
        balances.update(t.accountId, (v) => v + t.amountKopecks, ifAbsent: () => t.amountKopecks);
      case TransactionType.expense:
        balances.update(t.accountId, (v) => v - t.amountKopecks, ifAbsent: () => -t.amountKopecks);
      case TransactionType.transfer:
        balances.update(t.accountId, (v) => v - t.amountKopecks, ifAbsent: () => -t.amountKopecks);
        final target = t.targetAccountId;
        if (target != null) {
          balances.update(target, (v) => v + t.amountKopecks, ifAbsent: () => t.amountKopecks);
        }
    }
  }
  return balances;
}

int totalBalanceKopecks(Map<String, int> perAccount) =>
    perAccount.values.fold(0, (a, b) => a + b);
