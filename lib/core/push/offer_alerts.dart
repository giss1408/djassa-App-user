import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../personal_lists.dart';
import 'topics.dart';

/// Offer alerts: a push when a shop publishes a new deal ("bon plan").
///
/// The customer turns them on and picks a commune; the shops they starred are
/// followed too. Each choice is an FCM topic the phone subscribes to, so the
/// choice stays on the phone: the server sends to "anyone on this topic" and
/// never learns who is on it. Off until the customer turns it on.
class OfferAlertSettings {
  const OfferAlertSettings({this.enabled = false, this.commune, this.subscribed = const {}});

  factory OfferAlertSettings.fromJson(Map<String, Object?> json) => OfferAlertSettings(
        enabled: json['enabled'] == true,
        commune: json['commune'] as String?,
        subscribed: {for (final t in (json['subscribed'] as List<Object?>? ?? const [])) if (t is String) t},
      );

  final bool enabled;

  /// The commune whose new deals the customer wants; null for favourites only.
  final String? commune;

  /// Topics this phone is subscribed to now, so a change subscribes and
  /// unsubscribes only the difference.
  final Set<String> subscribed;

  Map<String, Object?> toJson() => {'enabled': enabled, 'commune': commune, 'subscribed': subscribed.toList()..sort()};

  /// What the phone should be subscribed to, given these settings.
  Set<String> wantedTopics(Iterable<int> favoriteVenueIds) => enabled
      ? {if (commune != null) communeTopic(commune!), for (final id in favoriteVenueIds) venueTopic(id)}
      : const {};
}

/// The phone's side of FCM, behind an interface so tests need no Firebase.
abstract class PushGateway {
  /// False when this build has no Firebase project (lib/core/config/env.dart).
  bool get available;

  /// Asks Android 13+ for the notification permission. True when granted.
  Future<bool> requestPermission();

  Future<void> subscribe(String topic);

  Future<void> unsubscribe(String topic);
}

/// A build without Firebase: alerts cannot be turned on.
class UnavailablePushGateway implements PushGateway {
  const UnavailablePushGateway();

  @override
  bool get available => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> subscribe(String topic) async {}

  @override
  Future<void> unsubscribe(String topic) async {}
}

/// Replaced in main.dart by the Firebase gateway when the build is configured.
final pushGatewayProvider = Provider<PushGateway>((ref) => const UnavailablePushGateway());

class OfferAlertsNotifier extends Notifier<OfferAlertSettings> {
  late Future<void> _ready;

  @override
  OfferAlertSettings build() {
    _ready = _load();
    // A star added or removed follows or unfollows that shop's alerts.
    ref.listen(personalListsProvider.select((l) => [for (final v in l.favorites) v.id]), (_, __) => _sync());
    return const OfferAlertSettings();
  }

  Future<File> _file() async => File('${(await ref.read(personalDirectoryProvider)()).path}/offer_alerts.json');

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, Object?>) state = OfferAlertSettings.fromJson(json);
    } catch (_) {
      // A corrupt file only turns alerts off; the customer can turn them on again.
    }
  }

  /// Turns alerts on, asking for the permission first. False when the
  /// customer refused it or this build has no Firebase.
  Future<bool> enable({String? commune}) async {
    await _ready;
    final gateway = ref.read(pushGatewayProvider);
    if (!gateway.available || !await gateway.requestPermission()) return false;
    state = OfferAlertSettings(enabled: true, commune: commune ?? state.commune, subscribed: state.subscribed);
    await _sync();
    return true;
  }

  Future<void> disable() async {
    await _ready;
    state = OfferAlertSettings(commune: state.commune, subscribed: state.subscribed);
    await _sync();
  }

  Future<void> chooseCommune(String? commune) async {
    await _ready;
    state = OfferAlertSettings(enabled: state.enabled, commune: commune, subscribed: state.subscribed);
    await _sync();
  }

  /// Brings the phone's subscriptions in line with the settings. A topic that
  /// fails (no network) stays out of `subscribed` and is retried next time.
  Future<void> _sync() async {
    await _ready;
    final gateway = ref.read(pushGatewayProvider);
    final favorites = [for (final v in ref.read(personalListsProvider).favorites) v.id];
    final wanted = state.wantedTopics(favorites);
    final now = {...state.subscribed};
    for (final topic in now.difference(wanted)) {
      try {
        await gateway.unsubscribe(topic);
        now.remove(topic);
      } catch (_) {}
    }
    for (final topic in wanted.difference(now)) {
      try {
        await gateway.subscribe(topic);
        now.add(topic);
      } catch (_) {}
    }
    state = OfferAlertSettings(enabled: state.enabled, commune: state.commune, subscribed: now);
    try {
      await (await _file()).writeAsString(jsonEncode(state.toJson()), flush: true);
    } catch (_) {
      // Kept for this session; saved again on the next change.
    }
  }

  /// At start-up: catch up on anything a previous session could not finish.
  Future<void> resume() => _sync();
}

final offerAlertsProvider = NotifierProvider<OfferAlertsNotifier, OfferAlertSettings>(OfferAlertsNotifier.new);
