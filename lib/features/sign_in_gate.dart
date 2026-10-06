import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import 'sign_in_screen.dart';

/// Signs the customer in only when they need it: to pay, or to see their
/// points. Browsing offers, shops and pharmacies never asks.
///
/// True when a session is open, either already or after the sign-in screen;
/// false when the customer closed it without signing in.
Future<bool> ensureSignedIn(BuildContext context, WidgetRef ref, {required String reason}) async {
  if (ref.read(sessionProvider).signedIn) return true;
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'sign_in'),
      fullscreenDialog: true,
      builder: (_) => SignInScreen(reason: reason),
    ),
  );
  return ref.read(sessionProvider).signedIn;
}
