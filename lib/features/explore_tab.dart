import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/model/deal.dart';
import '../core/model/venue.dart';
import '../core/personal_lists.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'favorite_star.dart';
import 'pharmacies_tab.dart';
import 'venue_screen.dart';

/// Every kind of place: search by what you want (a dish, a pagne, rice...),
/// narrow by category and commune.
class ExploreTab extends ConsumerStatefulWidget {
  const ExploreTab({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<ExploreTab> createState() => ExploreTabState();
}

class ExploreTabState extends ConsumerState<ExploreTab> {
  final _query = TextEditingController();
  List<Category> _categories = Category.fallback;
  String? _category;
  String? _commune;
  List<Venue>? _venues;
  Object? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _load();
    ref.read(djassaApiProvider).categories().then((c) {
      if (mounted && c.isNotEmpty) setState(() => _categories = c);
    }).catchError((_) {}); // keep the built-in list
  }

  /// Lets the home screen open this tab on a category.
  void showCategory(String? category) {
    if (category == _category) return;
    setState(() => _category = category);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final venues = await ref.read(djassaApiProvider).venues(category: _category, query: _query.text, commune: _commune);
      if (mounted) setState(() => _venues = venues);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Runs a recent search again.
  void _repeat(String query) {
    _query.text = query;
    _debounce?.cancel();
    setState(() {});
    _load();
  }

  // One request after typing stops, not one per keystroke: each costs data.
  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final venues = _venues;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: Strings.exploreTitle,
            subtitle: 'Abidjan',
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(DjassaRadius.md), boxShadow: djassaShadowStrong),
              child: TextField(
                controller: _query,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (q) {
                  ref.read(personalListsProvider.notifier).searched(q);
                  _load();
                },
                decoration: InputDecoration(
                  hintText: Strings.searchAllHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _query.clear();
                            _load();
                            setState(() {});
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DjassaRadius.md), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DjassaRadius.md), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          CategoryFilter(
            categories: _categories,
            selected: _category,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            onChanged: showCategory,
          ),
          const SizedBox(height: 8),
          CommuneFilter(
            selected: _commune,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            onChanged: (c) {
              setState(() => _commune = c);
              _load();
            },
          ),
          if (_query.text.isEmpty) _RecentSearches(onPick: _repeat),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_category == 'pharmacy') ...[const _OnDutyBanner(), const SizedBox(height: 14)],
                if (_error != null)
                  LoadError(onRetry: _load)
                else if (venues == null)
                  const LoadingCards()
                else if (venues.isEmpty)
                  const EmptyState(icon: Icons.search_off_rounded, title: Strings.noResults, message: Strings.noResultsHint)
                else ...[
                  Text('${venues.length} ${Strings.places}'.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 10),
                  if (venues.any((v) => v.isSample)) const SampleNotice(),
                  for (final v in venues)
                    VenueCard(
                      venue: v,
                      cover: true,
                      action: FavoriteStar(venue: v, onDark: true),
                      onTap: () {
                        // Opening a result is what makes a typed search worth remembering.
                        ref.read(personalListsProvider.notifier).searched(_query.text);
                        Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'venue'), builder: (_) => VenueScreen(venueId: v.id)));
                      },
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

/// Browsing pharmacies is not the same as needing one tonight: point to the
/// on-duty list from here.
class _OnDutyBanner extends StatelessWidget {
  const _OnDutyBanner();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: DjassaColors.pharmacyTint,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'pharmacies'), builder: (_) => const PharmaciesScreen())),
      padding: const EdgeInsets.all(14),
      child: const Row(children: [
        LiveDot(),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Strings.onDutyBanner, style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0B5E3F))),
            Text(Strings.onDutyBannerAction, style: TextStyle(fontSize: 13.5, color: DjassaColors.pharmacy, fontWeight: FontWeight.w600)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: DjassaColors.pharmacy),
      ]),
    );
  }
}


/// The last searches, as chips: tap to search again, the cross to forget
/// one, "Effacer" to forget them all. Shown while the search box is empty.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searches = ref.watch(personalListsProvider.select((s) => s.recentSearches));
    if (searches.isEmpty) return const SizedBox.shrink();
    final lists = ref.read(personalListsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(Strings.recentSearches, actionLabel: Strings.clearHistory, onAction: lists.clearSearches),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in searches)
                InputChip(
                  avatar: const Icon(Icons.history_rounded, size: 18),
                  label: Text(q),
                  onPressed: () => onPick(q),
                  onDeleted: () => lists.forgetSearch(q),
                  deleteButtonTooltipMessage: Strings.forgetSearch,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
