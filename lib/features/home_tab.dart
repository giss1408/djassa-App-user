import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/model/payment.dart';
import '../core/model/venue.dart';
import '../core/personal_lists.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'sign_in_gate.dart';
import '../core/model/deal.dart';
import 'about_name_screen.dart';
import 'account_screen.dart';
import 'pharmacies_tab.dart';
import 'payments_screen.dart';
import 'venue_screen.dart';

/// The daily hub: points, the four things people come for, and live previews
/// (who is on duty tonight, where to eat, what was paid).
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key, required this.onScan, required this.onOpenTab, required this.onExplore});

  final VoidCallback onScan;
  final ValueChanged<int> onOpenTab;

  /// Opens Explorer on a category (null: all).
  final ValueChanged<String?> onExplore;

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  int? _points;
  List<Venue>? _onDuty;
  List<Venue>? _discover;
  List<Deal>? _featured;
  List<Category> _categories = Category.fallback;
  List<Payment>? _payments;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Each block loads on its own: one slow call must not blank the whole page.
  Future<void> _load() async {
    final api = ref.read(djassaApiProvider);
    // Points and payments are the customer's own: only with a session.
    final signedIn = ref.read(sessionProvider).signedIn;
    await Future.wait([
      if (signedIn) api.loyalty().then((l) => _set(() => _points = l.totalPoints)).catchError((_) {}),
      api.onDutyPharmacies().then((v) => _set(() => _onDuty = v)).catchError((_) => _set(() => _onDuty = const [])),
      // Pharmacies have their own section above; the rest is what to discover.
      api
          .venues()
          .then((v) => _set(() => _discover = v.where((x) => !x.isPharmacy).toList()))
          .catchError((_) => _set(() => _discover = const [])),
      api.deals(featured: true).then((d) => _set(() => _featured = d)).catchError((_) => _set(() => _featured = const [])),
      api.categories().then((c) => _set(() => _categories = c.isEmpty ? Category.fallback : c)).catchError((_) {}),
      if (signedIn) api.payments().then((p) => _set(() => _payments = p)).catchError((_) => _set(() => _payments = const [])),
    ]);
  }

  void _set(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _openVenue(Venue v) => Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'venue'), builder: (_) => VenueScreen(venueId: v.id)));

  void _openPharmacies() => Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'pharmacies'), builder: (_) => const PharmaciesScreen()));

  void _openPayments() => Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'payments'), builder: (_) => const PaymentsScreen()));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider);
    final lists = ref.watch(personalListsProvider);
    final username = session.signedIn ? session.username : null;
    final name = username == null || username.isEmpty ? null : '${username[0].toUpperCase()}${username.substring(1)}';

    return RefreshIndicator(
      onRefresh: _load,
      edgeOffset: MediaQuery.paddingOf(context).top,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Hero + the points card riding over its bottom edge. The Stack
          // reserves the overhang so the whole card stays tappable.
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 64),
                child: PatternedSurface(
                  gradient: DjassaColors.headerGradient,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(DjassaRadius.xl + 4)),
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 12, 96),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Strings.greeting(DateTime.now()).toUpperCase(),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                            const SizedBox(height: 2),
                            Text(name ?? 'Djassa',
                                style: serifStyle(40, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(Strings.homeTagline, style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 14.5)),
                          ],
                        ),
                      ),
                      _AccountMenu(initial: name?[0] ?? 'D'),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 0,
                child: _PointsCard(
                  points: _points,
                  signedIn: session.signedIn,
                  onTap: session.signedIn
                      ? () => widget.onOpenTab(3)
                      : () => ensureSignedIn(context, ref, reason: Strings.signInToSeePoints),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code_scanner_rounded,
                    label: Strings.quickScan,
                    color: Colors.white,
                    background: DjassaColors.orangeDeep,
                    onTap: widget.onScan,
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.explore_rounded,
                    label: Strings.quickExplore,
                    color: DjassaColors.orangeDeep,
                    background: DjassaColors.orangeTint,
                    onTap: () => widget.onExplore(null),
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.local_pharmacy_rounded,
                    label: Strings.quickPharmacy,
                    color: DjassaColors.pharmacy,
                    background: DjassaColors.pharmacyTint,
                    onTap: _openPharmacies,
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.local_offer_rounded,
                    label: Strings.quickDeals,
                    color: DjassaColors.green,
                    background: DjassaColors.greenTint,
                    onTap: () => widget.onOpenTab(2),
                  ),
                ),
              ],
            ),
          ),
          if (_featured == null || _featured!.isNotEmpty) ...[
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 10),
              child: SectionHeader(Strings.featuredDealsHome, actionLabel: Strings.seeAll, onAction: () => widget.onOpenTab(2)),
            ),
            SizedBox(
              height: 176,
              child: _featured == null
                  ? const _CarouselSkeleton(width: 300)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: _featured!.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(
                        width: 300,
                        child: DealCard(
                          deal: _featured![i],
                          hero: true,
                          onTap: () {
                            ref.read(usageTrackerProvider).track('deal_opened', {'deal_id': _featured![i].id});
                            Navigator.of(context).push(
                              MaterialPageRoute(settings: const RouteSettings(name: 'venue'), builder: (_) => VenueScreen(venueId: _featured![i].venueId)),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(Strings.browseByCategory),
          ),
          SizedBox(
            height: 98,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final c = _categories[i];
                return _CategoryTile(
                  category: c,
                  onTap: c.key == 'pharmacy' ? _openPharmacies : () => widget.onExplore(c.key),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 10),
            child: SectionHeader(
              Strings.onDutyNow,
              leading: const LiveDot(),
              actionLabel: Strings.seeAll,
              onAction: _openPharmacies,
            ),
          ),
          SizedBox(
            height: 104,
            child: _onDuty == null
                ? const _CarouselSkeleton(width: 290)
                : _onDuty!.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(Strings.noPharmacyOnDuty, style: text.bodySmall),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: _onDuty!.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _PharmacyMini(
                          pharmacy: _onDuty![i],
                          onTap: () => _openVenue(_onDuty![i]),
                          onCall: _onDuty![i].phone == null ? null : () => _call(_onDuty![i].phone!),
                        ),
                      ),
          ),
          // Kept on the phone: there signed in or not, and offline too.
          if (lists.favorites.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Padding(padding: EdgeInsets.only(left: 20, right: 10), child: SectionHeader(Strings.favorites)),
            _VenueRow(venues: lists.favorites, onTap: _openVenue),
          ],
          if (lists.recentVenues.isNotEmpty) ...[
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 10),
              child: SectionHeader(
                Strings.recentlyViewed,
                actionLabel: Strings.clearHistory,
                onAction: ref.read(personalListsProvider.notifier).clearRecentVenues,
              ),
            ),
            _VenueRow(venues: lists.recentVenues, onTap: _openVenue),
          ],
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 10),
            child: SectionHeader(Strings.toDiscover, actionLabel: Strings.seeAll, onAction: () => widget.onExplore(null)),
          ),
          SizedBox(
            height: 212,
            child: _discover == null
                ? const _CarouselSkeleton(width: 200)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _discover!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _MaquisMini(venue: _discover![i], onTap: () => _openVenue(_discover![i])),
                  ),
          ),
          if (_payments != null && _payments!.isNotEmpty) ...[
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 10),
              child: SectionHeader(Strings.recentPayments, actionLabel: Strings.seeAll, onAction: _openPayments),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (final (i, p) in _payments!.take(3).indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      PaymentRow(payment: p),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 120), // clears the raised Pay button
        ],
      ),
    );
  }

  Future<void> _call(String phone) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.callFailed)));
    }
  }
}

/// Initial in a translucent disc; opens the account menu.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden until the customer reaches 100 points (the server decides).
    final suggestions = ref.watch(suggestionsLinkProvider).valueOrNull;
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DjassaRadius.md)),
      onSelected: (v) {
        if (v == 'sign_in') {
          ensureSignedIn(context, ref, reason: Strings.signInToPay);
        } else if (v == 'account') {
          Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'account'), builder: (_) => const AccountScreen()));
        } else if (v == 'about') {
          Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'about_name'), builder: (_) => const AboutNameScreen()));
        } else if (v == 'suggest' && suggestions != null) {
          launchUrl(Uri.parse(suggestions), mode: LaunchMode.externalApplication).then((ok) {
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.suggestionsFailed)));
            }
          });
        } else if (v == 'logout') {
          ref.read(sessionProvider.notifier).signOut();
        }
      },
      itemBuilder: (_) => [
        if (!signedIn)
          const PopupMenuItem(
            value: 'sign_in',
            child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.login_rounded), title: Text(Strings.signInAction)),
          ),
        if (signedIn)
          const PopupMenuItem(
            value: 'account',
            child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.manage_accounts_outlined), title: Text(Strings.account)),
          ),
        const PopupMenuItem(
          value: 'about',
          child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.auto_stories_outlined), title: Text(Strings.aboutNameLink)),
        ),
        if (suggestions != null)
          const PopupMenuItem(
            value: 'suggest',
            child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.help_outline_rounded), title: Text(Strings.suggestions)),
          ),
        if (signedIn)
          const PopupMenuItem(
            value: 'logout',
            child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout_rounded), title: Text(Strings.signOut)),
          ),
      ],
      child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.only(top: 4, right: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
        ),
        child: Text(initial.toUpperCase(), style: serifStyle(24, color: Colors.white, height: 1)),
      ),
    );
  }
}

/// The loyalty balance, dressed as a membership card: deep green, wax
/// texture, the balance in the display serif.
class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.points, required this.signedIn, required this.onTap});

  final int? points;
  final bool signedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: signedIn ? '${Strings.myPoints} : ${points ?? 0} ${Strings.points}' : '${Strings.pointsSignedOut}. ${Strings.pointsSignedOutHint}',
      child: GestureDetector(
        onTap: onTap,
        child: PatternedSurface(
          gradient: DjassaColors.loyaltyGradient,
          borderRadius: BorderRadius.circular(DjassaRadius.lg),
          boxShadow: djassaShadowStrong,
          patternOpacity: 0.07,
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Strings.myPoints.toUpperCase(),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    if (!signedIn)
                      Text(Strings.pointsSignedOut, style: serifStyle(34, color: Colors.white, height: 1.1))
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(points == null ? '—' : '$points', style: serifStyle(46, color: Colors.white, height: 1)),
                          const SizedBox(width: 6),
                          Text(Strings.points,
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(signedIn ? Strings.seeRewardsShort : Strings.pointsSignedOutHint,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, required this.color, required this.background});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DjassaRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(DjassaRadius.md + 4)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: DjassaColors.ink),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PharmacyMini extends StatelessWidget {
  const _PharmacyMini({required this.pharmacy, required this.onTap, required this.onCall});

  final Venue pharmacy;
  final VoidCallback onTap;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 290,
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Row(
          children: [
            VenueThumb.of(pharmacy, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pharmacy.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(pharmacy.commune, style: text.bodySmall, maxLines: 1),
                  if (pharmacy.dutyEndsAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${Strings.untilShort} ${Strings.shortDay(pharmacy.dutyEndsAt!)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DjassaColors.pharmacy),
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
            if (onCall != null)
              IconButton.filled(
                onPressed: onCall,
                tooltip: Strings.call,
                style: IconButton.styleFrom(backgroundColor: DjassaColors.pharmacy, foregroundColor: Colors.white),
                icon: const Icon(Icons.call_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

/// Favourites or recently viewed shops, as the same small cards as "À découvrir".
class _VenueRow extends StatelessWidget {
  const _VenueRow({required this.venues, required this.onTap});

  final List<Venue> venues;
  final ValueChanged<Venue> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 212,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: venues.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _MaquisMini(venue: venues[i], onTap: () => onTap(venues[i])),
      ),
    );
  }
}

class _MaquisMini extends StatelessWidget {
  const _MaquisMini({required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 200,
      child: SoftCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                VenueBanner(venue: venue, height: 112),
                if (venue.pointsPer100 > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.stars_rounded, size: 14, color: DjassaColors.green),
                        const SizedBox(width: 3),
                        Text('${venue.pointsPer100} ${Strings.pointsPer100}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: DjassaColors.green)),
                      ]),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.place_outlined, size: 14, color: DjassaColors.muted),
                    const SizedBox(width: 2),
                    Expanded(child: Text(venue.commune, style: text.bodySmall, maxLines: 1)),
                    if (venue.acceptsPayment) const Icon(Icons.qr_code_2_rounded, size: 16, color: DjassaColors.orangeDeep),
                  ]),
                  const SizedBox(height: 4),
                  Text(venue.specialties ?? '',
                      style: text.bodySmall?.copyWith(color: DjassaColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A kind of retailer on the home screen: tinted icon tile and its name.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category.key);
    final colors = style.colorsFor(0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DjassaRadius.md),
      child: SizedBox(
        width: 76,
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DjassaColors.surface,
              borderRadius: BorderRadius.circular(DjassaRadius.md + 4),
              border: Border.all(color: DjassaColors.line),
            ),
            child: Icon(style.icon, color: colors.last, size: 28),
          ),
          const SizedBox(height: 6),
          Text(category.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: DjassaColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

/// Grey cards where a carousel will be, so the page does not jump.
class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => Container(
        width: width,
        decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(DjassaRadius.lg)),
      ),
    );
  }
}
