import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_providers.dart';
import '../../core/providers/app_providers.dart';
import '../../sync/sync_scheduler.dart';
import 'login_screen.dart';

/// Экран настроек: подключение к бэкенду, ручной sync, выход.
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
    final schedulerAsync = ref.watch(syncSchedulerProvider);
    final statusAsync = ref.watch(syncStatusProvider);
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
                      ref.invalidate(syncSchedulerProvider);
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
          _SyncPanel(
            schedulerAsync: schedulerAsync,
            statusAsync: statusAsync,
            authAsync: authAsync,
          ),
        ],
      ),
    );
  }
}

class _SyncPanel extends StatelessWidget {
  const _SyncPanel({
    required this.schedulerAsync,
    required this.statusAsync,
    required this.authAsync,
  });

  final AsyncValue<SyncScheduler> schedulerAsync;
  final AsyncValue<SyncStatus> statusAsync;
  final AsyncValue<Object?> authAsync;

  @override
  Widget build(BuildContext context) {
    return schedulerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Ошибка: $e'),
      data: (scheduler) {
        final status = statusAsync.value ?? scheduler.status;
        final lastSynced = status.lastSyncedAt;
        final result = status.lastResult;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              switch (status.phase) {
                SyncPhase.idle => lastSynced == null
                    ? 'Ещё не синхронизировано'
                    : 'Последняя синхронизация: $lastSynced',
                SyncPhase.syncing => 'Идёт синхронизация…',
                SyncPhase.offline => 'Нет соединения — работаете офлайн',
                SyncPhase.error => 'Последняя попытка не удалась: ${status.lastError}',
              },
            ),
            if (result != null) ...[
              const SizedBox(height: 4),
              Text(
                'Последний цикл: отправлено ${result.pushed}, получено ${result.pulled}, '
                'конфликтов ${result.conflicts}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: authAsync.value == null
                  ? null
                  : () async {
                      final ok = await scheduler.triggerSync();
                      if (context.mounted) {
                        final s = scheduler.status;
                        final msg = ok
                            ? (s.lastResult == null
                                ? 'Синхронизация завершена'
                                : 'Готово: ${s.lastResult}')
                            : (s.phase == SyncPhase.offline
                                ? 'Нет соединения'
                                : 'Пропущено');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                      }
                    },
              child: const Text('Синхронизировать сейчас'),
            ),
          ],
        );
      },
    );
  }
}
