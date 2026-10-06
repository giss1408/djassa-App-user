import 'package:flutter/material.dart';

import '../core/model/deal.dart';
import '../core/model/money.dart';
import '../core/model/payment.dart';
import '../core/model/venue.dart';
import '../core/net/api_exception.dart';
import '../l10n/strings.dart';
import 'money_text.dart';
import 'theme.dart';

/// "5 000 F" for a whole-franc amount.
String francs(int amount) => formatMoney(Money.fromMajor(amount, 'XOF'));

/// The server's own words when it refused, a plain sentence otherwise.
String errorMessage(Object error) {
  if (error is ClientErrorException && error.detail is String) return error.detail! as String;
  return Strings.loadFailed;
}

/// Brand header: deep-orange gradient with a wax-print texture and a
/// rounded bottom edge, the way the site's hero frames a page. [child] sits
/// inside the gradient under the title (a search field, a balance...).
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.child,
    this.gradient = DjassaColors.headerGradient,
    this.bottomPadding = 22,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? child;
  final Gradient gradient;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return PatternedSurface(
      gradient: gradient,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(DjassaRadius.xl)),
      padding: EdgeInsets.fromLTRB(20, top + 18, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null) ...[
                      Text(subtitle!.toUpperCase(),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.78), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                    ],
                    Text(title, style: serifStyle(34, color: Colors.white)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const _FlagStripe(),
          if (child != null) ...[const SizedBox(height: 18), child!],
        ],
      ),
    );
  }
}

/// A gradient surface carrying the Djassa wax-print texture. The pattern is
/// static and painted once behind a [RepaintBoundary], so it costs nothing
/// while scrolling.
class PatternedSurface extends StatelessWidget {
  const PatternedSurface({
    super.key,
    required this.gradient,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.padding = EdgeInsets.zero,
    this.patternOpacity = 0.09,
    this.boxShadow,
  });

  final Gradient gradient;
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final double patternOpacity;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: borderRadius, boxShadow: boxShadow),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: WaxPatternPainter(opacity: patternOpacity))),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Djassa's texture: rows of concentric rings and diamonds, the geometry of
/// the wax prints sold in every djassa. Thin white strokes at low opacity so
/// it reads as fabric, not decoration, and never fights the text on top.
class WaxPatternPainter extends CustomPainter {
  const WaxPatternPainter({this.opacity = 0.09, this.color = Colors.white, this.cell = 44});

  final double opacity;
  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final dot = Paint()..color = color.withOpacity(opacity * 1.4);
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Offset every other row by half a cell, like a woven repeat.
        final center = Offset(c * cell + (r.isOdd ? cell / 2 : 0), r * cell);
        if ((r + c).isEven) {
          canvas.drawCircle(center, cell * 0.34, paint);
          canvas.drawCircle(center, cell * 0.2, paint);
          canvas.drawCircle(center, 1.8, dot);
        } else {
          final h = cell * 0.26;
          final path = Path()
            ..moveTo(center.dx, center.dy - h)
            ..lineTo(center.dx + h, center.dy)
            ..lineTo(center.dx, center.dy + h)
            ..lineTo(center.dx - h, center.dy)
            ..close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(WaxPatternPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.color != color || oldDelegate.cell != cell;
}

/// Côte d'Ivoire orange-white-green hairline, a nod shared with immoizi.
class _FlagStripe extends StatelessWidget {
  const _FlagStripe();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 3,
          width: 54,
          child: Row(children: [
            Expanded(child: Container(color: const Color(0xFFFFB27A))),
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: const Color(0xFF7FD6A4))),
          ]),
        ),
      ),
    );
  }
}

/// Round translucent icon button for use on the gradient header.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      shape: const CircleBorder(),
      child: IconButton(onPressed: onPressed, tooltip: tooltip, icon: Icon(icon, color: Colors.white)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.leading});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (actionLabel != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(actionLabel!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DjassaColors.orangeDeep)),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: DjassaColors.orangeDeep),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small pulsing-free "live" dot: a solid dot inside a soft halo. Static on
/// purpose, a looping animation drains battery on the screen left open.
class LiveDot extends StatelessWidget {
  const LiveDot({super.key, this.color = DjassaColors.pharmacy});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
  }
}

/// White rounded surface with the hairline border used across the app.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? DjassaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DjassaRadius.lg),
        side: const BorderSide(color: DjassaColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Small rounded label. Meaning is carried by the words, never colour alone.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.icon, this.color = DjassaColors.inkSoft, this.background = DjassaColors.sand});

  const Tag.djassa({super.key})
      : label = Strings.acceptsDjassa,
        icon = Icons.qr_code_2_rounded,
        color = DjassaColors.orangeDeep,
        background = DjassaColors.orangeTint;

  const Tag.sample({super.key})
      : label = Strings.sample,
        icon = Icons.science_outlined,
        color = DjassaColors.muted,
        background = const Color(0xFFF0EEE8);

  final String label;
  final IconData? icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// How a kind of venue looks: its icon and the warm gradients its generated
/// covers are drawn from. Keys the app does not know yet (a category added
/// server-side) get a generic storefront rather than breaking.
class CategoryStyle {
  const CategoryStyle(this.icon, this.gradients);

  final IconData icon;
  final List<List<Color>> gradients;

  List<Color> colorsFor(int id) => gradients[id % gradients.length];

  static const _warm = [
    [Color(0xFFE65E32), Color(0xFFB5401D)],
    [Color(0xFFD6A284), Color(0xFF9E5B3A)],
    [Color(0xFFF2994A), Color(0xFFC94A22)],
    [Color(0xFF75975D), Color(0xFF234B39)],
    [Color(0xFFE8B04B), Color(0xFFB9772A)],
  ];

  static const _styles = {
    'maquis': CategoryStyle(Icons.restaurant_rounded, _warm),
    'restaurant': CategoryStyle(Icons.restaurant_menu_rounded, [
      [Color(0xFF8C5A3C), Color(0xFF4E2E1C)],
      [Color(0xFFE8B04B), Color(0xFFB9772A)],
      [Color(0xFFE65E32), Color(0xFF9E3517)],
    ]),
    'pharmacy': CategoryStyle(Icons.local_pharmacy_rounded, [
      [Color(0xFF2BB673), DjassaColors.pharmacy],
    ]),
    'superette': CategoryStyle(Icons.shopping_basket_rounded, [
      [Color(0xFF75975D), Color(0xFF234B39)],
      [Color(0xFFE8B04B), Color(0xFFB9772A)],
    ]),
    'mode': CategoryStyle(Icons.checkroom_rounded, [
      [Color(0xFFB85C8A), Color(0xFF6E2A52)],
      [Color(0xFFE65E32), Color(0xFF9E3517)],
    ]),
    'beaute': CategoryStyle(Icons.content_cut_rounded, [
      [Color(0xFFD98A9B), Color(0xFF9C4057)],
      [Color(0xFFD6A284), Color(0xFF9E5B3A)],
    ]),
    'telephonie': CategoryStyle(Icons.smartphone_rounded, [
      [Color(0xFF4A7FB5), Color(0xFF1F3F66)],
      [Color(0xFF3D4A44), Color(0xFF18221F)],
    ]),
  };

  static const _fallback = CategoryStyle(Icons.storefront_rounded, _warm);

  static CategoryStyle of(String key) => _styles[key] ?? _fallback;
}

/// One-tap category filter: "Tous" then each kind of venue, with its icon.
class CategoryFilter extends StatelessWidget {
  const CategoryFilter(
      {super.key, required this.categories, required this.selected, required this.onChanged, this.padding = EdgeInsets.zero});

  final List<Category> categories;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final options = <Category?>[null, ...categories];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = options[i];
          final isSelected = selected == c?.key;
          final color = isSelected ? Colors.white : DjassaColors.ink;
          return ChoiceChip(
            avatar: Icon(c == null ? Icons.apps_rounded : CategoryStyle.of(c.key).icon,
                size: 18, color: isSelected ? Colors.white : DjassaColors.orangeDeep),
            label: Text(c?.plural ?? Strings.allCategories),
            selected: isSelected,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: color),
            onSelected: (_) => onChanged(c?.key),
          );
        },
      ),
    );
  }
}

/// Generated thumbnail: there are no venue photos yet, and a grey box looks
/// broken. A warm gradient picked from the venue id plus a category icon
/// looks intentional and stays stable for each venue.
class VenueThumb extends StatelessWidget {
  const VenueThumb({super.key, required this.id, required this.category, this.size = 64});

  VenueThumb.of(Venue venue, {super.key, this.size = 64})
      : id = venue.id,
        category = venue.category;

  final int id;
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: PatternedSurface(
        gradient: LinearGradient(colors: CategoryStyle.of(category).colorsFor(id), begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.28),
        patternOpacity: 0.14,
        child: SizedBox.expand(
          child: Icon(CategoryStyle.of(category).icon, color: Colors.white, size: size * 0.44),
        ),
      ),
    );
  }
}

/// A venue in a list: thumbnail, name, place, what it offers with Djassa.
///
/// With [cover], the venue's generated cover spans the card, the way food
/// apps lead with the place. Used where browsing is the point (maquis); the
/// compact row stays for lists people scan in a hurry (pharmacies).
class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, required this.onTap, this.footer, this.cover = false, this.action});

  final Venue venue;
  final VoidCallback onTap;
  final Widget? footer;
  final bool cover;

  /// A button on the card, e.g. the favourite star: over the photo's top-left
  /// corner with [cover], at the end of the name row otherwise.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final place = Row(
      children: [
        const Icon(Icons.place_outlined, size: 15, color: DjassaColors.muted),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            [venue.commune, if (venue.address != null) venue.address].join(' · '),
            style: text.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final tags = [
      if (venue.acceptsPayment) const Tag.djassa(),
      if (venue.pointsPer100 > 0)
        Tag('${venue.pointsPer100} ${Strings.pointsPer100}',
            icon: Icons.stars_rounded, color: DjassaColors.green, background: DjassaColors.greenTint),
      if (venue.isSample && !cover) const Tag.sample(),
    ];

    if (cover) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SoftCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  VenueBanner(venue: venue, height: 128),
                  if (venue.isSample) const Positioned(top: 12, right: 12, child: Tag.sample()),
                  if (action != null) Positioned(top: 2, left: 2, child: action!),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(venue.name, style: text.titleMedium?.copyWith(fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    place,
                    if (venue.specialties != null) ...[
                      const SizedBox(height: 6),
                      Text(venue.specialties!,
                          style: text.bodyMedium?.copyWith(color: DjassaColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 6, children: tags),
                    ],
                    if (footer != null) ...[const SizedBox(height: 12), footer!],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VenueThumb.of(venue),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(venue.name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      place,
                      if (venue.specialties != null) ...[
                        const SizedBox(height: 6),
                        Text(venue.specialties!,
                            style: text.bodyMedium?.copyWith(color: DjassaColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: tags),
            ],
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}

/// Discreet banner at the top of a list containing demo data.
class SampleNotice extends StatelessWidget {
  const SampleNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: DjassaColors.warningTint, borderRadius: BorderRadius.circular(DjassaRadius.md)),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF8A6D1F)),
          SizedBox(width: 10),
          Expanded(child: Text(Strings.sampleNotice, style: TextStyle(fontSize: 13.5, color: Color(0xFF6B5418)))),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: DjassaColors.sand, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: DjassaColors.orangeDeep),
          ),
          const SizedBox(height: 16),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: text.bodySmall, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: message ?? Strings.loadFailed,
      action: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text(Strings.retry),
      ),
    );
  }
}

/// Placeholder cards while a list loads: the layout does not jump when the
/// data arrives, which reads as faster than a lone spinner.
class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(6)),
        );
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(18)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [bar(160, 14), const SizedBox(height: 10), bar(110, 11), const SizedBox(height: 10), bar(190, 11)],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One-tap commune filter.
class CommuneFilter extends StatelessWidget {
  const CommuneFilter({super.key, required this.selected, required this.onChanged, this.padding = EdgeInsets.zero});

  final String? selected;
  final ValueChanged<String?> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final options = <String?>[null, ...Strings.communes];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final value = options[i];
          final isSelected = selected == value;
          return ChoiceChip(
            label: Text(value ?? Strings.allCommunes),
            selected: isSelected,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : DjassaColors.ink),
            onSelected: (_) => onChanged(value),
          );
        },
      ),
    );
  }
}

/// Colour dot identifying a wallet next to its name.
class WalletSwatch extends StatelessWidget {
  const WalletSwatch(this.wallet, {super.key, this.size = 12});

  final Wallet wallet;
  final double size;

  static Color colorOf(Wallet w) => switch (w) {
        Wallet.wave => WalletColors.wave,
        Wallet.orange => WalletColors.orange,
        Wallet.mtn => WalletColors.mtn,
        Wallet.moov => WalletColors.moov,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colorOf(wallet), shape: BoxShape.circle),
    );
  }
}

/// Full-width banner version of [VenueThumb], for cards and the venue page.
/// Until venues have photos, a wax-print gradient with the venue's initials
/// set in the display serif gives each place its own recognisable cover.
class VenueBanner extends StatelessWidget {
  const VenueBanner({
    super.key,
    required this.venue,
    this.height = 92,
    this.radius = 0,
    this.monogramSize,
    this.showIcon = true,
    this.imageUrl,
  });

  final Venue venue;
  final double height;
  final double radius;
  final double? monogramSize;

  /// Off on the venue page, where the back button owns that corner.
  final bool showIcon;

  /// A photo of the shop over the gradient. Defaults to the list cover
  /// (320 px); the shop page passes its 720 px photo. The gradient and
  /// monogram stay underneath, so a slow or failed load still looks right.
  final String? imageUrl;

  static String initials(String name) {
    const skip = {'chez', 'le', 'la', 'les', 'de', 'des', 'du', 'maquis', 'pharmacie', "l'", 'd\'', 'et'};
    final words = name.split(RegExp(r"[\s'’-]+")).where((w) => w.isNotEmpty && !skip.contains(w.toLowerCase())).toList();
    if (words.isEmpty) return name.isEmpty ? '' : name[0].toUpperCase();
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(venue.category);
    final colors = style.colorsFor(venue.id);
    final icon = style.icon;
    return SizedBox(
      height: height,
      child: PatternedSurface(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(radius),
        patternOpacity: 0.13,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: 14,
              bottom: -height * 0.08,
              child: Text(initials(venue.name),
                  style: serifStyle(monogramSize ?? height * 0.9, color: Colors.white.withOpacity(0.22), height: 1)),
            ),
            if ((imageUrl ?? venue.coverUrl) != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Image.network(
                  imageUrl ?? venue.coverUrl!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // Fade in over the gradient instead of popping.
                  frameBuilder: (context, child, frame, sync) =>
                      sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 250), child: child),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (showIcon)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Light "fading" rectangle placeholder colour, shared by skeletons.
const skeletonColor = Color(0xFFECE6D9);

/// A paper ticket: a white card torn in two by a dashed line with a
/// half-circle notch at each end. Used for the receipt and reward vouchers,
/// the two things a customer shows at a counter.
///
/// Built from three plain pieces (top, tear strip, bottom) rather than one
/// clipped shape, so the tear sits wherever the top ends without measuring.
class Ticket extends StatelessWidget {
  const Ticket({super.key, required this.top, required this.bottom});

  final Widget top;
  final Widget bottom;

  static const _radius = Radius.circular(DjassaRadius.lg);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(color: DjassaColors.surface, borderRadius: BorderRadius.vertical(top: _radius)),
          child: top,
        ),
        const SizedBox(height: 24, child: CustomPaint(painter: _TearPainter())),
        DecoratedBox(
          decoration: const BoxDecoration(color: DjassaColors.surface, borderRadius: BorderRadius.vertical(bottom: _radius)),
          child: bottom,
        ),
      ],
    );
  }
}

class _TearPainter extends CustomPainter {
  const _TearPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final notch = size.height / 2;
    final y = size.height / 2;
    final strip = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()
        ..addOval(Rect.fromCircle(center: Offset(0, y), radius: notch))
        ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: notch)),
    );
    canvas.drawPath(strip, Paint()..color = DjassaColors.surface);

    final dash = Paint()
      ..color = DjassaColors.line
      ..strokeWidth = 1.5;
    const len = 6.0, gap = 5.0;
    for (var x = notch + 8; x < size.width - notch - 8; x += len + gap) {
      canvas.drawLine(Offset(x, y), Offset(x + len, y), dash);
    }
  }

  @override
  bool shouldRepaint(_TearPainter oldDelegate) => false;
}

/// "-20 %" or the deal price, whichever sells it best, for badges.
String dealHeadline(Deal d) {
  final pct = d.effectivePercent;
  if (pct != null) return '-$pct %';
  if (d.price != null) return francs(d.price!);
  return Strings.dealBadge;
}

/// The diagonal corner banner on a deal's image: green "BON PLAN", red
/// "FLASH", or the yellow "PROMO" sticker. Clipped by the parent's corners.
class DealRibbonBanner extends StatelessWidget {
  const DealRibbonBanner({super.key, required this.ribbon, required this.child, this.radius = DjassaRadius.md});

  final DealRibbon ribbon;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final (label, color, ink) = switch (ribbon) {
      DealRibbon.bonPlan => (Strings.ribbonBonPlan, DjassaColors.green, Colors.white),
      DealRibbon.flash => (Strings.ribbonFlash, DjassaColors.danger, Colors.white),
      DealRibbon.promo => (Strings.ribbonPromo, const Color(0xFFFFC83D), DjassaColors.ink),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Banner(
        message: label,
        location: BannerLocation.topStart,
        color: color,
        textStyle: TextStyle(color: ink, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6, height: 1),
        child: child,
      ),
    );
  }
}

/// A deal, as a card. [hero] is the large sponsored format for carousels;
/// the default is the compact row used in lists.
///
/// Sponsored deals always carry a visible "Sponsorisé" label: paid placement
/// the customer cannot tell apart from the rest would cost the app its trust.
class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.deal, required this.onTap, this.hero = false});

  final Deal deal;

  /// Null on the venue's own page, where there is nowhere further to go.
  final VoidCallback? onTap;
  final bool hero;

  @override
  Widget build(BuildContext context) => hero ? _hero(context) : _row(context);

  Widget _hero(BuildContext context) {
    final colors = CategoryStyle.of(deal.venueCategory).colorsFor(deal.venueId);
    return Semantics(
      button: true,
      label: '${deal.isFeatured ? '${Strings.sponsored}. ' : ''}${deal.title}, ${deal.venueName}',
      child: GestureDetector(
        onTap: onTap,
        child: DealRibbonBanner(
          ribbon: deal.ribbon,
          radius: DjassaRadius.lg,
          child: PatternedSurface(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(DjassaRadius.lg),
            patternOpacity: 0.12,
            child: DecoratedBox(
              // Darkens the lower half so white text stays readable on the
              // lightest gradients.
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x73000000)],
                  stops: [0.35, 1],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          // Clears the corner banner.
                          child: Padding(
                            padding: const EdgeInsets.only(left: 30, top: 4),
                            child: Wrap(spacing: 6, runSpacing: 6, children: [
                              if (deal.isFeatured) const _SponsoredPill(onDark: true),
                              if (deal.isSample) const Tag.sample(),
                            ]),
                          ),
                        ),
                        Text(dealHeadline(deal), style: serifStyle(40, color: Colors.white, height: 0.9)),
                      ],
                    ),
                    const Spacer(),
                    Text(deal.title,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(CategoryStyle.of(deal.venueCategory).icon, size: 15, color: Colors.white.withOpacity(0.9)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text('${deal.venueName} · ${deal.venueCommune}',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text(Strings.dealEnds(deal.endsAt),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = CategoryStyle.of(deal.venueCategory).colorsFor(deal.venueId);
    final soon = deal.endsAt.difference(DateTime.now()) < const Duration(days: 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: DealRibbonBanner(
                ribbon: deal.ribbon,
                child: PatternedSurface(
                  gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(DjassaRadius.md),
                  patternOpacity: 0.14,
                  child: Center(
                    child: FittedBox(
                      child: Padding(
                        // Lower than centre: the banner takes the top corner.
                        padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                        child: Text(dealHeadline(deal), style: serifStyle(30, color: Colors.white, height: 1)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (deal.isFeatured) ...[const _SponsoredPill(), const SizedBox(height: 6)],
                  Text(deal.title, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${deal.venueName} · ${deal.venueCommune}', style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (deal.price != null) ...[
                      Text(francs(deal.price!),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DjassaColors.orangeDeep)),
                      if (deal.originalPrice != null) ...[
                        const SizedBox(width: 6),
                        Text(francs(deal.originalPrice!),
                            style: const TextStyle(fontSize: 13, color: DjassaColors.muted, decoration: TextDecoration.lineThrough)),
                      ],
                      const Spacer(),
                    ] else
                      const Spacer(),
                    Icon(Icons.schedule_rounded, size: 14, color: soon ? DjassaColors.danger : DjassaColors.muted),
                    const SizedBox(width: 3),
                    Text(Strings.dealEnds(deal.endsAt),
                        style:
                            TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: soon ? DjassaColors.danger : DjassaColors.muted)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsoredPill extends StatelessWidget {
  const _SponsoredPill({this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : DjassaColors.warningTint,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(Strings.sponsored.toUpperCase(),
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF6B5418))),
    );
  }
}
