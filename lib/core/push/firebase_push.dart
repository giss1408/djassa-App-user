import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/env.dart';
import 'offer_alerts.dart';

/// FCM through topics only: no device token is read or sent anywhere.
class FirebasePushGateway implements PushGateway {
  FirebasePushGateway(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  bool get available => true;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> subscribe(String topic) => _messaging.subscribeToTopic(topic);

  @override
  Future<void> unsubscribe(String topic) => _messaging.unsubscribeFromTopic(topic);
}

/// Starts Firebase when the build carries a project (Env.pushConfigured), and
/// returns the gateway; null otherwise, and on any start-up failure, so a
/// Firebase problem costs the alerts, never the app.
Future<FirebasePushGateway?> startFirebasePush() async {
  if (!Env.pushConfigured) return null;
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseSenderId,
        projectId: Env.firebaseProjectId,
      ),
    );
    return FirebasePushGateway(FirebaseMessaging.instance);
  } catch (_) {
    return null;
  }
}

/// The shop a deal alert points to, or null for anything else.
int? venueIdOf(RemoteMessage message) =>
    message.data['type'] == 'deal' ? int.tryParse('${message.data['venue_id']}') : null;
