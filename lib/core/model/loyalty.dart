import 'venue.dart';

class Loyalty {
  const Loyalty({required this.totalPoints, required this.venues, required this.history});

  factory Loyalty.fromJson(Map<String, Object?> json) => Loyalty(
        totalPoints: json['total_points'] as int? ?? 0,
        venues: [
          for (final v in (json['venues'] as List<Object?>? ?? const [])) VenueBalance.fromJson(v! as Map<String, Object?>),
        ],
        history: [
          for (final e in (json['history'] as List<Object?>? ?? const [])) LoyaltyEntry.fromJson(e! as Map<String, Object?>),
        ],
      );

  final int totalPoints;
  final List<VenueBalance> venues;
  final List<LoyaltyEntry> history;
}

/// Points are held per venue: each place funds its own rewards.
class VenueBalance {
  const VenueBalance({
    required this.venueId,
    required this.venueName,
    required this.points,
    required this.rewards,
  });

  factory VenueBalance.fromJson(Map<String, Object?> json) => VenueBalance(
        venueId: json['venue_id'] as int,
        venueName: json['venue_name'] as String,
        points: json['points'] as int,
        rewards: [
          for (final r in (json['rewards'] as List<Object?>? ?? const [])) Reward.fromJson(r! as Map<String, Object?>),
        ],
      );

  final int venueId;
  final String venueName;
  final int points;
  final List<Reward> rewards;
}

class LoyaltyEntry {
  const LoyaltyEntry({
    required this.id,
    required this.venueName,
    required this.points,
    required this.reason,
    required this.createdAt,
    this.voucherCode,
    this.rewardTitle,
  });

  factory LoyaltyEntry.fromJson(Map<String, Object?> json) => LoyaltyEntry(
        id: json['id'] as int,
        venueName: json['venue_name'] as String,
        points: json['points'] as int,
        reason: json['reason'] as String,
        voucherCode: json['voucher_code'] as String?,
        rewardTitle: json['reward_title'] as String?,
        createdAt: parseServerTime(json['created_at']) ?? DateTime.now(),
      );

  final int id;
  final String venueName;
  final int points;
  final String reason; // "payment" | "redeem"
  final String? voucherCode;
  final String? rewardTitle;
  final DateTime createdAt;
}

class Voucher {
  const Voucher({
    required this.code,
    required this.rewardTitle,
    required this.venueName,
    required this.remainingPoints,
  });

  factory Voucher.fromJson(Map<String, Object?> json) => Voucher(
        code: json['voucher_code'] as String,
        rewardTitle: json['reward_title'] as String,
        venueName: json['venue_name'] as String,
        remainingPoints: json['remaining_points'] as int,
      );

  final String code;
  final String rewardTitle;
  final String venueName;
  final int remainingPoints;
}
