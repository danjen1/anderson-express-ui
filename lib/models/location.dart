class Location {
  const Location({
    required this.id,
    required this.locationNumber,
    required this.status,
    required this.type,
    required this.clientId,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String locationNumber;
  final String status;
  final String type;
  final int clientId;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: (json['id'] ?? '').toString(),
      locationNumber: (json['location_number'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      clientId: int.tryParse((json['client_id'] ?? '').toString()) ?? 0,
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      zipCode: json['zip_code']?.toString(),
      latitude: json['latitude'] == null
          ? null
          : double.tryParse(json['latitude'].toString()),
      longitude: json['longitude'] == null
          ? null
          : double.tryParse(json['longitude'].toString()),
    );
  }
}

class LocationCreateInput {
  const LocationCreateInput({
    required this.type,
    required this.clientId,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
  });

  final String type;
  final int clientId;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
    'type': type,
    'client_id': clientId,
    'address': address,
    'city': city,
    'state': state,
    'zip_code': zipCode,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class LocationUpdateInput {
  const LocationUpdateInput({
    this.type,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
  });

  final String? type;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (address != null) data['address'] = address;
    if (city != null) data['city'] = city;
    if (state != null) data['state'] = state;
    if (zipCode != null) data['zip_code'] = zipCode;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    return data;
  }
}
