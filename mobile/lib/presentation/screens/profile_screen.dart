import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_providers.dart';

const _bgBeige = Color(0xFFF4EDE3);
const _labelsPrimary = Colors.black;
const _grey = Color(0xFF9E9E9E);
const _accentBlue = Color(0xFF0088FF);
const _accentRed = Color(0xFFFF383C);
const _accentGreen = Color(0xFF34C759);

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
    final snap = authAsync.value;
    final userId = (snap as dynamic)?.userId as String? ?? '—';

    return Scaffold(
      backgroundColor: _bgBeige,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.chevron_left,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Настройки',
                    style: TextStyle(
                      color: _labelsPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.45,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Text(
                        'Профиль',
                        style: TextStyle(
                          color: _labelsPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 50,
                            backgroundColor: Color(0xFFEDEDED),
                            child: Icon(Icons.person, size: 50, color: _grey),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {},
                            child: const Text(
                              'Изменить фото',
                              style: TextStyle(
                                color: _accentBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.31,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ProfileCard(
                      children: [
                        _ProfileRow(
                          label: 'Имя и фамилия',
                          value: userId,
                          onTap: () {},
                          showChevron: true,
                          showDivider: true,
                        ),
                        _ProfileRow(
                          label: 'Почта',
                          value: '—',
                          onTap: () {},
                          showChevron: true,
                          showDivider: true,
                        ),
                        _ProfileRow(
                          label: 'Пароль',
                          value: '',
                          onTap: () {},
                          showChevron: true,
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ProfileCard(
                      children: [
                        _ProfileRowWithSwitch(
                          label: 'Вход по биометрии',
                          value: _biometricEnabled,
                          onChanged: (v) => setState(() => _biometricEnabled = v),
                          showDivider: true,
                        ),
                        _ProfileRow(
                          label: 'Активные устройства',
                          value: '1',
                          onTap: () {},
                          showChevron: true,
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _ProfileCard(
                      children: [
                        _ProfileRow(
                          label: 'Дата регистрации',
                          value: '—',
                          onTap: null,
                          showChevron: false,
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton(
                          onPressed: () => _confirmDeleteAccount(context),
                          style: TextButton.styleFrom(
                            backgroundColor: _accentRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(1000),
                            ),
                          ),
                          child: const Text(
                            'Удалить аккаунт',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text('Это действие необратимо. Все данные будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: _accentRed),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Удаление аккаунта — пока не реализовано')),
      );
    }
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: Color(0xFFE8E8E8),
              blurRadius: 0,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF1A1A1A), size: 22),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.showChevron,
    required this.showDivider,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 45,
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _labelsPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.43,
                  ),
                ),
                const Spacer(),
                if (value.isNotEmpty)
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _grey,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.43,
                      ),
                    ),
                  ),
                if (showChevron) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: _grey, size: 20),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0x1F000000)),
      ],
    );
  }
}

class _ProfileRowWithSwitch extends StatelessWidget {
  const _ProfileRowWithSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.showDivider,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 45,
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _labelsPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.43,
                ),
              ),
              const Spacer(),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: _accentGreen,
              activeTrackColor: _accentGreen.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0x1F000000)),
      ],
    );
  }
}
