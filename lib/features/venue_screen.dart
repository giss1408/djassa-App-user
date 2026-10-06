import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/model/deal.dart';
import '../core/model/venue.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/directions.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../core/personal_lists.dart';
import 'favorite_star.dart';
import 'scan_screen.dart';
import 'sign_in_gate.dart';
import 'venue_media_strip.dart';

class VenueScreen extends ConsumerStatefulWidget {
  const VenueScreen({super.key, required this.venueId});

  final int venueId;

  @override
  ConsumerState<VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends ConsumerState<VenueScreen> {
  Venue? _venue;
  Object? _error;

  @override
  void initState() {
    super.initState();
    ref.read(usageTrackerProvider).track('venue_viewed', {'venue_id': widget.venueId});
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final v = await ref.read(hossoukoApiProvider).venue(widget.venueId);
      if (mounted) setState(() => _venue = v);
      ref.read(personalListsProvider.notifier).viewed(v);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _scan() async {
    final signedIn = await ensureSignedIn(context, ref, reason: Strings.signInToPay);
    if (!signedIn || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'scan'), builder: (_) => const ScanScreen()));
    _load(); // points here may have changed
  }

  @override
  Widget build(BuildContext context) {
    final v = _venue;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: Colors.black.withOpacity(0.22),
            shape: const CircleBorder(),
            child: const BackButton(color: Colors.white),
          ),
        ),
        actions: [if (v != null) FavoriteStar(venue: v, onDark: true)],
      ),
      bottomNavigationBar: v == null || !v.acceptsPayment
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text(Strings.scanToPay),
                ),
              ),
            ),
      body: _error != null
          ? SafeArea(child: LoadError(onRetry: _load))
          : v == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    VenueBanner(
                      venue: v,
                      height: 230 + MediaQuery.paddingOf(context).top,
                      showIcon: false,
                      // Full width on the shop page: the 720 px photo, not the list thumbnail.
                      imageUrl: v.media.where((m) => !m.isVideo).map((m) => m.mediumUrl).firstOrNull ?? v.coverUrl,
                    ),
                    Transform.translate(
                      offset: const Offset(0, -26),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: HossoukoColors.paper,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(HossoukoRadius.xl)),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              Tag(Category.labelOf(v.category), icon: CategoryStyle.of(v.category).icon),
                              if (v.acceptsPayment) const Tag.hossouko(),
                              if (v.isSample) const Tag.sample(),
                            ]),
                            const SizedBox(height: 12),
                            Text(v.name, style: text.headlineMedium),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.place_outlined, size: 17, color: HossoukoColors.muted),
                              const SizedBox(width: 4),
                              Text(v.commune, style: text.bodyMedium?.copyWith(color: HossoukoColors.muted)),
                            ]),
                            if (v.description != null) ...[
                              const SizedBox(height: 14),
                              Text(v.description!, style: text.bodyMedium?.copyWith(color: HossoukoColors.inkSoft)),
                            ],
                            if (v.media.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              VenueMediaStrip(media: v.media),
                            ],
                            const SizedBox(height: 18),
                            SoftCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              child: Column(children: [
                                if (v.specialties != null)
                                  _InfoRow(icon: Icons.ramen_dining_rounded, label: Strings.specialties, value: v.specialties!),
                                if (v.openingHours != null)
                                  _InfoRow(icon: Icons.schedule_rounded, label: Strings.hours, value: v.openingHours!),
                                if (v.address != null) _InfoRow(icon: Icons.map_outlined, label: Strings.address, value: v.address!),
                                if (v.phone != null)
                                  _InfoRow(
                                    icon: Icons.call_outlined,
                                    label: Strings.phone,
                                    value: v.phone!,
                                    trailing: IconButton.filledTonal(
                                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: v.phone!.replaceAll(' ', ''))),
                                      icon: const Icon(Icons.call_rounded),
                                      tooltip: Strings.call,
                                    ),
                                  ),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            // Directions in the phone's maps app. Always
                            // offered: without coordinates it searches the
                            // name and address, and says so.
                            OutlinedButton.icon(
                              onPressed: () => openDirections(context, v),
                              icon: const Icon(Icons.directions_rounded),
                              label: const Text(Strings.directions),
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: v.acceptsPayment ? HossoukoColors.orangeTint : const Color(0xFFF0EEE8),
                                borderRadius: BorderRadius.circular(HossoukoRadius.md),
                              ),
                              child: Row(children: [
                                Icon(v.acceptsPayment ? Icons.qr_code_2_rounded : Icons.qr_code_2_outlined,
                                    color: v.acceptsPayment ? HossoukoColors.orangeDeep : HossoukoColors.muted),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(v.acceptsPayment ? Strings.payHereHint : Strings.noPaymentHere, style: text.bodyMedium)),
                              ]),
                            ),
                            if (v.deals.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const SectionHeader(Strings.dealsHere),
                              for (final d in v.deals) DealCard(deal: d, onTap: null),
                            ],
                            if (v.pointsPer100 > 0) ...[
                              const SizedBox(height: 24),
                              Row(children: [
                                Expanded(child: Text(Strings.yourPointsHere, style: text.titleLarge)),
                                Text('${v.myPoints} ${Strings.pts}', style: text.titleLarge?.copyWith(color: HossoukoColors.green)),
                              ]),
                              Text('${v.pointsPer100} ${Strings.pointsPer100}', style: text.bodySmall),
                              const SizedBox(height: 12),
                              for (final r in v.rewards)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SoftCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.card_giftcard_rounded, size: 20, color: HossoukoColors.orangeDeep),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(r.title, style: text.titleSmall)),
                                          Text(v.myPoints >= r.costPoints ? Strings.unlocked : '${r.costPoints} ${Strings.pts}',
                                              style: text.labelMedium
                                                  ?.copyWith(color: v.myPoints >= r.costPoints ? HossoukoColors.green : HossoukoColors.muted)),
                                        ]),
                                        const SizedBox(height: 10),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(99),
                                          child: LinearProgressIndicator(
                                            value: (v.myPoints / r.costPoints).clamp(0, 1).toDouble(),
                                            minHeight: 6,
                                            backgroundColor: HossoukoColors.greenTint,
                                            color: HossoukoColors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.trailing});

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: HossoukoColors.sand, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: HossoukoColors.orangeDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: text.bodySmall),
            Text(value, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
