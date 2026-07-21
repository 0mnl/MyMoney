import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_providers.dart';
import '../../core/providers/app_providers.dart';
import '../../sync/sync_manager.dart';
import 'family_screen.dart';
import 'login_screen.dart';

/// Экран настроек: подключение к бэкенду, ручной sync, семья, выход.
/// Минимальный Material — под будущий Figma-макет.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _urlLoaded = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseUrlAsync = ref.watch(apiBaseUrlProvider);
    final authAsync = ref.watch(authSnapshotProvider);
    final syncManagerAsync = ref.watch(syncManagerProvider);
    final prefsAsync = ref.watch(sharedPrefsProvider);

    baseUrlAsync.whenData((url) {
      if (!_urlLoaded) {
        _urlController.text = url;
        _urlLoaded = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Бэкенд', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL бэкенда',
              hintText: 'http://10.0.2.2:8080',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: prefsAsync.hasValue
                  ? () async {
                      await setApiBaseUrl(prefsAsync.value!, _urlController.text);
                      ref.invalidate(apiBaseUrlProvider);
                      ref.invalidate(apiClientProvider);
                      ref.invalidate(authApiProvider);
                      ref.invalidate(familyApiProvider);
                      ref.invalidate(syncApiProvider);
                      ref.invalidate(syncManagerProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('URL сохранён')));
                      }
                    }
                  : null,
              child: const Text('Сохранить URL'),
            ),
          ),
          const Divider(height: 32),
          const Text('Учётная запись', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          authAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Ошибка: $e'),
            data: (snap) {
              if (snap == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Не подключено — работаете офлайн.'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Войти / Зарегистрироваться'),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('userId: ${snap.userId}'),
                  Text('familyId: ${snap.familyId}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(authStoreProvider).clear();
                      ref.invalidate(authSnapshotProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Вы вышли из учётной записи')));
                      }
                    },
                    child: const Text('Выйти'),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          const Text('Синхронизация', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          syncManagerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Ошибка: $e'),
            data: (manager) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(manager.lastSyncedAt == null
                    ? 'Ещё не синхронизировано'
                    : 'Последняя синхронизация: ${manager.lastSyncedAt}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: authAsync.value == null
                      ? null
                      : () => _runSync(context, manager),
                  child: const Text('Синхронизировать сейчас'),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          const Text('Семья', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: authAsync.value == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const FamilyScreen()),
                    ),
            child: const Text('Управление семьёй'),
          ),
        ],
      ),
    );
  }

  Future<void> _runSync(BuildContext context, SyncManager manager) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Синхронизация…')));
    try {
      final result = await manager.sync();
      setState(() {}); // refresh lastSyncedAt label
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Готово: pushed=${result.pushed}, pulled=${result.pulled}, conflicts=${result.conflicts}',
        ),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Ошибка синхронизации: $e')));
    }
  }
}
