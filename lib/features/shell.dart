import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import 'home_tab.dart';
import 'loyalty_tab.dart';
import 'deals_tab.dart';
import 'explore_tab.dart';
import 'scan_screen.dart';
import 'sign_in_gate.dart';

/// Four tabs (home, explore, deals, loyalty) around one central action. Paying is the gesture that makes the
/// app essential (it earns the points and builds the merchant's history), so
/// it gets the big button in the middle, the way mobile-money apps put "scan".
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;

  /// Labels for usage analytics, in tab order.
  static const _tabNames = ['home', 'explore', 'deals', 'loyalty'];

  @override
  void initState() {
    super.initState();
    _trackTab(0);
  }

  void _trackTab(int tab) => ref.read(usageTrackerProvider).track('tab_view', {'screen': _tabNames[tab]});
  // Bumped after a payment so tabs showing points reload.
  int _refresh = 0;

  Future<void> _scan() async {
    final signedIn = await ensureSignedIn(context, ref, reason: Strings.signInToPay);
    if (!signedIn || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'scan'), builder: (_) => const ScanScreen()));
    if (mounted) setState(() => _refresh++);
  }

  final _explore = GlobalKey<ExploreTabState>();

  void _go(int tab) {
    if (tab != _tab) _trackTab(tab);
    setState(() => _tab = tab);
  }

  /// Explorer, filtered on [category] (null: everything).
  void _openExplore(String? category) {
    _go(1);
    // The tab is built by now (IndexedStack keeps all children alive).
    _explore.currentState?.showCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    // Signing in or out reloads the tabs that show the customer's own data.
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final tabs = [
      HomeTab(key: ValueKey('home$_refresh$signedIn'), onScan: _scan, onOpenTab: _go, onExplore: _openExplore),
      ExploreTab(key: _explore),
      const DealsTab(),
      LoyaltyTab(key: ValueKey('loyalty$_refresh$signedIn')),
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: HossoukoColors.surface,
          border: Border(top: BorderSide(color: HossoukoColors.line)),
          boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, -4))],
        ),
        padding: EdgeInsets.only(bottom: bottom),
        height: 70 + bottom,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NavItem(
                icon: Icons.home_outlined, active: Icons.home_rounded, label: Strings.tabHome, selected: _tab == 0, onTap: () => _go(0)),
            _NavItem(
                icon: Icons.explore_outlined,
                active: Icons.explore_rounded,
                label: Strings.tabExplore,
                selected: _tab == 1,
                onTap: () => _go(1)),
            _PayButton(onTap: _scan),
            _NavItem(
                icon: Icons.local_offer_outlined,
                active: Icons.local_offer_rounded,
                label: Strings.tabDeals,
                selected: _tab == 2,
                onTap: () => _go(2)),
            _NavItem(
                icon: Icons.stars_outlined,
                active: Icons.stars_rounded,
                label: Strings.tabLoyalty,
                selected: _tab == 3,
                onTap: () => _go(3)),
          ],
        ),
      ),
    );
  }
}

/// The raised centre action: a gradient disc lifted out of the bar with a
/// paper-coloured ring, labelled so first-time users know it means "pay".
class _PayButton extends StatelessWidget {
  const _PayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Semantics(
        button: true,
        label: Strings.scanToPay,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          // The disc overhangs the bar; taps on the overhang still land
          // because most of the disc sits inside the bar's bounds.
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: -22,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [HossoukoColors.orange, HossoukoColors.orangeDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: HossoukoColors.surface, width: 4),
                    boxShadow: const [BoxShadow(color: Color(0x55C94A22), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                ),
              ),
              const Positioned(
                bottom: 12,
                child: Text(Strings.scan, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: HossoukoColors.orangeDeep)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.active, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final IconData active;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? HossoukoColors.orangeDeep : HossoukoColors.muted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? HossoukoColors.orangeTint : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Icon(selected ? active : icon, color: color, size: 24),
              ),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color), maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}
