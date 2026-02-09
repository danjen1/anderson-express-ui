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
    this.photoUrl,
    this.accessNotes,
    this.parkingNotes,
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
  final String? photoUrl;
  final String? accessNotes;
  final String? parkingNotes;

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
      photoUrl: json['photo_url']?.toString(),
      accessNotes: json['access_notes']?.toString(),
      parkingNotes: json['parking_notes']?.toString(),
    );
  }
}

class LocationCreateInput {
  const LocationCreateInput({
    required this.type,
    required this.clientId,
    this.status,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
    this.photoUrl,
    this.accessNotes,
    this.parkingNotes,
  });

  final String type;
  final int clientId;
  final String? status;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  final String? accessNotes;
  final String? parkingNotes;

  Map<String, dynamic> toJson() => {
    'type': type,
    'client_id': clientId,
    'status': status,
    'address': address,
    'city': city,
    'state': state,
    'zip_code': zipCode,
    'latitude': latitude,
    'longitude': longitude,
    'photo_url': photoUrl,
    'access_notes': accessNotes,
    'parking_notes': parkingNotes,
  };
}

class LocationUpdateInput {
  const LocationUpdateInput({
    this.type,
    this.status,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
    this.photoUrl,
    this.accessNotes,
    this.parkingNotes,
  });

  final String? type;
  final String? status;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  final String? accessNotes;
  final String? parkingNotes;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (status != null) data['status'] = status;
    if (address != null) data['address'] = address;
    if (city != null) data['city'] = city;
    if (state != null) data['state'] = state;
    if (zipCode != null) data['zip_code'] = zipCode;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (photoUrl != null) data['photo_url'] = photoUrl;
    if (accessNotes != null) data['access_notes'] = accessNotes;
    if (parkingNotes != null) data['parking_notes'] = parkingNotes;
    return data;
  }
}
