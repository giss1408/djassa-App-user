import 'package:djassa_user/core/djassa_api.dart';
import 'package:djassa_user/core/model/payment.dart';
import 'package:djassa_user/core/model/deal.dart';
import 'package:djassa_user/core/model/venue.dart';
import 'package:djassa_user/core/net/api_client.dart';
import 'package:djassa_user/core/net/api_exception.dart';
import 'package:djassa_user/core/providers.dart';
import 'package:djassa_user/features/confirm_pay_screen.dart';
import 'package:djassa_user/l10n/strings.dart';
import 'package:djassa_user/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Records every idempotency key; fails the first call like a dropped
/// connection, then succeeds.
class _FlakyApi extends DjassaApi {
  _FlakyApi() : super(ApiClient(
          inner: MockClient((_) async => http.Response('{}', 500)),
          tokenProvider: () async => 't',
          baseUrl: 'http://x',
        ));

  final keys = <String>[];
  final amounts = <int>[];

  @override
  Future<Payment> pay({
    required String payCode,
    int? amount,
    required Wallet wallet,
    required String payerPhone,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    amounts.add(amount!);
    if (keys.length == 1) throw const NetworkException('timeout');
    return Payment(
      id: 1,
      venueId: _target.venueId,
      venueName: _target.name,
      amount: amount,
      walletProvider: wallet.wire,
      status: 'succeeded',
      pointsAwarded: 50,
      createdAt: DateTime(2026),
    );
  }
}

/// A venue's static QR, as the server resolved it: the customer types the amount.
const _target = PayTarget(
  code: 'ABCDEFGHJK',
  venueId: 7,
  name: 'Maquis Test',
  commune: 'Cocody',
  category: 'maquis',
  isSample: true,
  pointsPer100: 1,
  payoutProvider: 'wave',
  payoutAccountMasked: '••••0001',
);

void main() {
  testWidgets('a retry after a network error reuses the key and locks the form', (tester) async {
    // A tall phone, so the whole form is built (ListView builds lazily).
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final api = _FlakyApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [djassaApiProvider.overrideWithValue(api)],
      child: MaterialApp(theme: djassaTheme(), home: const ConfirmPayScreen(target: _target)),
    ));

    await tester.enterText(find.byKey(const Key('pay-amount')), '5000');
    await tester.enterText(find.byKey(const Key('pay-phone')), '07 12 34 56 78');
    await tester.pump();
    // The bottom button, then the explicit "yes" in the summary sheet.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.sheetConfirm));
    await tester.pumpAndSettle();

    expect(api.keys, hasLength(1), reason: 'the confirmation reached the API');
    // Outcome unknown: the customer is told they won't be charged twice,
    // and the amount can no longer be edited.
    expect(find.text(Strings.payNetworkError), findsOneWidget);
    final amountField = tester.widget<TextField>(find.byKey(const Key('pay-amount')));
    expect(amountField.enabled, isFalse);

    // Retrying skips the sheet: this payment was already confirmed once.
    await tester.tap(find.text(Strings.retry));
    await tester.pumpAndSettle();

    expect(api.keys, hasLength(2));
    expect(api.keys[0], api.keys[1], reason: 'same key => server returns the first payment');
    expect(api.amounts, [5000, 5000]);
    expect(find.text(Strings.paymentDone.toUpperCase()), findsOneWidget, reason: 'receipt shown');
  });

  test('each new payment gets a fresh 128-bit key', () {
    final a = newIdempotencyKey();
    final b = newIdempotencyKey();
    expect(a, hasLength(32));
    expect(a, isNot(b));
  });

  test('server times are read as UTC', () {
    final t = parseServerTime('2026-10-04T08:00:00')!;
    expect(t.toUtc().hour, 8);
    expect(parseServerTime(null), isNull);
  });

  test('venue JSON with rewards and duty end', () {
    final v = Venue.fromJson({
      'id': 3, 'category': 'pharmacy', 'name': 'P', 'commune': 'Cocody',
      'points_per_100': 1, 'accepts_payment': false, 'is_sample': true,
      'duty_ends_at': '2026-10-04T08:00:00',
      'rewards': [{'id': 1, 'title': 'Livraison', 'cost_points': 60}],
      'my_points': 12,
    });
    expect(v.isPharmacy, isTrue);
    expect(v.rewards.single.costPoints, 60);
    expect(v.dutyEndsAt, isNotNull);
    expect(v.myPoints, 12);
  });

  test('deal badge percent comes from the prices when not stated', () {
    final d = Deal.fromJson({
      'id': 1, 'venue_id': 2, 'venue_name': 'V', 'venue_category': 'mode', 'venue_commune': 'Plateau',
      'title': 'Pagne', 'price': 7500, 'original_price': 10000,
      'ends_at': '2026-10-04T08:00:00', 'is_featured': true, 'is_sample': true,
    });
    expect(d.effectivePercent, 25);
    expect(d.isFeatured, isTrue);
  });
}
