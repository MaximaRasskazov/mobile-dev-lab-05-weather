class City {
  final int id;
  final String name;
  final String country;
  final String region;
  final double latitude;
  final double longitude;

  City({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country = '',
    this.region = '',
  });

  String get fullName {
    String result = name;
    if (region.isNotEmpty && region != name) {
      result = '$result, $region';
    }
    if (country.isNotEmpty) {
      result = '$result, $country';
    }
    return result;
  }

  factory City.fromJson(Map<String, dynamic> data) {
    return City(
      id: data['id'] as int,
      name: data['name'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      country: data['country'] as String? ?? '',
      region: data['admin1'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'country': country,
      'admin1': region,
    };
  }
}
