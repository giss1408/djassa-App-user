/// Names of the alert topics. The backend computes the same names
/// (app/services/push.py, `topic_slug`); if the two disagree, an alert reaches
/// nobody, so test/offer_alerts_test.dart pins both against the same examples.
library;

/// "Cocody" -> "cocody", "Port-Bouët" -> "port_bouet".
String topicSlug(String value) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y',
  };
  final plain = value.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  return plain.replaceAll(RegExp('[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
}

/// New deals of every shop in a commune.
String communeTopic(String commune) => 'offers_${topicSlug(commune)}';

/// New deals of one shop, for customers who starred it.
String venueTopic(int venueId) => 'venue_$venueId';
