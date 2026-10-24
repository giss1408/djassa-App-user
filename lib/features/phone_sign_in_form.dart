import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_repository.dart';
import '../core/config/env.dart';
import '../core/fidelia_api.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import 'account_screen.dart';
import 'password_screens.dart';

enum _Mode { signIn, register, claim }

/// Phone number and password: sign in, or create the account.
///
/// A new account opens at once; the sign-in screen then asks for the code a
/// Fidelia admin sends on WhatsApp. A number that already has an account
/// without a password (from the SMS days) gets the code first, typed here
/// with the new password ([_Mode.claim]).
///
/// Nothing is remembered between launches: the number is the account, and a
/// shared phone should not offer the last person's.
class PhoneSignInForm extends ConsumerStatefulWidget {
  const PhoneSignInForm({super.key});

  @override
  ConsumerState<PhoneSignInForm> createState() => _PhoneSignInFormState();
}

class _PhoneSignInFormState extends ConsumerState<PhoneSignInForm> {
  // Prefilled only in debug builds given FIDELIA_DEV_PHONE. See Env.
  final _phone = TextEditingController(text: Env.devPhone);
  final _password = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _hidden = true;
  bool _busy = false;
  // Loyalty consent. Never pre-ticked: agreeing has to be the customer's act.
  bool _consent = false;
  String? _error;
  String? _claimMessage;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _switch(_Mode mode) => setState(() {
        _mode = mode;
        _error = null;
        _code.clear();
      });

  Future<void> _submit() async {
    if (_busy) return;
    final phone = _phone.text.trim();
    final password = _password.text;
    String? problem;
    if (phone.isEmpty) {
      problem = Strings.signInPhoneMissing;
    } else if (password.isEmpty) {
      problem = Strings.signInPasswordMissing;
    } else if (_mode != _Mode.signIn && !isAcceptablePassword(password)) {
      problem = Strings.passwordRule;
    } else if (_mode == _Mode.claim && _code.text.length != 6) {
      problem = Strings.verifyCodeMissing;
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = ref.read(sessionProvider.notifier);
    final consent = _consent ? loyaltyConsentVersion : null;
    final result = await switch (_mode) {
      _Mode.signIn => session.signIn(phone: phone, password: password),
      _Mode.register => session.register(phone: phone, password: password, loyaltyConsentVersion: consent),
      _Mode.claim => session.claim(phone: phone, code: _code.text, password: password, loyaltyConsentVersion: consent),
    };
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        // The sign-in screen moves on, or closes.
        case SignInSuccess():
          _error = null;
        case SignInNeedsClaim(:final message):
          _mode = _Mode.claim;
          _claimMessage = message;
          _error = null;
        case SignInRejected(:final message) || SignInUnavailable(:final message):
          _error = message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final signingIn = _mode == _Mode.signIn;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mode == _Mode.claim) ...[
            Text(Strings.claimTitle, style: text.titleMedium),
            const SizedBox(height: 6),
            Text(_claimMessage ?? '', style: text.bodyMedium),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _phone,
            enabled: !_busy && _mode != _Mode.claim,
            keyboardType: TextInputType.phone,
            autocorrect: false,
            // Never suggest a number: a market phone is often shared.
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(20)],
            decoration: const InputDecoration(
              labelText: Strings.signInPhoneLabel,
              hintText: Strings.signInPhoneHint,
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
          ),
          if (_mode == _Mode.claim) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _code,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              style: const TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: Strings.claimCodeLabel, prefixIcon: Icon(Icons.chat_outlined)),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: _hidden,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: [signingIn ? AutofillHints.password : AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: signingIn ? Strings.signInPasswordLabel : Strings.newPassword,
              helperText: signingIn ? null : Strings.passwordRule,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _hidden ? Strings.showPassword : Strings.hidePassword,
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
          ),
          if (!signingIn) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _consent,
              onChanged: _busy ? null : (v) => setState(() => _consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(Strings.loyaltyConsent, style: text.bodySmall),
            ),
          ],
          ErrorLine(_error),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(switch (_mode) {
                    _Mode.signIn => Strings.signIn,
                    _Mode.register => Strings.register,
                    _Mode.claim => Strings.claimAction,
                  }),
          ),
          const SizedBox(height: 8),
          if (_mode == _Mode.claim)
            TextButton(onPressed: _busy ? null : () => _switch(_Mode.register), child: const Text(Strings.back))
          else
            TextButton(
              onPressed: _busy ? null : () => _switch(signingIn ? _Mode.register : _Mode.signIn),
              child: Text(signingIn ? Strings.noAccount : Strings.haveAccount),
            ),
          if (signingIn) ...[
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        settings: const RouteSettings(name: 'forgot_password'),
                        builder: (_) => ForgotPasswordScreen(phone: _phone.text.trim()),
                      )),
              child: const Text(Strings.forgotPassword),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'lost_number'), builder: (_) => const LostNumberScreen())),
              child: const Text(Strings.lostNumber),
            ),
          ],
        ],
      ),
    );
  }
}
