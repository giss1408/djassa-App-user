import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/model/venue.dart';
import '../l10n/strings.dart';

/// Opens directions to [venue] in the phone's maps app.
///
/// The maps app (Google Maps where installed, the browser otherwise) does the
/// routing, walking or driving, voice guidance and offline maps: nothing of
/// that ships in this app. See [Venue.directionsUri] for how the destination
/// is chosen.
Future<void> openDirections(BuildContext context, Venue venue) async {
  var ok = false;
  try {
    ok = await launchUrl(venue.directionsUri, mode: LaunchMode.externalApplication);
  } on Exception {
    ok = false;
  }
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.directionsFailed)));
  } else if (!venue.hasPosition) {
    // Say so rather than let the customer trust an address search as a pin.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.directionsApprox)));
  }
}
