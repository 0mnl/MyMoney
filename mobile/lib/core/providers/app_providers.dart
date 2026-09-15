import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/isar_service.dart';
import '../../data/local/seed_data.dart';
import '../../data/repository/local_account_repository.dart';
import '../../data/repository/local_budget_repository.dart';
import '../../data/repository/local_category_repository.dart';
import '../../data/repository/local_debt_payment_repository.dart';
import '../../data/repository/local_debt_repository.dart';
import '../../data/repository/local_goal_repository.dart';
import '../../data/repository/local_subscription_repository.dart';
import '../../data/repository/local_transaction_repository.dart';
import '../../domain/model/account.dart';
import '../../domain/model/budget.dart';
import '../../domain/model/category.dart';
import '../../domain/model/debt.dart';
import '../../domain/model/goal.dart';
import '../../domain/model/subscription.dart';
import '../../domain/model/transaction.dart';
import '../../domain/repository/account_repository.dart';
import '../../domain/repository/budget_repository.dart';
import '../../domain/repository/category_repository.dart';
import '../../domain/repository/debt_payment_repository.dart';
import '../../domain/repository/debt_repository.dart';
import '../../domain/repository/goal_repository.dart';
import '../../domain/repository/subscription_repository.dart';
import '../../domain/repository/transaction_repository.dart';

/// Fake single-user context for Etap 1 — no auth yet on the client.
/// The values are generated once and persisted so the same familyId is used
/// across app restarts. When Etap 4 wires the backend, `LocalSession` is
/// replaced by whatever JWT decoding gives us.
class LocalSession {
  const LocalSession({required this.userId, required this.familyId});
  final String userId;
  final String familyId;
}

final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

final isarServiceProvider = FutureProvider<IsarService>((ref) async {
  final service = await IsarService.open();
  ref.onDispose(() async {
    await service.close();
  });
  return service;
});

/// Bootstraps the local session and seeds default data on first launch.
final bootstrapProvider = FutureProvider<LocalSession>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final isarService = await ref.watch(isarServiceProvider.future);
  final isar = isarService.isar;

  const uuid = Uuid();
  final userId = prefs.getString('userId') ?? uuid.v4();
  final familyId = prefs.getString('familyId') ?? uuid.v4();
  final seeded = prefs.getBool('seeded') ?? false;

  await prefs.setString('userId', userId);
  await prefs.setString('familyId', familyId);

  if (!seeded) {
    final now = DateTime.now().toUtc();
    final categoryRepo = LocalCategoryRepository(isar);
    for (final c in SystemCategoriesCatalog.buildFor(familyId, now)) {
      await categoryRepo.create(c);
    }
    final accountRepo = LocalAccountRepository(isar);
    await accountRepo.create(SystemCategoriesCatalog.defaultAccount(familyId, now));
    await prefs.setBool('seeded', true);
  }

  await isarService.purgeOldSoftDeleted();

  return LocalSession(userId: userId, familyId: familyId);
});

final accountRepositoryProvider = FutureProvider<AccountRepository>((ref) async {
  final s = await ref.watch(isarServiceProvider.future);
  return LocalAccountRepository(s.isar);
});

final categoryRepositoryProvider = FutureProvider<CategoryRepository>((ref) async {
  final s = await ref.watch(isarServiceProvider.future);
  return LocalCategoryRepository(s.isar);
});

final transactionRepositoryProvider = FutureProvider<TransactionRepository>((ref) async {
  final s = await ref.watch(isarServiceProvider.future);
  return LocalTransactionRepository(s.isar);
});

final budgetRepositoryProvider = FutureProvider<BudgetRepository>((ref) async {
  final s = await ref.watch(isarServiceProvider.future);
  return LocalBudgetRepository(s.isar);
});

final goalRepositoryProvider = FutureProvider<GoalRepository>((ref) async {
  final s = await ref.watch(isarServiceProvider.future);
  return LocalGoalRepository(s.isar);
});

final debtRepositoryProvider = FutureProvider<DebtRepository>((ref) async {
  final s = await ref.watch(isarServiceProvider.future);
  return LocalDebtRepository(s.isar);
});

final debtPaymentRepositoryProvider =
    FutureProvider<DebtPaymentRepository>((ref) async {
  final s = await ref.watch(isarServiceProvider.future);
  return LocalDebtPaymentRepository(s.isar);
});

final subscriptionRepositoryProvider = FutureProvider<SubscriptionRepository>((ref) async {
  final s = await ref.watch(isarServiceProvider.future);
  return LocalSubscriptionRepository(s.isar);
});

/// Live streams — presentation subscribes to these, so any Isar write from
/// anywhere immediately updates every screen.
final accountsStreamProvider = StreamProvider<List<Account>>((ref) async* {
  final session = await ref.watch(bootstrapProvider.future);
  final repo = await ref.watch(accountRepositoryProvider.future);
  yield* repo.watchByFamily(session.familyId);
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) async* {
  final session = await ref.watch(bootstrapProvider.future);
  final repo = await ref.watch(categoryRepositoryProvider.future);
  yield* repo.watchByFamily(session.familyId);
});

final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) async* {
  final session = await ref.watch(bootstrapProvider.future);
  final repo = await ref.watch(transactionRepositoryProvider.future);
  yield* repo.watchByFamily(session.familyId);
});

final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) async* {
  final session = await ref.watch(bootstrapProvider.future);
  final repo = await ref.watch(budgetRepositoryProvider.future);
  yield* repo.watchByFamily(session.familyId);
});

final goalsStreamProvider = StreamProvider<List<Goal>>((ref) async* {
  final session = await ref.watch(bootstrapProvider.future);
  final repo = await ref.watch(goalRepositoryProvider.future);
  yield* repo.watchByFamily(session.familyId);
});

final debtsStreamProvider = StreamProvider<List<Debt>>((ref) async* {
  final session = await ref.watch(bootstrapProvider.future);
  final repo = await ref.watch(debtRepositoryProvider.future);
  yield* repo.watchByFamily(session.familyId);
});

final subscriptionsStreamProvider = StreamProvider<List<Subscription>>((ref) async* {
  final session = await ref.watch(bootstrapProvider.future);
  final repo = await ref.watch(subscriptionRepositoryProvider.future);
  yield* repo.watchByFamily(session.familyId);
});

/// График платежей конкретного долга. `family`-провайдер, а не общий поток:
/// график открывают по одному долгу за раз, и подписываться на все сразу
/// значило бы держать в памяти лишнее.
final debtPaymentsStreamProvider =
    StreamProvider.family<List<DebtPayment>, String>((ref, debtId) async* {
  final repo = await ref.watch(debtPaymentRepositoryProvider.future);
  yield* repo.watchByDebt(debtId);
});
