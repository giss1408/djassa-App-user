import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/monitoring/error_reporter.dart';
import 'core/monitoring/usage_tracker.dart';
import 'core/providers.dart';
import 'features/shell.dart';
import 'features/sign_in_screen.dart';
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
    // The shell reports its tabs itself.
    return session.signedIn ? const AppShell() : const _SignInTracked();
  }
}

/// Records the sign-in screen, which is swapped in rather than pushed.
class _SignInTracked extends ConsumerStatefulWidget {
  const _SignInTracked();

  @override
  ConsumerState<_SignInTracked> createState() => _SignInTrackedState();
}

class _SignInTrackedState extends ConsumerState<_SignInTracked> {
  @override
  void initState() {
    super.initState();
    ref.read(usageTrackerProvider).screen('sign_in');
  }

  @override
  Widget build(BuildContext context) => const SignInScreen();
}
