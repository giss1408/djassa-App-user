import 'package:hossouko_user/core/model/venue.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "Itinéraire" button opens a Google Maps directions link. With the
/// coordinates the merchant recorded in the shop, it routes to the exact spot;
/// without, it searches the name and address in the commune.
void main() {
  Map<String, Object?> json({double? lat, double? lng, String? address}) => {
        'id': 1,
        'category': 'maquis',
        'name': 'Maquis Chez Awa',
        'commune': 'Cocody',
        'address': address,
        'latitude': lat,
        'longitude': lng,
        'points_per_100': 1,
        'accepts_payment': true,
        'is_sample': false,
      };

  test('reads the coordinates the backend sends', () {
    final v = Venue.fromJson(json(lat: 5.3597, lng: -3.9676));
    expect(v.hasPosition, isTrue);
    expect(v.latitude, 5.3597);
    expect(v.longitude, -3.9676);
  });

  test('with coordinates, routes to the exact spot', () {
    final uri = Venue.fromJson(json(lat: 5.3597, lng: -3.9676)).directionsUri;
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], '5.359700,-3.967600');
  });

  test('without coordinates, searches the name and address in the commune', () {
    final v = Venue.fromJson(json(address: 'Angré, face pharmacie Arc-en-ciel'));
    expect(v.hasPosition, isFalse);
    expect(
      v.directionsUri.queryParameters['destination'],
      "Maquis Chez Awa, Angré, face pharmacie Arc-en-ciel, Cocody, Abidjan, Côte d'Ivoire",
    );
  });

  test('a blank address is left out of the search', () {
    final v = Venue.fromJson(json(address: '  '));
    expect(v.directionsUri.queryParameters['destination'], "Maquis Chez Awa, Cocody, Abidjan, Côte d'Ivoire");
  });

  test('integer coordinates from the server are accepted', () {
    final v = Venue.fromJson({...json(), 'latitude': 5, 'longitude': -4});
    expect(v.hasPosition, isTrue);
    expect(v.directionsUri.queryParameters['destination'], '5.000000,-4.000000');
  });
}
