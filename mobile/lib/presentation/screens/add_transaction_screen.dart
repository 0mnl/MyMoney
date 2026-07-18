import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/enums.dart';
import '../../domain/model/money.dart';
import '../../domain/model/transaction.dart';
import '../widgets/category_icon.dart';

/// Central "≤ 3 steps to add a transaction" flow (UC-03 / UC-04, Bible § 8).
/// All three steps are on the same screen:
///   1) tap an account chip,
///   2) tap a category chip (or leave blank for transfers — not on MVP mobile),
///   3) type the amount and hit save.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  TransactionType _type = TransactionType.expense;
  String? _accountId;
  String? _categoryId;
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Новая операция')),
      body: SafeArea(
        child: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (accounts) => categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
            data: (categories) {
              final wantedType =
                  _type == TransactionType.income ? CategoryType.income : CategoryType.expense;
              final availableCategories =
                  categories.where((c) => c.type == wantedType).toList();

              // Auto-preselect a single account when only one exists.
              if (_accountId == null && accounts.length == 1) {
                _accountId = accounts.first.id;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(value: TransactionType.expense, label: Text('Расход'), icon: Icon(Icons.remove)),
                      ButtonSegment(value: TransactionType.income, label: Text('Доход'), icon: Icon(Icons.add)),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() {
                      _type = s.first;
                      _categoryId = null;
                    }),
                  ),
                  const SizedBox(height: 24),
                  Text('1. Счёт', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in accounts)
                        ChoiceChip(
                          label: Text(a.name),
                          selected: _accountId == a.id,
                          onSelected: (_) => setState(() => _accountId = a.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('2. Категория', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in availableCategories)
                        ChoiceChip(
                          avatar: Icon(iconForName(c.icon), size: 18),
                          label: Text(c.name),
                          selected: _categoryId == c.id,
                          onSelected: (_) => setState(() => _categoryId = c.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('3. Сумма', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0,00',
                      suffixText: '₽',
                      border: OutlineInputBorder(),
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentCtrl,
                    decoration: const InputDecoration(labelText: 'Комментарий (не обязательно)'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Сохранить'),
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final accountId = _accountId;
    final categoryId = _categoryId;
    if (accountId == null) {
      _snack('Выберите счёт');
      return;
    }
    if (categoryId == null) {
      _snack('Выберите категорию');
      return;
    }
    final kopecks = Money.parseToKopecks(_amountCtrl.text);
    if (kopecks == null) {
      _snack('Введите положительную сумму');
      return;
    }
    setState(() => _saving = true);
    try {
      final session = await ref.read(bootstrapProvider.future);
      final repo = await ref.read(transactionRepositoryProvider.future);
      final now = DateTime.now().toUtc();
      final comment = _commentCtrl.text.trim();
      await repo.create(Transaction(
        id: const Uuid().v4(),
        familyId: session.familyId,
        accountId: accountId,
        categoryId: categoryId,
        type: _type,
        amountKopecks: kopecks,
        occurredAt: now,
        comment: comment.isEmpty ? null : comment,
        createdBy: session.userId,
        createdAt: now,
        updatedAt: now,
      ));
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
}
