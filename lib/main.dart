import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/monitoring/error_reporter.dart';
import 'core/monitoring/usage_tracker.dart';
import 'core/providers.dart';
import 'features/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Refuses to launch a release build pointed at a cleartext host.
  Env.assertHttpsInRelease();

  final reporter = ErrorReporter(app: 'user')..install();
  // Installs and what is seen, never tied to the customer's account.
  final usage = UsageTracker(app: 'user');
  runApp(ProviderScope(overrides: [usageTrackerProvider.overrideWithValue(usage)], child: const DjassaUserApp()));
  // Whatever an earlier session could not send goes now, once.
  unawaited(reporter.flush());
  unawaited(usage.start());
}

class DjassaUserApp extends ConsumerWidget {
  const DjassaUserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Djassa',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [ref.read(usageTrackerProvider).navigatorObserver],
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
    // Signed in or not: offers, shops and pharmacies are for everyone, and
    // sign-in opens over the app when paying or points need it. The shell
    // reports its tabs itself.
    return const AppShell();
  }
}
