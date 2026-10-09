import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';

import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'about_name_screen.dart';
import 'phone_sign_in_form.dart';

/// Sign-in with a phone number and an SMS code. The number is the customer's
/// account (CONCEPT.md, Tier 0), and the same key the counter uses for
/// loyalty, so points earned at a counter are there on first sign-in.
///
/// Opened over the app when the customer wants to pay or see their points
/// (sign_in_gate.dart), with [reason] saying why; it closes itself once the
/// session is open.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    ref.listen(sessionProvider.select((s) => s.signedIn), (_, signedIn) {
      if (signedIn && Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    });

    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0)
          : null,
      extendBodyBehindAppBar: true,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PatternedSurface(
            gradient: FideliaColors.headerGradient,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
            padding: EdgeInsets.fromLTRB(28, top + 44, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  alignment: Alignment.center,
                  child: Text('d', style: serifStyle(44, color: FideliaColors.orangeDeep, height: 0.9)),
                ),
                const SizedBox(height: 22),
                Text(Strings.signInTitle, style: serifStyle(42, color: Colors.white)),
                const SizedBox(height: 8),
                Text(reason ?? Strings.signInSubtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 15.5, height: 1.4)),
                const SizedBox(height: 22),
                const Wrap(spacing: 8, runSpacing: 8, children: [
                  _Feature(icon: Icons.restaurant_rounded, label: 'Maquis'),
                  _Feature(icon: Icons.local_pharmacy_rounded, label: 'Pharmacies de garde'),
                  _Feature(icon: Icons.qr_code_scanner_rounded, label: 'Paiement QR'),
                  _Feature(icon: Icons.stars_rounded, label: 'Fidélité'),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PhoneSignInForm(),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'about_name'), builder: (_) => const AboutNameScreen())),
                  child: const Text(Strings.aboutNameLink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
