import 'dart:convert';

import 'package:fidelia_user/core/auth/auth_repository.dart';
import 'package:fidelia_user/core/auth/token_store.dart';
import 'package:fidelia_user/core/net/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The customer app through the platform auth service (FIDELIA_AUTH_BASE): sign-in, sign-up with the WhatsApp activation code,
/// renewal, reset, password change. Stand-ins for both servers; nothing leaves the process.
String _jwt(Map<String, Object?> claims) {
  String part(Object v) => base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  return '${part({'alg': 'EdDSA'})}.${part(claims)}.sig';
}

final _exp = DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000;
String _access({bool mcp = false}) => _jwt({'sub': 'u', 'role': 'customer', 'exp': _exp, if (mcp) 'mcp': true});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStore store;
  late List<http.Request> authSent;
  late List<http.Request> fideliaSent;
  late http.Response Function(http.Request) authReply;
  late http.Response Function(http.Request) fideliaReply;
  late AuthRepository repo;

  http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = TokenStore();
    authSent = [];
    fideliaSent = [];
    authReply = (_) => json({'access_token': _access(), 'refresh_token': 'refresh-1', 'must_change_password': false});
    fideliaReply = (_) => json({'detail': 'fidelia must not be called'}, 500);
    ApiClient client(List<http.Request> log, http.Response Function(http.Request) Function() reply, String base) => ApiClient(
          inner: MockClient((r) async {
            log.add(r);
            return reply()(r);
          }),
          tokenProvider: store.readToken,
          baseUrl: base,
        );
    repo = AuthRepository(
      client: client(fideliaSent, () => fideliaReply, 'https://api.test.invalid'),
      authClient: client(authSent, () => authReply, 'https://auth.test.invalid'),
      tokenStore: store,
    );
  });

  test('sign-in goes to auth with product fidelia and app customer; the name shown is masked', () async {
    final r = await repo.signIn(phone: '07 01 02 03 04', password: 'pw-secret-1');
    expect(r, isA<SignInSuccess>());
    expect(authSent.single.url.path, '/v1/login');
    expect(jsonDecode(authSent.single.body), {'phone': '0701020304', 'password': 'pw-secret-1', 'product': 'fidelia', 'app': 'customer'});
    expect(await repo.currentUsername(), '07 •• •• 03 04');
    expect(fideliaSent, isEmpty);
  });

  test('refusals are explained in French', () async {
    final cases = {
      'invalid_credentials': 'Numéro ou mot de passe incorrect.',
      'not_activated': contains('code envoyé'),
      'account_blocked': 'Ce compte est suspendu. Contactez Fidelia.',
      'login_locked': contains('15 minutes'),
    };
    for (final e in cases.entries) {
      authReply = (_) => json({'detail': e.key}, 401);
      expect(((await repo.signIn(phone: '0701020304', password: 'x')) as SignInRejected).message, e.value);
    }
    expect(await store.readToken(), isNull);
  });

  test('sign-up creates a pending account at auth and asks for the WhatsApp code, with no session', () async {
    authReply = (_) => json({'status': 'pending_activation'}, 201);
    final r = await repo.register(phone: '0701020304', password: 'pw-secret-1', loyaltyConsentVersion: 'v1');
    expect(r, isA<SignInNeedsClaim>());
    expect((r as SignInNeedsClaim).message, AuthRepository.activationPending);
    expect(authSent.single.url.path, '/v1/register');
    expect(jsonDecode(authSent.single.body), {'phone': '0701020304', 'password': 'pw-secret-1', 'product': 'fidelia', 'consent': true});
    expect(await store.readToken(), isNull);
  });

  test('a number that already has an account is told so', () async {
    authReply = (_) => json({'detail': 'phone_taken'}, 409);
    final r = await repo.register(phone: '0701020304', password: 'pw-secret-1');
    expect((r as SignInRejected).message, contains('déjà un compte'));
  });

  test('the code activates, the password chosen at sign-up signs in, and the loyalty consent is recorded in fidelia', () async {
    authReply = (r) => r.url.path == '/v1/activate' ? http.Response('', 204) : json({'access_token': _access(), 'refresh_token': 'r', 'must_change_password': false});
    fideliaReply = (_) => json({'consent': true});
    final r = await repo.claim(phone: '0701020304', code: '123 456', password: 'pw-secret-1', loyaltyConsentVersion: 'fidelite-2026-10');
    expect(r, isA<SignInSuccess>());
    expect(authSent.map((x) => x.url.path), ['/v1/activate', '/v1/login']);
    expect(jsonDecode(authSent.first.body), {'phone': '0701020304', 'code': '123456'});
    expect(fideliaSent.single.url.path, '/api/customer/loyalty-consent');
    expect(fideliaSent.single.method, 'PUT');
    expect(jsonDecode(fideliaSent.single.body), {'consent_version': 'fidelite-2026-10'});
  });

  test('a wrong code stops there: no sign-in, no consent', () async {
    authReply = (_) => json({'detail': 'wrong_activation_code'}, 400);
    final r = await repo.claim(phone: '0701020304', code: '000000', password: 'pw-secret-1', loyaltyConsentVersion: 'v1');
    expect((r as SignInRejected).message, 'Code incorrect ou expiré.');
    expect(authSent.length, 1);
    expect(fideliaSent, isEmpty);
  });

  test('without the consent ticked nothing is sent to fidelia; a consent failure does not undo the sign-in', () async {
    authReply = (r) => r.url.path == '/v1/activate' ? http.Response('', 204) : json({'access_token': _access(), 'refresh_token': 'r', 'must_change_password': false});
    expect(await repo.claim(phone: '0701020304', code: '123456', password: 'pw-secret-1'), isA<SignInSuccess>());
    expect(fideliaSent, isEmpty);
    await store.clear();
    fideliaReply = (_) => json({'detail': 'down'}, 503);
    expect(await repo.claim(phone: '0701020304', code: '123456', password: 'pw-secret-1', loyaltyConsentVersion: 'v1'), isA<SignInSuccess>());
  });

  test('forgotten password goes to auth with the product', () async {
    authReply = (_) => json({'message': 'ok'}, 202);
    await repo.requestPassword('07 01 02 03 04');
    expect(authSent.single.url.path, '/v1/password/reset-request');
    expect(jsonDecode(authSent.single.body), {'phone': '0701020304', 'product': 'fidelia'});
  });

  test('a temporary password forces a change with the password just typed, then a token without the mark', () async {
    authReply = (r) => r.url.path == '/v1/login'
        ? json({'access_token': _access(mcp: true), 'refresh_token': 'refresh-1', 'must_change_password': true})
        : r.url.path == '/v1/password/change'
            ? http.Response('', 204)
            : json({'access_token': _access(), 'refresh_token': 'refresh-2', 'must_change_password': false});
    await repo.signIn(phone: '0701020304', password: 'temp-pass-1');
    expect(jwtMustChangePassword((await store.readToken())!), isTrue);
    await repo.changePassword(newPassword: 'brand-new-pass-1');
    expect(jsonDecode(authSent[1].body), {'current_password': 'temp-pass-1', 'new_password': 'brand-new-pass-1'});
    expect(jwtMustChangePassword((await store.readToken())!), isFalse);
    expect(await store.readRefreshToken(), 'refresh-2');
    expect(await repo.currentUsername(), '07 •• •• 03 04');
  });

  test('renewal and sign-out use auth; number checks and number change are not offered', () async {
    await repo.signIn(phone: '0701020304', password: 'pw-secret-1');
    expect(await repo.refresh(), isTrue);
    expect(authSent.last.url.path, '/v1/refresh');
    expect(await repo.numberRefused(), isFalse);
    await expectLater(repo.verifyNumber('123456'), throwsA(isA<AccountActionException>()));
    await expectLater(repo.revokeOtherSessions(), throwsA(isA<AccountActionException>()));
    authReply = (_) => http.Response('', 204);
    await repo.signOut();
    expect(authSent.last.url.path, '/v1/logout');
    expect(await store.readToken(), isNull);
    expect(fideliaSent, isEmpty);
  });

  test('number change: password + new number at auth, the code from the new number confirms, this session renews with the new number', () async {
    await repo.signIn(phone: '0701020304', password: 'pw-secret-1');
    authReply = (r) => r.url.path == '/v1/me/phone/request'
        ? json({'new_phone_masked': '+225 07 •• •• 08', 'status': 'waiting_for_code'}, 202)
        : r.url.path == '/v1/me/phone/confirm'
            ? json({'phone_masked': '+225 07 •• •• 08'})
            : json({'access_token': _access(), 'refresh_token': 'refresh-2', 'must_change_password': false});
    expect(await repo.requestNumberChange(newPhone: '07 05 06 07 08', password: 'pw-secret-1'), '+225 07 •• •• 08');
    expect(jsonDecode(authSent.last.body), {'new_phone': '0705060708', 'current_password': 'pw-secret-1'});
    await repo.confirmNumberChange('123 456');
    expect(authSent.map((x) => x.url.path).skip(1), ['/v1/me/phone/request', '/v1/me/phone/confirm', '/v1/refresh']);
    expect(jsonDecode(authSent[2].body), {'code': '123456'});
    expect(await store.readRefreshToken(), 'refresh-2');
    expect(fideliaSent, isEmpty);
  });

  test('number change refusals are explained and a failed confirm does not renew', () async {
    await repo.signIn(phone: '0701020304', password: 'pw-secret-1');
    final cases = {
      'invalid_credentials': 'Mot de passe incorrect.',
      'phone_taken': 'Ce numéro a déjà un compte Fidelia.',
    };
    for (final e in cases.entries) {
      authReply = (_) => json({'detail': e.key}, 409);
      await expectLater(repo.requestNumberChange(newPhone: '0705060708', password: 'x'), throwsA(isA<AccountActionException>().having((x) => x.message, 'message', e.value)));
    }
    authReply = (_) => json({'detail': 'wrong_activation_code'}, 400);
    final before = authSent.length;
    await expectLater(repo.confirmNumberChange('000000'), throwsA(isA<AccountActionException>().having((x) => x.message, 'message', 'Code incorrect ou expiré.')));
    expect(authSent.length, before + 1);
    authReply = (_) => json({'detail': 'product_unavailable'}, 503);
    await expectLater(repo.confirmNumberChange('123456'), throwsA(isA<AccountActionException>()));
  });

  test('without an auth client the repository is exactly the legacy one', () async {
    final legacy = AuthRepository(
      client: ApiClient(
        inner: MockClient((r) async {
          fideliaSent.add(r);
          return json({'access_token': _access(), 'refresh_token': 'r', 'phone_masked': '07 •• •• 00 02'});
        }),
        tokenProvider: store.readToken,
        baseUrl: 'https://api.test.invalid',
      ),
      tokenStore: store,
    );
    expect(legacy.authMode, isFalse);
    await legacy.signIn(phone: '0701020304', password: 'pw');
    expect(fideliaSent.single.url.path, '/api/auth/login');
  });
}
