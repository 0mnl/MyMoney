import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_providers.dart';

/// Минимальный экран входа/регистрации. Используется дважды в одной форме:
/// один тумблер выбирает режим. Успешный вход выполняет reset local + sync
/// внутри AuthenticateAndSyncUseCase.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? 'Регистрация' : 'Вход')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Войти')),
                ButtonSegment(value: true, label: Text('Регистрация')),
              ],
              selected: {_isRegister},
              onSelectionChanged: (s) => setState(() {
                _isRegister = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Пароль (мин. 8 символов)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRegister ? 'Зарегистрироваться' : 'Войти'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final usecase = await ref.read(authenticateAndSyncProvider.future);
      final snap = _isRegister
          ? await usecase.register(_emailController.text.trim(), _passwordController.text)
          : await usecase.login(_emailController.text.trim(), _passwordController.text);
      await ref.read(authSnapshotProvider.notifier).setSession(snap);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
