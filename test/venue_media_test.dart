import 'package:djassa_user/core/model/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the shop page carries its media, cheapest URL for the list', () {
    final venue = Venue.fromJson({
      'id': 1, 'category': 'maquis', 'name': 'Chez Awa', 'commune': 'Abobo',
      'points_per_100': 1, 'accepts_payment': true, 'is_sample': false,
      'cover_url': 'https://m/t.webp',
      'media': [
        {'id': 3, 'kind': 'image', 'status': 'ready', 'position': 1,
         'thumb_url': 'https://m/t.webp', 'medium_url': 'https://m/m.webp', 'large_url': 'https://m/l.webp'},
        {'id': 4, 'kind': 'video', 'status': 'ready', 'position': 2, 'thumb_url': 'https://m/p.webp',
         'poster_url': 'https://m/p.webp', 'video_url': 'https://m/v.mp4', 'video_bytes': 2400000, 'duration_s': 32},
      ],
    });
    expect(venue.coverUrl, 'https://m/t.webp');
    expect(venue.media, hasLength(2));
    expect(venue.media.first.isVideo, isFalse);
    expect(venue.media.first.mediumUrl, 'https://m/m.webp');
    expect(venue.media.last.isVideo, isTrue);
    expect(venue.media.last.videoBytes, 2400000);
  });

  test('a venue from a list has no media', () {
    final venue = Venue.fromJson({'id': 1, 'category': 'maquis', 'name': 'X', 'commune': 'Y'});
    expect(venue.media, isEmpty);
    expect(venue.coverUrl, isNull);
  });
}
