/// A good the customer is paying for in several installments at one shop
/// (`GET /api/customer/layaway`). The shop keeps the money and hands the good
/// over once the price is reached; Hossouko only keeps the record.
class LayawayPlan {
  const LayawayPlan({
    required this.id,
    required this.venueName,
    required this.item,
    required this.price,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.dueBy,
    required this.installments,
    this.refundedAmount,
  });

  factory LayawayPlan.fromJson(Map<String, Object?> json) => LayawayPlan(
        id: json['id'] as int,
        venueName: json['venue_name'] as String? ?? '',
        item: json['item'] as String,
        price: json['price'] as int,
        paid: json['paid'] as int,
        remaining: json['remaining'] as int,
        status: json['status'] as String,
        dueBy: _date(json['due_by'])!,
        refundedAmount: json['refunded_amount'] as int?,
        installments: [
          for (final i in (json['installments'] as List<Object?>? ?? const []))
            (amount: (i! as Map<String, Object?>)['amount'] as int, paidAt: _date(i['paid_at'])!),
        ],
      );

  final int id;
  final String venueName;
  final String item;
  final int price;
  final int paid;
  final int remaining;

  /// open | completed (paid, ready to collect) | delivered | cancelled.
  final String status;
  final DateTime dueBy;
  final List<({int amount, DateTime paidAt})> installments;
  final int? refundedAmount;

  bool get isActive => status == 'open' || status == 'completed';
  double get progress => price == 0 ? 0 : (paid / price).clamp(0, 1).toDouble();
}

/// The server sends naive UTC timestamps.
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value.endsWith('Z') ? value : '${value}Z')?.toLocal() : null;
