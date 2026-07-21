import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'analytics_screen.dart';
import 'budgets_screen.dart';
import 'debts_screen.dart';
import 'goals_screen.dart';
import 'home_tab.dart';
import 'settings_screen.dart';
import 'subscriptions_screen.dart';
import 'transactions_screen.dart';

/// Root scaffold with a bottom navigation. Settings tab hosts backend/sync/family
/// setup (Etap 4). A floating action button opens the central UC-03/UC-04
/// "Add Transaction" flow (Bible § 8, ≤ 3 steps).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    HomeTab(),
    AccountsScreen(),
    TransactionsScreen(),
    BudgetsScreen(),
    GoalsScreen(),
    DebtsScreen(),
    SubscriptionsScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddTransactionScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Операция'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Счета'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Операции'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Бюджет'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Цели'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Долги'),
          NavigationDestination(icon: Icon(Icons.autorenew_outlined), selectedIcon: Icon(Icons.autorenew), label: 'Подписки'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Статистика'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}
