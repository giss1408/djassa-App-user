import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_repository.dart';
import '../core/config/env.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'about_name_screen.dart';

/// Sign-in against the backend's demo accounts. Phone-number login anchored
/// to the mobile-money wallet is the intended Tier 0 identity; it does not
/// exist server-side yet, so this speaks the username/password API that does.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  // Prefilled only in debug builds given DJASSA_DEV_* defines. See Env.
  final _username = TextEditingController(text: Env.devUsername);
  final _password = TextEditingController(text: Env.devPassword);
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(sessionProvider.notifier).signIn(username: _username.text.trim(), password: _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = switch (result) {
        SignInSuccess() => null,
        SignInRejected() => Strings.signInRejected,
        SignInUnavailable(message: final m) => m,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PatternedSurface(
            gradient: DjassaColors.headerGradient,
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
                  child: Text('d', style: serifStyle(44, color: DjassaColors.orangeDeep, height: 0.9)),
                ),
                const SizedBox(height: 22),
                Text(Strings.signInTitle, style: serifStyle(42, color: Colors.white)),
                const SizedBox(height: 8),
                Text(Strings.signInSubtitle, style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 15.5, height: 1.4)),
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
                TextField(
                  controller: _username,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: Strings.username, prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: Strings.password,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: DjassaColors.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: text.bodyMedium?.copyWith(color: DjassaColors.danger))),
                  ]),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text(Strings.signIn),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutNameScreen())),
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
