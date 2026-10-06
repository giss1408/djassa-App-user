import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/model/loyalty.dart';
import '../core/model/venue.dart';
import '../core/net/api_exception.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'sign_in_gate.dart';

/// Points per venue, progress to the next reward, and where points came from.
class LoyaltyTab extends ConsumerStatefulWidget {
  const LoyaltyTab({super.key});

  @override
  ConsumerState<LoyaltyTab> createState() => _LoyaltyTabState();
}

class _LoyaltyTabState extends ConsumerState<LoyaltyTab> {
  Loyalty? _loyalty;
  Object? _error;
  int? _redeeming;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    if (!ref.read(sessionProvider).signedIn) return;
    try {
      final l = await ref.read(djassaApiProvider).loyalty();
      if (mounted) setState(() => _loyalty = l);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _redeem(Reward reward) async {
    setState(() => _redeeming = reward.id);
    try {
      final voucher = await ref.read(djassaApiProvider).redeem(reward.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(context: context, builder: (_) => _VoucherSheet(voucher: voucher));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    } finally {
      if (mounted) setState(() => _redeeming = null);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(sessionProvider.select((s) => s.signedIn))) return const _SignedOut();
    final l = _loyalty;
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: Strings.loyaltyTitle,
            subtitle: Strings.myPoints,
            gradient: DjassaColors.loyaltyGradient,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(l == null ? '—' : '${l.totalPoints}', style: serifStyle(72, color: Colors.white, height: 0.95)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${Strings.points} · ${l?.venues.length ?? 0} ${Strings.places}',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  LoadError(onRetry: _load)
                else if (l == null)
                  const LoadingCards(count: 2)
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 17, color: DjassaColors.muted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(Strings.noCashOut, style: text.bodySmall)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (l.venues.isEmpty)
                    const EmptyState(icon: Icons.stars_rounded, title: Strings.noPointsYet, message: Strings.noPointsHint),
                  for (final b in l.venues) _VenueLoyaltyCard(balance: b, redeeming: _redeeming, onRedeem: _redeem),
                  if (l.history.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const SectionHeader(Strings.history),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(children: [for (final e in l.history) _HistoryRow(entry: e)]),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueLoyaltyCard extends StatelessWidget {
  const _VenueLoyaltyCard({required this.balance, required this.redeeming, required this.onRedeem});

  final VenueBalance balance;
  final int? redeeming;
  final ValueChanged<Reward> onRedeem;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final next = balance.rewards
        .where((r) => r.costPoints > balance.points)
        .fold<Reward?>(null, (best, r) => best == null || r.costPoints < best.costPoints ? r : best);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProgressRing(
                  value: next == null ? 1 : balance.points / next.costPoints,
                  child: Text('${balance.points}', style: serifStyle(26, color: DjassaColors.green, height: 1)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(balance.venueName, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (next != null)
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${Strings.missing} ${next.costPoints - balance.points} ${Strings.pts} '),
                            TextSpan(
                                text: '→ ${next.title}', style: const TextStyle(fontWeight: FontWeight.w700, color: DjassaColors.inkSoft)),
                          ]),
                          style: text.bodySmall,
                        )
                      else
                        Text(Strings.allUnlocked, style: text.bodySmall?.copyWith(color: DjassaColors.green, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 12),
            for (final r in balance.rewards)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                decoration: BoxDecoration(
                  color: balance.points >= r.costPoints ? DjassaColors.greenTint : Colors.transparent,
                  borderRadius: BorderRadius.circular(DjassaRadius.sm + 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      balance.points >= r.costPoints ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                      size: 18,
                      color: balance.points >= r.costPoints ? DjassaColors.green : DjassaColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          Text('${r.costPoints} ${Strings.pts}', style: text.bodySmall),
                        ],
                      ),
                    ),
                    if (balance.points >= r.costPoints)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: DjassaColors.green,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        onPressed: redeeming == null ? () => onRedeem(r) : null,
                        child: redeeming == r.id
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text(Strings.redeem),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Circular progress towards the next reward, with the balance inside.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, required this.child});

  final double value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            strokeWidth: 5,
            strokeCap: StrokeCap.round,
            backgroundColor: DjassaColors.greenTint,
            color: DjassaColors.green,
          ),
          Center(child: child),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final LoyaltyEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final earned = entry.points > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: earned ? DjassaColors.greenTint : DjassaColors.orangeTint, shape: BoxShape.circle),
            child: Icon(earned ? Icons.add_rounded : Icons.redeem_rounded,
                size: 20, color: earned ? DjassaColors.green : DjassaColors.orangeDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  earned ? '${Strings.earnedAt} ${entry.venueName}' : '${entry.rewardTitle ?? ''} · ${entry.voucherCode ?? ''}',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${earned ? '' : '${entry.venueName} · '}${Strings.shortDateTime(entry.createdAt)}',
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(earned ? '+${entry.points}' : '${entry.points}',
              style: text.titleSmall?.copyWith(color: earned ? DjassaColors.green : DjassaColors.orangeDeep)),
        ],
      ),
    );
  }
}

class _VoucherSheet extends StatelessWidget {
  const _VoucherSheet({required this.voucher});

  final Voucher voucher;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_rounded, size: 44, color: DjassaColors.orangeDeep),
            const SizedBox(height: 10),
            Text(Strings.voucherTitle, style: text.headlineMedium),
            const SizedBox(height: 4),
            Text('${voucher.rewardTitle} · ${voucher.venueName}', style: text.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(color: DjassaColors.paper, borderRadius: BorderRadius.circular(DjassaRadius.lg + 4)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Ticket(
                  top: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                    child: Column(children: [
                      Text(Strings.voucherShow.toUpperCase(), style: text.labelSmall, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      SelectableText(voucher.code,
                          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: 10, color: DjassaColors.ink)),
                    ]),
                  ),
                  bottom: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Text('${voucher.remainingPoints} ${Strings.pts} ${Strings.remaining}',
                        style: text.bodySmall, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text(Strings.done)),
          ],
        ),
      ),
    );
  }
}


/// The loyalty tab before sign-in: what points are, and the way in.
class _SignedOut extends ConsumerWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const GradientHeader(title: Strings.loyaltyTitle, subtitle: Strings.myPoints, gradient: DjassaColors.loyaltyGradient),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(Strings.signInToSeePoints, style: text.bodyLarge),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ensureSignedIn(context, ref, reason: Strings.signInToSeePoints),
                child: const Text(Strings.signInAction),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
