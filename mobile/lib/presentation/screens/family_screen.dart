import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/providers/api_providers.dart';
import '../../data/remote/api/family_api.dart';
import '../theme/app_ui.dart';

/// Управление семьёй: участники, создание приглашения (токен + QR) и приём
/// чужого приглашения.
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final _inviteEmailController = TextEditingController();
  final _acceptTokenController = TextEditingController();

  List<FamilyMemberDto>? _members;
  String? _lastInviteToken;
  DateTime? _lastInviteExpiresAt;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMembers());
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    _acceptTokenController.dispose();
    super.dispose();
  }

  Future<void> _refreshMembers() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(familyApiProvider);
      final list = await api.listMembers();
      if (!mounted) return;
      setState(() => _members = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось получить список: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty) {
      mmSnack(context, 'Введите email участника');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(familyApiProvider);
      final result = await api.invite(email);
      if (!mounted) return;
      setState(() {
        _lastInviteToken = result.inviteToken;
        _lastInviteExpiresAt = result.expiresAt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось создать приглашение: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    final token = _acceptTokenController.text.trim();
    if (token.isEmpty) {
      mmSnack(context, 'Вставьте токен приглашения');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(familyApiProvider);
      await api.accept(token);
      // Сессия теперь мертва: сервер отозвал refresh-токен. Чистим локально.
      await ref.read(authStoreProvider).clear();
      ref.invalidate(authSnapshotProvider);
      if (mounted) {
        mmSnack(
          context,
          'Готово — войдите заново, чтобы получить новый family_id',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось принять приглашение: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authSnapshotProvider);
    final loggedIn = authAsync.value != null;

    return MmScreen(
      title: 'Семья',
      subtitle: 'Общий доступ к операциям',
      trailing: MmCircleButton(
        icon: Icons.refresh,
        tooltip: 'Обновить список',
        onTap: _busy ? () {} : _refreshMembers,
      ),
      child: !loggedIn
          ? const MmEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Нужен вход в аккаунт',
              message: 'Чтобы пригласить второго участника, '
                  'войдите в аккаунт на вкладке «Настройки».',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                const MmSectionHeader(title: 'Участники'),
                const SizedBox(height: 12),
                if (_members == null)
                  const MmLoading()
                else if (_members!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Пока никого нет.', style: MmType.subhead),
                  )
                else
                  MmGroupCard(
                    children: [
                      for (var i = 0; i < _members!.length; i++)
                        MmMenuRow(
                          icon: _members![i].role == 'OWNER'
                              ? Icons.star
                              : Icons.person,
                          iconBg: _members![i].role == 'OWNER'
                              ? MmColors.tintYellow
                              : MmColors.tintBlue,
                          iconColor: _members![i].role == 'OWNER'
                              ? MmColors.yellow
                              : MmColors.blue,
                          title: _shortId(_members![i].userId),
                          trailing: _members![i].role,
                          showChevron: false,
                          onTap: null,
                          isLast: i == _members!.length - 1,
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                const MmSectionHeader(title: 'Пригласить'),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MmField(
                        label: 'Email участника',
                        controller: _inviteEmailController,
                        hint: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      MmPrimaryButton(
                        label: 'Создать приглашение',
                        loading: _busy,
                        onPressed: _busy ? null : _invite,
                      ),
                    ],
                  ),
                ),
                if (_lastInviteToken != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _InviteCard(
                      token: _lastInviteToken!,
                      expiresAt: _lastInviteExpiresAt,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const MmSectionHeader(title: 'Принять приглашение'),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MmField(
                        label: 'Токен приглашения',
                        controller: _acceptTokenController,
                        hint: 'Вставьте код из приглашения',
                        helper: 'После принятия нужно будет войти заново — '
                            'сервер выдаёт новый family_id',
                      ),
                      MmSecondaryButton(
                        label: 'Принять',
                        icon: Icons.login,
                        onPressed: _busy ? null : _accept,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      style: MmType.subhead.copyWith(color: MmColors.red),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  static String _shortId(String userId) =>
      userId.length > 8 ? 'user ${userId.substring(0, 8)}…' : 'user $userId';
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.token, required this.expiresAt});

  final String token;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      radius: 24,
      shadows: MmShadows.tile,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Одноразовый токен приглашения', style: MmType.bodyStrong),
          const SizedBox(height: 12),
          Center(
            child: QrImageView(
              data: token,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            token,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Действителен до '
              '${DateFormat('d MMMM y, HH:mm', 'ru_RU').format(expiresAt!.toLocal())}',
              textAlign: TextAlign.center,
              style: MmType.caption,
            ),
          ],
          const SizedBox(height: 12),
          MmSecondaryButton(
            label: 'Скопировать',
            icon: Icons.copy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (context.mounted) mmSnack(context, 'Скопировано');
            },
          ),
        ],
      ),
    );
  }
}
