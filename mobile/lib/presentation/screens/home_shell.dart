import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_transaction_screen.dart';
import 'budgets_screen.dart';
import 'home_tab.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

final homeShellTabProvider = StateProvider<int>((_) => 0);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _tabs = <Widget>[
    HomeTab(),
    TransactionsScreen(),
    BudgetsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(homeShellTabProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: _FigmaBottomNav(
        selectedIndex: index,
        onTabSelected: (i) => ref.read(homeShellTabProvider.notifier).state = i,
        onAddPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddTransactionScreen()),
          );
        },
      ),
    );
  }
}

// ─── Custom bottom nav matching Figma design ────────────────────────────────

class _FigmaBottomNav extends StatelessWidget {
  const _FigmaBottomNav({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onAddPressed,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;

  static const _activeColor = Color(0xFF0088FF);
  static const _inactiveColor = Color(0xFF1A1A1A);
  static const _pillBg = Color(0x33F8F8F8);
  static const _pillShadows = [
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 15,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0xFFE8E8E8),
      blurRadius: 0,
      spreadRadius: 0.5,
    ),
  ];

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Главная'),
    (Icons.list_alt_outlined, Icons.list_alt, 'Операции'),
    (Icons.pie_chart_outline, Icons.pie_chart, 'Бюджет'),
    (Icons.settings_outlined, Icons.settings, 'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        top: 16,
        left: 25,
        right: 25,
        bottom: 25 + bottomPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Pill with 4 tabs
          Expanded(
            child: Container(
              height: 62,
              decoration: const BoxDecoration(
                color: _pillBg,
                borderRadius: BorderRadius.all(Radius.circular(1000)),
                boxShadow: _pillShadows,
              ),
              child: Row(
                children: List.generate(_items.length, (i) {
                  final (outlinedIcon, filledIcon, label) = _items[i];
                  final isActive = i == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTabSelected(i),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: isActive
                            ? const BoxDecoration(
                                color: _activeColor,
                                borderRadius: BorderRadius.all(Radius.circular(100)),
                              )
                            : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActive ? filledIcon : outlinedIcon,
                              size: 20,
                              color: isActive ? Colors.white : _inactiveColor,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.white : _inactiveColor,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Circular add button
          GestureDetector(
            onTap: onAddPressed,
            child: Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: _pillBg,
                shape: BoxShape.circle,
                boxShadow: _pillShadows,
              ),
              child: const Icon(
                Icons.add,
                size: 24,
                color: _inactiveColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

