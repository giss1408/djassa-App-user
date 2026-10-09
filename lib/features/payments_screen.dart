import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/model/payment.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  List<Payment>? _payments;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await ref.read(fideliaApiProvider).payments();
      if (mounted) setState(() => _payments = list);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _payments;
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.myPayments)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_error != null)
              LoadError(onRetry: _load)
            else if (list == null)
              const LoadingCards()
            else if (list.isEmpty)
              const EmptyState(icon: Icons.receipt_long_rounded, title: Strings.noPaymentsYet, message: Strings.noPaymentsHint)
            else
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [for (final p in list) PaymentRow(payment: p)]),
              ),
          ],
        ),
      ),
    );
  }
}

/// One payment: where, when, which wallet, how much, what it earned.
class PaymentRow extends StatelessWidget {
  const PaymentRow({super.key, required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = payment;
    final wallet = Wallet.fromWire(p.walletProvider);
    final (icon, color, bg) = p.succeeded
        ? (Icons.check_rounded, FideliaColors.success, FideliaColors.pharmacyTint)
        : p.failed
            ? (Icons.close_rounded, FideliaColors.danger, const Color(0xFFFDE4E4))
            : (Icons.schedule_rounded, FideliaColors.muted, FideliaColors.sand);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
            width: 40, height: 40, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.venueName, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              if (wallet != null) ...[WalletSwatch(wallet, size: 9), const SizedBox(width: 5)],
              Flexible(
                child: Text(
                  '${wallet?.label ?? p.walletProvider} · ${Strings.shortDateTime(p.createdAt)}',
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(francs(p.amount),
              style: text.titleSmall?.copyWith(
                decoration: p.failed ? TextDecoration.lineThrough : null,
                color: p.failed ? FideliaColors.muted : FideliaColors.ink,
              )),
          if (p.pointsAwarded > 0)
            Text('+${p.pointsAwarded} ${Strings.pts}',
                style: text.bodySmall?.copyWith(color: FideliaColors.green, fontWeight: FontWeight.w700))
          else if (p.failed)
            Text(Strings.paymentFailed, style: text.bodySmall?.copyWith(color: FideliaColors.danger)),
        ]),
      ]),
    );
  }
}
