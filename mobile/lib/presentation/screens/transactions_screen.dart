import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/account.dart';
import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';
import '../../domain/model/money.dart';
import '../../domain/model/transaction.dart';
import '../theme/app_ui.dart';
import '../widgets/category_icon.dart';
import 'add_transaction_screen.dart';

/// Фильтр по типу операции. `null` в [_TxFilter.type] — «Все».
enum _TxFilter { all, income, expense, transfer }

final _filterProvider = StateProvider<_TxFilter>((_) => _TxFilter.all);

/// Лента операций. Таб внутри `HomeShell`, поэтому [MmScreen.embedded] —
/// свой `Scaffold` перекрыл бы нижнюю навигацию оболочки.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsStreamProvider);
    final catAsync = ref.watch(categoriesStreamProvider);
    final accAsync = ref.watch(accountsStreamProvider);
    final filter = ref.watch(_filterProvider);

    return MmScreen(
      embedded: true,
      title: 'Операции',
      trailing: MmCircleButton(
        icon: Icons.add,
        tooltip: 'Новая операция',
        onTap: () => mmPush(context, const AddTransactionScreen()),
      ),
      headerBottom: MmSegmented<_TxFilter>(
        items: const [
          (_TxFilter.all, 'Все'),
          (_TxFilter.income, 'Доходы'),
          (_TxFilter.expense, 'Расходы'),
          (_TxFilter.transfer, 'Переводы'),
        ],
        selected: filter,
        onChanged: (v) => ref.read(_filterProvider.notifier).state = v,
      ),
      child: txAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (transactions) => catAsync.when(
          loading: () => const MmLoading(),
          error: (e, _) => MmError(e),
          data: (categories) => accAsync.when(
            loading: () => const MmLoading(),
            error: (e, _) => MmError(e),
            data: (accounts) => _Body(
              transactions: transactions,
              categories: categories,
              accounts: accounts,
              filter: filter,
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.transactions,
    required this.categories,
    required this.accounts,
    required this.filter,
  });

  final List<Transaction> transactions;
  final List<Category> categories;
  final List<Account> accounts;
  final _TxFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = transactions
        .where((t) => !t.isDeleted)
        .where(_matchesFilter)
        .toList();

    if (visible.isEmpty) {
      return MmEmptyState(
        icon: Icons.receipt_long_outlined,
        title: filter == _TxFilter.all
            ? 'Операций ещё нет'
            : 'Нет операций этого типа',
        message: 'Добавьте первую — она сразу попадёт в баланс и аналитику.',
        actionLabel: 'Новая операция',
        onAction: () => mmPush(context, const AddTransactionScreen()),
      );
    }

    final catById = {for (final c in categories) c.id: c};
    final accById = {for (final a in accounts) a.id: a};

    final income = visible
        .where((t) => t.type == TransactionType.income)
        .fold<int>(0, (s, t) => s + t.amountKopecks);
    final expense = visible
        .where((t) => t.type == TransactionType.expense)
        .fold<int>(0, (s, t) => s + t.amountKopecks);

    // Группировка по дню: без неё лента из полусотни строк читается как
    // сплошное полотно, и «когда это было» приходится вычитывать из подписи.
    final byDay = <DateTime, List<Transaction>>{};
    for (final t in visible) {
      final local = t.occurredAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      byDay.putIfAbsent(day, () => []).add(t);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.only(bottom: kMmTabBottomInset),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _TotalsCard(incomeKopecks: income, expenseKopecks: expense),
        ),
        const SizedBox(height: 20),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(_dayLabel(day), style: MmType.footnote),
                ),
                Text(
                  Money.formatRub(_daySum(byDay[day]!)),
                  style: MmType.footnote.copyWith(color: MmColors.labelTertiary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (final t in byDay[day]!)
                  _TransactionRow(
                    transaction: t,
                    category:
                        t.categoryId != null ? catById[t.categoryId!] : null,
                    accounts: accById,
                    onDelete: () => _delete(context, ref, t),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _matchesFilter(Transaction t) => switch (filter) {
        _TxFilter.all => true,
        _TxFilter.income => t.type == TransactionType.income,
        _TxFilter.expense => t.type == TransactionType.expense,
        _TxFilter.transfer => t.type == TransactionType.transfer,
      };

  /// Итог дня: доходы плюсом, расходы минусом, переводы не влияют — они
  /// перекладывают деньги между своими же счетами.
  static int _daySum(List<Transaction> items) => items.fold<int>(0, (s, t) {
        return switch (t.type) {
          TransactionType.income => s + t.amountKopecks,
          TransactionType.expense => s - t.amountKopecks,
          TransactionType.transfer => s,
        };
      });

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return DateFormat('d MMMM y', 'ru_RU').format(day);
  }

  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Transaction t,
  ) async {
    final ok = await mmConfirm(
      context,
      title: 'Удалить операцию?',
      message: 'Баланс счёта пересчитается сразу.',
    );
    if (!ok) return;
    final repo = await ref.read(transactionRepositoryProvider.future);
    await repo.softDelete(t.id);
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.incomeKopecks, required this.expenseKopecks});

  final int incomeKopecks;
  final int expenseKopecks;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              label: 'Доходы',
              value: Money.formatRub(incomeKopecks),
              color: MmColors.green,
            ),
          ),
          Container(width: 1, height: 40, color: MmColors.divider),
          const SizedBox(width: 12),
          Expanded(
            child: _Metric(
              label: 'Расходы',
              value: Money.formatRub(expenseKopecks),
              color: MmColors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: MmType.caption),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MmType.headline.copyWith(color: color),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.category,
    required this.accounts,
    required this.onDelete,
  });

  final Transaction transaction;
  final Category? category;
  final Map<String, Account> accounts;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIncome = t.type == TransactionType.income;
    final isTransfer = t.type == TransactionType.transfer;
    final color = isIncome
        ? MmColors.green
        : isTransfer
            ? MmColors.blue
            : MmColors.red;
    final sign = isIncome ? '+' : (isTransfer ? '' : '-');

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: MmColors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: MmColors.red),
      ),
      // Диалог подтверждения тот же, что и в меню операции: свайп не должен
      // быть более разрушительным способом удаления, чем обычный.
      confirmDismiss: (_) async {
        onDelete();
        // Возвращаем false всегда: строка исчезнет сама, когда поток Isar
        // отдаст обновлённый список. Иначе она пропала бы до подтверждения.
        return false;
      },
      child: MmListRow(
        icon: isTransfer ? Icons.swap_horiz : iconForName(category?.icon),
        title: category?.name ?? _fallbackTitle(t.type),
        subtitle: _subtitle(t),
        trailingText: '$sign${Money.formatRub(t.amountKopecks)}',
        trailingColor: color,
        onTap: () => mmPush(context, AddTransactionScreen(existing: t)),
        onLongPress: onDelete,
      ),
    );
  }

  /// Для перевода полезнее направление «откуда → куда», чем один счёт:
  /// операция затрагивает два счёта.
  String _subtitle(Transaction t) {
    final time = DateFormat('HH:mm', 'ru_RU').format(t.occurredAt.toLocal());
    final from = accounts[t.accountId]?.name ?? '—';
    if (t.type != TransactionType.transfer) {
      final comment = t.comment;
      return comment == null || comment.isEmpty
          ? '$time • $from'
          : '$time • $from • $comment';
    }
    final to = t.targetAccountId == null
        ? '—'
        : (accounts[t.targetAccountId!]?.name ?? '—');
    return '$time • $from → $to';
  }

  static String _fallbackTitle(TransactionType type) => switch (type) {
        TransactionType.income => 'Доход',
        TransactionType.expense => 'Расход',
        TransactionType.transfer => 'Перевод',
      };
}
