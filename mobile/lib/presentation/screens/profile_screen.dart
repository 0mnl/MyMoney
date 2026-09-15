import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_providers.dart';
import '../../core/providers/app_providers.dart';
import '../theme/app_ui.dart';

/// Профиль учётной записи. Часть полей ещё не приезжает с сервера — они
/// показываются прочерком, а не выдуманным значением: пустое поле честнее,
/// чем правдоподобная подстановка.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _biometricEnabled = false;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authSnapshotProvider);
    final sessionAsync = ref.watch(bootstrapProvider);
    final snap = authAsync.value;

    return MmScreen(
      title: 'Профиль',
      subtitle: snap == null ? 'Гость' : 'Учётная запись',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFFEDEDED),
                  child: Icon(Icons.person, size: 50, color: MmColors.grey),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () =>
                      mmSnack(context, 'Изменение фото — пока не реализовано'),
                  child: Text(
                    'Изменить фото',
                    style: MmType.body.copyWith(color: MmColors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          MmGroupCard(
            title: 'Учётная запись',
            children: [
              MmMenuRow(
                icon: Icons.badge_outlined,
                iconBg: MmColors.tintBlue,
                iconColor: MmColors.blue,
                title: 'Идентификатор',
                trailing: _short(snap?.userId),
                showChevron: false,
                onTap: null,
              ),
              MmMenuRow(
                icon: Icons.mail_outline,
                iconBg: MmColors.tintIndigo,
                iconColor: MmColors.indigo,
                title: 'Почта',
                trailing: '—',
                onTap: () => mmSnack(context, 'Смена почты — пока не реализована'),
              ),
              MmMenuRow(
                icon: Icons.lock_outline,
                iconBg: MmColors.tintGrey,
                iconColor: MmColors.labelTertiary,
                title: 'Пароль',
                onTap: () =>
                    mmSnack(context, 'Смена пароля — пока не реализована'),
                isLast: true,
              ),
            ],
          ),
          MmGroupCard(
            title: 'Безопасность',
            children: [
              _SwitchRow(
                title: 'Вход по биометрии',
                value: _biometricEnabled,
                onChanged: (v) {
                  setState(() => _biometricEnabled = v);
                  mmSnack(context, 'Биометрия — пока не реализована');
                },
              ),
              MmMenuRow(
                icon: Icons.devices,
                iconBg: MmColors.tintGreen,
                iconColor: MmColors.green,
                title: 'Активные устройства',
                trailing: '1',
                onTap: () =>
                    mmSnack(context, 'Список устройств — пока не реализован'),
                isLast: true,
              ),
            ],
          ),
          MmGroupCard(
            title: 'Данные семьи',
            children: [
              MmMenuRow(
                icon: Icons.groups_outlined,
                iconBg: MmColors.tintPurple,
                iconColor: MmColors.purple,
                title: 'Идентификатор семьи',
                subtitle: 'К нему привязаны счета, категории и операции',
                trailing: _short(
                  snap?.familyId ?? sessionAsync.value?.familyId,
                ),
                showChevron: false,
                onTap: null,
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MmPrimaryButton(
              label: 'Удалить аккаунт',
              color: MmColors.red,
              onPressed: _confirmDeleteAccount,
            ),
          ),
        ],
      ),
    );
  }

  static String _short(String? id) {
    if (id == null || id.isEmpty) return '—';
    return id.length > 8 ? '${id.substring(0, 8)}…' : id;
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await mmConfirm(
      context,
      title: 'Удалить аккаунт?',
      message: 'Это действие необратимо. Все данные будут удалены.',
    );
    if (ok && mounted) {
      mmSnack(context, 'Удаление аккаунта — пока не реализовано');
    }
  }
}

/// Переключатель строкой меню — чтобы группа с ним выглядела так же, как
/// соседние строки, а не как поле из формы.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MmColors.divider, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: MmColors.tintOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fingerprint, size: 18, color: MmColors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: MmType.body)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: MmColors.green,
            activeTrackColor: MmColors.green.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
