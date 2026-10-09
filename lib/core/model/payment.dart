import 'venue.dart';

/// The four mobile-money wallets in Cote d'Ivoire, as the backend names them.
enum Wallet {
  wave('wave', 'Wave'),
  orange('orange', 'Orange Money'),
  mtn('mtn', 'MTN MoMo'),
  moov('moov', 'Moov Money');

  const Wallet(this.wire, this.label);
  final String wire;
  final String label;

  static Wallet? fromWire(String value) {
    for (final w in values) {
      if (w.wire == value) return w;
    }
    return null;
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.amount,
    required this.walletProvider,
    required this.status,
    required this.pointsAwarded,
    required this.createdAt,
    this.failureReason,
    this.providerReference,
    this.checkoutUrl,
  });

  factory Payment.fromJson(Map<String, Object?> json) => Payment(
        id: json['id'] as int,
        venueId: json['venue_id'] as int,
        venueName: json['venue_name'] as String,
        amount: json['amount'] as int,
        walletProvider: json['wallet_provider'] as String,
        status: json['status'] as String,
        failureReason: json['failure_reason'] as String?,
        providerReference: json['provider_reference'] as String?,
        checkoutUrl: json['checkout_url'] as String?,
        pointsAwarded: json['points_awarded'] as int? ?? 0,
        createdAt: parseServerTime(json['created_at']) ?? DateTime.now(),
      );

  final int id;
  final int venueId;
  final String venueName;

  /// Whole francs CFA. XOF has no minor unit.
  final int amount;
  final String walletProvider;

  /// "pending" | "succeeded" | "failed"
  final String status;
  final String? failureReason;
  final String? providerReference;

  /// Set while a wallet checkout (Wave) waits for the customer's approval:
  /// the app opens it, the Wave app confirms, the server settles.
  final String? checkoutUrl;
  final int pointsAwarded;
  final DateTime createdAt;

  bool get succeeded => status == 'succeeded';
  bool get failed => status == 'failed';
  bool get awaitsWallet => status == 'pending' && checkoutUrl != null;
}

/// What a scanned QR resolves to, as the SERVER knows it. The confirmation
/// screen shows these fields, never text read from the QR, so a forged
/// sticker cannot display a trusted name.
class PayTarget {
  const PayTarget({
    required this.code,
    required this.venueId,
    required this.name,
    required this.commune,
    required this.category,
    required this.isSample,
    required this.pointsPer100,
    required this.payoutProvider,
    required this.payoutAccountMasked,
    this.amount,
    this.expiresAt,
  });

  factory PayTarget.fromJson(String code, Map<String, Object?> json) => PayTarget(
        code: code,
        venueId: json['venue_id'] as int,
        name: json['name'] as String,
        commune: json['commune'] as String,
        category: json['category'] as String,
        isSample: json['is_sample'] as bool? ?? false,
        pointsPer100: json['points_per_100'] as int? ?? 0,
        payoutProvider: json['payout_provider'] as String,
        payoutAccountMasked: json['payout_account_masked'] as String,
        amount: json['amount'] as int?,
        expiresAt: parseServerTime(json['expires_at']),
      );

  final String code;
  final int venueId;
  final String name;
  final String commune;
  final String category;
  final bool isSample;
  final int pointsPer100;
  final String payoutProvider;
  final String payoutAccountMasked;

  /// Set when the merchant fixed the amount (a one-time payment request).
  final int? amount;
  final DateTime? expiresAt;

  bool get fixedAmount => amount != null;
}

/// Extracts the code from a scanned QR, or null if it is not a Fidelia
/// payment QR. Strict on purpose: anything else is refused before any
/// network call. QRs printed under the old names (djassa://, hossouko://)
/// still scan.
String? parsePayQr(String raw) {
  final match = RegExp(r'^(?:fidelia|hossouko|djassa)://pay/([A-Z0-9]{6,16})$').firstMatch(raw.trim());
  return match?.group(1);
}
