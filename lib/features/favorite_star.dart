import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/model/venue.dart';
import '../core/personal_lists.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';

/// The star that adds a shop to "Mes favoris". No account needed: favourites
/// stay on the phone (personal_lists.dart).
class FavoriteStar extends ConsumerWidget {
  const FavoriteStar({super.key, required this.venue, this.onDark = false});

  final Venue venue;

  /// On a photo or a dark header: white outline, in a translucent disc.
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(personalListsProvider.select((s) => s.isFavorite(venue.id)));
    final icon = Icon(
      on ? Icons.star_rounded : Icons.star_outline_rounded,
      color: on ? const Color(0xFFF5B800) : (onDark ? Colors.white : FideliaColors.muted),
    );
    final button = IconButton(
      tooltip: on ? Strings.removeFavorite : Strings.addFavorite,
      onPressed: () => ref.read(personalListsProvider.notifier).toggleFavorite(venue),
      icon: icon,
    );
    if (!onDark) return button;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(color: Colors.black.withOpacity(0.22), shape: const CircleBorder(), child: button),
    );
  }
}
