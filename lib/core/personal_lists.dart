import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'model/venue.dart';

/// Favourite shops (the star), recent searches and recently viewed shops.
///
/// Kept on the phone only, in one small file: they work without an account,
/// cost no data, and tell Hossouko nothing about what the customer looks at.
/// Uninstalling the app or "Effacer" removes them.
class PersonalLists {
  const PersonalLists({
    this.favorites = const [],
    this.recentSearches = const [],
    this.recentVenues = const [],
  });

  factory PersonalLists.fromJson(Map<String, Object?> json) {
    List<Venue> venues(Object? list) => [
          for (final v in (list as List<Object?>? ?? const []))
            if (v is Map<String, Object?>) Venue.fromJson(v),
        ];
    return PersonalLists(
      favorites: venues(json['favorites']),
      recentSearches: [for (final q in (json['recent_searches'] as List<Object?>? ?? const [])) if (q is String) q],
      recentVenues: venues(json['recent_venues']),
    );
  }

  /// Newest first, in every list.
  final List<Venue> favorites;
  final List<String> recentSearches;
  final List<Venue> recentVenues;

  bool isFavorite(int venueId) => favorites.any((v) => v.id == venueId);

  Map<String, Object?> toJson() => {
        'favorites': [for (final v in favorites) v.toSnapshotJson()],
        'recent_searches': recentSearches,
        'recent_venues': [for (final v in recentVenues) v.toSnapshotJson()],
      };

  PersonalLists copyWith({List<Venue>? favorites, List<String>? recentSearches, List<Venue>? recentVenues}) => PersonalLists(
        favorites: favorites ?? this.favorites,
        recentSearches: recentSearches ?? this.recentSearches,
        recentVenues: recentVenues ?? this.recentVenues,
      );
}

/// Where the file lives. Tests point it at a temporary directory.
final personalDirectoryProvider = Provider<Future<Directory> Function()>((ref) => getApplicationSupportDirectory);

class PersonalListsNotifier extends Notifier<PersonalLists> {
  static const maxFavorites = 100;
  static const maxSearches = 8;
  static const maxRecentVenues = 10;

  late Future<void> _ready;

  @override
  PersonalLists build() {
    _ready = _load();
    return const PersonalLists();
  }

  Future<File> _file() async => File('${(await ref.read(personalDirectoryProvider)()).path}/personal_lists.json');

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, Object?>) state = PersonalLists.fromJson(json);
    } catch (_) {
      // A corrupt file costs the customer their lists, never the app.
    }
  }

  /// Every change waits for the file to be read first, so a tap during
  /// start-up is not overwritten by the lists loading behind it.
  Future<void> _update(PersonalLists Function(PersonalLists) change) async {
    await _ready;
    state = change(state);
    try {
      await (await _file()).writeAsString(jsonEncode(state.toJson()), flush: true);
    } catch (_) {
      // Kept for this session; saved again on the next change.
    }
  }

  static List<Venue> _front(List<Venue> list, Venue venue, int max) =>
      [venue, ...list.where((v) => v.id != venue.id)].take(max).toList();

  Future<void> toggleFavorite(Venue venue) => _update((s) => s.copyWith(
        favorites: s.isFavorite(venue.id)
            ? s.favorites.where((v) => v.id != venue.id).toList()
            : _front(s.favorites, venue, maxFavorites),
      ));

  /// A shop page was opened. A favourite's saved card is refreshed too, so a
  /// renamed shop or a new photo shows up.
  Future<void> viewed(Venue venue) => _update((s) => s.copyWith(
        recentVenues: _front(s.recentVenues, venue, maxRecentVenues),
        favorites: [for (final v in s.favorites) v.id == venue.id ? venue : v],
      ));

  /// Searches of two letters or more, without repeats (whatever the case).
  Future<void> searched(String query) {
    final q = query.trim();
    if (q.length < 2) return Future.value();
    return _update((s) => s.copyWith(
          recentSearches: [q, ...s.recentSearches.where((x) => x.toLowerCase() != q.toLowerCase())].take(maxSearches).toList(),
        ));
  }

  Future<void> forgetSearch(String query) =>
      _update((s) => s.copyWith(recentSearches: s.recentSearches.where((x) => x != query).toList()));

  Future<void> clearSearches() => _update((s) => s.copyWith(recentSearches: const []));

  Future<void> clearRecentVenues() => _update((s) => s.copyWith(recentVenues: const []));
}

final personalListsProvider = NotifierProvider<PersonalListsNotifier, PersonalLists>(PersonalListsNotifier.new);
