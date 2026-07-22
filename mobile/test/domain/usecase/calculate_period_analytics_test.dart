import 'package:flutter_test/flutter_test.dart';
import 'package:mymoney/domain/model/budget.dart';
import 'package:mymoney/domain/model/category.dart';
import 'package:mymoney/domain/model/enums.dart';
import 'package:mymoney/domain/model/transaction.dart';
import 'package:mymoney/domain/repository/budget_repository.dart';
import 'package:mymoney/domain/repository/category_repository.dart';
import 'package:mymoney/domain/repository/transaction_repository.dart';
import 'package:mymoney/domain/usecase/calculate_period_analytics.dart';

class _StubTransactionRepo implements TransactionRepository {
  _StubTransactionRepo(this._items);
  final List<Transaction> _items;

  @override
  Future<void> create(Transaction transaction) async {}

  @override
  Future<Transaction?> findById(String id) async =>
      _items.where((t) => t.id == id).cast<Transaction?>().firstOrNull;

  @override
  Future<List<Transaction>> listByFamily(
    String familyId, {
    String? accountId,
    int limit = 200,
  }) async =>
      _items.where((t) => t.familyId == familyId).toList();

  @override
  Future<void> update(Transaction transaction) async {}

  @override
  Future<void> softDelete(String id) async {}

  @override
  Stream<List<Transaction>> watchByFamily(String familyId) =>
      Stream.value(_items);
}

class _StubBudgetRepo implements BudgetRepository {
  _StubBudgetRepo(this._items);
  final List<Budget> _items;

  @override
  Future<void> create(Budget budget) async {}

  @override
  Future<Budget?> findById(String id) async =>
      _items.where((b) => b.id == id).cast<Budget?>().firstOrNull;

  @override
  Future<List<Budget>> listByFamily(String familyId) async =>
      _items.where((b) => b.familyId == familyId).toList();

  @override
  Future<void> update(Budget budget) async {}

  @override
  Future<void> softDelete(String id) async {}

  @override
  Stream<List<Budget>> watchByFamily(String familyId) => Stream.value(_items);
}

class _StubCategoryRepo implements CategoryRepository {
  _StubCategoryRepo(this._items);
  final List<Category> _items;

  @override
  Future<void> create(Category category) async {}

  @override
  Future<Category?> findById(String id) async =>
      _items.where((c) => c.id == id).cast<Category?>().firstOrNull;

  @override
  Future<List<Category>> listByFamily(
    String familyId, {
    CategoryType? type,
    bool includeArchived = false,
  }) async =>
      _items.where((c) => c.familyId == familyId).toList();

  @override
  Future<void> update(Category category) async {}

  @override
  Future<void> softDelete(String id) async {}

  @override
  Stream<List<Category>> watchByFamily(String familyId) => Stream.value(_items);
}

Category _cat(String id, {CategoryType type = CategoryType.expense}) => Category(
      id: id,
      familyId: 'f1',
      name: id,
      type: type,
      icon: null,
      color: '4CAF50',
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );

Transaction _tx({
  required String id,
  required TransactionType type,
  required int amount,
  String? categoryId,
  String? targetAccountId,
  DateTime? occurredAt,
  bool isDeleted = false,
}) =>
    Transaction(
      id: id,
      familyId: 'f1',
      accountId: 'a1',
      categoryId: categoryId,
      type: type,
      targetAccountId: targetAccountId,
      amountKopecks: amount,
      occurredAt: occurredAt ?? DateTime.utc(2026, 7, 15),
      createdBy: 'u1',
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
      isDeleted: isDeleted,
    );

void main() {
  const familyId = 'f1';
  final start = DateTime.utc(2026, 7, 1);
  final end = DateTime.utc(2026, 8, 1);

  group('CalculatePeriodAnalytics', () {
    test('пустой период — нулевые суммы, без категорий', () async {
      final uc = CalculatePeriodAnalytics(
        _StubTransactionRepo(const []),
        _StubBudgetRepo(const []),
        _StubCategoryRepo(const []),
      );

      final r = await uc(
        familyId: familyId,
        periodStart: start,
        periodEnd: end,
      );

      expect(r.totalIncomeKopecks, 0);
      expect(r.totalExpenseKopecks, 0);
      expect(r.categoryBreakdown, isEmpty);
    });

    test('считает доход и расход отдельно', () async {
      final uc = CalculatePeriodAnalytics(
        _StubTransactionRepo([
          _tx(id: 't1', type: TransactionType.expense, amount: 50000, categoryId: 'food'),
          _tx(id: 't2', type: TransactionType.income, amount: 100000),
        ]),
        _StubBudgetRepo(const []),
        _StubCategoryRepo([_cat('food')]),
      );

      final r = await uc(familyId: familyId, periodStart: start, periodEnd: end);
      expect(r.totalIncomeKopecks, 100000);
      expect(r.totalExpenseKopecks, 50000);
    });

    test('группирует расходы по категории и считает процент', () async {
      final uc = CalculatePeriodAnalytics(
        _StubTransactionRepo([
          _tx(id: 't1', type: TransactionType.expense, amount: 30000, categoryId: 'food'),
          _tx(id: 't2', type: TransactionType.expense, amount: 20000, categoryId: 'transport'),
          _tx(id: 't3', type: TransactionType.expense, amount: 10000, categoryId: 'food'),
        ]),
        _StubBudgetRepo(const []),
        _StubCategoryRepo([_cat('food'), _cat('transport')]),
      );

      final r = await uc(familyId: familyId, periodStart: start, periodEnd: end);
      expect(r.totalExpenseKopecks, 60000);
      expect(r.categoryBreakdown['food']?.totalKopecks, 40000);
      expect(r.categoryBreakdown['transport']?.totalKopecks, 20000);
      expect(
        r.categoryBreakdown['food']?.percentageOfTotal,
        closeTo(66.67, 0.01),
      );
    });

    test('исключает удалённые транзакции', () async {
      final uc = CalculatePeriodAnalytics(
        _StubTransactionRepo([
          _tx(id: 't1', type: TransactionType.expense, amount: 50000, categoryId: 'food'),
          _tx(id: 't2', type: TransactionType.expense, amount: 30000, categoryId: 'food', isDeleted: true),
        ]),
        _StubBudgetRepo(const []),
        _StubCategoryRepo([_cat('food')]),
      );

      final r = await uc(familyId: familyId, periodStart: start, periodEnd: end);
      expect(r.totalExpenseKopecks, 50000);
    });

    test('исключает транзакции вне периода', () async {
      final uc = CalculatePeriodAnalytics(
        _StubTransactionRepo([
          _tx(id: 't1', type: TransactionType.expense, amount: 50000, categoryId: 'food'),
          _tx(
            id: 't2',
            type: TransactionType.expense,
            amount: 30000,
            categoryId: 'food',
            occurredAt: DateTime.utc(2026, 8, 5),
          ),
        ]),
        _StubBudgetRepo(const []),
        _StubCategoryRepo([_cat('food')]),
      );

      final r = await uc(familyId: familyId, periodStart: start, periodEnd: end);
      expect(r.totalExpenseKopecks, 50000);
    });

    test('переводы не влияют на totals', () async {
      final uc = CalculatePeriodAnalytics(
        _StubTransactionRepo([
          _tx(
            id: 't1',
            type: TransactionType.transfer,
            amount: 10000,
            targetAccountId: 'a2',
          ),
        ]),
        _StubBudgetRepo(const []),
        _StubCategoryRepo(const []),
      );

      final r = await uc(familyId: familyId, periodStart: start, periodEnd: end);
      expect(r.totalIncomeKopecks, 0);
      expect(r.totalExpenseKopecks, 0);
    });
  });
}
