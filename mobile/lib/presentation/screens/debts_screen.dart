import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/debt.dart';
import '../../domain/model/money.dart';
import '../theme/app_ui.dart';
import 'debt_schedule_screen.dart';

enum _DebtFilter { all, iOwe, owedToMe, closed }

final _filterProvider = StateProvider<_DebtFilter>((_) => _DebtFilter.all);

/// Долги в обе стороны (I_OWE / OWED_TO_ME) и вход в график платежей.
/// Открывается из «Настройки → Разделы → Долги».
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsStreamProvider);
    final filter = ref.watch(_filterProvider);

    return MmScreen(
      title: 'Долги',
      trailing: MmCircleButton(
        icon: Icons.add,
        tooltip: 'Новый долг',
        onTap: () => _openSheet(context),
      ),
      headerBottom: MmSegmented<_DebtFilter>(
        items: const [
          (_DebtFilter.all, 'Все'),
          (_DebtFilter.iOwe, 'Я должен'),
          (_DebtFilter.owedToMe, 'Мне должны'),
          (_DebtFilter.closed, 'Закрытые'),
        ],
        selected: filter,
        onChanged: (v) => ref.read(_filterProvider.notifier).state = v,
      ),
      child: debtsAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (allDebts) {
          final debts = allDebts.where((d) => !d.isDeleted).toList();
          if (debts.isEmpty) {
            return MmEmptyState(
              icon: Icons.handshake_outlined,
              title: 'Долгов нет',
              message: 'Добавьте долг, чтобы не забыть, кому и сколько, '
                  'и разбить выплату на график.',
              actionLabel: 'Добавить долг',
              onAction: () => _openSheet(context),
            );
          }

          final open = debts.where((d) => d.status == DebtStatus.open);
          final iOwe = open
              .where((d) => d.direction == DebtDirection.iOwe)
              .fold<int>(0, (s, d) => s + d.amountKopecks);
          final owedToMe = open
              .where((d) => d.direction == DebtDirection.owedToMe)
              .fold<int>(0, (s, d) => s + d.amountKopecks);

          final shown = debts.where((d) => switch (filter) {
                _DebtFilter.all => d.status == DebtStatus.open,
                _DebtFilter.iOwe => d.status == DebtStatus.open &&
                    d.direction == DebtDirection.iOwe,
                _DebtFilter.owedToMe => d.status == DebtStatus.open &&
                    d.direction == DebtDirection.owedToMe,
                _DebtFilter.closed => d.status == DebtStatus.closed,
              },).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MmCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Я должен',
                          value: Money.formatRub(iOwe),
                          color: MmColors.red,
                        ),
                      ),
                      Container(width: 1, height: 40, color: MmColors.divider),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Metric(
                          label: 'Мне должны',
                          value: Money.formatRub(owedToMe),
                          color: MmColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Text(
                    'В этой выборке пусто.',
                    textAlign: TextAlign.center,
                    style: MmType.subhead,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final d in shown)
                        _DebtRow(
                          debt: d,
                          onTap: () => _openActions(context, ref, d),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Нажмите на долг, чтобы открыть график платежей, '
                  'изменить или закрыть его.',
                  style: MmType.caption,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _openSheet(BuildContext context, {Debt? existing}) {
    return mmShowSheet<void>(context, child: _DebtSheet(existing: existing));
  }

  static Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
  ) async {
    final isOpen = debt.status == DebtStatus.open;
    final action = await mmShowSheet<String>(
      context,
      child: MmSheet(
        title: debt.counterpartyName,
        subtitle:
            '${debt.direction.labelRu} • ${Money.formatRub(debt.amountKopecks)}',
        children: [
          MmGroupCard(
            margin: EdgeInsets.zero,
            children: [
              MmMenuRow(
                icon: Icons.event_repeat,
                iconBg: MmColors.tintBlue,
                iconColor: MmColors.blue,
                title: 'График платежей',
                showChevron: false,
                onTap: () => Navigator.pop(context, 'schedule'),
              ),
              MmMenuRow(
                icon: Icons.edit_outlined,
                iconBg: MmColors.tintGrey,
                iconColor: MmColors.labelTertiary,
                title: 'Изменить',
                showChevron: false,
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              MmMenuRow(
                icon: isOpen ? Icons.task_alt : Icons.replay,
                iconBg: MmColors.tintGreen,
                iconColor: MmColors.green,
                title: isOpen ? 'Закрыть долг' : 'Переоткрыть',
                showChevron: false,
                onTap: () => Navigator.pop(context, 'status'),
              ),
              MmMenuRow(
                icon: Icons.delete_outline,
                iconBg: MmColors.tintRed,
                iconColor: MmColors.red,
                title: 'Удалить',
                showChevron: false,
                isLast: true,
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'schedule':
        await mmPush(context, DebtScheduleScreen(debt: debt));
      case 'edit':
        await _openSheet(context, existing: debt);
      case 'status':
        final statusRepo = await ref.read(debtRepositoryProvider.future);
        await statusRepo.update(
          debt.copyWith(
            status: isOpen ? DebtStatus.closed : DebtStatus.open,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      case 'delete':
        final ok = await mmConfirm(
          context,
          title: 'Удалить долг?',
          message: '${debt.counterpartyName} — '
              '${Money.formatRub(debt.amountKopecks)}. '
              'График платежей по нему тоже перестанет отображаться.',
        );
        if (!ok) return;
        final repo = await ref.read(debtRepositoryProvider.future);
        await repo.softDelete(debt.id);
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: MmType.caption),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MmType.headline.copyWith(color: color),
        ),
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt, required this.onTap});

  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isClosed = debt.status == DebtStatus.closed;
    final iOwe = debt.direction == DebtDirection.iOwe;
    final overdue = !isClosed &&
        debt.dueDate != null &&
        debt.dueDate!.isBefore(DateTime.now().toUtc());

    final notes = <String>[
      debt.direction.labelRu,
      if (debt.interestRate > 0) '${debt.interestRate.toStringAsFixed(2)}%',
      if (debt.dueDate != null)
        'до ${DateFormat('d.MM.yyyy').format(debt.dueDate!.toLocal())}',
      if (overdue) 'просрочен',
    ];

    return Opacity(
      opacity: isClosed ? 0.55 : 1,
      child: MmListRow(
        icon: isClosed
            ? Icons.check_circle_outline
            : (iOwe ? Icons.south_west : Icons.north_east),
        iconColor: isClosed
            ? MmColors.labelTertiary
            : (iOwe ? MmColors.red : MmColors.green),
        title: debt.counterpartyName,
        subtitle: notes.join(' • '),
        strikeThrough: isClosed,
        trailingText: Money.formatRub(debt.amountKopecks),
        trailingColor: isClosed
            ? MmColors.labelTertiary
            : (iOwe ? MmColors.red : MmColors.green),
        onTap: onTap,
      ),
    );
  }
}

// ─── Форма создания / редактирования ─────────────────────────────────────────

class _DebtSheet extends ConsumerStatefulWidget {
  const _DebtSheet({this.existing});
  final Debt? existing;

  @override
  ConsumerState<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends ConsumerState<_DebtSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _rateCtrl;
  late DebtDirection _direction;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.counterpartyName ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : Money.formatPlain(e.amountKopecks),
    );
    // Ноль показываем пустым полем: «0,00» в поле ставки выглядит как
    // введённое значение, хотя означает «беспроцентный».
    _rateCtrl = TextEditingController(
      text: (e == null || e.interestRate == 0) ? '' : _formatRate(e.interestRate),
    );
    _direction = e?.direction ?? DebtDirection.iOwe;
    _dueDate = e?.dueDate;
  }

  /// Убирает хвост `.0` у целых ставок: 12.0 → «12», 12.5 → «12.5».
  static String _formatRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return MmSheet(
      title: isEdit ? 'Изменить долг' : 'Новый долг',
      primaryLabel: isEdit ? 'Сохранить' : 'Создать',
      onPrimary: _save,
      children: [
        MmChipsField<DebtDirection>(
          label: 'Направление',
          // У созданного долга направление не меняем: оно определяет знак
          // в сводке, поэтому показываем только выбранное.
          items: [
            for (final d in DebtDirection.values)
              if (!isEdit || d == _direction) (d, d.labelRu),
          ],
          selected: _direction,
          onSelected: (d) => setState(() => _direction = d),
        ),
        MmField(
          label: 'Кто или кому',
          controller: _nameCtrl,
          hint: 'Имя или организация',
          autofocus: !isEdit,
          textCapitalization: TextCapitalization.sentences,
        ),
        MmField(
          label: 'Сумма',
          controller: _amountCtrl,
          hint: '0,00',
          suffix: '₽',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        MmField(
          label: 'Ставка, % годовых',
          controller: _rateCtrl,
          hint: '0',
          helper: 'Пусто — беспроцентный долг',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        MmPickerRow(
          label: 'Срок',
          icon: Icons.event,
          value: _dueDate == null
              ? 'Без срока'
              : DateFormat('d MMMM y', 'ru_RU').format(_dueDate!.toLocal()),
          onTap: _pickDate,
          onClear: _dueDate == null ? null : () => setState(() => _dueDate = null),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate?.toLocal() ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _dueDate = DateTime.utc(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = Money.parseToKopecks(_amountCtrl.text);
    if (name.isEmpty || amount == null) {
      mmSnack(context, 'Укажите имя и сумму больше нуля');
      return;
    }

    final rawRate = _rateCtrl.text.trim().replaceAll(',', '.');
    final rate = rawRate.isEmpty ? 0.0 : double.tryParse(rawRate);
    if (rate == null || rate < 0 || rate > 1000) {
      mmSnack(context, 'Ставка должна быть от 0 до 1000%');
      return;
    }

    final now = DateTime.now().toUtc();
    final session = await ref.read(bootstrapProvider.future);
    final repo = await ref.read(debtRepositoryProvider.future);
    final existing = widget.existing;

    if (existing == null) {
      await repo.create(
        Debt(
          id: const Uuid().v4(),
          familyId: session.familyId,
          counterpartyName: name,
          direction: _direction,
          amountKopecks: amount,
          interestRate: rate,
          dueDate: _dueDate,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await repo.update(
        existing.copyWith(
          counterpartyName: name,
          amountKopecks: amount,
          interestRate: rate,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null,
          updatedAt: now,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
