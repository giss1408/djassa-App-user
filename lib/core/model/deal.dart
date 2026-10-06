import 'venue.dart';

/// A kind of venue, as the server lists them (maquis, supérette, mode...).
class Category {
  const Category({required this.key, required this.label, required this.plural});

  factory Category.fromJson(Map<String, Object?> json) => Category(
        key: json['key'] as String,
        label: json['label'] as String,
        plural: json['plural'] as String,
      );

  final String key;
  final String label;
  final String plural;

  /// Display name for a category key, falling back to the key itself.
  static String labelOf(String key) {
    for (final c in fallback) {
      if (c.key == key) return c.label;
    }
    return key.isEmpty ? key : '${key[0].toUpperCase()}${key.substring(1)}';
  }

  /// Used when /api/categories cannot be reached, so browsing still works.
  static const fallback = [
    Category(key: 'maquis', label: 'Maquis', plural: 'Maquis'),
    Category(key: 'restaurant', label: 'Restaurant', plural: 'Restaurants'),
    Category(key: 'superette', label: 'Supérette', plural: 'Supérettes'),
    Category(key: 'pharmacy', label: 'Pharmacie', plural: 'Pharmacies'),
    Category(key: 'mode', label: 'Mode', plural: 'Boutiques de mode'),
    Category(key: 'beaute', label: 'Beauté', plural: 'Salons de beauté'),
    Category(key: 'telephonie', label: 'Téléphonie', plural: 'Téléphonie'),
  ];
}

/// A time-limited offer ("bon plan") published by a venue.
class Deal {
  const Deal({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.venueCategory,
    required this.venueCommune,
    required this.title,
    required this.endsAt,
    required this.isFeatured,
    required this.isSample,
    this.description,
    this.discountPercent,
    this.price,
    this.originalPrice,
    this.ribbon = DealRibbon.bonPlan,
  });

  factory Deal.fromJson(Map<String, Object?> json) => Deal(
        id: json['id'] as int,
        venueId: json['venue_id'] as int,
        venueName: json['venue_name'] as String,
        venueCategory: json['venue_category'] as String,
        venueCommune: json['venue_commune'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        discountPercent: json['discount_percent'] as int?,
        price: json['price'] as int?,
        originalPrice: json['original_price'] as int?,
        ribbon: DealRibbon.fromWire(json['ribbon'] as String?),
        endsAt: parseServerTime(json['ends_at']) ?? DateTime.now(),
        isFeatured: json['is_featured'] as bool? ?? false,
        isSample: json['is_sample'] as bool? ?? false,
      );

  final int id;
  final int venueId;
  final String venueName;
  final String venueCategory;
  final String venueCommune;
  final String title;
  final String? description;
  final int? discountPercent;

  /// Whole francs CFA.
  final int? price;
  final int? originalPrice;
  final DateTime endsAt;

  /// The corner banner on the deal's image, chosen by the merchant.
  final DealRibbon ribbon;

  /// Paid placement. Always labelled "Sponsorisé" in the app.
  final bool isFeatured;
  final bool isSample;

  /// The percentage to put on the badge: the stated one, or the one implied
  /// by the two prices.
  int? get effectivePercent {
    if (discountPercent != null) return discountPercent;
    final p = price, o = originalPrice;
    if (p == null || o == null || o <= 0 || p >= o) return null;
    return ((o - p) * 100 / o).round();
  }
}

/// The corner banner a deal wears: a "bon plan", a flash sale, or the promo
/// sticker. Unknown values (a newer server) fall back to the bon plan.
enum DealRibbon {
  bonPlan('bon_plan'),
  flash('flash'),
  promo('promo');

  const DealRibbon(this.wire);

  final String wire;

  static DealRibbon fromWire(String? value) => DealRibbon.values.firstWhere((r) => r.wire == value, orElse: () => DealRibbon.bonPlan);
}
