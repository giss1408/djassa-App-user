import 'dart:async';

import '../net/api_client.dart';
import '../net/api_exception.dart';
import 'token_store.dart';

/// A recovery action failed; [message] is ready to show.
class AccountActionException implements Exception {
  const AccountActionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Outcome of a sign-in attempt, as something the UI can render directly.
sealed class SignInResult {
  const SignInResult();
}

class SignInSuccess extends SignInResult {
  const SignInSuccess(this.username);

  /// The masked phone number, shown as the account name.
  final String username;
}

/// Wrong password or code, a locked or suspended number. Distinct from
/// [SignInUnavailable] so the UI can say why instead of "no connection".
class SignInRejected extends SignInResult {
  const SignInRejected(this.message);
  final String message;
}

/// The server could not be reached, or it failed. Sign-in is the one operation
/// that cannot be queued offline: without a token there is nothing to queue
/// against.
class SignInUnavailable extends SignInResult {
  const SignInUnavailable(this.message);
  final String message;
}

/// The number already has an account without a password (from SMS sign-in,
/// or created by the team). The team sends a code on WhatsApp; [message] says
/// so, and [AuthRepository.claim] sets the password with it.
class SignInNeedsClaim extends SignInResult {
  const SignInNeedsClaim(this.message);
  final String message;
}

/// Sign-in with phone number + password, session renewal, sign-out.
///
/// The backend (`fidelia-BE/backend-api/app/api/password_auth.py`) exchanges
/// the password for a 60-minute access token and a 90-day single-use refresh
/// token. Both live in [TokenStore]. An expired access token is renewed with
/// [refresh] before or after the request that needs it (see `providers.dart`),
/// so the session survives as long as the app is opened at least once every
/// 90 days.
///
/// A new account opens a session at once, but its number is not proven: a
/// Fidelia admin sends a code on WhatsApp ([verifyNumber]), and until then the
/// server refuses everything else.
class AuthRepository {
  AuthRepository({required ApiClient client, required TokenStore tokenStore, ApiClient? authClient})
      : _client = client,
        _tokenStore = tokenStore,
        _auth = authClient;

  /// The platform auth service (SSO) when set: sign-in, sign-up with the WhatsApp activation code, renewal, sign-out, forgotten
  /// password and password change go there; fidelia only receives the access token it issued. Null = fidelia's own sign-in.
  final ApiClient? _auth;

  bool get authMode => _auth != null;

  /// Set by [confirmNumberChange] in auth mode: when the change takes effect if the service applies a security delay (24 h), else null.
  DateTime? numberChangeScheduledFor;

  static const _product = 'fidelia';

  /// The temporary password just typed, in memory only, so the forced "new password" step can send it as the current one.
  String? _signInPassword;

  /// Shown after sign-up in auth mode: the account waits for the code a Fidelia admin sends on WhatsApp.
  static const activationPending =
      'Compte créé. L\'équipe Fidelia vous envoie un code sur WhatsApp : saisissez-le ici pour activer votre compte.';

  /// The session this app opens.
  /// Anyone with a number gets one.
  static const appRole = 'customer';

  final ApiClient _client;
  final TokenStore _tokenStore;

  /// The refresh in flight, shared by every caller. Refresh tokens are single
  /// use and the server treats a second use as theft, so two concurrent
  /// refreshes with the same token would sign the user out.
  Completer<bool>? _refreshing;

  /// Whether this device holds a session: a live access token, or a refresh
  /// token that can mint one. The server stays the authority; a refused
  /// refresh clears the session.
  Future<bool> hasValidSession() async {
    final token = await _tokenStore.readToken();
    if (token != null && token.isNotEmpty && !isTokenExpired(token)) return true;
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh != null && refresh.isNotEmpty) return true;
    await _tokenStore.clear();
    return false;
  }

  Future<String?> currentUsername() => _tokenStore.readUsername();

  static const _unusable = 'La réponse du serveur est inutilisable';
  static const noPasswordYet = 'Ce numéro n\'a pas encore de mot de passe. Créez votre compte avec ce numéro.';

  /// Exchanges the number and password for a session.
  Future<SignInResult> signIn({required String phone, required String password}) {
    if (_auth != null) return _authSignIn(phone, password);
    return _signIn(
      '/api/auth/login',
      {'phone': _digits(phone), 'country_code': 'CI', 'password': password, 'app': appRole},
    );
  }

  /// Creates the account and opens its session, not yet verified. A number
  /// that already has an account without a password answers
  /// [SignInNeedsClaim] instead.
  Future<SignInResult> register({required String phone, required String password, String? loyaltyConsentVersion}) {
    if (_auth != null) return _authRegister(phone, password);
    return _signIn(
      '/api/auth/register',
      {
        'phone': _digits(phone),
        'country_code': 'CI',
        'password': password,
        'app': appRole,
        if (loyaltyConsentVersion != null) 'loyalty_consent_version': loyaltyConsentVersion,
      },
    );
  }

  /// Sets the first password of an existing account with the code the team
  /// sent on WhatsApp after [register] answered [SignInNeedsClaim].
  Future<SignInResult> claim({
    required String phone,
    required String code,
    required String password,
    String? loyaltyConsentVersion,
  }) {
    if (_auth != null) return _authActivate(phone, code, password, loyaltyConsentVersion);
    return _signIn(
      '/api/auth/claim',
      {
        'phone': _digits(phone),
        'country_code': 'CI',
        'code': code.replaceAll(' ', ''),
        'password': password,
        'app': appRole,
        if (loyaltyConsentVersion != null) 'loyalty_consent_version': loyaltyConsentVersion,
      },
    );
  }

  Future<SignInResult> _signIn(String path, Map<String, Object?> body) async {
    try {
      final answer = await _client.postJson(path, body: body, authenticated: false);
      // 202 from register: no session, a code is on its way.
      if (answer['access_token'] == null && answer['message'] is String) return SignInNeedsClaim(answer['message'] as String);
      return await _store(answer) ? SignInSuccess(await currentUsername() ?? '') : const SignInUnavailable(_unusable);
    } on ClientErrorException catch (error) {
      if (error.statusCode == 409 && error.detail == 'password_not_set') return const SignInRejected(noPasswordYet);
      // 401 wrong password or code, 403 suspended, 409 taken, 422 weak password, 423 locked.
      return SignInRejected(_detail(error));
    } on ServerErrorException {
      return const SignInUnavailable('Le serveur est indisponible');
    } on NetworkException catch (error) {
      return SignInUnavailable(error.message);
    } on ApiException catch (error) {
      return SignInUnavailable(error.message);
    }
  }

  /// Asks the team for a temporary password, sent on WhatsApp to [phone].
  /// Returns the server's answer, which never says whether the number has an
  /// account.
  Future<String> requestPassword(String phone) => _action(() async {
        final auth = _auth;
        if (auth != null) {
          final body = await auth.postJson('/v1/password/reset-request', body: {'phone': _digits(phone), 'product': _product}, authenticated: false);
          return body['message'] as String? ?? 'Si ce numéro a un compte, l\'équipe Fidelia vous envoie un mot de passe temporaire sur WhatsApp.';
        }
        final body = await _client.postJson(
          '/api/auth/password-reset',
          body: {'phone': _digits(phone), 'country_code': 'CI'},
          authenticated: false,
        );
        return body['message'] as String? ?? '';
      });

  /// Sets a new password. [current] is omitted right after signing in with a
  /// temporary password. The server's new token pair replaces the stored
  /// one, which no longer carries the `pc` claim.
  Future<void> changePassword({String? current, required String newPassword}) => _action(() async {
        final auth = _auth;
        if (auth != null) {
          final currentPassword = current ?? _signInPassword;
          if (currentPassword == null) throw const AccountActionException('Saisissez votre mot de passe actuel.');
          try {
            await auth.postJson('/v1/password/change',
                body: {'current_password': currentPassword, 'new_password': newPassword}, unauthorizedEndsSession: false);
          } on ClientErrorException catch (e) {
            throw AccountActionException(e.detail == 'invalid_credentials' ? 'Mot de passe actuel incorrect.' : _detail(e));
          }
          _signInPassword = null;
          // The change itself returns no token: renew, which issues one without the "must change" mark.
          if (!await refresh()) throw const AccountActionException(_unusable);
          return;
        }
        final body = await _client.postJson(
          '/api/auth/password',
          body: {if (current != null) 'current': current, 'new': newPassword},
          // A wrong current password is a 401 that must not end the session.
          unauthorizedEndsSession: false,
        );
        if (!await _store(body)) throw const AccountActionException(_unusable);
      });

  /// Whether the team turned the number down: it is not on WhatsApp, so no
  /// code can reach it. False when the server cannot say.
  Future<bool> numberRefused() async {
    if (_auth != null) return false;
    try {
      final body = await _client.getJson('/api/auth/me');
      return body['number_refused'] == true;
    } on ApiException {
      return false;
    }
  }

  /// Proves the number with the code a Fidelia admin sent on WhatsApp. The
  /// new session carries `vf`; every other session on the account ends.
  Future<void> verifyNumber(String code) => _action(() async {
        if (_auth != null) throw const AccountActionException(_unavailableInAuth);
        final body = await _client.postJson(
          '/api/auth/verify-number',
          body: {'code': code.replaceAll(' ', '')},
          unauthorizedEndsSession: false,
        );
        if (!await _store(body)) throw const AccountActionException(_unusable);
      });

  /// Fixes a number mistyped at sign-up, before it was ever verified. The
  /// team then checks the new one.
  Future<void> correctNumber(String phone) => _action(() async {
        if (_auth != null) throw const AccountActionException(_unavailableInAuth);
        final body = await _client.postJson(
          '/api/auth/number',
          body: {'phone': _digits(phone), 'country_code': 'CI'},
          unauthorizedEndsSession: false,
        );
        if (!await _store(body)) throw const AccountActionException(_unusable);
      });

  static const _unavailableInAuth = 'Cette action n\'est pas encore disponible avec ce mode de connexion. Contactez l\'équipe Fidelia.';

  // --- Sign-in through the platform auth service ----------------------------

  Future<SignInResult> _authSignIn(String phone, String password) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    try {
      final body = await _auth!.postJson(
        '/v1/login',
        body: {'phone': _digits(phone), 'password': password, 'product': _product, 'app': appRole},
        authenticated: false,
      );
      if (!await _store(body, username: maskPhone(digits))) return const SignInUnavailable(_unusable);
      _signInPassword = body['must_change_password'] == true ? password : null;
      return SignInSuccess(await currentUsername() ?? '');
    } on ClientErrorException catch (error) {
      return SignInRejected(_authMessage(error));
    } on ServerErrorException {
      return const SignInUnavailable('Le serveur est indisponible');
    } on NetworkException catch (error) {
      return SignInUnavailable(error.message);
    } on ApiException catch (error) {
      return SignInUnavailable(error.message);
    }
  }

  /// Sign-up at auth: no session yet. The account waits for the code a Fidelia admin sends on WhatsApp (see [claim]).
  Future<SignInResult> _authRegister(String phone, String password) async {
    try {
      await _auth!.postJson(
        '/v1/register',
        body: {'phone': _digits(phone), 'password': password, 'product': _product, 'consent': true},
        authenticated: false,
      );
      return const SignInNeedsClaim(activationPending);
    } on ClientErrorException catch (error) {
      return SignInRejected(_authMessage(error));
    } on ServerErrorException {
      return const SignInUnavailable('Le serveur est indisponible');
    } on NetworkException catch (error) {
      return SignInUnavailable(error.message);
    } on ApiException catch (error) {
      return SignInUnavailable(error.message);
    }
  }

  /// Activates with the WhatsApp code, signs in with the password chosen at sign-up, and records the loyalty consent ticked at
  /// sign-up (a fidelia setting, kept in fidelia).
  Future<SignInResult> _authActivate(String phone, String code, String password, String? loyaltyConsentVersion) async {
    try {
      await _auth!.postJson('/v1/activate', body: {'phone': _digits(phone), 'code': code.replaceAll(' ', '')}, authenticated: false);
    } on ClientErrorException catch (error) {
      return SignInRejected(_authMessage(error));
    } on ServerErrorException {
      return const SignInUnavailable('Le serveur est indisponible');
    } on NetworkException catch (error) {
      return SignInUnavailable(error.message);
    } on ApiException catch (error) {
      return SignInUnavailable(error.message);
    }
    final result = await _authSignIn(phone, password);
    if (result is SignInSuccess && loyaltyConsentVersion != null) {
      try {
        await _client.putJson('/api/customer/loyalty-consent', body: {'consent_version': loyaltyConsentVersion});
      } on ApiException {
        // Not fatal: the switch in the account screen offers it again.
      }
    }
    return result;
  }

  static String _authMessage(ClientErrorException error) => switch (error.detail) {
        'invalid_credentials' => 'Numéro ou mot de passe incorrect.',
        'not_activated' => 'Ce compte n\'est pas encore activé : saisissez le code envoyé par l\'équipe Fidelia sur WhatsApp.',
        'account_blocked' => 'Ce compte est suspendu. Contactez Fidelia.',
        'no_access_to_app' => 'Ce numéro n\'a pas accès à cette application.',
        'login_locked' => 'Trop d\'essais. Réessayez dans 15 minutes.',
        'temp_password_expired' => 'Ce mot de passe temporaire a expiré. Demandez-en un nouveau.',
        'rate_limited' => 'Trop de tentatives. Réessayez dans quelques minutes.',
        'phone_taken' => 'Ce numéro a déjà un compte : connectez-vous, ou demandez un nouveau mot de passe.',
        'wrong_activation_code' => 'Code incorrect ou expiré.',
        'weak_password' => 'Mot de passe trop simple : choisissez-en un autre.',
        final String other => other,
        _ => error.message,
      };

  /// "07 •• •• 03 04" from the digits typed, the way the account name is shown.
  static String maskPhone(String digits) {
    final d = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return d.length < 10 ? '•• •• ••' : '${d.substring(0, 2)} •• •• ${d.substring(6, 8)} ${d.substring(8, 10)}';
  }

  static String _digits(String phone) => phone.replaceAll(RegExp(r'\s+'), '');

  /// Renews the access token. True when a new one is stored; false when the
  /// server refused the refresh token (the session is over). Throws
  /// [NetworkException] or [ServerErrorException] when the server could not
  /// say, so being offline never signs anyone out.
  Future<bool> refresh() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;
    final completer = _refreshing = Completer<bool>();
    _doRefresh().then(completer.complete, onError: completer.completeError).whenComplete(() => _refreshing = null);
    return completer.future;
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final body = await (_auth ?? _client).postJson(
        _auth != null ? '/v1/refresh' : '/api/auth/refresh',
        body: {'refresh_token': refreshToken},
        authenticated: false,
      );
      return _store(body, username: await currentUsername());
    } on ClientErrorException {
      return false;
    }
  }

  Future<bool> _store(Map<String, Object?> body, {String? username}) async {
    final access = body['access_token'];
    final refresh = body['refresh_token'];
    if (access is! String || access.isEmpty || refresh is! String || refresh.isEmpty) return false;
    await _tokenStore.save(
      token: access,
      refreshToken: refresh,
      username: body['phone_masked'] as String? ?? username ?? '',
    );
    return true;
  }

  /// Ends the session: revoked on the server when reachable, always wiped
  /// here. Offline, the refresh token dies with the local copy anyway, and
  /// the last access token expires within the hour.
  Future<void> signOut() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    _signInPassword = null;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await (_auth ?? _client).postJson(_auth != null ? '/v1/logout' : '/api/auth/logout', body: {'refresh_token': refreshToken}, authenticated: false);
      } on ApiException {
        // Best effort; the local wipe below is what matters on this device.
      }
    }
    await _tokenStore.clear();
  }

  // --- Account recovery (fidelia-BE app/api/account.py) ---------------------

  /// Ends every session but this device's: a lost or stolen phone that is
  /// still signed in loses access within the hour. Returns how many ended.
  Future<int> revokeOtherSessions() => _action(() async {
        if (_auth != null) throw const AccountActionException(_unavailableInAuth);
        final refreshToken = await _tokenStore.readRefreshToken();
        final body = await _client.postJson(
          '/api/auth/sessions/revoke-others',
          body: {if (refreshToken != null) 'refresh_token': refreshToken},
        );
        final revoked = body['revoked'];
        return revoked is int ? revoked : 0;
      });

  /// Asks the team for a WhatsApp code on [newPhone]. The password proves
  /// the person: a phone left unlocked must not be enough to move the
  /// account. Returns the masked new number.
  Future<String> requestNumberChange({required String newPhone, required String password}) => _action(() async {
        final auth = _auth;
        if (auth != null) {
          try {
            final body = await auth.postJson(
              '/v1/me/phone/request',
              body: {'new_phone': newPhone.replaceAll(RegExp(r'\s+'), ''), 'current_password': password},
              unauthorizedEndsSession: false,
            );
            return body['new_phone_masked'] as String? ?? newPhone;
          } on ClientErrorException catch (e) {
            throw AccountActionException(switch (e.detail) {
              'invalid_credentials' => 'Mot de passe incorrect.',
              'phone_taken' => 'Ce numéro a déjà un compte Fidelia.',
              'same_phone' => 'C\'est déjà le numéro de ce compte.',
              'staff_cannot_change_phone' => 'Les comptes de l\'équipe changent de numéro par un super administrateur.',
              'login_locked' => 'Trop d\'essais. Réessayez dans 15 minutes.',
              'rate_limited' => 'Trop de demandes aujourd\'hui. Réessayez demain.',
              final String other => other,
              _ => e.message,
            });
          }
        }
        final body = await _client.postJson(
          '/api/auth/change-number/request',
          body: {'new_phone': newPhone, 'country_code': 'CI', 'password': password},
          unauthorizedEndsSession: false,
        );
        return body['new_phone_masked'] as String? ?? newPhone;
      });

  /// Moves the account to the new number with the code the team sent there.
  /// The server ends every other session and returns a new one for this
  /// device, stored here. Returns the masked new number.
  Future<String> confirmNumberChange(String code) => _action(() async {
        final auth = _auth;
        if (auth != null) {
          final Map<String, Object?> body;
          try {
            body = await auth.postJson('/v1/me/phone/confirm', body: {'code': code.replaceAll(' ', '')}, unauthorizedEndsSession: false);
          } on ClientErrorException catch (e) {
            throw AccountActionException(switch (e.detail) {
              'wrong_activation_code' => 'Code incorrect ou expiré.',
              'no_activation_code' => 'Aucun code en cours : refaites la demande.',
              'activation_locked' => 'Trop d\'essais : refaites la demande.',
              'phone_taken' => 'Ce numéro a déjà un compte Fidelia.',
              'product_unavailable' => 'Le service est momentanément indisponible. Réessayez dans quelques minutes avec le même code.',
              final String other => other,
              _ => e.message,
            });
          }
          final effective = body['effective_at'];
          if (body['status'] == 'scheduled' && effective is String) {
            // A security delay: the old number keeps working until then, nothing to renew yet.
            numberChangeScheduledFor = DateTime.tryParse(effective)?.toLocal();
            return body['phone_masked'] as String? ?? '';
          }
          numberChangeScheduledFor = null;
          // This session stays alive on the old number's token: renew it, which carries the new number.
          if (!await refresh()) throw const AccountActionException(_unusable);
          return await currentUsername() ?? '';
        }
        final body = await _client.postJson(
          '/api/auth/change-number/confirm',
          body: {'code': code.replaceAll(' ', '')},
          unauthorizedEndsSession: false,
        );
        if (!await _store(body)) throw const AccountActionException(_unusable);
        return await currentUsername() ?? '';
      });

  /// Old number gone: from a session on the new, verified number, files the
  /// request a Fidelia admin reviews. Returns the server's message saying
  /// what happens next.
  Future<String> fileRecovery({required String oldPhone, required String details}) => _action(() async {
        if (_auth != null) throw const AccountActionException(_unavailableInAuth);
        final body = await _client.postJson(
          '/api/auth/recovery',
          body: {'old_phone': oldPhone, 'country_code': 'CI', 'details': details},
        );
        return body['message'] as String? ?? '';
      });

  Future<T> _action<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ClientErrorException catch (error) {
      throw AccountActionException(_detail(error));
    } on ServerErrorException {
      throw const AccountActionException('Le serveur est indisponible');
    } on ApiException catch (error) {
      throw AccountActionException(error.message);
    }
  }

  static String _detail(ClientErrorException error) =>
      error.detail is String ? error.detail as String : error.message;
}
