import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/providers/api_providers.dart';
import '../../data/remote/api/family_api.dart';

/// Экран управления семьёй: список членов, форма приглашения, форма принятия
/// приглашения. Минимальный Material — под будущий Figma-макет.
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
      final api = await ref.read(familyApiProvider.future);
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
    if (email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = await ref.read(familyApiProvider.future);
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
    if (token.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = await ref.read(familyApiProvider.future);
      await api.accept(token);
      // Сессия теперь мертва: сервер отозвал refresh-токен. Чистим локально.
      await ref.read(authStoreProvider).clear();
      ref.invalidate(authSnapshotProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Готово — теперь войдите заново, чтобы получить новый family_id'),
        ));
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

    return Scaffold(
      appBar: AppBar(title: const Text('Семья')),
      body: !loggedIn
          ? const _NotLoggedInHint()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Участники', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_members == null)
                  const Center(child: CircularProgressIndicator())
                else if (_members!.isEmpty)
                  const Text('Пусто.')
                else
                  ..._members!.map((m) => ListTile(
                        leading: Icon(m.role == 'OWNER' ? Icons.star : Icons.person),
                        title: Text('user ${m.userId.length > 8 ? '${m.userId.substring(0, 8)}…' : m.userId}'),
                        subtitle: Text(m.role),
                      )),
                TextButton(
                  onPressed: _busy ? null : _refreshMembers,
                  child: const Text('Обновить список'),
                ),
                const Divider(height: 32),
                const Text('Пригласить в семью', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _inviteEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email участника',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _invite,
                    child: const Text('Создать приглашение'),
                  ),
                ),
                if (_lastInviteToken != null) _InviteResultCard(
                  token: _lastInviteToken!,
                  expiresAt: _lastInviteExpiresAt,
                ),
                const Divider(height: 32),
                const Text('Принять приглашение', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _acceptTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Токен приглашения',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _accept,
                    child: const Text('Принять'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
    );
  }
}

class _NotLoggedInHint extends StatelessWidget {
  const _NotLoggedInHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Чтобы пригласить второго участника, войдите в аккаунт '
          'на вкладке «Настройки».',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _InviteResultCard extends StatelessWidget {
  const _InviteResultCard({required this.token, required this.expiresAt});

  final String token;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Токен приглашения (одноразовый):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Center(
              child: QrImageView(
                data: token,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              token,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            if (expiresAt != null) ...[
              const SizedBox(height: 4),
              Text('Действителен до: $expiresAt',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: token));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Скопировано')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Скопировать'),
            ),
          ],
        ),
      ),
    );
  }
}
