import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/goal.dart';
import '../../domain/model/money.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsStreamProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Цели')),
        body: goalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (allGoals) {
            final goals = allGoals.where((g) => !g.isDeleted).toList();
            if (goals.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Пока нет ни одной цели.\nДобавьте цель — и вносите средства по мере накопления.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) => _GoalCard(
                goal: goals[i],
                onDeposit: () => _openContribute(context, ref, goals[i], deposit: true),
                onWithdraw: () => _openContribute(context, ref, goals[i], deposit: false),
                onEdit: () => _openEditSheet(context, ref, goals[i]),
                onDelete: () => _confirmDelete(context, ref, goals[i]),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'add-goal',
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
        child: const _GoalSheet(),
      ),
    );
  }

  Future<void> _openEditSheet(BuildContext context, WidgetRef ref, Goal goal) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _GoalSheet(existing: goal),
      ),
    );
  }

  Future<void> _openContribute(
    BuildContext context,
    WidgetRef ref,
    Goal goal, {
    required bool deposit,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(deposit ? 'Пополнить цель' : 'Снять с цели'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Сумма, ₽'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (confirmed != true) return;
    final amount = Money.parseToKopecks(controller.text);
    if (amount == null) return;

    final repo = await ref.read(goalRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    if (deposit) {
      await repo.update(goal.copyWith(
        currentAmountKopecks: goal.currentAmountKopecks + amount,
        updatedAt: now,
      ));
    } else {
      final next = goal.currentAmountKopecks - amount;
      if (next < 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Невозможно снять больше, чем накоплено')),
          );
        }
        return;
      }
      await repo.update(goal.copyWith(currentAmountKopecks: next, updatedAt: now));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить цель «${goal.name}»?'),
        content: const Text('История пополнений не сохраняется отдельно; цель просто исчезнет из списка.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = await ref.read(goalRepositoryProvider.future);
      await repo.softDelete(goal.id);
    }
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onEdit,
    required this.onDelete,
  });

  final Goal goal;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final barValue = goal.targetAmountKopecks <= 0
        ? 0.0
        : (goal.currentAmountKopecks / goal.targetAmountKopecks).clamp(0.0, 1.0);
    final colors = Theme.of(context).colorScheme;
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
                    child: Text(goal.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (goal.isCompleted)
                    Icon(Icons.check_circle, color: colors.primary, size: 20),
                ],
              ),
              if (goal.targetDate != null) ...[
                const SizedBox(height: 2),
                Text(
                  'До: ${DateFormat('d MMMM yyyy', 'ru_RU').format(goal.targetDate!.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              LinearProgressIndicator(value: barValue, minHeight: 8),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Накоплено: ${Money.formatRub(goal.currentAmountKopecks)}'),
                  Text('Цель: ${Money.formatRub(goal.targetAmountKopecks)}'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onWithdraw,
                    icon: const Icon(Icons.remove),
                    label: const Text('Снять'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onDeposit,
                    icon: const Icon(Icons.add),
                    label: const Text('Пополнить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({this.existing});
  final Goal? existing;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _targetCtrl = TextEditingController(
      text: e == null ? '' : (e.targetAmountKopecks / 100).toStringAsFixed(2),
    );
    _targetDate = e?.targetDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'Новая цель' : 'Изменить цель',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Целевая сумма, ₽'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _targetDate == null
                      ? 'Дата не задана'
                      : 'До ${DateFormat('d MMMM yyyy', 'ru_RU').format(_targetDate!.toLocal())}',
                ),
              ),
              TextButton(
                onPressed: _pickDate,
                child: const Text('Выбрать дату'),
              ),
              if (_targetDate != null)
                IconButton(
                  tooltip: 'Убрать дату',
                  onPressed: () => setState(() => _targetDate = null),
                  icon: const Icon(Icons.clear),
                ),
            ],
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate?.toLocal() ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) {
      setState(() => _targetDate = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target = Money.parseToKopecks(_targetCtrl.text);
    if (name.isEmpty || target == null) return;

    final session = await ref.read(bootstrapProvider.future);
    final repo = await ref.read(goalRepositoryProvider.future);
    final now = DateTime.now().toUtc();

    final existing = widget.existing;
    if (existing == null) {
      await repo.create(Goal(
        id: const Uuid().v4(),
        familyId: session.familyId,
        name: name,
        targetAmountKopecks: target,
        currentAmountKopecks: 0,
        targetDate: _targetDate,
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      await repo.update(existing.copyWith(
        name: name,
        targetAmountKopecks: target,
        targetDate: _targetDate,
        clearTargetDate: _targetDate == null,
        updatedAt: now,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }
}
