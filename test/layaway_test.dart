import 'package:djassa_user/core/model/layaway.dart';
import 'package:djassa_user/features/loyalty_tab.dart';
import 'package:djassa_user/l10n/strings.dart';
import 'package:djassa_user/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _json({String status = 'open', int paid = 30000, int? refunded}) => {
      'id': 7,
      'venue_name': 'Boutique Awa',
      'item': 'Refrigerateur 90 L',
      'price': 90000,
      'paid': paid,
      'remaining': 90000 - paid,
      'status': status,
      'due_by': '2026-12-31T00:00:00',
      'refunded_amount': refunded,
      'installments': [
        {'id': 1, 'amount': paid, 'source': 'cash_declared', 'paid_at': '2026-10-06T10:00:00'},
      ],
    };

Future<void> _pump(WidgetTester tester, LayawayPlan plan) => tester.pumpWidget(
      MaterialApp(theme: djassaTheme(), home: Scaffold(body: LayawayCard(plan: plan))),
    );

/// A customer sees the goods they are paying for in installments, at any shop,
/// and what happens next: what is left, or that it is ready to collect.
void main() {
  test('reads the plan the server sends', () {
    final plan = LayawayPlan.fromJson(_json());
    expect((plan.paid, plan.remaining, plan.installments.length), (30000, 60000, 1));
    expect(plan.progress, closeTo(0.333, 0.001));
    expect(plan.isActive, isTrue);
    expect(LayawayPlan.fromJson(_json(status: 'delivered', paid: 90000)).isActive, isFalse);
  });

  testWidgets('an open plan shows what is left to pay', (tester) async {
    await _pump(tester, LayawayPlan.fromJson(_json()));
    expect(find.text('Refrigerateur 90 L'), findsOneWidget);
    expect(find.textContaining(Strings.layawayRemaining), findsOneWidget);
  });

  testWidgets('a paid plan tells the customer to collect it', (tester) async {
    await _pump(tester, LayawayPlan.fromJson(_json(status: 'completed', paid: 90000)));
    expect(find.text(Strings.layawayReady), findsOneWidget);
  });

  testWidgets('a cancelled plan shows what the shop refunded', (tester) async {
    await _pump(tester, LayawayPlan.fromJson(_json(status: 'cancelled', refunded: 30000)));
    expect(find.textContaining(Strings.layawayRefunded), findsOneWidget);
  });
}
