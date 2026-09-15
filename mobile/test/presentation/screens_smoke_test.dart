import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mymoney/core/providers/api_providers.dart';
import 'package:mymoney/core/providers/app_providers.dart';
import 'package:mymoney/data/remote/auth_store.dart';
import 'package:mymoney/domain/model/account.dart';
import 'package:mymoney/domain/model/analytics.dart';
import 'package:mymoney/domain/model/budget.dart';
import 'package:mymoney/domain/model/category.dart';
import 'package:mymoney/domain/model/debt.dart';
import 'package:mymoney/domain/model/enums.dart';
import 'package:mymoney/domain/model/goal.dart';
import 'package:mymoney/domain/model/subscription.dart';
import 'package:mymoney/domain/model/transaction.dart';
import 'package:mymoney/domain/usecase/debt_schedule.dart';
import 'package:mymoney/presentation/providers/analytics_providers.dart';
import 'package:mymoney/presentation/screens/accounts_screen.dart';
import 'package:mymoney/presentation/screens/add_transaction_screen.dart';
import 'package:mymoney/presentation/screens/analytics_screen.dart';
import 'package:mymoney/presentation/screens/budgets_screen.dart';
import 'package:mymoney/presentation/screens/categories_screen.dart';
import 'package:mymoney/presentation/screens/debt_schedule_screen.dart';
import 'package:mymoney/presentation/screens/debts_screen.dart';
import 'package:mymoney/presentation/screens/goals_screen.dart';
import 'package:mymoney/presentation/screens/home_tab.dart';
import 'package:mymoney/presentation/screens/profile_screen.dart';
import 'package:mymoney/presentation/screens/settings_screen.dart';
import 'package:mymoney/presentation/screens/subscriptions_screen.dart';
import 'package:mymoney/presentation/screens/transactions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Дымовые тесты экранов: каждый должен отрисоваться и с данными, и на пустой
/// базе. Ловят ровно то, что не видит `flutter analyze`, — падение в `build`,
/// переполнение по ширине и обращение к провайдеру, который на экране не
/// переопределён.
/// Сессии в тестах нет: `AuthStore` лезет в secure storage, которого на
/// тестовой платформе не существует.
class _NoSessionAuthNotifier extends AuthSnapshotNotifier {
  @override
  Future<AuthSnapshot?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final now = DateTime.utc(2026, 8, 20, 12);

  final account = Account(
    id: 'acc',
    familyId: 'fam',
    name: 'Карта',
    type: 'card',
    initialBalanceKopecks: 500000,
    creditLimitKopecks: 1000000,
    createdAt: now,
    updatedAt: now,
  );

  final category = Category(
    id: 'cat',
    familyId: 'fam',
    name: 'Продукты',
    type: CategoryType.expense,
    icon: 'shopping_cart',
    createdAt: now,
    updatedAt: now,
  );

  final transaction = Transaction(
    id: 'tx',
    familyId: 'fam',
    accountId: 'acc',
    categoryId: 'cat',
    type: TransactionType.expense,
    amountKopecks: 123456,
    occurredAt: now,
    comment: 'Ужин',
    createdBy: 'user',
    createdAt: now,
    updatedAt: now,
  );

  final budget = Budget(
    id: 'bud',
    familyId: 'fam',
    categoryId: 'cat',
    periodType: BudgetPeriodType.month,
    periodStart: DateTime.utc(2026, 8),
    plannedAmountKopecks: 300000,
    createdAt: now,
    updatedAt: now,
  );

  final goal = Goal(
    id: 'goal',
    familyId: 'fam',
    name: 'Отпуск',
    targetAmountKopecks: 5000000,
    currentAmountKopecks: 1500000,
    targetDate: DateTime.utc(2026, 12, 31),
    createdAt: now,
    updatedAt: now,
  );

  final debt = Debt(
    id: 'debt',
    familyId: 'fam',
    counterpartyName: 'Банк',
    direction: DebtDirection.iOwe,
    amountKopecks: 10000000,
    interestRate: 12,
    dueDate: DateTime.utc(2027),
    createdAt: now,
    updatedAt: now,
  );

  final subscription = Subscription(
    id: 'sub',
    familyId: 'fam',
    name: 'Музыка',
    amountKopecks: 29900,
    billingPeriod: SubscriptionPeriod.monthly,
    nextChargeDate: DateTime.utc(2026, 9),
    createdAt: now,
    updatedAt: now,
  );

  final analytics = PeriodAnalytics(
    periodStart: DateTime.utc(2026, 8),
    periodEnd: DateTime.utc(2026, 9),
    totalIncomeKopecks: 8000000,
    totalExpenseKopecks: 123456,
    categoryBreakdown: {
      'cat': const CategorySpend(
        categoryId: 'cat',
        categoryName: 'Продукты',
        totalKopecks: 123456,
        percentageOfTotal: 100,
      ),
    },
    budgetComparison: {
      'cat': const CategoryBudgetComparison(
        categoryId: 'cat',
        categoryName: 'Продукты',
        plannedKopecks: 300000,
        actualKopecks: 123456,
      ),
    },
  );

  final payments = buildDebtSchedule(
    debt: debt,
    months: 6,
    firstDueDate: DateTime.utc(2026, 9),
  );

  /// Один и тот же набор переопределений на все экраны: так тест не зависит от
  /// того, какие именно потоки читает конкретный экран сегодня.
  List<Override> overrides({required bool withData}) => [
        bootstrapProvider.overrideWith(
          (ref) async => const LocalSession(userId: 'user', familyId: 'fam'),
        ),
        accountsStreamProvider.overrideWith(
          (ref) => Stream.value(withData ? [account] : const <Account>[]),
        ),
        categoriesStreamProvider.overrideWith(
          (ref) => Stream.value(withData ? [category] : const <Category>[]),
        ),
        transactionsStreamProvider.overrideWith(
          (ref) => Stream.value(withData ? [transaction] : const <Transaction>[]),
        ),
        budgetsStreamProvider.overrideWith(
          (ref) => Stream.value(withData ? [budget] : const <Budget>[]),
        ),
        goalsStreamProvider.overrideWith(
          (ref) => Stream.value(withData ? [goal] : const <Goal>[]),
        ),
        debtsStreamProvider.overrideWith(
          (ref) => Stream.value(withData ? [debt] : const <Debt>[]),
        ),
        subscriptionsStreamProvider.overrideWith(
          (ref) => Stream.value(
            withData ? [subscription] : const <Subscription>[],
          ),
        ),
        debtPaymentsStreamProvider.overrideWith(
          (ref, debtId) => Stream.value(
            withData ? payments : const <DebtPayment>[],
          ),
        ),
        periodAnalyticsProvider.overrideWith((ref) async => analytics),
        authSnapshotProvider.overrideWith(_NoSessionAuthNotifier.new),
        sharedPrefsProvider.overrideWith(
          (ref) => SharedPreferences.getInstance(),
        ),
      ];

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required bool withData,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(withData: withData),
        child: MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Табы рисуются внутри `HomeShell`, у которого есть Scaffold —
          // здесь он нужен по той же причине: снекбары и модальные листы.
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final screens = <String, Widget>{
    'Главная': const HomeTab(),
    'Операции': const TransactionsScreen(),
    'Бюджет': const BudgetsScreen(),
    'Счета': const AccountsScreen(),
    'Категории': const CategoriesScreen(),
    'Цели': const GoalsScreen(),
    'Долги': const DebtsScreen(),
    'Подписки': const SubscriptionsScreen(),
    'Статистика': const AnalyticsScreen(),
    'Новая операция': const AddTransactionScreen(),
    'Настройки': const SettingsScreen(),
    'Профиль': const ProfileScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key}: рисуется с данными', (tester) async {
      await pump(tester, entry.value, withData: true);
      expect(tester.takeException(), isNull);
      expect(find.text(entry.key), findsWidgets);
    });

    testWidgets('${entry.key}: рисуется на пустой базе', (tester) async {
      await pump(tester, entry.value, withData: false);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('График платежей: рисуется с данными', (tester) async {
    await pump(tester, DebtScheduleScreen(debt: debt), withData: true);
    expect(tester.takeException(), isNull);
    expect(find.text('График платежей'), findsWidgets);
  });

  testWidgets('График платежей: пустой график предлагает создать',
      (tester) async {
    await pump(tester, DebtScheduleScreen(debt: debt), withData: false);
    expect(tester.takeException(), isNull);
    expect(find.text('Создать график'), findsOneWidget);
  });
}
