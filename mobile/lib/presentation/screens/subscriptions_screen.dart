import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/money.dart';
import '../../domain/model/subscription.dart';
import '../theme/app_ui.dart';

/// Подписки: список по дате ближайшего списания и быстрая отметка «оплачено»,
/// сдвигающая дату на период вперёд.
/// Открывается из «Настройки → Разделы → Подписки».
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(subscriptionsStreamProvider);

    return MmScreen(
      title: 'Подписки',
      trailing: MmCircleButton(
        icon: Icons.add,
        tooltip: 'Новая подписка',
        onTap: () => _openSheet(context),
      ),
      child: subsAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (allSubs) {
          final subs = allSubs.where((s) => !s.isDeleted).toList()
            ..sort((a, b) => a.nextChargeDate.compareTo(b.nextChargeDate));

          if (subs.isEmpty) {
            return MmEmptyState(
              icon: Icons.autorenew,
              title: 'Подписок нет',
              message: 'Добавьте регулярные списания — '
                  'и увидите, сколько они стоят в месяц.',
              actionLabel: 'Добавить подписку',
              onAction: () => _openSheet(context),
            );
          }

          final perMonth = subs.fold<int>(0, (s, x) => s + _monthlyCost(x));

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MmCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('В среднем в месяц', style: MmType.subhead),
                      const SizedBox(height: 4),
                      Text(Money.formatRub(perMonth), style: MmType.largeTitle),
                      const SizedBox(height: 6),
                      Text(
                        'Подписок: ${subs.length}. '
                        'Недельные и годовые пересчитаны к месяцу.',
                        style: MmType.caption,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const MmSectionHeader(title: 'Ближайшие списания'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final s in subs)
                      _SubscriptionRow(
                        sub: s,
                        onTap: () => _openActions(context, ref, s),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Нажмите на подписку, чтобы отметить оплату, '
                  'изменить или удалить её.',
                  style: MmType.caption,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Приведение к месячной стоимости — только для сводки сверху. В самих
  /// подписках хранится исходная сумма за свой период.
  static int _monthlyCost(Subscription s) => switch (s.billingPeriod) {
        SubscriptionPeriod.weekly => (s.amountKopecks * 52 / 12).round(),
        SubscriptionPeriod.monthly => s.amountKopecks,
        SubscriptionPeriod.yearly => (s.amountKopecks / 12).round(),
      };

  static Future<void> _openSheet(BuildContext context, {Subscription? existing}) {
    return mmShowSheet<void>(
      context,
      child: _SubscriptionSheet(existing: existing),
    );
  }

  static Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    Subscription sub,
  ) async {
    final action = await mmShowSheet<String>(
      context,
      child: MmSheet(
        title: sub.name,
        subtitle: '${sub.billingPeriod.labelRu} • '
            '${Money.formatRub(sub.amountKopecks)}',
        children: [
          MmGroupCard(
            margin: EdgeInsets.zero,
            children: [
              MmMenuRow(
                icon: Icons.done,
                iconBg: MmColors.tintGreen,
                iconColor: MmColors.green,
                title: 'Оплачено',
                subtitle: 'Сдвинуть дату на следующий период',
                showChevron: false,
                onTap: () => Navigator.pop(context, 'advance'),
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
      case 'advance':
        final repo = await ref.read(subscriptionRepositoryProvider.future);
        await repo.update(
          sub.copyWith(
            nextChargeDate: _nextChargeAfter(sub),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      case 'edit':
        await _openSheet(context, existing: sub);
      case 'delete':
        final ok = await mmConfirm(
          context,
          title: 'Удалить подписку?',
          message: sub.name,
        );
        if (!ok) return;
        final deleteRepo = await ref.read(subscriptionRepositoryProvider.future);
        await deleteRepo.softDelete(sub.id);
    }
  }

  static DateTime _nextChargeAfter(Subscription sub) =>
      switch (sub.billingPeriod) {
        SubscriptionPeriod.weekly =>
          sub.nextChargeDate.add(const Duration(days: 7)),
        SubscriptionPeriod.monthly => _safeNextMonth(sub.nextChargeDate),
        SubscriptionPeriod.yearly => DateTime.utc(
            sub.nextChargeDate.year + 1,
            sub.nextChargeDate.month,
            sub.nextChargeDate.day,
            sub.nextChargeDate.hour,
            sub.nextChargeDate.minute,
          ),
      };

  /// Прибавление месяца с защитой от 31-го числа: у февраля его нет, и наивный
  /// `month + 1` дал бы 3 марта вместо 28 февраля.
  static DateTime _safeNextMonth(DateTime from) {
    final month = from.month + 1;
    final year = from.year + (month > 12 ? 1 : 0);
    final m = month > 12 ? 1 : month;
    final lastDay = DateTime.utc(year, m + 1, 0).day;
    return DateTime.utc(year, m, from.day.clamp(1, lastDay), from.hour, from.minute);
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({required this.sub, required this.onTap});

  final Subscription sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final overdue = sub.nextChargeDate.isBefore(now);
    final days = sub.nextChargeDate.difference(now).inDays;

    final when = overdue
        ? 'просрочено'
        : days == 0
            ? 'сегодня'
            : 'через $days ${_pluralDays(days)}';

    return MmListRow(
      icon: Icons.autorenew,
      iconColor: overdue ? MmColors.red : MmColors.label,
      title: sub.name,
      subtitle: '${sub.billingPeriod.labelRu} • '
          '${DateFormat('d MMM y', 'ru_RU').format(sub.nextChargeDate.toLocal())}',
      trailingText: Money.formatRub(sub.amountKopecks),
      trailingColor: overdue ? MmColors.red : MmColors.label,
      trailingBelow: when,
      onTap: onTap,
    );
  }

  static String _pluralDays(int days) {
    final mod10 = days % 10;
    final mod100 = days % 100;
    if (mod10 == 1 && mod100 != 11) return 'день';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'дня';
    return 'дней';
  }
}

// ─── Форма создания / редактирования ─────────────────────────────────────────

class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet({this.existing});
  final Subscription? existing;

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet> {
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
      text: e == null ? '' : Money.formatPlain(e.amountKopecks),
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
    final isEdit = widget.existing != null;

    return MmSheet(
      title: isEdit ? 'Изменить подписку' : 'Новая подписка',
      primaryLabel: isEdit ? 'Сохранить' : 'Создать',
      onPrimary: _save,
      children: [
        MmField(
          label: 'Название',
          controller: _nameCtrl,
          hint: 'Например, Музыка',
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
        MmChipsField<SubscriptionPeriod>(
          label: 'Периодичность',
          items: [
            for (final p in SubscriptionPeriod.values) (p, p.labelRu),
          ],
          selected: _period,
          onSelected: (p) => setState(() => _period = p),
        ),
        MmPickerRow(
          label: 'Следующее списание',
          icon: Icons.event,
          value: DateFormat('d MMMM y', 'ru_RU').format(_nextDate.toLocal()),
          onTap: _pickDate,
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate.toLocal(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _nextDate = DateTime.utc(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = Money.parseToKopecks(_amountCtrl.text);
    if (name.isEmpty || amount == null) {
      mmSnack(context, 'Укажите название и сумму больше нуля');
      return;
    }

    final now = DateTime.now().toUtc();
    final session = await ref.read(bootstrapProvider.future);
    final repo = await ref.read(subscriptionRepositoryProvider.future);
    final existing = widget.existing;

    if (existing == null) {
      await repo.create(
        Subscription(
          id: const Uuid().v4(),
          familyId: session.familyId,
          name: name,
          amountKopecks: amount,
          billingPeriod: _period,
          nextChargeDate: _nextDate,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await repo.update(
        existing.copyWith(
          name: name,
          amountKopecks: amount,
          billingPeriod: _period,
          nextChargeDate: _nextDate,
          updatedAt: now,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
