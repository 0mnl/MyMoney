import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_providers.dart';
import '../../sync/sync_scheduler.dart';
import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'analytics_screen.dart';
import 'budgets_screen.dart';
import 'debts_screen.dart';
import 'family_screen.dart';
import 'goals_screen.dart';
import 'home_tab.dart';
import 'settings_screen.dart';
import 'subscriptions_screen.dart';
import 'transactions_screen.dart';

/// Индекс выбранной вкладки. Вынесен в провайдер, чтобы отдельные экраны
/// (например, «Все» / карточки счетов на главной, пункты меню в настройках)
/// могли переключать таб без пробрасывания колбэков.
final homeShellTabProvider = StateProvider<int>((_) => 0);

/// Root scaffold with a bottom navigation. Settings tab hosts backend/sync/family
/// setup (Etap 4). A floating action button opens the central UC-03/UC-04
/// "Add Transaction" flow (Bible § 8, ≤ 3 steps).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _tabs = <Widget>[
    HomeTab(),
    AccountsScreen(),
    TransactionsScreen(),
    BudgetsScreen(),
    GoalsScreen(),
    DebtsScreen(),
    SubscriptionsScreen(),
    AnalyticsScreen(),
    FamilyScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Keep the scheduler alive while the shell is on screen. It only starts
    // once regardless of how many times this build fires (see start() guard).
    ref.listen(syncSchedulerProvider, (_, next) {
      next.whenData((s) => s.start());
    });
    ref.watch(syncSchedulerProvider);

    final index = ref.watch(homeShellTabProvider);

    return Scaffold(
      body: Column(
        children: [
          const _SyncStatusBar(),
          Expanded(child: IndexedStack(index: index, children: _tabs)),
        ],
      ),
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
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(homeShellTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Счета'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Операции'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Бюджет'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Цели'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Долги'),
          NavigationDestination(icon: Icon(Icons.autorenew_outlined), selectedIcon: Icon(Icons.autorenew), label: 'Подписки'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Статистика'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Семья'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}

/// Slim strip at the top: shown only when sync is not idle. Идея — не мешать
/// нормальному использованию, но показать состояние если что-то не так.
class _SyncStatusBar extends ConsumerWidget {
  const _SyncStatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(syncStatusProvider);
    final status = async.value;
    if (status == null || status.phase == SyncPhase.idle) {
      return const SizedBox.shrink();
    }
    final (bg, fg, icon, label) = switch (status.phase) {
      SyncPhase.syncing => (
          Colors.blue.shade50,
          Colors.blue.shade900,
          Icons.sync,
          'Синхронизация...',
        ),
      SyncPhase.offline => (
          Colors.grey.shade200,
          Colors.grey.shade800,
          Icons.cloud_off,
          'Нет соединения',
        ),
      SyncPhase.error => (
          Colors.orange.shade50,
          Colors.orange.shade900,
          Icons.warning_amber_rounded,
          'Ошибка синхронизации',
        ),
      SyncPhase.idle => (Colors.transparent, Colors.transparent, Icons.check, ''),
    };
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: fg)),
          ],
        ),
      ),
    );
  }
}
