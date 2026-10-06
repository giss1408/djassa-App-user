import 'dart:io';

import 'package:djassa_user/core/model/venue.dart';
import 'package:djassa_user/core/personal_lists.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Venue _venue(int id, {String name = 'Maquis'}) =>
    Venue(id: id, category: 'maquis', name: '$name $id', commune: 'Cocody', pointsPer100: 1, acceptsPayment: true, isSample: false);

void main() {
  late Directory dir;
  late ProviderContainer container;

  ProviderContainer open() {
    final c = ProviderContainer(overrides: [personalDirectoryProvider.overrideWithValue(() async => dir)]);
    addTearDown(c.dispose);
    return c;
  }

  PersonalListsNotifier lists() => container.read(personalListsProvider.notifier);
  PersonalLists state() => container.read(personalListsProvider);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('djassa_lists_');
    container = open();
  });

  test('the star adds and removes a favourite, and it survives a restart', () async {
    await lists().toggleFavorite(_venue(1));
    await lists().toggleFavorite(_venue(2));
    expect(state().favorites.map((v) => v.id), [2, 1]);
    await lists().toggleFavorite(_venue(1));
    expect(state().isFavorite(1), isFalse);

    final restarted = open();
    restarted.read(personalListsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final again = restarted.read(personalListsProvider);
    expect(again.favorites.single.name, 'Maquis 2');
    expect(again.isFavorite(2), isTrue);
  });

  test('recently viewed: newest first, no repeats, ten at most', () async {
    for (var i = 1; i <= 12; i++) {
      await lists().viewed(_venue(i));
    }
    await lists().viewed(_venue(5));
    final ids = state().recentVenues.map((v) => v.id).toList();
    expect(ids.first, 5);
    expect(ids, hasLength(PersonalListsNotifier.maxRecentVenues));
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('viewing a favourite refreshes its saved card', () async {
    await lists().toggleFavorite(_venue(3, name: 'Ancien nom'));
    await lists().viewed(_venue(3, name: 'Nouveau nom'));
    expect(state().favorites.single.name, 'Nouveau nom 3');
  });

  test('searches: trimmed, two letters or more, no repeats whatever the case, eight at most', () async {
    await lists().searched('a');
    await lists().searched('  garba ');
    await lists().searched('Attiéké');
    await lists().searched('GARBA');
    expect(state().recentSearches, ['GARBA', 'Attiéké']);
    for (var i = 0; i < 10; i++) {
      await lists().searched('plat $i');
    }
    expect(state().recentSearches, hasLength(PersonalListsNotifier.maxSearches));
    await lists().forgetSearch('plat 9');
    expect(state().recentSearches, isNot(contains('plat 9')));
    await lists().clearSearches();
    await lists().clearRecentVenues();
    expect(state().recentSearches, isEmpty);
  });

  test('a tap while the lists are still loading is not lost', () async {
    await lists().toggleFavorite(_venue(1));
    final restarted = open();
    // Starred before the file has been read back.
    await restarted.read(personalListsProvider.notifier).toggleFavorite(_venue(2));
    expect(restarted.read(personalListsProvider).favorites.map((v) => v.id), [2, 1]);
  });

  test('a corrupt file costs the lists, not the app', () async {
    File('${dir.path}/personal_lists.json').writeAsStringSync('{not json');
    final restarted = open();
    await restarted.read(personalListsProvider.notifier).searched('garba');
    expect(restarted.read(personalListsProvider).recentSearches, ['garba']);
  });
}
