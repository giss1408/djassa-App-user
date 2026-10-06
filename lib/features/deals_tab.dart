import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/model/deal.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'venue_screen.dart';

/// "Bons plans": sponsored offers up top as large cards, then every live
/// offer, ending soonest first.
class DealsTab extends ConsumerStatefulWidget {
  const DealsTab({super.key});

  @override
  ConsumerState<DealsTab> createState() => _DealsTabState();
}

class _DealsTabState extends ConsumerState<DealsTab> {
  List<Category> _categories = Category.fallback;
  String? _category;
  List<Deal>? _deals;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    ref.read(hossoukoApiProvider).categories().then((c) {
      if (mounted && c.isNotEmpty) setState(() => _categories = c);
    }).catchError((_) {});
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final deals = await ref.read(hossoukoApiProvider).deals(category: _category);
      if (mounted) setState(() => _deals = deals);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _open(Deal d) {
    ref.read(usageTrackerProvider).track('deal_opened', {'deal_id': d.id});
    Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'venue'), builder: (_) => VenueScreen(venueId: d.venueId)));
  }

  @override
  Widget build(BuildContext context) {
    final deals = _deals;
    final featured = deals?.where((d) => d.isFeatured).toList() ?? const <Deal>[];
    final rest = deals?.where((d) => !d.isFeatured).toList() ?? const <Deal>[];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: Strings.dealsTitle,
            subtitle: Strings.dealsSubtitle,
            trailing: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.local_offer_rounded, color: HossoukoColors.orangeDeep, size: 26),
            ),
          ),
          const SizedBox(height: 14),
          CategoryFilter(
            categories: _categories,
            selected: _category,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            onChanged: (c) {
              setState(() => _category = c);
              _load();
            },
          ),
          const SizedBox(height: 18),
          if (_error != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: LoadError(onRetry: _load))
          else if (deals == null)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: LoadingCards())
          else if (deals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: EmptyState(icon: Icons.local_offer_outlined, title: Strings.noDeals, message: Strings.noDealsHint),
            )
          else ...[
            if (featured.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: SectionHeader(Strings.featuredDeals)),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: featured.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => SizedBox(
                    width: MediaQuery.sizeOf(context).width - 64,
                    child: DealCard(deal: featured[i], hero: true, onTap: () => _open(featured[i])),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (rest.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(Strings.allDeals),
                    if (rest.any((d) => d.isSample)) const SampleNotice(),
                    for (final d in rest) DealCard(deal: d, onTap: () => _open(d)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}
