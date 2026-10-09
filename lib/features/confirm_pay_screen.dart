import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/fidelia_api.dart';
import '../core/model/payment.dart';
import '../core/net/api_exception.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'receipt_screen.dart';
import 'wave_wait_screen.dart';

/// Step 2 of paying: check who you are paying, then confirm twice — once on
/// this screen, once in a summary sheet — before any money moves.
///
/// ## Retrying without paying twice
///
/// If the request times out we cannot know whether it reached the server. The
/// form then locks and "Réessayer" resends the SAME request with the SAME
/// idempotency key: the server answers with the original payment if it went
/// through, so the customer is never charged twice. Editing is blocked in
/// that state on purpose, since a new amount under the old key would be
/// silently ignored.
class ConfirmPayScreen extends ConsumerStatefulWidget {
  const ConfirmPayScreen({super.key, required this.target});

  final PayTarget target;

  @override
  ConsumerState<ConfirmPayScreen> createState() => _ConfirmPayScreenState();
}

class _ConfirmPayScreenState extends ConsumerState<ConfirmPayScreen> {
  final _amount = TextEditingController();
  final _phone = TextEditingController();
  Wallet _wallet = Wallet.wave;
  bool _busy = false;
  String? _error;
  String? _uncertainKey;
  Timer? _ticker;
  Duration? _left;

  PayTarget get t => widget.target;

  @override
  void initState() {
    super.initState();
    if (t.expiresAt != null) {
      _tick();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    final left = t.expiresAt!.difference(DateTime.now());
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (left.isNegative) _ticker?.cancel();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  int? get _amountValue => t.amount ?? int.tryParse(_amount.text);
  bool get _expired => _left == Duration.zero;
  bool get _locked => _busy || _uncertainKey != null;

  String? _validate() {
    final amount = _amountValue;
    if (amount == null || amount < 100 || amount > 2000000) return Strings.amountInvalid;
    if (_phone.text.replaceAll(RegExp(r'[^0-9]'), '').length < 8) return Strings.phoneInvalid;
    return null;
  }

  Future<void> _review() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    FocusScope.of(context).unfocus();
    // Retrying an uncertain request skips the sheet: it was already confirmed.
    if (_uncertainKey == null) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        builder: (_) => _ConfirmSheet(target: t, amount: _amountValue!, wallet: _wallet, phone: _phone.text),
      );
      if (ok != true || !mounted) return;
    }
    await _pay();
  }

  Future<void> _pay() async {
    ref.read(usageTrackerProvider).track('payment_started', {'wallet': _wallet.name});
    final key = _uncertainKey ?? newIdempotencyKey();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payment = await ref.read(fideliaApiProvider).pay(
            payCode: t.code,
            amount: t.fixedAmount ? null : _amountValue,
            wallet: _wallet,
            payerPhone: '+225 ${_phone.text}',
            idempotencyKey: key,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _uncertainKey = null;
      });
      HapticFeedback.heavyImpact();
      if (!payment.awaitsWallet) {
        ref.read(usageTrackerProvider).track('payment_completed', {'wallet': _wallet.name, 'status': payment.status});
      }
      // A Wave checkout is approved in the Wave app first; the wait screen
      // opens it and hands over to the receipt once Wave has answered.
      final again = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => payment.awaitsWallet ? WaveWaitScreen(payment: payment) : ReceiptScreen(payment: payment)));
      // A declined payment offers "try again" and lands back here; anything
      // else closes the flow.
      if (mounted && again != true) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.isRetryable) {
          _uncertainKey = key;
          _error = Strings.payNetworkError;
        } else {
          _uncertainKey = null;
          _error = errorMessage(e);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final amount = _amountValue;
    final points = amount == null ? 0 : (amount ~/ 100) * t.pointsPer100;
    final payout = Wallet.fromWire(t.payoutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.confirmTitle)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _busy || _expired ? null : _review,
            child: _busy
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                    SizedBox(width: 12),
                    Text(Strings.paying),
                  ])
                : Text(_uncertainKey != null
                    ? Strings.retry
                    : amount == null
                        ? Strings.payAmount
                        : '${Strings.payAmount} ${francs(amount)}'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // Who: as the server knows them.
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  VenueThumb(id: t.venueId, category: t.category, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.name, style: text.titleMedium),
                      Text(t.commune, style: text.bodySmall),
                    ]),
                  ),
                  if (t.isSample) const Tag.sample(),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: FideliaColors.pharmacyTint, borderRadius: BorderRadius.circular(FideliaRadius.sm)),
                  child: const Row(children: [
                    Icon(Icons.verified_rounded, size: 20, color: FideliaColors.success),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(Strings.verifiedMerchant,
                          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0B5E3F), fontSize: 14)),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  const SizedBox(width: 4),
                  if (payout != null) ...[WalletSwatch(payout, size: 10), const SizedBox(width: 8)],
                  Text('${Strings.receivedOn} ${payout?.label ?? t.payoutProvider} ${t.payoutAccountMasked}', style: text.bodySmall),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // How much.
          if (t.fixedAmount)
            PatternedSurface(
              gradient:
                  const LinearGradient(colors: [FideliaColors.ink, Color(0xFF0E1513)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(FideliaRadius.lg),
              patternOpacity: 0.06,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(Strings.amountFixed.toUpperCase(),
                      style:
                          TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Text(francs(t.amount!), style: serifStyle(58, color: Colors.white)),
                  if (_left != null) ...[
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.timer_outlined, size: 16, color: _expired ? const Color(0xFFFF9C80) : Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        _expired
                            ? 'QR code expiré'
                            : '${Strings.expiresIn} ${_left!.inMinutes}:${(_left!.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(color: _expired ? const Color(0xFFFF9C80) : Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ],
                ],
              ),
            )
          else ...[
            Text(Strings.amount, style: text.labelMedium),
            const SizedBox(height: 8),
            TextField(
              key: const Key('pay-amount'),
              controller: _amount,
              enabled: !_locked,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
              onChanged: (_) => setState(() {}),
              style: serifStyle(52),
              decoration: const InputDecoration(hintText: Strings.amountHint, suffixText: 'F CFA'),
            ),
          ],
          const SizedBox(height: 22),

          // With what.
          Text(Strings.wallet, style: text.labelMedium),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.1,
            children: [
              for (final w in Wallet.values)
                _WalletTile(wallet: w, selected: _wallet == w, onTap: _locked ? null : () => setState(() => _wallet = w)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('pay-phone'),
            controller: _phone,
            enabled: !_locked,
            keyboardType: TextInputType.phone,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: Strings.walletPhone,
              hintText: Strings.walletPhoneHint,
              prefixIcon: Icon(Icons.phone_iphone_rounded),
              prefixText: '+225 ',
            ),
          ),
          const SizedBox(height: 18),
          if (points > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: FideliaColors.greenTint, borderRadius: BorderRadius.circular(FideliaRadius.md)),
              child: Row(children: [
                const Icon(Icons.stars_rounded, color: FideliaColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${Strings.youWillEarn} $points ${Strings.points}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: FideliaColors.green, fontSize: 15)),
                ),
              ]),
            ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined, size: 18, color: FideliaColors.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(Strings.fundsNotice, style: text.bodySmall)),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFDE4E4), borderRadius: BorderRadius.circular(FideliaRadius.md)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline_rounded, color: FideliaColors.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFF8E1C1C), fontSize: 14.5))),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({required this.wallet, required this.selected, required this.onTap});

  final Wallet wallet;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FideliaColors.orangeTint : FideliaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FideliaRadius.md),
        side: BorderSide(color: selected ? FideliaColors.orangeDeep : FideliaColors.line, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FideliaRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            WalletSwatch(wallet, size: 14),
            const SizedBox(width: 10),
            Expanded(child: Text(wallet.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5), maxLines: 1)),
            if (selected) const Icon(Icons.check_circle_rounded, color: FideliaColors.orangeDeep, size: 20),
          ]),
        ),
      ),
    );
  }
}

/// The final, explicit "yes": amount, recipient and wallet in one sentence.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.target, required this.amount, required this.wallet, required this.phone});

  final PayTarget target;
  final int amount;
  final Wallet wallet;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Strings.sheetTitle, style: text.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(francs(amount), style: text.displaySmall?.copyWith(fontSize: 56), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: [
                _Line(label: Strings.sheetTo, value: target.name),
                const Divider(height: 1),
                _Line(label: Strings.sheetWith, value: '${wallet.label} · +225 $phone', leading: WalletSwatch(wallet, size: 10)),
              ]),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.lock_rounded, size: 20),
              label: const Text(Strings.sheetConfirm),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(Strings.cancel)),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.leading});

  final String label;
  final String value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        SizedBox(width: 44, child: Text(label, style: text.bodySmall)),
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(child: Text(value, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
