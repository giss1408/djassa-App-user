import 'package:fidelia_user/core/model/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the code from a Fidelia payment QR', () {
    expect(parsePayQr('fidelia://pay/AB12CD34'), 'AB12CD34');
    expect(parsePayQr('  fidelia://pay/AB12CD34\n'), 'AB12CD34');
  });

  test('QRs printed under the old names still scan', () {
    expect(parsePayQr('hossouko://pay/AB12CD34'), 'AB12CD34');
    expect(parsePayQr('djassa://pay/AB12CD34'), 'AB12CD34');
  });

  test('anything else is refused', () {
    expect(parsePayQr('https://evil.example/pay/AB12CD34'), isNull);
    expect(parsePayQr('fidelia://pay/ab12cd34'), isNull);
    expect(parsePayQr('fidelia://pay/AB12CD34?x=1'), isNull);
    expect(parsePayQr('other://pay/AB12CD34'), isNull);
  });
}
