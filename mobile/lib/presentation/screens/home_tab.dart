import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/balances.dart';
import '../../domain/model/enums.dart';
import '../../domain/model/money.dart';
import '../widgets/category_icon.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return SafeArea(
      child: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (accounts) => transactionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (transactions) => categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
            data: (categories) {
              final balances = computeAccountBalances(accounts, transactions);
              final total = totalBalanceKopecks(balances);
              final catById = {for (final c in categories) c.id: c};
              final recent = transactions.take(10).toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _TotalCard(total: total)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Последние операции',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (recent.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Пока пусто. Нажмите «+ Операция» внизу справа.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: recent.length,
                      itemBuilder: (context, i) {
                        final t = recent[i];
                        final cat = t.categoryId != null ? catById[t.categoryId!] : null;
                        final isIncome = t.type == TransactionType.income;
                        final color = isIncome
                            ? Colors.green.shade700
                            : t.type == TransactionType.expense
                                ? Colors.red.shade700
                                : Colors.blue.shade700;
                        final sign = isIncome
                            ? '+'
                            : t.type == TransactionType.expense
                                ? '-'
                                : '';
                        return ListTile(
                          leading: CircleAvatar(child: Icon(iconForName(cat?.icon))),
                          title: Text(cat?.name ?? _fallbackTitle(t.type)),
                          subtitle: Text(t.comment ?? _typeLabel(t.type)),
                          trailing: Text(
                            '$sign${Money.formatRub(t.amountKopecks)}',
                            style: TextStyle(color: color, fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _fallbackTitle(TransactionType type) => switch (type) {
        TransactionType.income => 'Доход',
        TransactionType.expense => 'Расход',
        TransactionType.transfer => 'Перевод',
      };
  static String _typeLabel(TransactionType type) => switch (type) {
        TransactionType.income => 'Доход',
        TransactionType.expense => 'Расход',
        TransactionType.transfer => 'Перевод между счетами',
      };
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Общий баланс', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(
                  Money.formatRub(total),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
}
