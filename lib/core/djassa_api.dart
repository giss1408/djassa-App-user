import 'dart:math';

import 'model/deal.dart';
import 'model/loyalty.dart';
import 'model/payment.dart';
import 'model/venue.dart';
import 'net/api_client.dart';

/// Every customer-facing call, typed. Screens never build URLs themselves.
class DjassaApi {
  DjassaApi(this._client);

  final ApiClient _client;

  Future<List<Category>> categories() async {
    final list = await _client.getJsonList('/api/categories');
    return [for (final c in list) Category.fromJson(c! as Map<String, Object?>)];
  }

  /// Live deals, sponsored first. [featured] true: only the sponsored ones.
  Future<List<Deal>> deals({String? category, String? commune, bool? featured}) async {
    final list = await _client.getJsonList('/api/deals', query: {
      if (category != null) 'category': category,
      if (commune != null) 'commune': commune,
      if (featured != null) 'featured': '$featured',
    });
    return [for (final d in list) Deal.fromJson(d! as Map<String, Object?>)];
  }

  /// Venues of one [category], or of every kind when null.
  Future<List<Venue>> venues({String? category, String? query, String? commune}) async {
    final list = await _client.getJsonList('/api/venues', query: {
      if (category != null) 'category': category,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (commune != null) 'commune': commune,
    });
    return [for (final v in list) Venue.fromJson(v! as Map<String, Object?>)];
  }

  Future<Venue> venue(int id) async => Venue.fromJson(await _client.getJson('/api/venues/$id'));

  Future<List<Venue>> onDutyPharmacies({String? commune}) async {
    final list = await _client.getJsonList('/api/pharmacies/on-duty', query: {
      if (commune != null) 'commune': commune,
    });
    return [for (final v in list) Venue.fromJson(v! as Map<String, Object?>)];
  }

  /// Starts a payment. [idempotencyKey] must be reused on a retry of the SAME
  /// payment: if the first response was lost, the server returns that payment
  /// instead of charging the customer a second time.
  /// Step 1 of paying: ask the server who a scanned code belongs to.
  Future<PayTarget> checkPayCode(String code) async => PayTarget.fromJson(code, await _client.getJson('/api/customer/pay-codes/$code'));

  Future<Payment> pay({
    required String payCode,
    int? amount,
    required Wallet wallet,
    required String payerPhone,
    required String idempotencyKey,
  }) async {
    final json = await _client.postJson(
      '/api/customer/payments',
      idempotencyKey: idempotencyKey,
      body: {
        'pay_code': payCode,
        if (amount != null) 'amount': amount,
        'wallet_provider': wallet.wire,
        'payer_msisdn': payerPhone,
        'idempotency_key': idempotencyKey,
      },
    );
    return Payment.fromJson(json);
  }

  /// One payment. For a pending Wave checkout the server first asks Wave, so
  /// polling this shows the outcome even when Wave's notification is late.
  Future<Payment> payment(int id) async => Payment.fromJson(await _client.getJson('/api/customer/payments/$id'));

  Future<List<Payment>> payments() async {
    final list = await _client.getJsonList('/api/customer/payments');
    return [for (final p in list) Payment.fromJson(p! as Map<String, Object?>)];
  }

  Future<Loyalty> loyalty() async => Loyalty.fromJson(await _client.getJson('/api/customer/loyalty'));

  Future<Voucher> redeem(int rewardId) async =>
      Voucher.fromJson(await _client.postJson('/api/customer/loyalty/redeem', body: {'reward_id': rewardId}));
}

/// 128 random bits as hex. Enough that two payments never collide, without
/// pulling in a uuid package for one call.
String newIdempotencyKey() {
  final random = Random.secure();
  return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
