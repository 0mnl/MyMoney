import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/budget.dart';
import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';
import '../../domain/model/money.dart';
import '../../domain/usecase/budget_progress.dart';

/// Список бюджетов + прогресс за период. Каждая карточка сразу показывает
/// на сколько уже потрачено — цель UI Этапа 2 (Bible §24 «Бюджет считается
/// корректно для всех трёх периодов»).
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final txAsync = ref.watch(transactionsStreamProvider);
    final catsAsync = ref.watch(categoriesStreamProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Бюджеты')),
        body: budgetsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (budgets) => txAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
            data: (transactions) => catsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (categories) {
                final visibleBudgets = budgets.where((b) => !b.isDeleted).toList();
                if (visibleBudgets.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Пока нет ни одного бюджета.\nДобавьте план для категории — вы сразу увидите, сколько уже потрачено.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final catById = {for (final c in categories) c.id: c};
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: visibleBudgets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final b = visibleBudgets[i];
                    final progress = computeBudgetProgress(b, transactions);
                    return _BudgetCard(
                      progress: progress,
                      category: catById[b.categoryId],
                      onDelete: () => _confirmDelete(context, ref, b),
                      onEdit: () => _openEditSheet(context, ref, b),
                    );
                  },
                );
              },
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'add-budget',
          onPressed: () => _openAddSheet(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _BudgetSheet(),
      ),
    );
  }

  Future<void> _openEditSheet(BuildContext context, WidgetRef ref, Budget budget) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BudgetSheet(existing: budget),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить бюджет?'),
        content: const Text('Операции по категории останутся; бюджет просто перестанет отображаться.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = await ref.read(budgetRepositoryProvider.future);
      await repo.softDelete(budget.id);
    }
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.progress,
    required this.category,
    required this.onDelete,
    required this.onEdit,
  });

  final BudgetProgress progress;
  final Category? category;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final b = progress.budget;
    final planned = b.plannedAmountKopecks;
    final spent = progress.spentAmountKopecks;
    final barValue = planned <= 0 ? 0.0 : (spent / planned).clamp(0.0, 1.0);
    final barColor = progress.isOverspent
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onEdit,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category?.name ?? 'Категория удалена',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(b.periodType.labelRu, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: barValue, color: barColor, minHeight: 8),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Потрачено: ${Money.formatRub(spent)}'),
                  Text('План: ${Money.formatRub(planned)}'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                progress.isOverspent
                    ? 'Превышение на ${Money.formatRub(-progress.remainingAmountKopecks)}'
                    : 'Осталось: ${Money.formatRub(progress.remainingAmountKopecks)}',
                style: TextStyle(
                  color: progress.isOverspent
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.existing});
  final Budget? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final TextEditingController _amountCtrl;
  BudgetPeriodType _period = BudgetPeriodType.month;
  DateTime _periodStart = _firstDayOfCurrentMonthUtc();
  String? _categoryId;

  static DateTime _firstDayOfCurrentMonthUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, 1);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountCtrl = TextEditingController(
      text: e == null ? '' : (e.plannedAmountKopecks / 100).toStringAsFixed(2),
    );
    if (e != null) {
      _period = e.periodType;
      _periodStart = e.periodStart;
      _categoryId = e.categoryId;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesStreamProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'Новый бюджет' : 'Изменить бюджет',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          catsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Ошибка: $e'),
            data: (categories) {
              final expense = categories
                  .where((c) => c.type == CategoryType.expense && !c.isArchived)
                  .toList();
              _categoryId ??= expense.isNotEmpty ? expense.first.id : null;
              return DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Категория расходов'),
                items: expense
                    .map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: widget.existing == null
                    ? (v) => setState(() => _categoryId = v)
                    : null,
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BudgetPeriodType>(
            initialValue: _period,
            decoration: const InputDecoration(labelText: 'Период'),
            items: BudgetPeriodType.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.labelRu)))
                .toList(),
            onChanged: widget.existing == null
                ? (v) => setState(() => _period = v ?? BudgetPeriodType.month)
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(labelText: 'Сумма плана, ₽'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = Money.parseToKopecks(_amountCtrl.text);
    if (amount == null || _categoryId == null) return;

    final session = await ref.read(bootstrapProvider.future);
    final repo = await ref.read(budgetRepositoryProvider.future);
    final now = DateTime.now().toUtc();

    final existing = widget.existing;
    if (existing == null) {
      await repo.create(Budget(
        id: const Uuid().v4(),
        familyId: session.familyId,
        categoryId: _categoryId!,
        periodType: _period,
        periodStart: _periodStart,
        plannedAmountKopecks: amount,
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      await repo.update(existing.copyWith(plannedAmountKopecks: amount, updatedAt: now));
    }
    if (mounted) Navigator.of(context).pop();
  }
}
