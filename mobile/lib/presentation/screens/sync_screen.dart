import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/api_providers.dart';
import '../../sync/sync_scheduler.dart';
import '../theme/app_ui.dart';

/// Состояние облачной синхронизации и ручной запуск цикла.
///
/// `SyncScheduler.triggerSync()` и `syncStatusProvider` существовали, но точки
/// входа в интерфейсе у них не было — статус синхронизации нельзя было ни
/// увидеть, ни запустить вручную. Экран открывается из «Настройки → Данные →
/// Синхронизация» и только когда включён `FeatureFlags.cloudSync`: без него
/// планировщик не стартует и показывать было бы нечего.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(syncStatusProvider);
    final authAsync = ref.watch(authSnapshotProvider);

    return MmScreen(
      title: 'Синхронизация',
      subtitle: 'Обмен данными с сервером',
      child: statusAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (status) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _phaseColor(status.phase),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_phaseLabel(status.phase), style: MmType.subhead),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status.lastSyncedAt == null
                        ? 'Ещё не синхронизировано'
                        : DateFormat('d MMMM y, HH:mm', 'ru_RU')
                            .format(status.lastSyncedAt!.toLocal()),
                    style: MmType.headline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            MmPrimaryButton(
              label: 'Синхронизировать сейчас',
              icon: Icons.sync,
              loading: _busy || status.phase == SyncPhase.syncing,
              onPressed: _busy ? null : _syncNow,
            ),
            const SizedBox(height: 24),
            MmGroupCard(
              title: 'Последний цикл',
              margin: EdgeInsets.zero,
              children: [
                MmMenuRow(
                  icon: Icons.upload_outlined,
                  iconBg: MmColors.tintBlue,
                  iconColor: MmColors.blue,
                  title: 'Отправлено',
                  trailing: '${status.lastResult?.pushed ?? 0}',
                  showChevron: false,
                  onTap: null,
                ),
                MmMenuRow(
                  icon: Icons.download_outlined,
                  iconBg: MmColors.tintGreen,
                  iconColor: MmColors.green,
                  title: 'Получено',
                  trailing: '${status.lastResult?.pulled ?? 0}',
                  showChevron: false,
                  onTap: null,
                ),
                MmMenuRow(
                  icon: Icons.merge_type,
                  iconBg: MmColors.tintOrange,
                  iconColor: MmColors.orange,
                  title: 'Конфликтов',
                  subtitle: 'Разрешены по правилу «побеждает последний»',
                  trailing: '${status.lastResult?.conflicts ?? 0}',
                  showChevron: false,
                  onTap: null,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Адрес сервера здесь не показывается намеренно: это деталь
            // хостинга, повлиять на которую из приложения нельзя, а знать —
            // незачем. Осталось только то, что пользователю пригодится:
            // жива ли сессия.
            MmGroupCard(
              title: 'Подключение',
              margin: EdgeInsets.zero,
              children: [
                MmMenuRow(
                  icon: Icons.person_outline,
                  iconBg: MmColors.tintIndigo,
                  iconColor: MmColors.indigo,
                  title: 'Сессия',
                  trailing:
                      authAsync.value == null ? 'Не выполнен вход' : 'Активна',
                  showChevron: false,
                  onTap: null,
                  isLast: true,
                ),
              ],
            ),
            if (status.lastError != null) ...[
              const SizedBox(height: 16),
              Text(
                'Последняя ошибка: ${status.lastError}',
                style: MmType.caption.copyWith(color: MmColors.red),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Локальная база остаётся источником истины на устройстве. '
              'Сервер нужен, чтобы данные видели другие участники семьи.',
              style: MmType.caption,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      final scheduler = await ref.read(syncSchedulerProvider.future);
      final ran = await scheduler.triggerSync();
      if (mounted && !ran) {
        mmSnack(context, 'Синхронизация пропущена: нет сети или цикл уже идёт');
      }
    } catch (e) {
      if (mounted) mmSnack(context, 'Не удалось синхронизировать: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _phaseLabel(SyncPhase phase) => switch (phase) {
        SyncPhase.idle => 'Последняя синхронизация',
        SyncPhase.syncing => 'Идёт синхронизация…',
        SyncPhase.offline => 'Нет сети',
        SyncPhase.error => 'Ошибка синхронизации',
      };

  static Color _phaseColor(SyncPhase phase) => switch (phase) {
        SyncPhase.idle => MmColors.green,
        SyncPhase.syncing => MmColors.blue,
        SyncPhase.offline => MmColors.grey,
        SyncPhase.error => MmColors.red,
      };
}
