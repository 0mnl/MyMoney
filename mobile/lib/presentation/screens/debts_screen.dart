import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/debt.dart';
import '../../domain/model/money.dart';

/// Минимальный экран для учёта долгов (I_OWE / OWED_TO_ME).
/// Список + кнопка добавить + переключение статуса OPEN/CLOSED свайпом
/// (в MVP — через диалог редактирования).
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsStreamProvider);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Долги')),
        body: debtsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (debts) {
            if (debts.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Долгов пока нет.\nДобавьте, чтобы не забыть, кому и сколько.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              itemCount: debts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _DebtTile(
                debt: debts[i],
                onEdit: () => _openSheet(context, ref, existing: debts[i]),
                onDelete: () => _delete(context, ref, debts[i]),
                onToggleStatus: () => _toggleStatus(ref, debts[i]),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'add-debt',
          onPressed: () => _openSheet(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Долг'),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref, {Debt? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _DebtForm(existing: existing),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Debt debt) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить долг?'),
        content: Text(debt.counterpartyName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      final repo = await ref.read(debtRepositoryProvider.future);
      await repo.softDelete(debt.id);
    }
  }

  Future<void> _toggleStatus(WidgetRef ref, Debt debt) async {
    final repo = await ref.read(debtRepositoryProvider.future);
    await repo.update(debt.copyWith(
      status: debt.status == DebtStatus.open ? DebtStatus.closed : DebtStatus.open,
      updatedAt: DateTime.now().toUtc(),
    ));
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.debt,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });
  final Debt debt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final signColor = debt.direction == DebtDirection.iOwe ? Colors.red : Colors.green;
    return ListTile(
      leading: Icon(
        debt.status == DebtStatus.open ? Icons.access_time : Icons.check_circle,
        color: debt.status == DebtStatus.open ? null : Colors.grey,
      ),
      title: Text(
        debt.counterpartyName,
        style: TextStyle(
          decoration: debt.status == DebtStatus.closed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text([
        debt.direction.labelRu,
        if (debt.dueDate != null) 'до ${DateFormat('d.MM.yyyy').format(debt.dueDate!.toLocal())}',
      ].join(' • ')),
      trailing: Text(
        Money.formatRub(debt.amountKopecks),
        style: TextStyle(color: signColor, fontWeight: FontWeight.bold),
      ),
      onTap: onEdit,
      onLongPress: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(debt.status == DebtStatus.open ? 'Закрыть долг' : 'Переоткрыть'),
              onTap: () {
                Navigator.pop(context);
                onToggleStatus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtForm extends ConsumerStatefulWidget {
  const _DebtForm({this.existing});
  final Debt? existing;

  @override
  ConsumerState<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<_DebtForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late DebtDirection _direction;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.counterpartyName ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : (e.amountKopecks / 100).toStringAsFixed(2),
    );
    _direction = e?.direction ?? DebtDirection.iOwe;
    _dueDate = e?.dueDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Новый долг' : 'Редактирование',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<DebtDirection>(
            segments: const [
              ButtonSegment(value: DebtDirection.iOwe, label: Text('Я должен')),
              ButtonSegment(value: DebtDirection.owedToMe, label: Text('Мне должны')),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Кто/кому',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Сумма ₽',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(_dueDate == null
                    ? 'Без срока'
                    : 'Срок: ${DateFormat('d MMM yyyy', 'ru_RU').format(_dueDate!.toLocal())}'),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _dueDate = picked.toUtc());
                },
                child: const Text('Выбрать'),
              ),
              if (_dueDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _dueDate = null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final rubles = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (name.isEmpty || rubles == null || rubles <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите имя и сумму > 0')),
      );
      return;
    }
    final kopecks = (rubles * 100).round();
    final now = DateTime.now().toUtc();
    final session = await ref.read(bootstrapProvider.future);
    final repo = await ref.read(debtRepositoryProvider.future);
    if (widget.existing == null) {
      await repo.create(Debt(
        id: const Uuid().v4(),
        familyId: session.familyId,
        counterpartyName: name,
        direction: _direction,
        amountKopecks: kopecks,
        dueDate: _dueDate,
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      await repo.update(widget.existing!.copyWith(
        counterpartyName: name,
        amountKopecks: kopecks,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        updatedAt: now,
      ));
    }
    if (mounted) Navigator.pop(context);
  }
}
