import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/model/venue.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/directions.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'venue_screen.dart';

/// Pharmacies on duty ("de garde") right now.
///
/// The screen people open in a hurry, often at night: who is open, until
/// when, and a Call button — nothing in the way.
class PharmaciesTab extends ConsumerStatefulWidget {
  const PharmaciesTab({super.key, this.showBack = false});

  /// Set when pushed as its own screen rather than shown in a tab.
  final bool showBack;

  @override
  ConsumerState<PharmaciesTab> createState() => _PharmaciesTabState();
}

class _PharmaciesTabState extends ConsumerState<PharmaciesTab> {
  String? _commune;
  List<Venue>? _pharmacies;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await ref.read(djassaApiProvider).onDutyPharmacies(commune: _commune);
      if (mounted) setState(() => _pharmacies = list);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _call(String phone) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.callFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _pharmacies;
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: Strings.onDutyPharmacies,
            subtitle: Strings.onDutyPharmaciesSubtitle,
            leading: widget.showBack
                ? HeaderIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            gradient: const LinearGradient(
              colors: [DjassaColors.pharmacy, Color(0xFF0B5E3F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            trailing: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.local_pharmacy_rounded, color: DjassaColors.pharmacy, size: 28),
            ),
          ),
          const SizedBox(height: 14),
          CommuneFilter(
            selected: _commune,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            onChanged: (c) {
              setState(() => _commune = c);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  LoadError(onRetry: _load)
                else if (list == null)
                  const LoadingCards()
                else if (list.isEmpty)
                  const EmptyState(icon: Icons.local_pharmacy_outlined, title: Strings.noPharmacyOnDuty)
                else ...[
                  if (list.any((v) => v.isSample)) const SampleNotice(),
                  for (final p in list)
                    VenueCard(
                      venue: p,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VenueScreen(venueId: p.id))),
                      footer: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        decoration: BoxDecoration(color: DjassaColors.pharmacyTint, borderRadius: BorderRadius.circular(DjassaRadius.md)),
                        child: Row(
                          children: [
                            const Icon(Icons.nightlight_round, size: 18, color: DjassaColors.pharmacy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(Strings.onDuty,
                                      style: TextStyle(
                                          fontSize: 11.5, fontWeight: FontWeight.w800, color: DjassaColors.pharmacy, letterSpacing: 0.8)),
                                  if (p.dutyEndsAt != null)
                                    Text('${Strings.until} ${Strings.dateTime(p.dutyEndsAt!)}',
                                        style: text.bodySmall?.copyWith(color: const Color(0xFF0B5E3F), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            // At night, the route matters as much as the call.
                            IconButton.filledTonal(
                              onPressed: () => openDirections(context, p),
                              icon: const Icon(Icons.directions_rounded, color: DjassaColors.pharmacy),
                              tooltip: Strings.directions,
                            ),
                            const SizedBox(width: 6),
                            if (p.phone != null)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: DjassaColors.pharmacy,
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                                ),
                                onPressed: () => _call(p.phone!),
                                icon: const Icon(Icons.call_rounded, size: 18),
                                label: const Text(Strings.call),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The on-duty list as a screen of its own, opened from home and Explorer.
class PharmaciesScreen extends StatelessWidget {
  const PharmaciesScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: PharmaciesTab(showBack: true));
}
