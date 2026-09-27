import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_repository.dart';
import 'auth/token_store.dart';
import 'djassa_api.dart';
import 'net/api_client.dart';

/// Wiring for the whole app. Nothing here holds UI state.

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  final client = ApiClient(
    tokenProvider: tokenStore.readToken,
    // A 401 from any call means the token is dead. Clear it once, here.
    onUnauthorized: () async {
      await tokenStore.clear();
      ref.read(sessionProvider.notifier).onTokenRejected();
    },
  );
  ref.onDispose(client.close);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    client: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final djassaApiProvider = Provider<DjassaApi>((ref) => DjassaApi(ref.watch(apiClientProvider)));

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

  Future<SignInResult> signIn({required String username, required String password}) async {
    final result = await ref.read(authRepositoryProvider).signIn(username: username, password: password);
    if (result is SignInSuccess) {
      state = SessionState(signedIn: true, username: result.username, checked: true);
    }
    return result;
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const SessionState(signedIn: false, checked: true);
  }

  void onTokenRejected() {
    state = const SessionState(signedIn: false, checked: true);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
