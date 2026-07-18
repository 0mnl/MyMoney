import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/enums.dart';
import '../../domain/model/money.dart';
import '../widgets/category_icon.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsStreamProvider);
    final catAsync = ref.watch(categoriesStreamProvider);
    final accAsync = ref.watch(accountsStreamProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Операции')),
        body: txAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (transactions) => catAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
            data: (categories) => accAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (accounts) {
                if (transactions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Операций ещё нет.', textAlign: TextAlign.center),
                    ),
                  );
                }
                final catById = {for (final c in categories) c.id: c};
                final accById = {for (final a in accounts) a.id: a};
                final df = DateFormat('d MMM y, HH:mm', 'ru_RU');
                return ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = transactions[i];
                    final cat = t.categoryId != null ? catById[t.categoryId!] : null;
                    final acc = accById[t.accountId];
                    final isIncome = t.type == TransactionType.income;
                    final color = isIncome
                        ? Colors.green.shade700
                        : t.type == TransactionType.expense
                            ? Colors.red.shade700
                            : Colors.blue.shade700;
                    final sign = isIncome ? '+' : t.type == TransactionType.expense ? '-' : '';
                    return Dismissible(
                      key: ValueKey(t.id),
                      background: Container(color: Colors.red.shade100, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete)),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Удалить операцию?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (_) async {
                        final repo = await ref.read(transactionRepositoryProvider.future);
                        await repo.softDelete(t.id);
                      },
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(iconForName(cat?.icon))),
                        title: Text(cat?.name ?? _fallbackTitle(t.type)),
                        subtitle: Text('${df.format(t.occurredAt.toLocal())} • ${acc?.name ?? '—'}'),
                        trailing: Text(
                          '$sign${Money.formatRub(t.amountKopecks)}',
                          style: TextStyle(color: color, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
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
}
