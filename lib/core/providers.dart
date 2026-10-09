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
  const SessionState({required this.signedIn, this.username, this.checked = false});

  final bool signedIn;
  final String? username;

  /// Whether the stored token has been inspected yet, so the app does not
  /// flash the sign-in screen at someone already signed in.
  final bool checked;
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionState(signedIn: false);
  }

  Future<void> restore() async {
    final auth = ref.read(authRepositoryProvider);
    final valid = await auth.hasValidSession();
    state = SessionState(
      signedIn: valid,
      username: valid ? await auth.currentUsername() : null,
      checked: true,
    );
  }

  Future<SignInResult> verifyCode({required String phone, required String code, String? loyaltyConsentVersion}) async {
    final result =
        await ref.read(authRepositoryProvider).verifyCode(phone: phone, code: code, loyaltyConsentVersion: loyaltyConsentVersion);
    if (result is SignInSuccess) {
      state = SessionState(signedIn: true, username: result.username, checked: true);
    }
    return result;
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const SessionState(signedIn: false, checked: true);
  }


  /// The account moved to another number; this device holds its new session.
  void onNumberChanged(String username) {
    state = SessionState(signedIn: true, username: username, checked: true);
  }

  void onTokenRejected() {
    state = const SessionState(signedIn: false, checked: true);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
