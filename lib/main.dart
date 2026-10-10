import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/monitoring/error_reporter.dart';
import 'core/monitoring/usage_tracker.dart';
import 'core/providers.dart';
import 'core/push/firebase_push.dart';
import 'core/push/offer_alerts.dart';
import 'features/shell.dart';
import 'features/venue_screen.dart';
import 'l10n/strings.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Refuses to launch a release build pointed at a cleartext host.
  Env.assertHttpsInRelease();

  final reporter = ErrorReporter(app: 'user')..install();
  // Installs and what is seen, never tied to the customer's account.
  final usage = UsageTracker(app: 'user');
  // Offer alerts, only in a build that carries a Firebase project. Starting
  // Firebase is local work (no network), so the launch does not wait on a cell.
  final push = await startFirebasePush();
  runApp(ProviderScope(
    overrides: [
      usageTrackerProvider.overrideWithValue(usage),
      if (push != null) pushGatewayProvider.overrideWithValue(push),
    ],
    child: FideliaUserApp(pushEnabled: push != null),
  ));
  // Whatever an earlier session could not send goes now, once.
  unawaited(reporter.flush());
  unawaited(usage.start());
}

class FideliaUserApp extends ConsumerStatefulWidget {
  const FideliaUserApp({super.key, this.pushEnabled = false});

  /// Whether Firebase started, so alert taps can be listened to.
  final bool pushEnabled;

  @override
  ConsumerState<FideliaUserApp> createState() => _FideliaUserAppState();
}

class _FideliaUserAppState extends ConsumerState<FideliaUserApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Subscriptions a previous session could not finish (no network) are
    // retried now.
    unawaited(ref.read(offerAlertsProvider.notifier).resume());
    if (widget.pushEnabled) _listenToAlerts();
  }

  void _listenToAlerts() {
    // Tapped while the app was in the background.
    FirebaseMessaging.onMessageOpenedApp.listen(_opened);
    // Tapped while the app was closed: wait for the first frame, so there is a
    // navigator to open the shop with.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) _opened(first);
    });
    // In the foreground Android shows nothing by itself: a bar at the bottom
    // does, without interrupting what the customer is doing.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      final venueId = venueIdOf(message);
      _messenger.currentState?.showSnackBar(SnackBar(
        content: Text(notification.body ?? notification.title ?? ''),
        action: venueId == null ? null : SnackBarAction(label: Strings.seeOffer, onPressed: () => _openVenue(venueId)),
      ));
    });
  }

  void _opened(RemoteMessage message) {
    final venueId = venueIdOf(message);
    if (venueId != null) _openVenue(venueId);
  }

  void _openVenue(int venueId) {
    ref.read(usageTrackerProvider).track('deal_alert_opened', {'venue_id': venueId});
    _navigator.currentState?.push(
      MaterialPageRoute(settings: const RouteSettings(name: 'venue'), builder: (_) => VenueScreen(venueId: venueId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fidelia',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      navigatorObservers: [ref.read(usageTrackerProvider).navigatorObserver],
      theme: fideliaTheme(),
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
