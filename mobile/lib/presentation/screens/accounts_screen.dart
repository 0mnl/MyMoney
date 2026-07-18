import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/account.dart';
import '../../domain/model/balances.dart';
import '../../domain/model/money.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Счета')),
        body: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (accounts) => transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
            data: (transactions) {
              final balances = computeAccountBalances(accounts, transactions);
              if (accounts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Счетов нет. Добавьте счёт кнопкой ниже.', textAlign: TextAlign.center),
                  ),
                );
              }
              return ListView.separated(
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = accounts[i];
                  final bal = balances[a.id] ?? a.initialBalanceKopecks;
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet)),
                    title: Text(a.name),
                    subtitle: Text(a.type),
                    trailing: Text(
                      Money.formatRub(bal),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onLongPress: () => _confirmDelete(context, ref, a),
                  );
                },
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'add-account',
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
        child: _AddAccountSheet(),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить «${account.name}»?'),
        content: const Text('Счёт будет скрыт. Операции по нему сохранятся.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = await ref.read(accountRepositoryProvider.future);
      await repo.softDelete(account.id);
    }
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _nameCtrl = TextEditingController();
  final _initialCtrl = TextEditingController(text: '0');
  String _type = 'cash';

  static const _types = <String>['cash', 'card', 'savings', 'other'];
  static const _typeLabels = <String, String>{
    'cash': 'Наличные',
    'card': 'Карта',
    'savings': 'Накопления',
    'other': 'Другое',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _initialCtrl.dispose();
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
          Text('Новый счёт', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Название'),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Тип'),
            items: _types
                .map((t) => DropdownMenuItem<String>(value: t, child: Text(_typeLabels[t] ?? t)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? 'cash'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _initialCtrl,
            decoration: const InputDecoration(labelText: 'Начальный баланс, ₽'),
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
    if (_nameCtrl.text.trim().isEmpty) return;
    final kopecks = Money.parseToKopecks(_initialCtrl.text) ?? 0;
    final session = await ref.read(bootstrapProvider.future);
    final repo = await ref.read(accountRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    await repo.create(Account(
      id: const Uuid().v4(),
      familyId: session.familyId,
      name: _nameCtrl.text.trim(),
      type: _type,
      initialBalanceKopecks: kopecks,
      createdAt: now,
      updatedAt: now,
    ));
    if (mounted) Navigator.of(context).pop();
  }
}
