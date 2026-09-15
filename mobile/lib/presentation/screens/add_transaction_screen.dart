import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/account.dart';
import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';
import '../../domain/model/money.dart';
import '../../domain/model/transaction.dart';
import '../theme/app_ui.dart';
import '../widgets/category_icon.dart';

/// Central "≤ 3 steps to add a transaction" flow (UC-03 / UC-04, Bible § 8).
/// All steps are on the same screen:
///   1) сумма,
///   2) счёт,
///   3) категория — для перевода вместо категории выбирается счёт-получатель.
///
/// Экран работает в двух режимах. Без [existing] это создание новой операции;
/// с [existing] — редактирование: поля предзаполнены, `id`/`createdAt`/
/// `createdBy` сохраняются, меняется только `updatedAt`. Это важно для
/// синхронизации: LWW-разрешение конфликтов опирается на `updatedAt`, а
/// новый `id` превратил бы правку в дубликат.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.existing});

  /// Операция для редактирования; `null` — создаём новую.
  final Transaction? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _type;
  String? _accountId;
  String? _targetAccountId;
  String? _categoryId;
  late DateTime _occurredAt;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _commentCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? TransactionType.expense;
    _accountId = existing?.accountId;
    _targetAccountId = existing?.targetAccountId;
    _categoryId = existing?.categoryId;
    _occurredAt = existing?.occurredAt.toLocal() ?? DateTime.now();
    _amountCtrl = TextEditingController(
      text: existing == null ? '' : Money.formatPlain(existing.amountKopecks),
    );
    _commentCtrl = TextEditingController(text: existing?.comment ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _isTransfer => _type == TransactionType.transfer;

  Color get _accent => switch (_type) {
        TransactionType.income => MmColors.green,
        TransactionType.expense => MmColors.red,
        TransactionType.transfer => MmColors.blue,
      };

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return MmScreen(
      title: widget.isEditing ? 'Изменить операцию' : 'Новая операция',
      trailing: widget.isEditing
          ? MmCircleButton(
              icon: Icons.delete_outline,
              iconColor: MmColors.red,
              tooltip: 'Удалить операцию',
              onTap: _saving ? () {} : _confirmDelete,
            )
          : null,
      headerBottom: MmSegmented<TransactionType>(
        items: const [
          (TransactionType.expense, 'Расход'),
          (TransactionType.income, 'Доход'),
          (TransactionType.transfer, 'Перевод'),
        ],
        selected: _type,
        onChanged: (t) => setState(() {
          _type = t;
          // Категория и счёт-получатель осмысленны только для своих типов —
          // иначе при переключении осталось бы значение от прошлого выбора
          // и ушло бы в сохранение.
          _categoryId = null;
          _targetAccountId = null;
        }),
      ),
      child: accountsAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (accounts) => categoriesAsync.when(
          loading: () => const MmLoading(),
          error: (e, _) => MmError(e),
          data: (categories) => _buildForm(accounts, categories),
        ),
      ),
    );
  }

  Widget _buildForm(List<Account> accounts, List<Category> categories) {
    final visibleAccounts =
        accounts.where((a) => !a.isArchived && !a.isDeleted).toList();

    // Единственный счёт выбирать вручную незачем.
    if (_accountId == null && visibleAccounts.length == 1) {
      _accountId = visibleAccounts.first.id;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        _AmountCard(controller: _amountCtrl, accent: _accent),
        const SizedBox(height: 20),
        MmChipsField<String>(
          label: _isTransfer ? 'Счёт списания' : 'Счёт',
          items: [for (final a in visibleAccounts) (a.id, a.name)],
          selected: _accountId,
          onSelected: (id) => setState(() {
            _accountId = id;
            // Перевод на самого себя смысла не имеет.
            if (_targetAccountId == id) _targetAccountId = null;
          }),
          emptyHint: 'Счетов нет — добавьте счёт в Настройках',
        ),
        if (_isTransfer)
          MmChipsField<String>(
            label: 'Счёт зачисления',
            items: [
              for (final a in visibleAccounts.where((a) => a.id != _accountId))
                (a.id, a.name),
            ],
            selected: _targetAccountId,
            onSelected: (id) => setState(() => _targetAccountId = id),
            emptyHint: 'Нужен второй счёт — добавьте его в Настройках',
          )
        else
          _CategoryPicker(
            categories: categories,
            type: _type,
            selectedId: _categoryId,
            onSelected: (id) => setState(() => _categoryId = id),
          ),
        MmPickerRow(
          label: 'Дата и время',
          icon: Icons.event,
          value: DateFormat('d MMMM y, HH:mm', 'ru_RU').format(_occurredAt),
          onTap: _pickDateTime,
        ),
        MmField(
          label: 'Комментарий',
          controller: _commentCtrl,
          hint: 'Не обязательно',
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        MmPrimaryButton(
          label: widget.isEditing ? 'Сохранить изменения' : 'Сохранить',
          color: _accent,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      // Операцию задним числом заводят часто, будущим — почти никогда,
      // поэтому верхняя граница «сегодня» отсекает опечатки в годе.
      lastDate: DateTime.now(),
      locale: const Locale('ru'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (!mounted) return;

    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _occurredAt.hour,
        time?.minute ?? _occurredAt.minute,
      );
    });
  }

  Future<void> _save() async {
    final accountId = _accountId;
    if (accountId == null) {
      mmSnack(context, _isTransfer ? 'Выберите счёт списания' : 'Выберите счёт');
      return;
    }

    String? targetAccountId;
    String? categoryId;
    if (_isTransfer) {
      targetAccountId = _targetAccountId;
      if (targetAccountId == null) {
        mmSnack(context, 'Выберите счёт зачисления');
        return;
      }
    } else {
      categoryId = _categoryId;
      if (categoryId == null) {
        mmSnack(context, 'Выберите категорию');
        return;
      }
    }

    final kopecks = Money.parseToKopecks(_amountCtrl.text);
    if (kopecks == null) {
      mmSnack(context, 'Введите положительную сумму');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = await ref.read(transactionRepositoryProvider.future);
      final session = await ref.read(bootstrapProvider.future);
      final now = DateTime.now().toUtc();
      final comment = _commentCtrl.text.trim();
      final existing = widget.existing;

      final tx = Transaction(
        // При редактировании сохраняем идентичность записи, иначе для
        // синхронизации это была бы новая операция, а старая осталась бы жить.
        id: existing?.id ?? const Uuid().v4(),
        familyId: existing?.familyId ?? session.familyId,
        accountId: accountId,
        categoryId: categoryId,
        type: _type,
        targetAccountId: targetAccountId,
        amountKopecks: kopecks,
        occurredAt: _occurredAt.toUtc(),
        comment: comment.isEmpty ? null : comment,
        attachmentPhotoPath: existing?.attachmentPhotoPath,
        createdBy: existing?.createdBy ?? session.userId,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        isDeleted: existing?.isDeleted ?? false,
      );

      if (existing == null) {
        await repo.create(tx);
      } else {
        await repo.update(tx);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;

    final ok = await mmConfirm(
      context,
      title: 'Удалить операцию?',
      message: 'Баланс счёта пересчитается сразу.',
    );
    if (!ok || !mounted) return;

    final repo = await ref.read(transactionRepositoryProvider.future);
    await repo.softDelete(existing.id);
    if (mounted) Navigator.of(context).pop();
  }
}

/// Крупное поле суммы — первое, что видно на экране: ввод суммы и есть
/// главное действие, остальное чаще всего уже предзаполнено.
class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.controller, required this.accent});

  final TextEditingController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Сумма', style: MmType.subhead),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  // Выравнивание вправо, чтобы сумма всегда стояла вплотную
                  // к «₽», а не отъезжала от него на полэкрана.
                  textAlign: TextAlign.right,
                  style: MmType.largeTitle.copyWith(color: accent),
                  decoration: InputDecoration.collapsed(
                    hintText: '0,00',
                    hintStyle: MmType.largeTitle.copyWith(color: MmColors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('₽', style: MmType.section.copyWith(color: MmColors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Выбор категории с поддержкой двух уровней: родительские категории
/// показываются подзаголовками, дочерние — «таблетками» под ними. Плоский
/// список (категории без родителя и без детей) рисуется одним рядом.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.type,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final TransactionType type;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final wantedType = type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    final available = categories
        .where((c) => c.type == wantedType && !c.isArchived && !c.isDeleted)
        .toList();

    if (available.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Категория', style: MmType.caption),
            const SizedBox(height: 8),
            Text(
              'Нет категорий — добавьте их в Настройках',
              style: MmType.subhead.copyWith(color: MmColors.red),
            ),
          ],
        ),
      );
    }

    final byParent = <String, List<Category>>{};
    final roots = <Category>[];
    for (final c in available) {
      final parent = c.parentCategoryId;
      if (parent == null) {
        roots.add(c);
      } else {
        byParent.putIfAbsent(parent, () => []).add(c);
      }
    }

    // Родитель мог быть удалён или заархивирован — его дети иначе исчезли бы
    // из выбора совсем. Поднимаем их на верхний уровень.
    final rootIds = roots.map((c) => c.id).toSet();
    for (final entry in byParent.entries.toList()) {
      if (!rootIds.contains(entry.key)) {
        roots.addAll(entry.value);
        byParent.remove(entry.key);
      }
    }

    // Категории без детей идут одним общим рядом — иначе каждая заняла бы
    // отдельную строку и экран растянулся бы вдвое.
    final flat = roots.where((c) => byParent[c.id] == null).toList();
    final withChildren = roots.where((c) => byParent[c.id] != null).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Категория', style: MmType.caption),
          const SizedBox(height: 8),
          if (flat.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in flat) _chip(c)],
            ),
          for (final root in withChildren) ...[
            const SizedBox(height: 12),
            Text(root.name, style: MmType.footnote),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Родитель тоже выбираем: операция может относиться к нему
                // напрямую, без уточнения подкатегорией.
                _chip(root),
                for (final child in byParent[root.id]!) _chip(child),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(Category c) => MmChip(
        label: c.name,
        icon: iconForName(c.icon),
        selected: selectedId == c.id,
        onTap: () => onSelected(c.id),
      );
}
