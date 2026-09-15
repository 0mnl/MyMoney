import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/goal.dart';
import '../../domain/model/money.dart';
import '../theme/app_ui.dart';

/// Накопительные цели. Экран существовал и работал, но ссылок на него в меню
/// не было — попасть сюда можно было только из кода. Теперь открывается из
/// «Настройки → Разделы → Цели».
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsStreamProvider);

    return MmScreen(
      title: 'Цели',
      trailing: MmCircleButton(
        icon: Icons.add,
        tooltip: 'Новая цель',
        onTap: () => _openSheet(context),
      ),
      child: goalsAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (allGoals) {
          final goals = allGoals.where((g) => !g.isDeleted).toList();
          if (goals.isEmpty) {
            return MmEmptyState(
              icon: Icons.flag_outlined,
              title: 'Целей пока нет',
              message: 'Отпуск, ремонт, подушка безопасности — '
                  'добавьте цель и вносите средства по мере накопления.',
              actionLabel: 'Создать цель',
              onAction: () => _openSheet(context),
            );
          }

          final saved = goals.fold<int>(0, (s, g) => s + g.currentAmountKopecks);
          final target = goals.fold<int>(0, (s, g) => s + g.targetAmountKopecks);

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MmCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Накоплено по целям', style: MmType.subhead),
                      const SizedBox(height: 4),
                      Text(Money.formatRub(saved), style: MmType.largeTitle),
                      const SizedBox(height: 12),
                      MmProgressBar(
                        value: target <= 0 ? 0 : saved / target,
                        color: MmColors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Цель: ${Money.formatRub(target)}',
                        style: MmType.caption,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              for (final g in goals)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _GoalCard(
                    goal: g,
                    onDeposit: () => _contribute(context, ref, g, deposit: true),
                    onWithdraw: () =>
                        _contribute(context, ref, g, deposit: false),
                    onEdit: () => _openSheet(context, existing: g),
                    onDelete: () => _confirmDelete(context, ref, g),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _openSheet(BuildContext context, {Goal? existing}) {
    return mmShowSheet<void>(context, child: _GoalSheet(existing: existing));
  }

  static Future<void> _contribute(
    BuildContext context,
    WidgetRef ref,
    Goal goal, {
    required bool deposit,
  }) async {
    final amount = await mmShowSheet<int>(
      context,
      child: _AmountSheet(
        title: deposit ? 'Пополнить цель' : 'Снять с цели',
        subtitle: goal.name,
        actionLabel: deposit ? 'Пополнить' : 'Снять',
        color: deposit ? MmColors.green : MmColors.red,
      ),
    );
    if (amount == null) return;

    final repo = await ref.read(goalRepositoryProvider.future);
    final now = DateTime.now().toUtc();

    if (deposit) {
      await repo.update(
        goal.copyWith(
          currentAmountKopecks: goal.currentAmountKopecks + amount,
          updatedAt: now,
        ),
      );
      return;
    }

    final next = goal.currentAmountKopecks - amount;
    if (next < 0) {
      if (context.mounted) {
        mmSnack(context, 'Невозможно снять больше, чем накоплено');
      }
      return;
    }
    await repo.update(goal.copyWith(currentAmountKopecks: next, updatedAt: now));
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) async {
    final ok = await mmConfirm(
      context,
      title: 'Удалить цель «${goal.name}»?',
      message: 'История пополнений не хранится отдельно — '
          'цель просто исчезнет из списка.',
    );
    if (!ok) return;
    final repo = await ref.read(goalRepositoryProvider.future);
    await repo.softDelete(goal.id);
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
    final value = goal.targetAmountKopecks <= 0
        ? 0.0
        : goal.currentAmountKopecks / goal.targetAmountKopecks;

    return MmCard(
      radius: 24,
      shadows: MmShadows.tile,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: onEdit,
      onLongPress: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.bodyStrong,
                ),
              ),
              if (goal.isCompleted)
                const Icon(Icons.check_circle, color: MmColors.green, size: 20)
              else
                Text('${goal.progressPercent}%', style: MmType.footnote),
            ],
          ),
          if (goal.targetDate != null) ...[
            const SizedBox(height: 2),
            Text(
              'До ${DateFormat('d MMMM y', 'ru_RU').format(goal.targetDate!.toLocal())}',
              style: MmType.caption,
            ),
          ],
          const SizedBox(height: 12),
          MmProgressBar(
            value: value,
            color: goal.isCompleted ? MmColors.green : MmColors.blue,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Money.formatRub(goal.currentAmountKopecks)} '
                  'из ${Money.formatRub(goal.targetAmountKopecks)}',
                  style: MmType.subhead.copyWith(color: MmColors.label),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MmSecondaryButton(
                  label: 'Снять',
                  icon: Icons.remove,
                  onPressed: onWithdraw,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MmPrimaryButton(
                  label: 'Пополнить',
                  icon: Icons.add,
                  color: MmColors.green,
                  onPressed: onDeposit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ввод одной суммы. Раньше это был `AlertDialog` с голым `TextField`;
/// вынесено отдельно, потому что тот же диалог нужен и для пополнения,
/// и для снятия.
class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final Color color;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MmSheet(
      title: widget.title,
      subtitle: widget.subtitle,
      primaryLabel: widget.actionLabel,
      primaryColor: widget.color,
      onPrimary: () {
        final amount = Money.parseToKopecks(_ctrl.text);
        if (amount == null) {
          mmSnack(context, 'Введите сумму больше нуля');
          return;
        }
        Navigator.of(context).pop(amount);
      },
      children: [
        MmField(
          label: 'Сумма',
          controller: _ctrl,
          hint: '0,00',
          suffix: '₽',
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }
}

// ─── Форма создания / редактирования ─────────────────────────────────────────

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
      text: e == null ? '' : Money.formatPlain(e.targetAmountKopecks),
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
    final isEdit = widget.existing != null;

    return MmSheet(
      title: isEdit ? 'Изменить цель' : 'Новая цель',
      primaryLabel: isEdit ? 'Сохранить' : 'Создать',
      onPrimary: _save,
      children: [
        MmField(
          label: 'Название',
          controller: _nameCtrl,
          hint: 'Например, Отпуск',
          autofocus: !isEdit,
          textCapitalization: TextCapitalization.sentences,
        ),
        MmField(
          label: 'Целевая сумма',
          controller: _targetCtrl,
          hint: '0,00',
          suffix: '₽',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        MmPickerRow(
          label: 'Срок',
          icon: Icons.event,
          value: _targetDate == null
              ? 'Не задан'
              : DateFormat('d MMMM y', 'ru_RU').format(_targetDate!.toLocal()),
          onTap: _pickDate,
          onClear:
              _targetDate == null ? null : () => setState(() => _targetDate = null),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate?.toLocal() ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 30),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _targetDate = DateTime.utc(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target = Money.parseToKopecks(_targetCtrl.text);
    if (name.isEmpty) {
      mmSnack(context, 'Введите название цели');
      return;
    }
    if (target == null) {
      mmSnack(context, 'Введите целевую сумму больше нуля');
      return;
    }

    final session = await ref.read(bootstrapProvider.future);
    final repo = await ref.read(goalRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    final existing = widget.existing;

    if (existing == null) {
      await repo.create(
        Goal(
          id: const Uuid().v4(),
          familyId: session.familyId,
          name: name,
          targetAmountKopecks: target,
          currentAmountKopecks: 0,
          targetDate: _targetDate,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await repo.update(
        existing.copyWith(
          name: name,
          targetAmountKopecks: target,
          targetDate: _targetDate,
          clearTargetDate: _targetDate == null,
          updatedAt: now,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
