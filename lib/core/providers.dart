import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_repository.dart';
import 'auth/token_store.dart';
import 'fidelia_api.dart';
import 'monitoring/usage_tracker.dart';
import 'net/api_client.dart';

/// Wiring for the whole app. Nothing here holds UI state.

/// Pilot usage analytics. Disabled here; `main` overrides it with the live
/// tracker, so tests and previews never send anything.
final usageTrackerProvider = Provider<UsageTracker>((ref) => UsageTracker(app: 'user', enabled: false));

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  final client = ApiClient(
    onTraffic: ref.watch(usageTrackerProvider).addTraffic,
    // An access token past its hour is renewed before the request rather
    // than spending a round trip on a certain 401. Read lazily: the auth
    // repository itself talks through this client.
    tokenProvider: () async {
      final token = await tokenStore.readToken();
      if (token == null || token.isEmpty || !isTokenExpired(token)) return token;
      return await ref.read(authRepositoryProvider).refresh() ? tokenStore.readToken() : token;
    },
    // A 401 anyway (token revoked, clock skew): renew once and replay.
    onRefresh: () => ref.read(authRepositoryProvider).refresh(),
    // Renewal refused too: the session is over. Clear it once, here.
    onUnauthorized: () async {
      await tokenStore.clear();
      ref.read(sessionProvider.notifier).onTokenRejected();
    },
  );
  ref.onDispose(client.close);
  return client;
});

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    client: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final fideliaApiProvider = Provider<FideliaApi>((ref) => FideliaApi(ref.watch(apiClientProvider)));

/// The suggestions WhatsApp link, null while hidden. Never an error: a
/// failure just keeps the menu entry out of sight.
final suggestionsLinkProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (!ref.watch(sessionProvider.select((s) => s.signedIn))) return null;
  try {
    return await ref.watch(fideliaApiProvider).suggestionsWhatsapp();
  } catch (_) {
    return null;
  }
});

/// Whether the customer is signed in.
class SessionState {
  const SessionState({
    required this.hasSession,
    this.username,
    this.checked = false,
    this.mustChangePassword = false,
    this.numberVerified = true,
  });

  /// A session is stored, usable or not yet.
  final bool hasSession;
  final String? username;

  /// Signed in with a temporary password the team sent: it must be replaced
  /// before anything else.
  final bool mustChangePassword;

  /// False until the number is proven with a Fidelia admin's WhatsApp code.
  final bool numberVerified;

  /// A session the server accepts for everything: paying, points, account.
  /// Until then the sign-in screen stays open on the step that is missing.
  bool get signedIn => hasSession && numberVerified && !mustChangePassword;

  /// Whether the stored token has been inspected yet, so the app does not
  /// flash the sign-in screen at someone already signed in.
  final bool checked;
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionState(hasSession: false);
  }

  Future<void> restore() async {
    final valid = await ref.read(authRepositoryProvider).hasValidSession();
    state = valid ? await _stored() : const SessionState(hasSession: false, checked: true);
  }

  /// The session as the stored token describes it.
  Future<SessionState> _stored() async {
    final token = await ref.read(tokenStoreProvider).readToken() ?? '';
    return SessionState(
      hasSession: true,
      username: await ref.read(authRepositoryProvider).currentUsername(),
      checked: true,
      mustChangePassword: token.isNotEmpty && jwtMustChangePassword(token),
      numberVerified: token.isEmpty || jwtNumberVerified(token),
    );
  }

  Future<SignInResult> _opened(Future<SignInResult> attempt) async {
    final result = await attempt;
    if (result is SignInSuccess) state = await _stored();
    return result;
  }

  Future<SignInResult> signIn({required String phone, required String password}) =>
      _opened(ref.read(authRepositoryProvider).signIn(phone: phone, password: password));

  Future<SignInResult> register({required String phone, required String password, String? loyaltyConsentVersion}) => _opened(
      ref.read(authRepositoryProvider).register(phone: phone, password: password, loyaltyConsentVersion: loyaltyConsentVersion));

  Future<SignInResult> claim({required String phone, required String code, required String password, String? loyaltyConsentVersion}) =>
      _opened(ref
          .read(authRepositoryProvider)
          .claim(phone: phone, code: code, password: password, loyaltyConsentVersion: loyaltyConsentVersion));

  /// Throws [AccountActionException] with the server's words.
  Future<void> changePassword({String? current, required String newPassword}) async {
    await ref.read(authRepositoryProvider).changePassword(current: current, newPassword: newPassword);
    state = await _stored();
  }

  /// Throws [AccountActionException] with the server's words.
  Future<void> verifyNumber(String code) async {
    await ref.read(authRepositoryProvider).verifyNumber(code);
    state = await _stored();
  }

  /// Throws [AccountActionException] with the server's words.
  Future<void> correctNumber(String phone) async {
    await ref.read(authRepositoryProvider).correctNumber(phone);
    state = await _stored();
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const SessionState(hasSession: false, checked: true);
  }

  /// The account moved to another number; this device holds its new session.
  Future<void> onNumberChanged() async {
    state = await _stored();
  }

  void onTokenRejected() {
    state = const SessionState(hasSession: false, checked: true);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
