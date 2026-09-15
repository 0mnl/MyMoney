import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feature_flags.dart';
import '../../core/providers/api_providers.dart';
import '../../core/providers/app_providers.dart';
import '../theme/app_ui.dart';
import '../widgets/under_development.dart';
import 'accounts_screen.dart';
import 'analytics_screen.dart';
import 'categories_screen.dart';
import 'debts_screen.dart';
import 'family_screen.dart';
import 'goals_screen.dart';
import 'profile_screen.dart';
import 'subscriptions_screen.dart';
import 'sync_screen.dart';

/// Хаб приложения: профиль, все разделы и служебные настройки.
///
/// Раньше отсюда открывались только «Счета», «Категории», «Семья» и экспорт;
/// «Цели», «Долги», «Подписки» и «Статистика» существовали в коде, но ссылок
/// на них не было ни здесь, ни где-либо ещё. Теперь каждый работающий экран
/// достижим из группы «Разделы», а функции, закрытые `FeatureFlags`, видны
/// с пометкой «Скоро» — вместо того чтобы просто отсутствовать.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authSnapshotProvider);
    final groups = _groups(context);
    final filtered = _filter(groups);

    return MmScreen(
      embedded: true,
      title: 'Настройки',
      headerBottom: _SearchPill(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: kMmTabBottomInset),
        children: [
          if (_query.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProfileCard(
                isAuthed: authAsync.value != null,
                onTap: () => mmPush(context, const ProfileScreen()),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Text(
                'Ничего не найдено',
                textAlign: TextAlign.center,
                style: MmType.subhead,
              ),
            )
          else
            for (final group in filtered)
              MmGroupCard(
                title: group.title,
                children: [
                  for (var i = 0; i < group.items.length; i++)
                    MmMenuRow(
                      icon: group.items[i].icon,
                      iconBg: group.items[i].iconBg,
                      iconColor: group.items[i].iconColor,
                      title: group.items[i].title,
                      subtitle: group.items[i].subtitle,
                      trailing: group.items[i].trailing,
                      onTap: group.items[i].onTap,
                      showChevron: group.items[i].onTap != null,
                      isLast: i == group.items.length - 1,
                    ),
                ],
              ),
          if (_query.isEmpty)
            MmGroupCard(
              children: [
                _LogoutRow(
                  enabled: authAsync.value != null,
                  onTap: _logout,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Поиск работает по заголовку и подписи строки: пустые группы после
  /// фильтрации не показываются.
  List<_MenuGroup> _filter(List<_MenuGroup> groups) {
    if (_query.isEmpty) return groups;
    final result = <_MenuGroup>[];
    for (final group in groups) {
      final items = group.items
          .where((i) =>
              i.title.toLowerCase().contains(_query) ||
              (i.subtitle?.toLowerCase().contains(_query) ?? false),)
          .toList();
      if (items.isNotEmpty) {
        result.add(_MenuGroup(title: group.title, items: items));
      }
    }
    return result;
  }

  List<_MenuGroup> _groups(BuildContext context) {
    return [
      _MenuGroup(
        title: 'Разделы',
        items: [
          _MenuItem(
            icon: Icons.insights,
            iconBg: MmColors.tintIndigo,
            iconColor: MmColors.indigo,
            title: 'Статистика',
            subtitle: 'Доходы, расходы, бюджеты',
            onTap: () => mmPush(context, const AnalyticsScreen()),
          ),
          _MenuItem(
            icon: Icons.flag_outlined,
            iconBg: MmColors.tintGreen,
            iconColor: MmColors.green,
            title: 'Цели',
            subtitle: 'Накопления на крупные покупки',
            onTap: () => mmPush(context, const GoalsScreen()),
          ),
          _MenuItem(
            icon: Icons.handshake_outlined,
            iconBg: MmColors.tintRed,
            iconColor: MmColors.red,
            title: 'Долги',
            subtitle: 'Кому и сколько, график платежей',
            onTap: () => mmPush(context, const DebtsScreen()),
          ),
          _MenuItem(
            icon: Icons.autorenew,
            iconBg: MmColors.tintCyan,
            iconColor: MmColors.cyan,
            title: 'Подписки',
            subtitle: 'Регулярные списания',
            onTap: () => mmPush(context, const SubscriptionsScreen()),
          ),
        ],
      ),
      _MenuGroup(
        title: 'Справочники',
        items: [
          _MenuItem(
            icon: Icons.account_balance_wallet,
            iconBg: MmColors.tintBlue,
            iconColor: MmColors.blue,
            title: 'Счета',
            subtitle: 'Кошельки, карты, накопления',
            onTap: () => mmPush(context, const AccountsScreen()),
          ),
          _MenuItem(
            icon: Icons.category,
            iconBg: MmColors.tintOrange,
            iconColor: MmColors.orange,
            title: 'Категории',
            subtitle: 'Подкатегории и иконки',
            onTap: () => mmPush(context, const CategoriesScreen()),
          ),
        ],
      ),
      _MenuGroup(
        title: 'Данные',
        items: [
          _MenuItem(
            icon: Icons.file_download_outlined,
            iconBg: MmColors.tintRed,
            iconColor: MmColors.red,
            title: 'Экспорт отчёта',
            subtitle: 'PDF или Excel',
            trailing: FeatureFlags.fileExport ? null : 'Скоро',
            onTap: FeatureFlags.fileExport
                ? () => mmPush(context, const AnalyticsScreen())
                : () => showUnderDevelopment(context, 'Экспорт отчёта'),
          ),
          _MenuItem(
            icon: Icons.sync,
            iconBg: MmColors.tintGreen,
            iconColor: MmColors.green,
            title: 'Синхронизация',
            subtitle: 'Обмен данными с сервером',
            trailing: FeatureFlags.cloudSync ? null : 'Скоро',
            onTap: FeatureFlags.cloudSync
                ? () => mmPush(context, const SyncScreen())
                : () => showUnderDevelopment(context, 'Синхронизация'),
          ),
          _MenuItem(
            icon: Icons.people,
            iconBg: MmColors.tintPurple,
            iconColor: MmColors.purple,
            title: 'Семья',
            subtitle: 'Приглашения и общий доступ',
            trailing: FeatureFlags.family ? null : 'Скоро',
            onTap: FeatureFlags.family
                ? () => mmPush(context, const FamilyScreen())
                : () => showUnderDevelopment(context, 'Семья'),
          ),
        ],
      ),
      _MenuGroup(
        title: 'Оформление',
        items: [
          _MenuItem(
            icon: Icons.palette,
            iconBg: MmColors.tintPurple,
            iconColor: MmColors.purple,
            title: 'Тема',
            trailing: 'Светлая',
            onTap: () => showUnderDevelopment(context, 'Смена темы'),
          ),
          // Пункт «Валюта» убран намеренно: приложение работает только с
          // рублём (ADR-0002 + ADR-0006), и строка «RUB» с шевроном обещала
          // выбор, которого нет и не планируется в MVP.
        ],
      ),
      _MenuGroup(
        title: 'О приложении',
        items: [
          const _MenuItem(
            icon: Icons.info_outline,
            iconBg: MmColors.tintGrey,
            iconColor: MmColors.labelTertiary,
            title: 'Версия приложения',
            trailing: '1.0.0',
            onTap: null,
          ),
          _MenuItem(
            icon: Icons.description,
            iconBg: MmColors.tintGrey,
            iconColor: MmColors.labelTertiary,
            title: 'Условия использования',
            onTap: () => mmSnack(context, 'Условия — пока не опубликованы'),
          ),
          _MenuItem(
            icon: Icons.privacy_tip,
            iconBg: MmColors.tintIndigo,
            iconColor: MmColors.indigo,
            title: 'Политика конфиденциальности',
            onTap: () => mmSnack(context, 'Политика — пока не опубликована'),
          ),
        ],
      ),
    ];
  }

  /// Сбрасывает сессию. Гейт в `main.dart` смотрит на [authSnapshotProvider],
  /// поэтому инвалидация здесь сама подменяет всё дерево онбордингом —
  /// навигация не нужна, снекбар показывать негде.
  ///
  /// Два шага до сброса сессии — не перестраховка, а исправление двух потерь:
  ///
  ///  1. **Досылаем несинхронизированное.** Следующий вход стирает локальную
  ///     базу (`AuthenticateAndSyncUseCase._resetLocal`), чтобы забрать
  ///     состояние с сервера. Всё, что не успело уехать, этот шаг уничтожал
  ///     молча — операция, добавленная в метро перед выходом, просто
  ///     исчезала. Если сети нет, выход всё равно состоится: держать
  ///     пользователя в аккаунте из-за неудачного запроса нельзя.
  ///
  ///  2. **Стираем локальную базу.** Isar не зашифрован, и «выход» без
  ///     очистки оставлял всю историю трат лежать на устройстве в открытом
  ///     виде — включая случай, когда телефон отдают другому человеку.
  Future<void> _logout() async {
    if (FeatureFlags.cloudSync) {
      try {
        final scheduler = await ref.read(syncSchedulerProvider.future);
        await scheduler.triggerSync(reason: 'logout');
      } catch (_) {
        // Нет сети или сервер недоступен — выходим как есть.
      }
    }

    final isarService = await ref.read(isarServiceProvider.future);
    await isarService.isar.writeTxn(() => isarService.isar.clear());
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.remove('sync.last_synced_at');
    await prefs.remove('sync.last_pushed_at');
    await prefs.setBool('seeded', false);

    await ref.read(authStoreProvider).clear();
    ref.invalidate(authSnapshotProvider);
  }
}

class _MenuGroup {
  const _MenuGroup({required this.title, required this.items});
  final String title;
  final List<_MenuItem> items;
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
}

/// Поиск по настройкам. Раньше это была нарисованная «таблетка» без поля
/// ввода — теперь она действительно фильтрует список.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x28787880),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF727272), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: MmType.body,
              decoration: InputDecoration.collapsed(
                hintText: 'Поиск по настройкам',
                hintStyle: MmType.body.copyWith(color: const Color(0xFF727272)),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox(width: 20)
                : GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(Icons.close,
                        color: Color(0xFF727272), size: 20,),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.isAuthed, required this.onTap});

  final bool isAuthed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFEDEDED),
            child: Icon(
              isAuthed ? Icons.person : Icons.person_outline,
              color: MmColors.grey,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isAuthed ? 'Учётная запись' : 'Гость',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.headline,
                ),
                const SizedBox(height: 2),
                Text(
                  isAuthed ? 'Профиль и данные' : 'Войдите для доступа к профилю',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: MmColors.grey, size: 22),
        ],
      ),
    );
  }
}

class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              'Выйти',
              style: MmType.bodyStrong.copyWith(
                color: enabled ? MmColors.red : MmColors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
