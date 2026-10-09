import 'dart:convert';
import 'dart:io';

import 'package:fidelia_user/core/monitoring/usage_tracker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late List<http.Request> sent;
  var offline = false;

  UsageTracker tracker() => UsageTracker(
        app: 'user',
        client: MockClient((request) async {
          if (offline) throw const SocketException('no signal');
          sent.add(request);
          return http.Response('{"accepted": 1}', 202);
        }),
        directory: () async => dir,
        enabled: true,
        baseUrl: 'https://api.test',
        clock: () => DateTime.utc(2026, 10, 2, 9),
      );

  List<Map<String, Object?>> events(http.Request request) =>
      [for (final e in (jsonDecode(request.body) as Map)['events'] as List) Map<String, Object?>.from(e as Map)];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('usage_test');
    sent = [];
    offline = false;
  });

  tearDown(() => dir.delete(recursive: true));

  test('an install is counted once, and never tied to an account', () async {
    await tracker().start();
    await tracker().start();
    final installs = sent.expand(events).where((e) => e['name'] == 'app_open' && e['props'] != null);
    expect(installs, hasLength(1));
    // The customer app has no token provider: no Authorization header, ever.
    expect(sent.every((r) => !r.headers.containsKey('Authorization')), isTrue);
    expect((jsonDecode(sent.first.body) as Map)['app'], 'user');
  });

  test('what was seen waits offline and goes on the next launch', () async {
    offline = true;
    final usage = tracker();
    await usage.start();
    usage
      ..track('venue_viewed', {'venue_id': 12})
      ..track('venue_viewed', {'venue_id': 12})
      ..track('deal_opened', {'deal_id': 3});
    await Future<void>.delayed(const Duration(seconds: 3)); // the debounced save
    expect(sent, isEmpty);

    offline = false;
    await tracker().start();
    final seen = events(sent.single);
    expect(seen.firstWhere((e) => e['name'] == 'venue_viewed')['count'], 2);
    expect(seen.firstWhere((e) => e['name'] == 'deal_opened')['props'], {'deal_id': 3});
  });

  testWidgets('pushed screens with a name are recorded', (tester) async {
    final usage = tracker();
    await tester.runAsync(usage.start);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(WidgetsApp(
      navigatorKey: navigator,
      navigatorObservers: [usage.navigatorObserver],
      color: const Color(0xFF000000),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(settings: settings, pageBuilder: (c, _, __) => builder(c)),
      home: const SizedBox(),
    ));
    navigator.currentState!.push(PageRouteBuilder(settings: const RouteSettings(name: 'venue'), pageBuilder: (_, __, ___) => const SizedBox()));
    await tester.pumpAndSettle();
    final screens = usage.queued.values.where((e) => e['name'] == 'screen_view').map((e) => (e['props'] as Map)['screen']);
    expect(screens, ['venue']);
    await tester.pump(const Duration(seconds: 3)); // let the debounced save run
  });
}
