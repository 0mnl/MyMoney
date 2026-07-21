import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    setState(() => _busy = true);
    try {
      final api = await ref.read(familyApiProvider.future);
      final list = await api.listMembers();
      setState(() => _members = list);
    } catch (e) {
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
      setState(() {
        _lastInviteToken = result.inviteToken;
        _lastInviteExpiresAt = result.expiresAt;
      });
    } catch (e) {
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
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = 'Не удалось принять приглашение: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Семья')),
      body: ListView(
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
                  title: Text('user ${m.userId.substring(0, 8)}…'),
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
          if (_lastInviteToken != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Токен приглашения (одноразовый):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(_lastInviteToken!),
                    const SizedBox(height: 4),
                    Text('До: $_lastInviteExpiresAt'),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _lastInviteToken!));
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
            ),
          ],
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
