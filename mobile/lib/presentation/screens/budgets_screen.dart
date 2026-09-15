import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/budget.dart';
import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';
import '../../domain/model/money.dart';
import '../../domain/usecase/budget_progress.dart';
import '../theme/app_ui.dart';
import '../widgets/category_icon.dart';

/// Список бюджетов с прогрессом за период (Bible §24: «Бюджет считается
/// корректно для всех трёх периодов»).
///
/// Таб внутри `HomeShell` — отсюда [MmScreen.embedded] и отступ снизу под
/// плавающей навигацией.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final txAsync = ref.watch(transactionsStreamProvider);
    final catsAsync = ref.watch(categoriesStreamProvider);

    return MmScreen(
      embedded: true,
      title: 'Бюджет',
      trailing: MmCircleButton(
        icon: Icons.add,
        tooltip: 'Новый бюджет',
        onTap: () => _openSheet(context),
      ),
      child: budgetsAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (budgets) => txAsync.when(
          loading: () => const MmLoading(),
          error: (e, _) => MmError(e),
          data: (transactions) => catsAsync.when(
            loading: () => const MmLoading(),
            error: (e, _) => MmError(e),
            data: (categories) {
              final visible = budgets.where((b) => !b.isDeleted).toList();
              if (visible.isEmpty) {
                return MmEmptyState(
                  icon: Icons.pie_chart_outline,
                  title: 'Бюджетов пока нет',
                  message: 'Задайте план по категории — и увидите, '
                      'сколько уже потрачено.',
                  actionLabel: 'Создать бюджет',
                  onAction: () => _openSheet(context),
                );
              }

              final catById = {for (final c in categories) c.id: c};
              final progresses = [
                for (final b in visible) computeBudgetProgress(b, transactions),
              ];
              final planned = progresses.fold<int>(
                0,
                (s, p) => s + p.budget.plannedAmountKopecks,
              );
              final spent =
                  progresses.fold<int>(0, (s, p) => s + p.spentAmountKopecks);

              return ListView(
                padding: const EdgeInsets.only(bottom: kMmTabBottomInset),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _OverallCard(
                      plannedKopecks: planned,
                      spentKopecks: spent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const MmSectionHeader(title: 'По категориям'),
                  const SizedBox(height: 12),
                  for (final p in progresses)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _BudgetCard(
                        progress: p,
                        category: catById[p.budget.categoryId],
                        onEdit: () => _openSheet(context, existing: p.budget),
                        onDelete: () => _confirmDelete(context, ref, p.budget),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static Future<void> _openSheet(BuildContext context, {Budget? existing}) {
    return mmShowSheet<void>(
      context,
      child: _BudgetSheet(existing: existing),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
  ) async {
    final ok = await mmConfirm(
      context,
      title: 'Удалить бюджет?',
      message: 'Операции по категории останутся, '
          'бюджет просто перестанет отображаться.',
    );
    if (!ok) return;
    final repo = await ref.read(budgetRepositoryProvider.future);
    await repo.softDelete(budget.id);
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.plannedKopecks, required this.spentKopecks});

  final int plannedKopecks;
  final int spentKopecks;

  @override
  Widget build(BuildContext context) {
    final remaining = plannedKopecks - spentKopecks;
    final over = remaining < 0;
    final value = plannedKopecks <= 0 ? 0.0 : spentKopecks / plannedKopecks;

    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Потрачено из плана', style: MmType.subhead),
          const SizedBox(height: 4),
          Text(Money.formatRub(spentKopecks), style: MmType.largeTitle),
          const SizedBox(height: 12),
          MmProgressBar(
            value: value,
            color: over ? MmColors.red : MmColors.green,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'План: ${Money.formatRub(plannedKopecks)}',
                  style: MmType.caption,
                ),
              ),
              Text(
                over
                    ? 'Превышение: ${Money.formatRub(-remaining)}'
                    : 'Осталось: ${Money.formatRub(remaining)}',
                style: MmType.caption.copyWith(
                  color: over ? MmColors.red : MmColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.progress,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetProgress progress;
  final Category? category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final b = progress.budget;
    final planned = b.plannedAmountKopecks;
    final spent = progress.spentAmountKopecks;
    final value = planned <= 0 ? 0.0 : spent / planned;
    final over = progress.isOverspent;

    return MmCard(
      radius: 24,
      shadows: MmShadows.tile,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      onTap: onEdit,
      onLongPress: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: MmColors.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconForName(category?.icon),
                  size: 18,
                  color: MmColors.label,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category?.name ?? 'Категория удалена',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.bodyStrong,
                ),
              ),
              Text(b.periodType.labelRu, style: MmType.caption),
            ],
          ),
          const SizedBox(height: 12),
          MmProgressBar(
            value: value,
            color: over ? MmColors.red : MmColors.blue,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Money.formatRub(spent)} из ${Money.formatRub(planned)}',
                  style: MmType.subhead.copyWith(color: MmColors.label),
                ),
              ),
              Text(
                over
                    ? '+${Money.formatRub(-progress.remainingAmountKopecks)}'
                    : Money.formatRub(progress.remainingAmountKopecks),
                style: MmType.footnote.copyWith(
                  color: over ? MmColors.red : MmColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Форма создания / редактирования ─────────────────────────────────────────

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.existing});
  final Budget? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final TextEditingController _amountCtrl;
  BudgetPeriodType _period = BudgetPeriodType.month;
  String? _categoryId;

  /// Начало периода считается от выбранного типа, а не всегда от первого числа
  /// месяца: недельный бюджет, стартующий 1-го числа, закрывался бы через семь
  /// дней и весь остаток месяца показывал бы ноль потрачено.
  DateTime get _periodStart {
    final now = DateTime.now();
    return switch (_period) {
      BudgetPeriodType.week => DateTime(
          now.year,
          now.month,
          now.day - (now.weekday - 1),
        ).toUtc(),
      BudgetPeriodType.month => DateTime.utc(now.year, now.month, 1),
      BudgetPeriodType.year => DateTime.utc(now.year, 1, 1),
    };
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountCtrl = TextEditingController(
      text: e == null ? '' : Money.formatPlain(e.plannedAmountKopecks),
    );
    if (e != null) {
      _period = e.periodType;
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
    final isEdit = widget.existing != null;
    final catsAsync = ref.watch(categoriesStreamProvider);

    return MmSheet(
      title: isEdit ? 'Изменить бюджет' : 'Новый бюджет',
      subtitle: isEdit
          // Категорию и период у существующего бюджета не меняем: период уже
          // «прожит», а смена категории превратила бы историю в чужую.
          ? 'Категорию и период у созданного бюджета изменить нельзя'
          : null,
      primaryLabel: isEdit ? 'Сохранить' : 'Создать',
      onPrimary: _save,
      children: [
        catsAsync.when(
          loading: () => const MmLoading(),
          error: (e, _) => MmError(e),
          data: (categories) {
            final expense = categories
                .where((c) =>
                    c.type == CategoryType.expense &&
                    !c.isArchived &&
                    !c.isDeleted,)
                .toList();
            _categoryId ??= expense.isNotEmpty ? expense.first.id : null;

            // При редактировании показываем только выбранную категорию: список
            // остальных обещал бы выбор, которого нет.
            final items = isEdit
                ? [
                    for (final c in expense.where((c) => c.id == _categoryId))
                      (c.id, c.name),
                  ]
                : [for (final c in expense) (c.id, c.name)];

            return MmChipsField<String>(
              label: 'Категория расходов',
              items: items,
              selected: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
              emptyHint: 'Нет категорий расходов — добавьте их в Настройках',
            );
          },
        ),
        MmChipsField<BudgetPeriodType>(
          label: 'Период',
          items: [
            for (final p in BudgetPeriodType.values)
              if (!isEdit || p == _period) (p, p.labelRu),
          ],
          selected: _period,
          onSelected: (p) => setState(() => _period = p),
        ),
        MmField(
          label: 'Сумма плана',
          controller: _amountCtrl,
          hint: '0,00',
          suffix: '₽',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final amount = Money.parseToKopecks(_amountCtrl.text);
    if (amount == null) {
      mmSnack(context, 'Введите сумму больше нуля');
      return;
    }
    if (_categoryId == null) {
      mmSnack(context, 'Выберите категорию');
      return;
    }

    final session = await ref.read(bootstrapProvider.future);
    final repo = await ref.read(budgetRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    final existing = widget.existing;

    if (existing == null) {
      await repo.create(
        Budget(
          id: const Uuid().v4(),
          familyId: session.familyId,
          categoryId: _categoryId!,
          periodType: _period,
          periodStart: _periodStart,
          plannedAmountKopecks: amount,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await repo.update(
        existing.copyWith(plannedAmountKopecks: amount, updatedAt: now),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
