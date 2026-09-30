import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/model/payment.dart';
import '../core/net/api_exception.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'receipt_screen.dart';

/// A Wave payment waits for the customer's approval in the Wave app.
///
/// The server created a checkout with the MERCHANT's own Wave account, so the
/// money goes straight to them. This screen opens Wave's page (which hands
/// over to the Wave app), then asks the server for the outcome: every few
/// seconds, and at once when the customer comes back to Djassa. The server
/// re-reads the checkout from Wave, so a late notification does not block.
///
/// Pops what the receipt pops (`true` = try again after a decline).
class WaveWaitScreen extends ConsumerStatefulWidget {
  const WaveWaitScreen({super.key, required this.payment});

  final Payment payment;

  @override
  ConsumerState<WaveWaitScreen> createState() => _WaveWaitScreenState();
}

class _WaveWaitScreenState extends ConsumerState<WaveWaitScreen> with WidgetsBindingObserver {
  // Wave checkouts stay open for a while; past this the screen stops asking
  // on its own and the payment list takes over.
  static const _giveUpAfter = Duration(minutes: 10);
  static const _every = Duration(seconds: 4);

  Timer? _timer;
  late final DateTime _started = DateTime.now();
  bool _checking = false;
  bool _gaveUp = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openWave());
    _timer = Timer.periodic(_every, (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _openWave() async {
    var ok = false;
    try {
      // External: Wave's page must run in the browser to hand over to the app.
      ok = await launchUrl(Uri.parse(widget.payment.checkoutUrl!), mode: LaunchMode.externalApplication);
    } on Exception {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.waveOpenFailed)));
    }
  }

  Future<void> _check() async {
    if (_checking || _done) return;
    if (DateTime.now().difference(_started) > _giveUpAfter) {
      _timer?.cancel();
      if (mounted) setState(() => _gaveUp = true);
      return;
    }
    _checking = true;
    try {
      final p = await ref.read(djassaApiProvider).payment(widget.payment.id);
      if (!mounted || p.status == 'pending') return;
      _done = true;
      _timer?.cancel();
      final again = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ReceiptScreen(payment: p)));
      if (mounted) Navigator.of(context).pop(again);
    } on ApiException {
      // Offline or asleep: the next tick tries again.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = widget.payment;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            children: [
              const Center(child: WalletSwatch(Wallet.wave, size: 56)),
              const SizedBox(height: 20),
              Text(Strings.waveWaitTitle, style: text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(francs(p.amount), style: serifStyle(48), textAlign: TextAlign.center),
              Text(p.venueName, style: text.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SoftCard(child: Text(Strings.waveWaitBody, style: text.bodyMedium)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (!_gaveUp) ...[
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(_gaveUp ? Strings.waveStillPending : Strings.waveChecking,
                      style: text.bodySmall, textAlign: TextAlign.center),
                ),
              ]),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _openWave,
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                label: const Text(Strings.waveOpen),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(Strings.done, style: TextStyle(color: DjassaColors.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
