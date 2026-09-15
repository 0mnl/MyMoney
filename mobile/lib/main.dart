import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/providers/api_providers.dart';
import 'core/providers/app_providers.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/onboarding/splash_screen.dart';
import 'presentation/screens/onboarding/welcome_screen.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  runApp(const ProviderScope(child: MyMoneyApp()));
}

class MyMoneyApp extends StatelessWidget {
  const MyMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyMoney',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: const Locale('ru'),
      home: const _AuthGate(),
    );
  }
}

/// Decides what the app shows at all: the onboarding flow or the shell.
///
/// Authentication is mandatory — without a session in secure storage the user
/// only ever reaches "Добро пожаловать". Because the gate watches
/// [authSnapshotProvider], logging out anywhere in the app drops straight back
/// here, and confirming a registration swaps in the shell without any explicit
/// navigation.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authSnapshotProvider);

    return auth.when(
      loading: () => const SplashScreen(),
      // Reading secure storage failed — treat it as "no session" rather than
      // wedging the user on an error screen they cannot act on.
      error: (_, __) => const WelcomeScreen(),
      data: (snapshot) =>
          snapshot == null ? const WelcomeScreen() : const _Boot(),
    );
  }
}

/// Waits for the local seed/migration to finish before showing the shell.
/// Keeps the user on the splash instead of an empty UI while the authenticated
/// family's data is being prepared.
class _Boot extends ConsumerWidget {
  const _Boot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);

    // Поднимаем планировщик синхронизации. Состояние намеренно не
    // проверяется: обмен с сервером идёт фоном и не должен задерживать
    // показ интерфейса ни на секунду — приложение работает и без сети.
    ref.watch(syncBootstrapProvider);

    return bootstrap.when(
      loading: () => const SplashScreen(),
      error: (e, _) => Scaffold(body: Center(child: Text('Не удалось запустить: $e'))),
      data: (_) => const HomeShell(),
    );
  }
}
