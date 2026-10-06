import 'package:djassa_user/core/model/deal.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _deal([String? ribbon]) => {
      'id': 1,
      'venue_id': 2,
      'venue_name': 'Maquis',
      'venue_category': 'maquis',
      'venue_commune': 'Cocody',
      'title': 'Garba -20 %',
      'ends_at': '2026-10-07T12:00:00',
      if (ribbon != null) 'ribbon': ribbon,
    };

void main() {
  test('the corner banner follows the server', () {
    expect(Deal.fromJson(_deal('flash')).ribbon, DealRibbon.flash);
    expect(Deal.fromJson(_deal('promo')).ribbon, DealRibbon.promo);
    expect(Deal.fromJson(_deal('bon_plan')).ribbon, DealRibbon.bonPlan);
  });

  test('an older server (no field) or a newer value shows the bon plan banner', () {
    expect(Deal.fromJson(_deal()).ribbon, DealRibbon.bonPlan);
    expect(Deal.fromJson(_deal('soldes')).ribbon, DealRibbon.bonPlan);
  });
}
