import 'deal.dart';

/// A place a customer can find and pay: a maquis, a pharmacy, a shop...
class Venue {
  const Venue({
    required this.id,
    required this.category,
    required this.name,
    required this.commune,
    required this.pointsPer100,
    required this.acceptsPayment,
    required this.isSample,
    this.address,
    this.phone,
    this.description,
    this.specialties,
    this.openingHours,
    this.dutyEndsAt,
    this.rewards = const [],
    this.deals = const [],
    this.myPoints = 0,
  });

  factory Venue.fromJson(Map<String, Object?> json) => Venue(
        id: json['id'] as int,
        category: json['category'] as String,
        name: json['name'] as String,
        commune: json['commune'] as String,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        description: json['description'] as String?,
        specialties: json['specialties'] as String?,
        openingHours: json['opening_hours'] as String?,
        pointsPer100: json['points_per_100'] as int? ?? 0,
        acceptsPayment: json['accepts_payment'] as bool? ?? false,
        isSample: json['is_sample'] as bool? ?? false,
        dutyEndsAt: parseServerTime(json['duty_ends_at']),
        rewards: [
          for (final r in (json['rewards'] as List<Object?>? ?? const [])) Reward.fromJson(r! as Map<String, Object?>),
        ],
        deals: [
          for (final d in (json['deals'] as List<Object?>? ?? const [])) Deal.fromJson(d! as Map<String, Object?>),
        ],
        myPoints: json['my_points'] as int? ?? 0,
      );

  final int id;
  final String category; // a key from /api/categories
  final String name;
  final String commune;
  final String? address;
  final String? phone;
  final String? description;
  final String? specialties;
  final String? openingHours;

  /// Loyalty points per 100 F paid. 0 means the venue is not in the programme.
  final int pointsPer100;

  /// Whether the venue has a payout wallet, i.e. can be paid through Djassa.
  final bool acceptsPayment;

  /// Demo data. Always shown as such: a sample pharmacy must never pass for a
  /// real one that is open tonight.
  final bool isSample;

  /// Set only on the on-duty pharmacy list.
  final DateTime? dutyEndsAt;

  /// Set only on the detail endpoint.
  final List<Reward> rewards;
  final List<Deal> deals;
  final int myPoints;

  bool get isPharmacy => category == 'pharmacy';
}

class Reward {
  const Reward({required this.id, required this.title, required this.costPoints});

  factory Reward.fromJson(Map<String, Object?> json) => Reward(
        id: json['id'] as int,
        title: json['title'] as String,
        costPoints: json['cost_points'] as int,
      );

  final int id;
  final String title;
  final int costPoints;
}

/// The backend sends naive UTC timestamps. Abidjan is UTC+0 all year, but
/// parse them as UTC anyway so a phone set to another zone still shows the
/// right hour.
DateTime? parseServerTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final hasZone = value.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(value);
  return DateTime.parse(hasZone ? value : '${value}Z').toLocal();
}
