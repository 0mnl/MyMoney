import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/money.dart';
import '../../domain/model/subscription.dart';

/// Минимальный экран подписок. Показывает список отсортированный по
/// nextChargeDate + быстрая кнопка "оплачено" — сдвигает дату на период.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(subscriptionsStreamProvider);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Подписки')),
        body: subsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (subs) {
            if (subs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Подписок пока нет.\nДобавьте, чтобы видеть предстоящие списания.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              itemCount: subs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _SubTile(
                sub: subs[i],
                onEdit: () => _openSheet(context, ref, existing: subs[i]),
                onDelete: () => _delete(context, ref, subs[i]),
                onAdvance: () => _advance(ref, subs[i]),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'add-sub',
          onPressed: () => _openSheet(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Подписка'),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref, {Subscription? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _SubForm(existing: existing),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Subscription sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить подписку?'),
        content: Text(sub.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      final repo = await ref.read(subscriptionRepositoryProvider.future);
      await repo.softDelete(sub.id);
    }
  }

  Future<void> _advance(WidgetRef ref, Subscription sub) async {
    final repo = await ref.read(subscriptionRepositoryProvider.future);
    final next = switch (sub.billingPeriod) {
      SubscriptionPeriod.weekly => sub.nextChargeDate.add(const Duration(days: 7)),
      SubscriptionPeriod.monthly => DateTime.utc(
          sub.nextChargeDate.year, sub.nextChargeDate.month + 1, sub.nextChargeDate.day,
          sub.nextChargeDate.hour, sub.nextChargeDate.minute),
      SubscriptionPeriod.yearly => DateTime.utc(
          sub.nextChargeDate.year + 1, sub.nextChargeDate.month, sub.nextChargeDate.day,
          sub.nextChargeDate.hour, sub.nextChargeDate.minute),
    };
    await repo.update(sub.copyWith(
      nextChargeDate: next,
      updatedAt: DateTime.now().toUtc(),
    ));
  }
}

class _SubTile extends StatelessWidget {
  const _SubTile({
    required this.sub,
    required this.onEdit,
    required this.onDelete,
    required this.onAdvance,
  });
  final Subscription sub;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final overdue = sub.nextChargeDate.isBefore(DateTime.now().toUtc());
    return ListTile(
      leading: Icon(Icons.autorenew, color: overdue ? Colors.red : null),
      title: Text(sub.name),
      subtitle: Text(
        '${sub.billingPeriod.labelRu} • '
        '${DateFormat('d MMM yyyy', 'ru_RU').format(sub.nextChargeDate.toLocal())}',
      ),
      trailing: Text(
        Money.formatRub(sub.amountKopecks),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: onEdit,
      onLongPress: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.done),
              title: const Text('Оплачено — сдвинуть на следующий период'),
              onTap: () {
                Navigator.pop(context);
                onAdvance();
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

class _SubForm extends ConsumerStatefulWidget {
  const _SubForm({this.existing});
  final Subscription? existing;

  @override
  ConsumerState<_SubForm> createState() => _SubFormState();
}

class _SubFormState extends ConsumerState<_SubForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late SubscriptionPeriod _period;
  late DateTime _nextDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : (e.amountKopecks / 100).toStringAsFixed(2),
    );
    _period = e?.billingPeriod ?? SubscriptionPeriod.monthly;
    _nextDate = e?.nextChargeDate ?? DateTime.now().toUtc();
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
            widget.existing == null ? 'Новая подписка' : 'Редактирование',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Название',
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
          DropdownButtonFormField<SubscriptionPeriod>(
            initialValue: _period,
            decoration: const InputDecoration(
              labelText: 'Периодичность',
              border: OutlineInputBorder(),
            ),
            items: SubscriptionPeriod.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.labelRu)))
                .toList(),
            onChanged: (v) => setState(() => _period = v!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Следующее списание: '
                    '${DateFormat('d MMM yyyy', 'ru_RU').format(_nextDate.toLocal())}'),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _nextDate = picked.toUtc());
                },
                child: const Text('Выбрать'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final rubles = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (name.isEmpty || rubles == null || rubles <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название и сумму > 0')),
      );
      return;
    }
    final kopecks = (rubles * 100).round();
    final now = DateTime.now().toUtc();
    final session = await ref.read(bootstrapProvider.future);
    final repo = await ref.read(subscriptionRepositoryProvider.future);
    if (widget.existing == null) {
      await repo.create(Subscription(
        id: const Uuid().v4(),
        familyId: session.familyId,
        name: name,
        amountKopecks: kopecks,
        billingPeriod: _period,
        nextChargeDate: _nextDate,
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      await repo.update(widget.existing!.copyWith(
        name: name,
        amountKopecks: kopecks,
        billingPeriod: _period,
        nextChargeDate: _nextDate,
        updatedAt: now,
      ));
    }
    if (mounted) Navigator.pop(context);
  }
}
