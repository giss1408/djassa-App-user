import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fidelia_user/core/auth/auth_repository.dart';
import 'package:fidelia_user/core/auth/token_store.dart';
import 'package:fidelia_user/core/monitoring/error_reporter.dart';
import 'package:fidelia_user/core/net/api_client.dart';
import 'package:fidelia_user/core/net/api_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';



// Generated per run: no password literal in the repository.
final password = 'p${DateTime.now().microsecondsSinceEpoch}';
final newPassword = 'n${DateTime.now().microsecondsSinceEpoch}';
final wrongPassword = 'w${DateTime.now().microsecondsSinceEpoch}';

/// Phone + password sign-in, session renewal, and error reporting, against a
/// stand-in for `app/api/auth.py` and `app/api/client_events.py`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> sent;
  late http.Response Function(http.Request) respond;
  late TokenStore store;
  late int unauthorizedCalls;
  late AuthRepository auth;
  late ApiClient client;

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Map<String, Object?> pair(String access, String refresh) =>
      {'access_token': access, 'refresh_token': refresh, 'token_type': 'bearer', 'expires_in': 3600, 'role': AuthRepository.appRole, 'phone_masked': '07 •• •• 00 02'};

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    sent = [];
    unauthorizedCalls = 0;
    store = TokenStore();
    client = ApiClient(
      inner: MockClient((request) async {
        sent.add(request);
        return respond(request);
      }),
      tokenProvider: store.readToken,
      onRefresh: () => auth.refresh(),
      onUnauthorized: () async {
        unauthorizedCalls++;
        await store.clear();
      },
      baseUrl: 'https://api.test.invalid',
    );
    auth = AuthRepository(client: client, tokenStore: store);
  });

  test('the number and password are exchanged for both tokens', () async {
    respond = (_) => json(pair('access-1', 'refresh-1'));

    final result = await auth.signIn(phone: '07 00 00 00 02', password: password);
    expect((result as SignInSuccess).username, '07 •• •• 00 02');
    expect(sent.single.url.path, '/api/auth/login');
    expect(jsonDecode(sent.single.body), {'phone': '0700000002', 'country_code': 'CI', 'password': password, 'app': AuthRepository.appRole});
    expect(await store.readToken(), 'access-1');
    expect(await store.readRefreshToken(), 'refresh-1');
  });

  test('the catalogue is read signed out; the customer\'s own data is not', () async {
    respond = (r) => json(<Object?>[]);
    expect(await client.getJsonList('/api/deals', optionalAuth: true), isEmpty);
    expect(sent.single.headers.containsKey('Authorization'), isFalse);
    expect(() => client.getJson('/api/customer/loyalty'), throwsA(isA<UnauthorizedException>()));

    // Signed in, the same call carries the token (a shop page shows my points).
    respond = (r) => json(pair('access-1', 'refresh-1'));
    await auth.signIn(phone: '0700000002', password: password);
    respond = (r) => json(<Object?>[]);
    await client.getJsonList('/api/deals', optionalAuth: true);
    expect(sent.last.headers['Authorization'], 'Bearer access-1');
  });

  test('a new account opens a session at once, with the consent ticked at sign-up, and only then', () async {
    respond = (_) => json(pair('access-1', 'refresh-1'), 201);
    final result = await auth.register(phone: '0700000002', password: password, loyaltyConsentVersion: 'fidelite-2026-10');
    expect(result, isA<SignInSuccess>());
    expect(sent.last.url.path, '/api/auth/register');
    expect(jsonDecode(sent.last.body)['loyalty_consent_version'], 'fidelite-2026-10');
    await auth.register(phone: '0700000002', password: password);
    expect((jsonDecode(sent.last.body) as Map).containsKey('loyalty_consent_version'), isFalse);
  });

  test('a number with an account but no password is claimed with the WhatsApp code', () async {
    respond = (_) => json({'message': 'Fidelia va vous envoyer un code sur WhatsApp.'}, 202);
    final asked = await auth.register(phone: '0700000002', password: password);
    expect((asked as SignInNeedsClaim).message, startsWith('Fidelia va'));
    expect(await store.readToken(), isNull);

    respond = (_) => json(pair('access-1', 'refresh-1'));
    final claimed = await auth.claim(phone: '0700000002', code: '123 456', password: password);
    expect(claimed, isA<SignInSuccess>());
    expect(sent.last.url.path, '/api/auth/claim');
    expect(jsonDecode(sent.last.body), {'phone': '0700000002', 'country_code': 'CI', 'code': '123456', 'password': password, 'app': 'customer'});
  });

  test('a wrong password shows the server\'s words and does not end anything', () async {
    respond = (_) => json({'detail': 'Numero ou mot de passe incorrect.'}, 401);
    final result = await auth.signIn(phone: '0700000002', password: wrongPassword);
    expect((result as SignInRejected).message, startsWith('Numero ou mot de passe'));
    expect(unauthorizedCalls, 0);
  });

  test('an account from before passwords is told to create its password', () async {
    respond = (_) => json({'detail': 'password_not_set'}, 409);
    final result = await auth.signIn(phone: '0700000002', password: wrongPassword);
    expect((result as SignInRejected).message, AuthRepository.noPasswordYet);
  });

  test('the WhatsApp code proves the number and stores the new session', () async {
    await store.save(token: 'unverified', refreshToken: 'refresh-1', username: 'x');
    respond = (_) => json(pair('verified', 'refresh-2'));
    await auth.verifyNumber('123 456');
    expect(sent.single.url.path, '/api/auth/verify-number');
    expect(jsonDecode(sent.single.body), {'code': '123456'});
    expect(await store.readToken(), 'verified');
  });

  test('a wrong WhatsApp code is a refusal, not a sign-out', () async {
    await store.save(token: 'unverified', refreshToken: 'refresh-1', username: 'x');
    respond = (_) => json({'detail': 'Code incorrect ou expire.'}, 401);
    await expectLater(auth.verifyNumber('000000'), throwsA(isA<AccountActionException>()));
    expect(sent.map((r) => r.url.path), ['/api/auth/verify-number']);
    expect(unauthorizedCalls, 0);
    expect(await store.readRefreshToken(), 'refresh-1');
  });

  test('a forgotten password is asked of the team without a session', () async {
    respond = (_) => json({'message': 'Si ce numero a un compte, Fidelia vous envoie un mot de passe.'}, 202);
    expect(await auth.requestPassword('07 00 00 00 02'), startsWith('Si ce numero'));
    expect(jsonDecode(sent.single.body), {'phone': '0700000002', 'country_code': 'CI'});
    expect(sent.single.headers['Authorization'], isNull);
  });

  test('a number the team turned down reads as not on WhatsApp', () async {
    await store.save(token: 'unverified', refreshToken: 'refresh-1', username: 'x');
    respond = (_) => json({'sub': 'tel:+2250700000002', 'role': AuthRepository.appRole, 'verified': false, 'number_refused': true});
    expect(await auth.numberRefused(), isTrue);
    expect(sent.single.url.path, '/api/auth/me');
    respond = (_) => json({'detail': 'down'}, 503);
    expect(await auth.numberRefused(), isFalse);
  });

  test('a 401 renews the session once and replays the request', () async {
    await store.save(token: 'stale', refreshToken: 'refresh-1', username: 'x');
    respond = (r) {
      if (r.url.path == '/api/auth/refresh') return json(pair('fresh', 'refresh-2'));
      return r.headers['Authorization'] == 'Bearer fresh' ? json({'ok': true}) : json({'detail': 'expired'}, 401);
    };

    expect(await client.getJson('/api/merchant/deals'), {'ok': true});
    expect(sent.map((r) => r.url.path), ['/api/merchant/deals', '/api/auth/refresh', '/api/merchant/deals']);
    expect(await store.readRefreshToken(), 'refresh-2');
    expect(unauthorizedCalls, 0);
  });

  test('concurrent renewals share one refresh: a second use would be read as theft', () async {
    await store.save(token: 'stale', refreshToken: 'refresh-1', username: 'x');
    final gate = Completer<void>();
    var refreshes = 0;
    client = ApiClient(
      inner: MockClient((request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshes++;
          await gate.future;
          return json(pair('fresh', 'refresh-2'));
        }
        return json({});
      }),
      tokenProvider: store.readToken,
      baseUrl: 'https://api.test.invalid',
    );
    auth = AuthRepository(client: client, tokenStore: store);

    final both = Future.wait([auth.refresh(), auth.refresh()]);
    gate.complete();
    expect(await both, [true, true]);
    expect(refreshes, 1);
  });

  test('a refused renewal ends the session', () async {
    await store.save(token: 'stale', refreshToken: 'revoked', username: 'x');
    respond = (r) => json({'detail': 'Session expiree. Reconnectez-vous.'}, 401);

    await expectLater(client.getJson('/api/merchant/deals'), throwsA(isA<UnauthorizedException>()));
    expect(unauthorizedCalls, 1);
    expect(await store.readRefreshToken(), isNull);
  });

  test('offline renewal keeps the session: a dead cell never signs anyone out', () async {
    await store.save(token: 'stale', refreshToken: 'refresh-1', username: 'x');
    respond = (r) {
      if (r.url.path == '/api/auth/refresh') throw const SocketException('no route');
      return json({'detail': 'expired'}, 401);
    };

    await expectLater(client.getJson('/api/merchant/deals'), throwsA(isA<NetworkException>()));
    expect(unauthorizedCalls, 0);
    expect(await store.readRefreshToken(), 'refresh-1');
  });

  test('sign-out revokes on the server and wipes the device', () async {
    await store.save(token: 'access', refreshToken: 'refresh-1', username: 'x');
    respond = (_) => http.Response('', 204);
    await auth.signOut();
    expect(sent.single.url.path, '/api/auth/logout');
    expect(jsonDecode(sent.single.body), {'refresh_token': 'refresh-1'});
    expect(await store.readToken(), isNull);
  });

  group('account recovery', () {
    test('signing out other phones keeps this one', () async {
      await store.save(token: 'access', refreshToken: 'mine', username: 'x');
      respond = (_) => json({'revoked': 2});
      expect(await auth.revokeOtherSessions(), 2);
      expect(sent.single.url.path, '/api/auth/sessions/revoke-others');
      expect(jsonDecode(sent.single.body), {'refresh_token': 'mine'});
    });

    test('a number change asks with the password, then moves with the WhatsApp code', () async {
      await store.save(token: 'access', refreshToken: 'old-refresh', username: '07 •• •• 56 78');
      respond = (r) => r.url.path == '/api/auth/change-number/request'
          ? json({'new_phone_masked': '05 •• •• 33 44'}, 202)
          : json({...pair('new-access', 'new-refresh'), 'phone_masked': '05 •• •• 33 44'});

      expect(await auth.requestNumberChange(newPhone: '0511223344', password: password), '05 •• •• 33 44');
      expect(jsonDecode(sent.first.body), {'new_phone': '0511223344', 'country_code': 'CI', 'password': password});
      expect(await auth.confirmNumberChange('222222'), '05 •• •• 33 44');
      expect(jsonDecode(sent.last.body), {'code': '222222'});
      expect(await store.readRefreshToken(), 'new-refresh');
    });

    test('a refusal arrives in the server\'s words', () async {
      await store.save(token: 'access', refreshToken: 'r', username: 'x');
      respond = (_) => json({'detail': 'Ce numero a deja un compte Fidelia.'}, 409);
      await expectLater(
        auth.requestNumberChange(newPhone: '0511223344', password: password),
        throwsA(isA<AccountActionException>().having((e) => e.message, 'message', startsWith('Ce numero'))),
      );
    });

    test('a lost-number request is filed from the new number\'s session', () async {
      await store.save(token: 'access', refreshToken: 'r', username: 'x');
      respond = (_) => json({'status': 'pending', 'message': 'Demande recue.'}, 202);
      expect(await auth.fileRecovery(oldPhone: '0712345678', details: 'Chez Tantie Awa, Yopougon'), 'Demande recue.');
      expect(sent.single.url.path, '/api/auth/recovery');
      expect(jsonDecode(sent.single.body), {'old_phone': '0712345678', 'country_code': 'CI', 'details': 'Chez Tantie Awa, Yopougon'});
      expect(sent.single.headers['Authorization'], 'Bearer access');
    });
  });

  group('ErrorReporter', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('fidelia-errors-'));
    tearDown(() => dir.delete(recursive: true));

    ErrorReporter reporter(http.Client inner) =>
        ErrorReporter(app: 'user', client: inner, directory: () async => dir, enabled: true, baseUrl: 'https://api.test.invalid');

    test('one bug hit many times is one report with a count, digits scrubbed', () async {
      final reports = <Map<String, Object?>>[];
      final r = reporter(MockClient((request) async {
        reports.add(jsonDecode(request.body) as Map<String, Object?>);
        return http.Response('{"accepted":1}', 202);
      }));
      final stack = StackTrace.fromString('#0      SyncService.flush (package:fidelia_user/core/data/sync_service.dart:88:5)\n');
      for (var i = 0; i < 3; i++) {
        r.record(StateError('sale for +2250700000002 of 150000 failed'), stack);
      }
      await r.flush();

      final body = reports.single;
      expect(body['app'], 'user');
      final events = body['events'] as List;
      expect(events, hasLength(1));
      final event = events.single as Map;
      expect(event['count'], 3);
      expect(event['message'], isNot(contains('0700000002')));
      expect(event['message'], isNot(contains('150000')));
      expect(event['stack'], contains('sync_service.dart:88:5'));

      // Delivered, so a second flush sends nothing.
      await r.flush();
      expect(reports, hasLength(1));
    });

    test('reports survive being offline, and a restart', () async {
      final offline = reporter(MockClient((_) async => throw const SocketException('offline')));
      offline.record(StateError('boom'), StackTrace.fromString('#0 main (file.dart:1:1)'));
      await offline.flush();
      await Future<void>.delayed(const Duration(milliseconds: 2100)); // the debounced save

      final received = <http.Request>[];
      final next = reporter(MockClient((request) async {
        received.add(request);
        return http.Response('{}', 202);
      }));
      await next.flush();
      expect(received, hasLength(1));
      expect(received.single.url.path, '/api/client-events');
    });
  });
}
