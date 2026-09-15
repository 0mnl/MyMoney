import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/account.dart';
import '../../domain/model/balances.dart';
import '../../domain/model/money.dart';
import '../theme/app_ui.dart';

/// Ярлыки типов счетов. `card` вынесен в константу, потому что от него
/// зависит показ кредитного лимита.
const _accountTypeCard = 'card';
const _accountTypeLabels = <String, String>{
  'cash': 'Наличные',
  _accountTypeCard: 'Карта',
  'savings': 'Накопления',
  'other': 'Другое',
};

IconData iconForAccountType(String type) => switch (type) {
      _accountTypeCard => Icons.credit_card,
      'cash' => Icons.payments,
      'savings' => Icons.account_balance,
      'crypto' => Icons.currency_bitcoin,
      _ => Icons.account_balance_wallet,
    };

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return MmScreen(
      title: 'Счета',
      trailing: MmCircleButton(
        icon: Icons.add,
        tooltip: 'Новый счёт',
        onTap: () => _openSheet(context),
      ),
      child: accountsAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (accounts) => transactionsAsync.when(
          loading: () => const MmLoading(),
          error: (e, _) => MmError(e),
          data: (transactions) {
            final visible = accounts.where((a) => !a.isDeleted).toList();
            if (visible.isEmpty) {
              return MmEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Счетов пока нет',
                message: 'Кошелёк, карта, накопления — заведите хотя бы один, '
                    'чтобы записывать операции.',
                actionLabel: 'Добавить счёт',
                onAction: () => _openSheet(context),
              );
            }

            final balances = computeAccountBalances(accounts, transactions);
            final active = visible.where((a) => !a.isArchived).toList();
            final archived = visible.where((a) => a.isArchived).toList();
            final total = active.fold<int>(
              0,
              (s, a) => s + (balances[a.id] ?? a.initialBalanceKopecks),
            );

            return ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: MmCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Всего на счетах', style: MmType.subhead),
                        const SizedBox(height: 4),
                        Text(Money.formatRub(total), style: MmType.largeTitle),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (active.isNotEmpty) ...[
                  const MmSectionHeader(title: 'Активные'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        for (final a in active)
                          _AccountRow(
                            account: a,
                            balanceKopecks:
                                balances[a.id] ?? a.initialBalanceKopecks,
                            onTap: () => _openSheet(context, existing: a),
                            onLongPress: () => _openActions(context, ref, a),
                          ),
                      ],
                    ),
                  ),
                ],
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const MmSectionHeader(title: 'В архиве'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        for (final a in archived)
                          _AccountRow(
                            account: a,
                            balanceKopecks:
                                balances[a.id] ?? a.initialBalanceKopecks,
                            dimmed: true,
                            onTap: () => _openSheet(context, existing: a),
                            onLongPress: () => _openActions(context, ref, a),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Долгое нажатие на счёт — архив и удаление. '
                    'Архивный счёт не предлагается в новых операциях, '
                    'но его история сохраняется.',
                    style: MmType.caption,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Future<void> _openSheet(BuildContext context, {Account? existing}) {
    return mmShowSheet<void>(context, child: _AccountSheet(existing: existing));
  }

  /// Архив и удаление вынесены в отдельное меню, а не в форму: это действия
  /// над счётом целиком, а не редактирование его полей.
  static Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final action = await mmShowSheet<String>(
      context,
      child: MmSheet(
        title: account.name,
        children: [
          MmGroupCard(
            margin: EdgeInsets.zero,
            children: [
              MmMenuRow(
                icon: account.isArchived ? Icons.unarchive : Icons.archive,
                iconBg: MmColors.tintOrange,
                iconColor: MmColors.orange,
                title: account.isArchived
                    ? 'Вернуть из архива'
                    : 'Убрать в архив',
                showChevron: false,
                onTap: () => Navigator.pop(context, 'archive'),
              ),
              MmMenuRow(
                icon: Icons.delete_outline,
                iconBg: MmColors.tintRed,
                iconColor: MmColors.red,
                title: 'Удалить счёт',
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

    final repo = await ref.read(accountRepositoryProvider.future);
    if (action == 'archive') {
      await repo.update(
        account.copyWith(
          isArchived: !account.isArchived,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final ok = await mmConfirm(
      context,
      title: 'Удалить «${account.name}»?',
      message: 'Счёт скроется из списков. Операции по нему сохранятся.',
    );
    if (ok) await repo.softDelete(account.id);
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.balanceKopecks,
    required this.onTap,
    required this.onLongPress,
    this.dimmed = false,
  });

  final Account account;
  final int balanceKopecks;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final limit = account.creditLimitKopecks;
    final typeLabel = _accountTypeLabels[account.type] ?? account.type;

    // Доступно к трате = лимит + баланс. Баланс кредитки обычно отрицательный,
    // поэтому именно плюс: лимит 100 000 при долге −30 000 даёт 70 000.
    final available = limit == null ? null : limit + balanceKopecks;

    // Сам лимит в строку не выносим: он не влезает рядом с «доступно» на
    // узком экране и виден в форме редактирования.
    final subtitle = limit == null
        ? typeLabel
        : '$typeLabel • доступно ${Money.formatRub(available!)}';

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: MmListRow(
        icon: iconForAccountType(account.type),
        title: account.name,
        subtitle: subtitle,
        trailingText: Money.formatRub(balanceKopecks),
        trailingColor: balanceKopecks < 0 ? MmColors.red : MmColors.label,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

// ─── Форма создания / редактирования ─────────────────────────────────────────

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.existing});
  final Account? existing;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _initialCtrl;
  late final TextEditingController _creditLimitCtrl;
  late String _type;
  late bool _archived;

  static const _types = <String>['cash', _accountTypeCard, 'savings', 'other'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _initialCtrl = TextEditingController(
      text: existing == null
          ? '0'
          : Money.formatPlain(existing.initialBalanceKopecks),
    );
    _creditLimitCtrl = TextEditingController(
      text: existing?.creditLimitKopecks == null
          ? ''
          : Money.formatPlain(existing!.creditLimitKopecks!),
    );
    _type = existing?.type ?? 'cash';
    _archived = existing?.isArchived ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _initialCtrl.dispose();
    _creditLimitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return MmSheet(
      title: isEdit ? 'Изменить счёт' : 'Новый счёт',
      primaryLabel: isEdit ? 'Сохранить' : 'Создать',
      onPrimary: _save,
      children: [
        MmField(
          label: 'Название',
          controller: _nameCtrl,
          hint: 'Например, Тинькофф',
          autofocus: !isEdit,
          textCapitalization: TextCapitalization.sentences,
        ),
        MmChipsField<String>(
          label: 'Тип',
          items: [
            for (final t in _types) (t, _accountTypeLabels[t] ?? t),
          ],
          selected: _type,
          onSelected: (t) => setState(() => _type = t),
        ),
        MmField(
          label: 'Начальный баланс',
          controller: _initialCtrl,
          hint: '0,00',
          suffix: '₽',
          helper: 'Для кредитной карты долг вводится со знаком минус',
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),

        // Лимит спрашиваем только у карты: у наличных и накоплений кредитного
        // лимита не бывает, и лишнее поле только путает.
        if (_type == _accountTypeCard)
          MmField(
            label: 'Кредитный лимит',
            controller: _creditLimitCtrl,
            hint: 'Пусто — это дебетовая карта',
            suffix: '₽',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),

        if (isEdit)
          MmSwitchRow(
            title: 'В архиве',
            subtitle: 'Не предлагается в новых операциях, история сохраняется',
            value: _archived,
            onChanged: (v) => setState(() => _archived = v),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      mmSnack(context, 'Введите название счёта');
      return;
    }

    final initial = Money.parseSignedToKopecks(_initialCtrl.text) ?? 0;

    // Лимит есть только у карты. При смене типа на не-карту его нужно
    // сбросить, иначе он останется висеть в базе невидимым для пользователя.
    final rawLimit = _creditLimitCtrl.text.trim();
    final creditLimit = (_type == _accountTypeCard && rawLimit.isNotEmpty)
        ? Money.parseToKopecks(rawLimit)
        : null;

    final repo = await ref.read(accountRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    final existing = widget.existing;

    if (existing != null) {
      await repo.update(
        existing.copyWith(
          name: name,
          type: _type,
          initialBalanceKopecks: initial,
          creditLimitKopecks: creditLimit,
          clearCreditLimit: creditLimit == null,
          isArchived: _archived,
          updatedAt: now,
        ),
      );
    } else {
      final session = await ref.read(bootstrapProvider.future);
      await repo.create(
        Account(
          id: const Uuid().v4(),
          familyId: session.familyId,
          name: name,
          type: _type,
          initialBalanceKopecks: initial,
          creditLimitKopecks: creditLimit,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }
}
