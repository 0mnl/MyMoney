import 'package:flutter_test/flutter_test.dart';
import 'package:mymoney/domain/model/analytics.dart';
import 'package:mymoney/domain/model/enums.dart';
import 'package:mymoney/domain/model/transaction.dart';
import 'package:mymoney/domain/model/category.dart';
import 'package:mymoney/domain/model/budget.dart';
import 'package:mymoney/domain/usecase/calculate_period_analytics.dart';

/// Mock repository implementations for testing
class MockTransactionRepository implements TransactionRepository {
  final List<Transaction> _transactions;

  MockTransactionRepository(this._transactions);

  @override
  Future<List<Transaction>> listByFamily(String familyId) async =>
      _transactions;

  @override
  Future<Transaction> create(Transaction tx) async => tx;

  @override
  Future<void> update(Transaction tx) async {}

  @override
  Future<void> softDelete(String id) async {}
}

class MockBudgetRepository implements BudgetRepository {
  final List<Budget> _budgets;

  MockBudgetRepository(this._budgets);

  @override
  Future<List<Budget>> listByFamily(String familyId) async => _budgets;

  @override
  Future<Budget> create(Budget budget) async => budget;

  @override
  Future<void> update(Budget budget) async {}

  @override
  Future<void> softDelete(String id) async {}
}

class MockCategoryRepository implements CategoryRepository {
  final List<Category> _categories;

  MockCategoryRepository(this._categories);

  @override
  Future<List<Category>> listByFamily(String familyId) async => _categories;
}

void main() {
  group('CalculatePeriodAnalytics', () {
    late MockTransactionRepository txRepo;
    late MockBudgetRepository budgetRepo;
    late MockCategoryRepository categoryRepo;
    late CalculatePeriodAnalytics usecase;

    setUp(() {
      txRepo = MockTransactionRepository([]);
      budgetRepo = MockBudgetRepository([]);
      categoryRepo = MockCategoryRepository([]);
      usecase = CalculatePeriodAnalytics(txRepo, budgetRepo, categoryRepo);
    });

    test('empty period returns zero totals', () async {
      final start = DateTime.utc(2026, 7, 1);
      final end = DateTime.utc(2026, 8, 1);

      final result = await usecase(
        familyId: 'f1',
        periodStart: start,
        periodEnd: end,
      );

      expect(result.totalIncomeKopecks, 0);
      expect(result.totalExpenseKopecks, 0);
      expect(result.categoryBreakdown.isEmpty, true);
    });

    test('counts only expense transactions in period', () async {
      final start = DateTime.utc(2026, 7, 1);
      final end = DateTime.utc(2026, 8, 1);

      final transactions = [
        Transaction(
          id: 't1',
          familyId: 'f1',
          accountId: 'a1',
          categoryId: 'food',
          type: TransactionType.expense,
          amountKopecks: 50000,
          occurredAt: DateTime.utc(2026, 7, 15),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
        ),
        Transaction(
          id: 't2',
          familyId: 'f1',
          accountId: 'a1',
          categoryId: 'food',
          type: TransactionType.income,
          amountKopecks: 100000,
          occurredAt: DateTime.utc(2026, 7, 20),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
        ),
      ];

      final categories = [
        Category(
          id: 'food',
          familyId: 'f1',
          name: 'Продукты',
          type: CategoryType.expense,
          isSystem: true,
          isArchived: false,
          icon: '🍔',
          color: 0xFF4CAF50,
          createdAt: start,
          updatedAt: start,
        ),
      ];

      txRepo = MockTransactionRepository(transactions);
      categoryRepo = MockCategoryRepository(categories);
      usecase = CalculatePeriodAnalytics(txRepo, budgetRepo, categoryRepo);

      final result = await usecase(
        familyId: 'f1',
        periodStart: start,
        periodEnd: end,
      );

      expect(result.totalIncomeKopecks, 100000);
      expect(result.totalExpenseKopecks, 50000);
      expect(result.netKopecks, 50000);
    });

    test('groups expenses by category correctly', () async {
      final start = DateTime.utc(2026, 7, 1);
      final end = DateTime.utc(2026, 8, 1);

      final transactions = [
        Transaction(
          id: 't1',
          familyId: 'f1',
          accountId: 'a1',
          categoryId: 'food',
          type: TransactionType.expense,
          amountKopecks: 30000,
          occurredAt: DateTime.utc(2026, 7, 10),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
        ),
        Transaction(
          id: 't2',
          familyId: 'f1',
          accountId: 'a1',
          categoryId: 'transport',
          type: TransactionType.expense,
          amountKopecks: 20000,
          occurredAt: DateTime.utc(2026, 7, 15),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
        ),
        Transaction(
          id: 't3',
          familyId: 'f1',
          accountId: 'a1',
          categoryId: 'food',
          type: TransactionType.expense,
          amountKopecks: 10000,
          occurredAt: DateTime.utc(2026, 7, 20),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
        ),
      ];

      final categories = [
        Category(
          id: 'food',
          familyId: 'f1',
          name: 'Продукты',
          type: CategoryType.expense,
          isSystem: true,
          isArchived: false,
          icon: '🍔',
          color: 0xFF4CAF50,
          createdAt: start,
          updatedAt: start,
        ),
        Category(
          id: 'transport',
          familyId: 'f1',
          name: 'Транспорт',
          type: CategoryType.expense,
          isSystem: true,
          isArchived: false,
          icon: '🚌',
          color: 0xFF2196F3,
          createdAt: start,
          updatedAt: start,
        ),
      ];

      txRepo = MockTransactionRepository(transactions);
      categoryRepo = MockCategoryRepository(categories);
      usecase = CalculatePeriodAnalytics(txRepo, budgetRepo, categoryRepo);

      final result = await usecase(
        familyId: 'f1',
        periodStart: start,
        periodEnd: end,
      );

      expect(result.totalExpenseKopecks, 60000);
      expect(result.categoryBreakdown['food']?.totalKopecks, 40000);
      expect(result.categoryBreakdown['transport']?.totalKopecks, 20000);
      expect(result.categoryBreakdown['food']?.percentageOfTotal, 66.666666666);
      expect(result.categoryBreakdown['transport']?.percentageOfTotal, 33.333333333);
    });

    test('excludes deleted transactions', () async {
      final start = DateTime.utc(2026, 7, 1);
      final end = DateTime.utc(2026, 8, 1);

      final transactions = [
        Transaction(
          id: 't1',
          familyId: 'f1',
          accountId: 'a1',
          categoryId: 'food',
          type: TransactionType.expense,
          amountKopecks: 50000,
          occurredAt: DateTime.utc(2026, 7, 15),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
          isDeleted: false,
        ),
        Transaction(
          id: 't2',
          familyId: 'f1',
          accountId: 'a1',
          categoryId: 'food',
          type: TransactionType.expense,
          amountKopecks: 30000,
          occurredAt: DateTime.utc(2026, 7, 20),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
          isDeleted: true,
        ),
      ];

      final categories = [
        Category(
          id: 'food',
          familyId: 'f1',
          name: 'Продукты',
          type: CategoryType.expense,
          isSystem: true,
          isArchived: false,
          icon: '🍔',
          color: 0xFF4CAF50,
          createdAt: start,
          updatedAt: start,
        ),
      ];

      txRepo = MockTransactionRepository(transactions);
      categoryRepo = MockCategoryRepository(categories);
      usecase = CalculatePeriodAnalytics(txRepo, budgetRepo, categoryRepo);

      final result = await usecase(
        familyId: 'f1',
        periodStart: start,
        periodEnd: end,
      );

      expect(result.totalExpenseKopecks, 50000);
    });

    test('excludes transactions outside period', () async {
      final start = DateTime.utc(2026, 7, 1);
      final end = DateTime.utc(2026, 8, 1);

      final transactions = [
        Transaction(
          id: 't1',
          familyId: 'f1',
          accountId: 'a1',
          categoryId: 'food',
          type: TransactionType.expense,
          amountKopecks: 50000,
          occurredAt: DateTime.utc(2026, 7, 15),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
        ),
        Transaction(
          id: 't2',
          familyId: 'f1',
          accountId: 'a1',
          categoryId: 'food',
          type: TransactionType.expense,
          amountKopecks: 30000,
          occurredAt: DateTime.utc(2026, 8, 5),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
        ),
      ];

      final categories = [
        Category(
          id: 'food',
          familyId: 'f1',
          name: 'Продукты',
          type: CategoryType.expense,
          isSystem: true,
          isArchived: false,
          icon: '🍔',
          color: 0xFF4CAF50,
          createdAt: start,
          updatedAt: start,
        ),
      ];

      txRepo = MockTransactionRepository(transactions);
      categoryRepo = MockCategoryRepository(categories);
      usecase = CalculatePeriodAnalytics(txRepo, budgetRepo, categoryRepo);

      final result = await usecase(
        familyId: 'f1',
        periodStart: start,
        periodEnd: end,
      );

      expect(result.totalExpenseKopecks, 50000);
    });

    test('transfers do not contribute to income/expense totals', () async {
      final start = DateTime.utc(2026, 7, 1);
      final end = DateTime.utc(2026, 8, 1);

      final transactions = [
        Transaction(
          id: 't1',
          familyId: 'f1',
          accountId: 'a1',
          type: TransactionType.transfer,
          targetAccountId: 'a2',
          amountKopecks: 10000,
          occurredAt: DateTime.utc(2026, 7, 15),
          createdBy: 'u1',
          createdAt: start,
          updatedAt: start,
        ),
      ];

      txRepo = MockTransactionRepository(transactions);
      usecase = CalculatePeriodAnalytics(txRepo, budgetRepo, categoryRepo);

      final result = await usecase(
        familyId: 'f1',
        periodStart: start,
        periodEnd: end,
      );

      expect(result.totalIncomeKopecks, 0);
      expect(result.totalExpenseKopecks, 0);
    });
  });
}
