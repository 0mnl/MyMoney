import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/account.dart';
import '../../domain/model/balances.dart';
import '../../domain/model/budget.dart';
import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';
import '../../domain/model/money.dart';
import '../../domain/model/transaction.dart';
import '../providers/analytics_providers.dart';
import '../theme/app_ui.dart';
import '../widgets/category_icon.dart';
import 'accounts_screen.dart';
import 'analytics_screen.dart';
import 'home_shell.dart';

const int _tabTransactions = 1;

/// Главная: общий баланс, расходы по категориям, счета и последние операции.
/// Экран задаёт визуальный язык всего приложения — токены и блоки вынесены в
/// `theme/app_ui.dart`, остальные экраны собираются из них же.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return MmScreen(
      embedded: true,
      title: 'Главная',
      child: accountsAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (accounts) => transactionsAsync.when(
          loading: () => const MmLoading(),
          error: (e, _) => MmError(e),
          data: (transactions) => categoriesAsync.when(
            loading: () => const MmLoading(),
            error: (e, _) => MmError(e),
            data: (categories) {
              final balances = computeAccountBalances(accounts, transactions);
              final total = totalBalanceKopecks(balances);
              final visibleAccounts = accounts
                  .where((a) => !a.isArchived && !a.isDeleted)
                  .toList();
              final catById = {for (final c in categories) c.id: c};
              final recent =
                  transactions.where((t) => !t.isDeleted).take(11).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: kMmTabBottomInset),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Всего на счетах',
                            style: TextStyle(
                              color: MmColors.labelSecondary,
                              fontSize: 17,
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w600,
                              height: 1.29,
                              letterSpacing: -0.43,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            Money.formatRub(total),
                            style: MmType.largeTitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  MmSectionHeader(
                    title: 'Расходы по категориям',
                    actionLabel: 'Все',
                    onAction: () => mmPush(context, const AnalyticsScreen()),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _PeriodSegmentedControl(),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _CategoryDonutSection(
                      onTap: () => mmPush(context, const AnalyticsScreen()),
                    ),
                  ),
                  const SizedBox(height: 28),
                  MmSectionHeader(
                    title: 'Счета',
                    actionLabel: 'Все',
                    onAction: () => mmPush(context, const AccountsScreen()),
                  ),
                  const SizedBox(height: 12),
                  _AccountsRow(
                    accounts: visibleAccounts,
                    balances: balances,
                    onCardTap: () => mmPush(context, const AccountsScreen()),
                  ),
                  const SizedBox(height: 24),
                  MmSectionHeader(
                    title: 'Последние операции',
                    actionLabel: 'Все',
                    onAction: () => _switchTab(ref, _tabTransactions),
                  ),
                  const SizedBox(height: 8),
                  if (recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      child: Text(
                        'Пока пусто. Нажмите «+» внизу справа.',
                        textAlign: TextAlign.center,
                        style: MmType.subhead,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          for (final t in recent)
                            _TransactionRow(
                              transaction: t,
                              category: t.categoryId != null
                                  ? catById[t.categoryId!]
                                  : null,
                              account: _findAccount(accounts, t.accountId),
                              onTap: () => _switchTab(ref, _tabTransactions),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static Account? _findAccount(List<Account> accounts, String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  static void _switchTab(WidgetRef ref, int index) {
    ref.read(homeShellTabProvider.notifier).state = index;
  }
}

class _PeriodSegmentedControl extends ConsumerWidget {
  const _PeriodSegmentedControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedAnalyticsPeriodProvider);
    return MmSegmented<BudgetPeriodType>(
      items: [
        for (final p in BudgetPeriodType.values) (p, p.labelRu),
      ],
      selected: period,
      onChanged: (v) =>
          ref.read(selectedAnalyticsPeriodProvider.notifier).state = v,
    );
  }
}

/// Кольцо расходов с легендой. Секторы рисуются по тем же цветам и в том же
/// порядке, что и в «Статистике», — иначе одна и та же категория была бы
/// разного цвета на двух экранах.
class _CategoryDonutSection extends ConsumerWidget {
  const _CategoryDonutSection({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(periodAnalyticsProvider);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: analyticsAsync.when(
        loading: () => const SizedBox(height: 174, child: MmLoading()),
        error: (_, __) => const SizedBox.shrink(),
        data: (analytics) {
          final total = analytics.totalExpenseKopecks;
          final cats = analytics.categoryBreakdown.values.toList()
            ..sort((a, b) => b.totalKopecks.compareTo(a.totalKopecks));
          final top = cats.take(6).toList();

          if (top.isEmpty) {
            return const SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'Нет расходов за этот период',
                  style: MmType.subhead,
                ),
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 174,
                height: 174,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 52,
                        sectionsSpace: 2,
                        sections: [
                          for (var i = 0; i < top.length; i++)
                            PieChartSectionData(
                              value: top[i].totalKopecks.toDouble(),
                              color:
                                  MmColors.chart[i % MmColors.chart.length],
                              radius: 32,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Расходы', style: MmType.subhead),
                        Text(Money.formatRub(total), style: MmType.section),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < top.length; i++) ...[
                      if (i > 0) const SizedBox(height: 5),
                      _CategoryLegendRow(
                        color: MmColors.chart[i % MmColors.chart.length],
                        label: top[i].categoryName,
                        percent:
                            '${top[i].percentageOfTotal.toStringAsFixed(0)}%',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final String percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MmType.footnote,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          percent,
          textAlign: TextAlign.right,
          style: MmType.footnote.copyWith(color: MmColors.labelTertiary),
        ),
      ],
    );
  }
}

class _AccountsRow extends StatelessWidget {
  const _AccountsRow({
    required this.accounts,
    required this.balances,
    required this.onCardTap,
  });

  final List<Account> accounts;
  final Map<String, int> balances;
  final VoidCallback onCardTap;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Нет счетов. Добавьте счёт в «Настройки → Счета».',
          style: MmType.subhead,
        ),
      );
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = accounts[i];
          return _AccountCard(
            icon: iconForAccountType(a.type),
            label: a.name,
            amount: Money.formatRub(balances[a.id] ?? 0),
            onTap: onCardTap,
          );
        },
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 161,
      height: 94,
      child: MmCard(
        radius: 24,
        shadows: MmShadows.tile,
        padding: const EdgeInsets.all(13),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: MmColors.label, size: 22),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MmType.caption.copyWith(color: MmColors.labelSecondary),
            ),
            Text(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MmType.bodyStrong,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.category,
    required this.account,
    required this.onTap,
  });

  final Transaction transaction;
  final Category? category;
  final Account? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;
    final amountColor = isIncome
        ? MmColors.green
        : isTransfer
            ? MmColors.blue
            : MmColors.red;
    final sign = isIncome ? '+' : (isTransfer ? '' : '-');
    final title = category?.name ??
        (isIncome ? 'Доход' : (isTransfer ? 'Перевод' : 'Расход'));

    return MmListRow(
      icon: isTransfer ? Icons.swap_horiz : iconForName(category?.icon),
      title: title,
      subtitle: _subtitle(),
      trailingText: '$sign${Money.formatRub(transaction.amountKopecks)}',
      trailingColor: amountColor,
      onTap: onTap,
    );
  }

  String _subtitle() {
    final acc = account?.name;
    final when = _relativeDate(transaction.occurredAt);
    if (acc == null) return when;
    return '$when, $acc';
  }

  static String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final local = dt.toLocal();
    final that = DateTime(local.year, local.month, local.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return '${_two(local.day)}.${_two(local.month)}.${local.year}';
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';
}
