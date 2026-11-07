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
  static const String defaultCity = 'Chandigarh';

  static const List<Place> all = <Place>[
    Place(name: 'Sector 17', city: 'Chandigarh', latitude: 30.7398, longitude: 76.7827),
    Place(name: 'Sector 35', city: 'Chandigarh', latitude: 30.7225, longitude: 76.7610),
    Place(name: 'Sector 22', city: 'Chandigarh', latitude: 30.7320, longitude: 76.7726),
    Place(name: 'Sector 8', city: 'Chandigarh', latitude: 30.7440, longitude: 76.7960),
    Place(name: 'Manimajra', city: 'Chandigarh', latitude: 30.7240, longitude: 76.8350),
    Place(name: 'Sector 9', city: 'Chandigarh', latitude: 30.7460, longitude: 76.7880),
    Place(name: 'Sector 11', city: 'Chandigarh', latitude: 30.7570, longitude: 76.7810),
    Place(name: 'Sector 44', city: 'Chandigarh', latitude: 30.7140, longitude: 76.7590),
    Place(name: 'Industrial Area', city: 'Chandigarh', latitude: 30.7056, longitude: 76.8013),
    Place(name: 'Sector 7', city: 'Chandigarh', latitude: 30.7390, longitude: 76.7990),
    Place(name: 'Sector 26', city: 'Chandigarh', latitude: 30.7273, longitude: 76.8094),
    Place(name: 'Sector 15', city: 'Chandigarh', latitude: 30.7500, longitude: 76.7700),
    Place(name: 'Sector 5', city: 'Chandigarh', latitude: 30.7560, longitude: 76.8020),
    Place(name: 'Sector 32', city: 'Chandigarh', latitude: 30.7156, longitude: 76.7750),
    Place(name: 'Sector 43', city: 'Chandigarh', latitude: 30.7194, longitude: 76.7497),
    Place(name: 'IT Park', city: 'Chandigarh', latitude: 30.7270, longitude: 76.8490),
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
