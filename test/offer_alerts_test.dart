import 'dart:io';

import 'package:fidelia_user/core/model/venue.dart';
import 'package:fidelia_user/core/personal_lists.dart';
import 'package:fidelia_user/core/push/offer_alerts.dart';
import 'package:fidelia_user/core/push/topics.dart';
import 'package:fidelia_user/features/offer_alerts_sheet.dart';
import 'package:fidelia_user/l10n/strings.dart';
import 'package:fidelia_user/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// FCM's phone side, in memory.
class _FakeGateway implements PushGateway {
  _FakeGateway({this.available = true});

  @override
  final bool available;
  bool granted = true;
  bool offline = false;
  final topics = <String>{};
  int permissionAsked = 0;

  @override
  Future<bool> requestPermission() async {
    permissionAsked++;
    return granted;
  }

  @override
  Future<void> subscribe(String topic) async {
    if (offline) throw const SocketException('offline');
    topics.add(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    if (offline) throw const SocketException('offline');
    topics.remove(topic);
  }
}

Venue _venue(int id) =>
    Venue(id: id, category: 'maquis', name: 'Maquis $id', commune: 'Cocody', pointsPer100: 1, acceptsPayment: true, isSample: false);

void main() {
  test('topic names match the backend (app/services/push.py, same examples)', () {
    expect(topicSlug('Cocody'), 'cocody');
    expect(topicSlug('Port-Bouët'), 'port_bouet');
    expect(topicSlug('  Yopougon  '), 'yopougon');
    expect(communeTopic('Treichville'), 'offers_treichville');
    expect(venueTopic(12), 'venue_12');
    // Every commune the app offers makes a valid FCM topic name.
    for (final c in Strings.communes) {
      expect(communeTopic(c), matches(RegExp(r'^[a-zA-Z0-9\-_.~%]+$')));
    }
  });

  group('settings', () {
    late Directory dir;
    late _FakeGateway gateway;

    ProviderContainer open() {
      final c = ProviderContainer(overrides: [
        personalDirectoryProvider.overrideWithValue(() async => dir),
        pushGatewayProvider.overrideWithValue(gateway),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('fidelia_alerts_');
      gateway = _FakeGateway();
    });

    test('off until the customer turns it on, then follows the commune and the favourites', () async {
      final c = open();
      await c.read(personalListsProvider.notifier).toggleFavorite(_venue(4));
      expect(c.read(offerAlertsProvider).enabled, isFalse);
      expect(gateway.topics, isEmpty);

      expect(await c.read(offerAlertsProvider.notifier).enable(), isTrue);
      expect(gateway.topics, {'venue_4'}, reason: 'no commune chosen yet: favourites only');

      await c.read(offerAlertsProvider.notifier).chooseCommune('Cocody');
      expect(gateway.topics, {'offers_cocody', 'venue_4'});

      await c.read(offerAlertsProvider.notifier).chooseCommune('Yopougon');
      expect(gateway.topics, {'offers_yopougon', 'venue_4'}, reason: 'the old commune is dropped');

      await c.read(offerAlertsProvider.notifier).disable();
      expect(gateway.topics, isEmpty);
    });

    test('a star added while alerts are on follows that shop', () async {
      final c = open();
      await c.read(offerAlertsProvider.notifier).enable(commune: 'Cocody');
      await c.read(personalListsProvider.notifier).toggleFavorite(_venue(9));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(gateway.topics, {'offers_cocody', 'venue_9'});

      await c.read(personalListsProvider.notifier).toggleFavorite(_venue(9));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(gateway.topics, {'offers_cocody'});
    });

    test('a refused permission leaves alerts off', () async {
      gateway.granted = false;
      final c = open();
      expect(await c.read(offerAlertsProvider.notifier).enable(commune: 'Cocody'), isFalse);
      expect(c.read(offerAlertsProvider).enabled, isFalse);
      expect(gateway.topics, isEmpty);
    });

    test('a build without Firebase cannot turn alerts on', () async {
      gateway = _FakeGateway(available: false);
      final c = open();
      expect(await c.read(offerAlertsProvider.notifier).enable(commune: 'Cocody'), isFalse);
      expect(gateway.permissionAsked, 0, reason: 'nothing to ask permission for');
    });

    test('subscriptions that failed offline are retried at the next start, and settings survive a restart', () async {
      final c = open();
      gateway.offline = true;
      await c.read(offerAlertsProvider.notifier).enable(commune: 'Cocody');
      expect(c.read(offerAlertsProvider).enabled, isTrue);
      expect(gateway.topics, isEmpty);

      gateway.offline = false;
      final restarted = open();
      await restarted.read(offerAlertsProvider.notifier).resume();
      expect(restarted.read(offerAlertsProvider).commune, 'Cocody');
      expect(gateway.topics, {'offers_cocody'});
    });
  });

  group('sheet', () {
    /// The settings file is real I/O, which the widget test's fake clock does
    /// not wait for: let real time pass, then rebuild, a few rounds.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    Future<_FakeGateway> pump(WidgetTester tester, {bool available = true}) async {
      final gateway = _FakeGateway(available: available);
      final dir = Directory.systemTemp.createTempSync('fidelia_sheet_');
      await tester.pumpWidget(ProviderScope(
        overrides: [
          personalDirectoryProvider.overrideWithValue(() async => dir),
          pushGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(theme: fideliaTheme(), home: const Scaffold(body: OfferAlertsSheet())),
      ));
      await settle(tester);
      return gateway;
    }

    testWidgets('turning alerts on shows the communes, and choosing one subscribes it', (tester) async {
      final gateway = await pump(tester);
      expect(find.text('Cocody'), findsNothing);

      await tester.tap(find.text(Strings.offerAlertsSwitch));
      await settle(tester);
      expect(find.text('Cocody'), findsOneWidget);

      await tester.tap(find.text('Cocody'));
      await settle(tester);
      expect(gateway.topics, {'offers_cocody'});
    });

    testWidgets('says so when this build has no alerts', (tester) async {
      await pump(tester, available: false);
      expect(find.text(Strings.offerAlertsUnavailable), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });
  });
}
