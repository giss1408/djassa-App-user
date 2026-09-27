import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/providers.dart';
import 'features/shell.dart';
import 'features/sign_in_screen.dart';
import 'ui/theme.dart';

void main() {
  // Refuses to launch a release build pointed at a cleartext host.
  Env.assertHttpsInRelease();

  runApp(const ProviderScope(child: DjassaUserApp()));
}

class DjassaUserApp extends StatelessWidget {
  const DjassaUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Djassa',
      debugShowCheckedModeBanner: false,
      theme: djassaTheme(),
      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends ConsumerWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (!session.checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return session.signedIn ? const AppShell() : const SignInScreen();
  }
}
