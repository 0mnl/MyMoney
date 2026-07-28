import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/account.dart';
import '../../domain/model/balances.dart';
import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';
import '../../domain/model/money.dart';
import '../../domain/model/transaction.dart';
import '../widgets/category_icon.dart';
import 'home_shell.dart';

// Tab indices inside HomeShell — keep in sync with _HomeShellState._tabs.
const int _tabAccounts = 1;
const int _tabTransactions = 2;
const int _tabAnalytics = 7;

const _bgBeige = Color(0xFFF4EDE3);
const _labelsPrimary = Colors.black;
const _labelsSecondary = Color(0x993C3C43);
const _accentRed = Color(0xFFFF383C);
const _accentGreen = Color(0xFF34C759);
const _accentIndigo = Color(0xFF6155F5);
const _accentBrown = Color(0xFFAC7F5E);
const _accentYellow = Color(0xFFFFCC00);
const _accentCyan = Color(0xFF00C0E8);
const _accentPink = Color(0xFFFF2D55);
const _accentBlue = Color(0xFF0088FF);
const _linkRed = Color(0xFF892029);

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Container(
      color: _bgBeige,
      child: SafeArea(
        bottom: false,
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
                final visibleAccounts =
                    accounts.where((a) => !a.isArchived && !a.isDeleted).toList();
                final catById = {for (final c in categories) c.id: c};
                final recent = transactions.take(11).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Text(
                          'Главная',
                          style: TextStyle(
                            color: _labelsPrimary,
                            fontSize: 34,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w700,
                            height: 1.21,
                            letterSpacing: 0.40,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _TotalBalanceCard(totalKopecks: total),
                      ),
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Расходы по категориям',
                          style: TextStyle(
                            color: _labelsPrimary,
                            fontSize: 22,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w700,
                            height: 1.27,
                            letterSpacing: -0.26,
                          ),
                        ),
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
                          onTap: () => _switchTab(ref, _tabAnalytics),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Счета',
                        onAll: () => _switchTab(ref, _tabAccounts),
                      ),
                      const SizedBox(height: 12),
                      _AccountsRow(
                        accounts: visibleAccounts,
                        balances: balances,
                        onCardTap: (_) => _switchTab(ref, _tabAccounts),
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: 'Последние операции',
                        onAll: () => _switchTab(ref, _tabTransactions),
                      ),
                      const SizedBox(height: 8),
                      if (recent.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          child: Text(
                            'Пока пусто. Нажмите «+ Операция» внизу справа.',
                            textAlign: TextAlign.center,
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
                                  category:
                                      t.categoryId != null ? catById[t.categoryId!] : null,
                                  account: _findAccount(accounts, t.accountId),
                                  onTap: () => _switchTab(ref, _tabTransactions),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
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

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.totalKopecks});
  final int totalKopecks;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 17, 19, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 48,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Всего на счетах',
            style: TextStyle(
              color: _labelsSecondary,
              fontSize: 17,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
              height: 1.29,
              letterSpacing: -0.43,
            ),
          ),
          Text(
            Money.formatRub(totalKopecks),
            style: const TextStyle(
              color: _labelsPrimary,
              fontSize: 34,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
              height: 1.21,
              letterSpacing: 0.40,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAll});
  final String title;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _labelsPrimary,
                fontSize: 22,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w700,
                height: 1.27,
                letterSpacing: -0.26,
              ),
            ),
          ),
          GestureDetector(
            onTap: onAll,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Text(
                'Все',
                style: TextStyle(
                  color: _linkRed,
                  fontSize: 17,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w400,
                  height: 1.29,
                  letterSpacing: -0.43,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSegmentedControl extends StatefulWidget {
  const _PeriodSegmentedControl();

  @override
  State<_PeriodSegmentedControl> createState() => _PeriodSegmentedControlState();
}

class _PeriodSegmentedControlState extends State<_PeriodSegmentedControl> {
  int _selected = 0;
  static const _labels = ['Неделя', 'Месяц', 'Год'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x1E767680),
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selected = i),
                child: Container(
                  height: 28,
                  alignment: Alignment.center,
                  decoration: _selected == i
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1000),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 20,
                              offset: Offset(0, 2),
                            ),
                          ],
                        )
                      : null,
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13.33,
                      fontFamily: 'SF Pro',
                      fontWeight:
                          _selected == i ? FontWeight.w600 : FontWeight.w500,
                      height: 1.35,
                      letterSpacing: -0.08,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryDonutSection extends StatelessWidget {
  const _CategoryDonutSection({required this.onTap});
  final VoidCallback onTap;

  // Placeholder distribution — real per-period aggregation lives in
  // analytics_providers; will be wired up in a follow-up task.
  static const _legend = <_LegendItem>[
    _LegendItem(color: _accentIndigo, label: 'Жильё', percent: '45%'),
    _LegendItem(color: _accentBrown, label: 'Транспорт', percent: '29%'),
    _LegendItem(color: _accentYellow, label: 'Еда', percent: '15%'),
    _LegendItem(color: _accentCyan, label: 'Техника', percent: '10%'),
    _LegendItem(color: _accentPink, label: 'Стройка', percent: '10%'),
    _LegendItem(color: _accentBlue, label: 'Прочее', percent: '10%'),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 174,
          height: 174,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: const ShapeDecoration(
                  color: _accentIndigo,
                  shape: OvalBorder(),
                ),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Расходы',
                    style: TextStyle(
                      color: _labelsSecondary,
                      fontSize: 15,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w400,
                      height: 1.33,
                      letterSpacing: -0.23,
                    ),
                  ),
                  Text(
                    '48 500 ',
                    style: TextStyle(
                      color: _labelsPrimary,
                      fontSize: 22,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w700,
                      height: 1.27,
                      letterSpacing: -0.26,
                    ),
                  ),
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
              for (var i = 0; i < _legend.length; i++) ...[
                if (i > 0) const SizedBox(height: 5),
                _CategoryLegendRow(item: _legend[i]),
              ],
            ],
          ),
        ),
      ],
    ),
    );
  }
}

class _LegendItem {
  const _LegendItem({required this.color, required this.label, required this.percent});
  final Color color;
  final String label;
  final String percent;
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({required this.item});
  final _LegendItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13.33,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
              height: 1.35,
              letterSpacing: -0.08,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          item.percent,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 13.33,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            height: 1.35,
            letterSpacing: -0.08,
          ),
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
  final ValueChanged<Account> onCardTap;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Нет счетов. Добавьте счёт на вкладке «Счета».',
          style: TextStyle(color: _labelsSecondary),
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
            icon: _iconForAccountType(a.type),
            label: a.name,
            amount: Money.formatRub(balances[a.id] ?? 0),
            onTap: () => onCardTap(a),
          );
        },
      ),
    );
  }

  static IconData _iconForAccountType(String type) => switch (type) {
        'card' => Icons.credit_card,
        'cash' => Icons.payments,
        'savings' => Icons.account_balance,
        'crypto' => Icons.currency_bitcoin,
        _ => Icons.account_balance_wallet,
      };
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: 161,
          height: 94,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 25,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.black, size: 22),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _labelsSecondary,
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
              height: 1.38,
              letterSpacing: -0.08,
            ),
          ),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
              height: 1.29,
              letterSpacing: -0.43,
            ),
          ),
        ],
      ),
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
    final Color amountColor = isIncome
        ? _accentGreen
        : isTransfer
            ? _accentBlue
            : _accentRed;
    final String sign = isIncome ? '+' : (isTransfer ? '' : '-');
    final String title =
        category?.name ?? (isIncome ? 'Доход' : (isTransfer ? 'Перевод' : 'Расход'));
    final String subtitle = _subtitle();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1F000000), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TransactionIcon(iconForName(category?.icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                    height: 1.29,
                    letterSpacing: -0.43,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x7F6B6B6B),
                    fontSize: 15,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                    height: 1.33,
                    letterSpacing: -0.23,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${Money.formatRub(transaction.amountKopecks)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: amountColor,
              fontSize: 20,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: -0.45,
            ),
          ),
        ],
      ),
    ),
      ),
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
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return '${_two(dt.day)}.${_two(dt.month)}.${dt.year}';
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';
}

class _TransactionIcon extends StatelessWidget {
  const _TransactionIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0x14000000),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.black, size: 20),
    );
  }
}
