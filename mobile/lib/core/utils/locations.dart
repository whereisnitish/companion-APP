/// A small, hand-curated place list.
///
/// A real build would put a geocoder behind this; for the MVP a fixed list of
/// neighbourhoods keeps discovery distances meaningful without asking for a
/// location permission on the very first screen, and without a maps API key.
class Place {
  const Place({
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String city;
  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) => other is Place && other.name == name && other.city == city;

  @override
  int get hashCode => Object.hash(name, city);
}

abstract final class Places {
  static const String defaultCity = 'Bengaluru';

  static const List<Place> all = <Place>[
    Place(name: 'Indiranagar', city: 'Bengaluru', latitude: 12.9784, longitude: 77.6408),
    Place(name: 'Koramangala', city: 'Bengaluru', latitude: 12.9352, longitude: 77.6245),
    Place(name: 'HSR Layout', city: 'Bengaluru', latitude: 12.9116, longitude: 77.6389),
    Place(name: 'Jayanagar', city: 'Bengaluru', latitude: 12.9250, longitude: 77.5938),
    Place(name: 'Whitefield', city: 'Bengaluru', latitude: 12.9698, longitude: 77.7500),
    Place(name: 'MG Road', city: 'Bengaluru', latitude: 12.9756, longitude: 77.6068),
    Place(name: 'Malleswaram', city: 'Bengaluru', latitude: 13.0035, longitude: 77.5647),
    Place(name: 'JP Nagar', city: 'Bengaluru', latitude: 12.9063, longitude: 77.5857),
    Place(name: 'Bellandur', city: 'Bengaluru', latitude: 12.9260, longitude: 77.6762),
    Place(name: 'Ulsoor', city: 'Bengaluru', latitude: 12.9822, longitude: 77.6222),
    Place(name: 'Domlur', city: 'Bengaluru', latitude: 12.9611, longitude: 77.6387),
    Place(name: 'Basavanagudi', city: 'Bengaluru', latitude: 12.9422, longitude: 77.5738),
    Place(name: 'Hebbal', city: 'Bengaluru', latitude: 13.0358, longitude: 77.5970),
    Place(name: 'Frazer Town', city: 'Bengaluru', latitude: 13.0983, longitude: 77.6180),
    Place(name: 'Rajajinagar', city: 'Bengaluru', latitude: 12.9982, longitude: 77.5525),
    Place(name: 'Sarjapur Road', city: 'Bengaluru', latitude: 12.9010, longitude: 77.6874),
  ];

  static Place get fallback => all.first;

  static Place? byName(String? name) {
    if (name == null) return null;
    for (final Place place in all) {
      if (place.name == name) return place;
    }
    return null;
  }

  static List<Place> search(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return all
        .where((Place place) => place.name.toLowerCase().contains(needle))
        .toList(growable: false);
  }
}

/// Portraits offered during profile setup.
///
/// Photo *upload* needs object storage, which is out of scope for the MVP, so
/// the flow offers a curated set and accepts any image URL. The field on the
/// profile is already `avatarUrl`, so wiring an uploader later changes only
/// this picker.
abstract final class StockPortraits {
  static const List<String> options = <String>[
    'https://randomuser.me/api/portraits/women/68.jpg',
    'https://randomuser.me/api/portraits/men/32.jpg',
    'https://randomuser.me/api/portraits/women/44.jpg',
    'https://randomuser.me/api/portraits/men/75.jpg',
    'https://randomuser.me/api/portraits/women/26.jpg',
    'https://randomuser.me/api/portraits/men/12.jpg',
    'https://randomuser.me/api/portraits/women/9.jpg',
    'https://randomuser.me/api/portraits/men/45.jpg',
    'https://randomuser.me/api/portraits/women/55.jpg',
    'https://randomuser.me/api/portraits/men/64.jpg',
    'https://randomuser.me/api/portraits/women/17.jpg',
    'https://randomuser.me/api/portraits/men/83.jpg',
  ];
}
