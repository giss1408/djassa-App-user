import 'package:flutter/material.dart';

import '../core/model/payment.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The outcome, in words first. Pops `true` when the customer wants to try a
/// declined payment again.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = payment;
    final (title, icon, color, tint) = p.succeeded
        ? (Strings.paymentDone, Icons.check_rounded, FideliaColors.success, FideliaColors.pharmacyTint)
        : p.failed
            ? (Strings.paymentFailed, Icons.close_rounded, FideliaColors.danger, const Color(0xFFFDE4E4))
            : (Strings.paymentPending, Icons.schedule_rounded, FideliaColors.muted, FideliaColors.sand);
    final wallet = Wallet.fromWire(p.walletProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.elasticOut,
                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                    child: Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white, size: 42),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Ticket(
                top: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Column(children: [
                    Text(title.toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: color)),
                    const SizedBox(height: 8),
                    Text(francs(p.amount), style: text.displaySmall?.copyWith(fontSize: 52), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(p.venueName, style: text.titleMedium?.copyWith(color: FideliaColors.inkSoft), textAlign: TextAlign.center),
                    if (p.succeeded && p.pointsAwarded > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(gradient: FideliaColors.loyaltyGradient, borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.stars_rounded, color: Color(0xFFFFC9A8), size: 20),
                          const SizedBox(width: 8),
                          Text('+${p.pointsAwarded} ${Strings.pointsEarned}',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ],
                    if (p.failed && p.failureReason != null) ...[
                      const SizedBox(height: 12),
                      Text(p.failureReason!, style: text.bodyMedium, textAlign: TextAlign.center),
                    ],
                  ]),
                ),
                bottom: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                  child: Column(children: [
                    _Detail(label: Strings.paidTo, value: p.venueName),
                    _Detail(
                      label: Strings.paidWith,
                      value: wallet?.label ?? p.walletProvider,
                      leading: wallet == null ? null : WalletSwatch(wallet, size: 10),
                    ),
                    _Detail(label: Strings.date, value: Strings.shortDateTime(p.createdAt)),
                    if (p.providerReference != null) _Detail(label: Strings.reference, value: p.providerReference!, mono: true),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              if (p.failed) ...[
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(Strings.tryAgain)),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(Strings.done)),
              ] else
                FilledButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(Strings.done)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.leading, this.mono = false});

  final String label;
  final String value;
  final Widget? leading;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Expanded(child: Text(label, style: text.bodySmall)),
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontFamily: mono ? 'monospace' : null)),
        ),
      ]),
    );
  }
}
