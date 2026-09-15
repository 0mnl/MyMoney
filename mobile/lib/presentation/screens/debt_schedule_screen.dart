import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/debt.dart';
import '../../domain/model/money.dart';
import '../../domain/usecase/debt_schedule.dart';
import '../theme/app_ui.dart';

/// График погашения одного долга (Bible v2 §7.7, §13).
///
/// Позиции графика — плановые, а не фактические платежи: отметка «оплачено»
/// не создаёт операцию по счёту. Связь с операцией предусмотрена полем
/// `DebtPayment.transactionId` и появится, когда погашение начнут проводить
/// через «Новую операцию».
class DebtScheduleScreen extends ConsumerWidget {
  const DebtScheduleScreen({super.key, required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(debtPaymentsStreamProvider(debt.id));

    return MmScreen(
      title: 'График платежей',
      subtitle: debt.counterpartyName,
      trailing: paymentsAsync.maybeWhen(
        data: (payments) => payments.isEmpty
            ? null
            : MmCircleButton(
                icon: Icons.refresh,
                tooltip: 'Пересоздать график',
                onTap: () => _generate(context, ref, hadSchedule: true),
              ),
        orElse: () => null,
      ),
      child: paymentsAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (payments) {
          if (payments.isEmpty) {
            return MmEmptyState(
              icon: Icons.event_repeat,
              title: 'Графика пока нет',
              message: 'Разбейте долг на равные платежи по месяцам — '
                  'с процентами, если ставка задана.',
              actionLabel: 'Создать график',
              onAction: () => _generate(context, ref, hadSchedule: false),
            );
          }

          final paid = payments
              .where((p) => p.isPaid)
              .fold<int>(0, (s, p) => s + p.plannedAmountKopecks);
          final total =
              payments.fold<int>(0, (s, p) => s + p.plannedAmountKopecks);
          final paidCount = payments.where((p) => p.isPaid).length;
          final df = DateFormat('d MMMM y', 'ru_RU');

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MmCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Погашено', style: MmType.subhead),
                      const SizedBox(height: 4),
                      Text(Money.formatRub(paid), style: MmType.largeTitle),
                      const SizedBox(height: 12),
                      MmProgressBar(
                        value: total == 0 ? 0 : paid / total,
                        color: MmColors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Из ${Money.formatRub(total)} • '
                        'платежей $paidCount из ${payments.length}',
                        style: MmType.caption,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const MmSectionHeader(title: 'Платежи'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (var i = 0; i < payments.length; i++)
                      _PaymentRow(
                        payment: payments[i],
                        index: i + 1,
                        count: payments.length,
                        dateLabel: df.format(payments[i].dueDate.toLocal()),
                        onToggle: () => _togglePaid(ref, payments[i]),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _togglePaid(WidgetRef ref, DebtPayment payment) async {
    final repo = await ref.read(debtPaymentRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    final nextPaid = !payment.isPaid;
    await repo.update(
      payment.copyWith(
        isPaid: nextPaid,
        paidAt: nextPaid ? now : null,
        // Снимая отметку, чистим и дату — иначе останется «оплачен тогда-то»
        // у неоплаченной позиции.
        clearPaidAt: !nextPaid,
        updatedAt: now,
      ),
    );
  }

  Future<void> _generate(
    BuildContext context,
    WidgetRef ref, {
    required bool hadSchedule,
  }) async {
    final params = await mmShowSheet<_ScheduleParams>(
      context,
      child: _ScheduleParamsSheet(debt: debt, isRegenerate: hadSchedule),
    );
    if (params == null) return;

    final repo = await ref.read(debtPaymentRepositoryProvider.future);
    // Пересоздание сначала гасит старый график: иначе позиции смешались бы
    // и сумма графика перестала бы сходиться с долгом.
    if (hadSchedule) await repo.softDeleteByDebt(debt.id);

    await repo.createAll(
      buildDebtSchedule(
        debt: debt,
        months: params.months,
        firstDueDate: params.firstDueDate,
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.index,
    required this.count,
    required this.dateLabel,
    required this.onToggle,
  });

  final DebtPayment payment;
  final int index;
  final int count;
  final String dateLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final overdue =
        !payment.isPaid && payment.dueDate.isBefore(DateTime.now().toUtc());

    return MmListRow(
      icon: Icons.event,
      leading: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: payment.isPaid ? MmColors.green : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: payment.isPaid
                    ? MmColors.green
                    : (overdue ? MmColors.red : MmColors.grey),
                width: 2,
              ),
            ),
            child: payment.isPaid
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
      ),
      title: Money.formatRub(payment.plannedAmountKopecks),
      strikeThrough: payment.isPaid,
      subtitle: overdue ? '$dateLabel • просрочен' : dateLabel,
      trailingText: '$index/$count',
      trailingStyle: MmType.footnote,
      trailingColor: overdue ? MmColors.red : MmColors.labelTertiary,
      onTap: onToggle,
    );
  }
}

class _ScheduleParams {
  const _ScheduleParams({required this.months, required this.firstDueDate});
  final int months;
  final DateTime firstDueDate;
}

class _ScheduleParamsSheet extends StatefulWidget {
  const _ScheduleParamsSheet({required this.debt, required this.isRegenerate});
  final Debt debt;
  final bool isRegenerate;

  @override
  State<_ScheduleParamsSheet> createState() => _ScheduleParamsSheetState();
}

class _ScheduleParamsSheetState extends State<_ScheduleParamsSheet> {
  final _monthsCtrl = TextEditingController(text: '6');
  late DateTime _firstDue;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDue = widget.debt.dueDate?.toLocal() ??
        DateTime(now.year, now.month + 1, now.day);
  }

  @override
  void dispose() {
    _monthsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = int.tryParse(_monthsCtrl.text) ?? 0;
    final valid = months > 0 && months <= 600;

    // Предпросмотр — самая полезная часть окна: видно, во что превратится
    // ставка, до того как график создан.
    final preview = valid
        ? buildDebtSchedule(
            debt: widget.debt,
            months: months,
            firstDueDate:
                DateTime.utc(_firstDue.year, _firstDue.month, _firstDue.day),
          )
        : const <DebtPayment>[];
    final total = preview.fold<int>(0, (s, p) => s + p.plannedAmountKopecks);

    return MmSheet(
      title: widget.isRegenerate ? 'Пересоздать график' : 'Создать график',
      subtitle: widget.isRegenerate
          ? 'Текущий график будет заменён, отметки об оплате сбросятся'
          : null,
      primaryLabel: widget.isRegenerate ? 'Пересоздать' : 'Создать',
      primaryColor: widget.isRegenerate ? MmColors.red : MmColors.blue,
      onPrimary: valid
          ? () => Navigator.pop(
                context,
                _ScheduleParams(
                  months: months,
                  firstDueDate: DateTime.utc(
                    _firstDue.year,
                    _firstDue.month,
                    _firstDue.day,
                  ),
                ),
              )
          : null,
      children: [
        MmField(
          label: 'Количество платежей (месяцев)',
          controller: _monthsCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        MmPickerRow(
          label: 'Первый платёж',
          icon: Icons.event,
          value: DateFormat('d MMMM y', 'ru_RU').format(_firstDue),
          onTap: _pickDate,
        ),
        if (valid)
          MmCard(
            radius: 20,
            shadows: MmShadows.tile,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'По ${Money.formatRub(preview.first.plannedAmountKopecks)} '
                  'в месяц',
                  style: MmType.bodyStrong,
                ),
                const SizedBox(height: 4),
                Text(
                  'Всего к выплате: ${Money.formatRub(total)}',
                  style: MmType.caption,
                ),
                if (widget.debt.interestRate > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Аннуитет по ставке '
                    '${widget.debt.interestRate.toStringAsFixed(2)}% годовых. '
                    'Переплата: '
                    '${Money.formatRub(total - widget.debt.amountKopecks)}',
                    style: MmType.caption,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('ru'),
    );
    if (picked != null) setState(() => _firstDue = picked);
  }
}
