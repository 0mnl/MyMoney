import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/api_providers.dart';
import '../../core/providers/app_providers.dart';
import '../../sync/sync_scheduler.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

const _bgBeige = Color(0xFFF4EDE3);
const _labelsPrimary = Colors.black;
const _grey = Color(0xFF9E9E9E);
const _searchFill = Color(0x28787880);
const _searchLabel = Color(0xFF727272);

// Tab indices — keep in sync with _HomeShellState._tabs.
const int _tabAccounts = 1;
const int _tabTransactions = 2;
const int _tabAnalytics = 7;
const int _tabFamily = 8;

/// Экран настроек по Figma-макету. Внутри — все существующие
/// администраторские функции (URL бэкенда, вход, ручной sync, выход).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authSnapshotProvider);
    final schedulerAsync = ref.watch(syncSchedulerProvider);
    final statusAsync = ref.watch(syncStatusProvider);

    return Container(
      color: _bgBeige,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Text(
                  'Настройки',
                  style: TextStyle(
                    color: _labelsPrimary,
                    fontSize: 34,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                    height: 1.21,
                    letterSpacing: 0.40,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _SearchPill(),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ProfileCard(
                  authAsync: authAsync,
                  onTap: () => _openLoginOrProfile(context, ref, authAsync),
                ),
              ),
              const SizedBox(height: 16),
              _GroupCard(
                rows: [
                  _MenuRow(
                    icon: Icons.account_balance_wallet,
                    iconBg: const Color(0xFFE8F0FF),
                    iconColor: const Color(0xFF0088FF),
                    title: 'Счета',
                    onTap: () => _switchTab(ref, _tabAccounts),
                  ),
                  _MenuRow(
                    icon: Icons.category,
                    iconBg: const Color(0xFFFFF3E0),
                    iconColor: const Color(0xFFFF9500),
                    title: 'Категории',
                    onTap: () => _switchTab(ref, _tabTransactions),
                  ),
                  _MenuRow(
                    icon: Icons.people,
                    iconBg: const Color(0xFFE7F8EE),
                    iconColor: const Color(0xFF34C759),
                    title: 'Семья',
                    trailing: authAsync.maybeWhen(
                      data: (snap) => snap == null ? 'Не подключено' : '',
                      orElse: () => '',
                    ),
                    onTap: () => _switchTab(ref, _tabFamily),
                    isLast: true,
                  ),
                ],
              ),
              _GroupCard(
                rows: [
                  _MenuRow(
                    icon: Icons.dns,
                    iconBg: const Color(0xFFEDEDF7),
                    iconColor: const Color(0xFF6155F5),
                    title: 'Бэкенд',
                    trailing: '',
                    onTap: () => _openBackendSheet(context, ref),
                  ),
                  _MenuRow(
                    icon: Icons.cloud_upload,
                    iconBg: const Color(0xFFE0F7FA),
                    iconColor: const Color(0xFF00C0E8),
                    title: 'Резервное копирование',
                    trailing: _lastSyncLabel(statusAsync.value),
                    onTap: () => _triggerSync(context, schedulerAsync, authAsync),
                  ),
                  _MenuRow(
                    icon: Icons.picture_as_pdf,
                    iconBg: const Color(0xFFFDECEC),
                    iconColor: const Color(0xFFFF383C),
                    title: 'Экспорт в PDF',
                    onTap: () => _switchTab(ref, _tabAnalytics),
                    isLast: true,
                  ),
                ],
              ),
              _GroupCard(
                rows: [
                  _MenuRow(
                    icon: Icons.palette,
                    iconBg: const Color(0xFFF3E5F5),
                    iconColor: const Color(0xFF9C27B0),
                    title: 'Тема',
                    trailing: 'Светлая',
                    onTap: () => _notImplemented(context, 'Смена темы'),
                  ),
                  _MenuRow(
                    icon: Icons.currency_exchange,
                    iconBg: const Color(0xFFE8F5E9),
                    iconColor: const Color(0xFF34C759),
                    title: 'Валюта',
                    trailing: 'RUB',
                    onTap: () => _notImplemented(context, 'Смена валюты'),
                    isLast: true,
                  ),
                ],
              ),
              const _GroupCard(
                rows: [
                  _MenuRow(
                    icon: Icons.info_outline,
                    iconBg: Color(0xFFEEEEEE),
                    iconColor: Color(0xFF757575),
                    title: 'Версия приложения',
                    trailing: '1.0.0',
                    onTap: null,
                    showChevron: false,
                  ),
                  _TermsRow(),
                  _PrivacyRow(),
                ],
              ),
              _GroupCard(
                rows: [
                  _LogoutRow(
                    enabled: authAsync.maybeWhen(
                      data: (snap) => snap != null,
                      orElse: () => false,
                    ),
                    onTap: () => _logout(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _switchTab(WidgetRef ref, int index) {
    ref.read(homeShellTabProvider.notifier).state = index;
  }

  static String _lastSyncLabel(SyncStatus? status) {
    if (status == null) return 'Не выполнено';
    switch (status.phase) {
      case SyncPhase.syncing:
        return 'Идёт…';
      case SyncPhase.offline:
        return 'Оффлайн';
      case SyncPhase.error:
        return 'Ошибка';
      case SyncPhase.idle:
        final ts = status.lastSyncedAt;
        if (ts == null) return 'Не выполнено';
        final today = DateTime.now();
        final isToday =
            ts.year == today.year && ts.month == today.month && ts.day == today.day;
        final time = DateFormat.Hm('ru_RU').format(ts);
        return isToday ? 'Сегодня, $time' : '${DateFormat.yMd('ru_RU').format(ts)}, $time';
    }
  }

  static Future<void> _openLoginOrProfile(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Object?> authAsync,
  ) async {
    final snap = authAsync.value;
    if (snap == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
    );
  }

  static Future<void> _openBackendSheet(BuildContext context, WidgetRef ref) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final current = await ref.read(apiBaseUrlProvider.future);
    if (!context.mounted) return;
    final controller = TextEditingController(text: current);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'URL бэкенда',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://10.0.2.2:8080',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await setApiBaseUrl(prefs, controller.text);
                ref.invalidate(apiBaseUrlProvider);
                ref.invalidate(apiClientProvider);
                ref.invalidate(authApiProvider);
                ref.invalidate(familyApiProvider);
                ref.invalidate(syncApiProvider);
                ref.invalidate(syncManagerProvider);
                ref.invalidate(syncSchedulerProvider);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL сохранён')),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _triggerSync(
    BuildContext context,
    AsyncValue<SyncScheduler> schedulerAsync,
    AsyncValue<Object?> authAsync,
  ) async {
    final scheduler = schedulerAsync.value;
    if (scheduler == null || authAsync.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала войдите в учётную запись')),
      );
      return;
    }
    final ok = await scheduler.triggerSync();
    if (!context.mounted) return;
    final s = scheduler.status;
    final msg = ok
        ? (s.lastResult == null
            ? 'Синхронизация завершена'
            : 'Готово: отправлено ${s.lastResult!.pushed}, получено ${s.lastResult!.pulled}')
        : (s.phase == SyncPhase.offline ? 'Нет соединения' : 'Пропущено');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authStoreProvider).clear();
    ref.invalidate(authSnapshotProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Вы вышли из учётной записи')),
    );
  }

  static void _notImplemented(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what — пока не реализовано')),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _searchFill,
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, color: _searchLabel, size: 20),
          SizedBox(width: 8),
          Text(
            'Search',
            style: TextStyle(
              color: _searchLabel,
              fontSize: 17,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
              height: 1.29,
              letterSpacing: -0.08,
            ),
          ),
          Spacer(),
          Icon(Icons.mic, color: _searchLabel, size: 20),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.authAsync, required this.onTap});
  final AsyncValue<Object?> authAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAuthed = authAsync.value != null;
    final title = isAuthed ? 'Учётная запись' : 'Гость';
    final subtitle = isAuthed
        ? 'Аккаунт, синхронизация и другое'
        : 'Войдите, чтобы включить синхронизацию';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(34),
        child: Ink(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 48,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFEDEDED),
                child: Icon(
                  isAuthed ? Icons.person : Icons.person_outline,
                  color: _grey,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w400,
                        height: 1.38,
                        letterSpacing: -0.08,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _grey, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.trailing,
    required this.onTap,
    this.isLast = false,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  final bool isLast;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: Color(0x1F000000), width: 1),
                  ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _labelsPrimary,
                    fontSize: 17,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                    height: 1.29,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
              if (trailing != null && trailing!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _grey,
                    fontSize: 15,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                    height: 1.33,
                    letterSpacing: -0.23,
                  ),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: _grey, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow();

  @override
  Widget build(BuildContext context) {
    return _MenuRow(
      icon: Icons.description,
      iconBg: const Color(0xFFF3F4F6),
      iconColor: const Color(0xFF6B7280),
      title: 'Условия использования',
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Условия использования — пока не опубликованы')),
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow();

  @override
  Widget build(BuildContext context) {
    return _MenuRow(
      icon: Icons.privacy_tip,
      iconBg: const Color(0xFFEFEFFB),
      iconColor: const Color(0xFF6155F5),
      title: 'Политика конфиденциальности',
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Политика — пока не опубликована')),
      ),
      isLast: true,
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
              style: TextStyle(
                color: enabled ? _accentRed : _grey,
                fontSize: 17,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
                height: 1.29,
                letterSpacing: -0.43,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _accentRed = Color(0xFFFF383C);
