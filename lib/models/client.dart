class Client {
  const Client({
    required this.id,
    required this.clientNumber,
    required this.name,
    required this.status,
    this.email,
    this.phoneNumber,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
    this.preferredContactMethod,
    this.preferredContactWindow,
    this.serviceNotes,
  });

  final String id;
  final String clientNumber;
  final String name;
  final String status;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  final String? preferredContactMethod;
  final String? preferredContactWindow;
  final String? serviceNotes;

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: (json['id'] ?? '').toString(),
      clientNumber: (json['client_number'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      email: json['email']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      zipCode: json['zip_code']?.toString(),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      preferredContactMethod: json['preferred_contact_method']?.toString(),
      preferredContactWindow: json['preferred_contact_window']?.toString(),
      serviceNotes: json['service_notes']?.toString(),
    );
  }
}

class ClientCreateInput {
  const ClientCreateInput({
    required this.name,
    required this.email,
    this.status,
    this.phoneNumber,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.preferredContactMethod,
    this.preferredContactWindow,
    this.serviceNotes,
  });

  final String name;
  final String email;
  final String? status;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? preferredContactMethod;
  final String? preferredContactWindow;
  final String? serviceNotes;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'status': status,
    'phone_number': phoneNumber,
    'address': address,
    'city': city,
    'state': state,
    'zip_code': zipCode,
    'preferred_contact_method': preferredContactMethod,
    'preferred_contact_window': preferredContactWindow,
    'service_notes': serviceNotes,
  };
}

class ClientUpdateInput {
  const ClientUpdateInput({
    this.name,
    this.email,
    this.status,
    this.phoneNumber,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.preferredContactMethod,
    this.preferredContactWindow,
    this.serviceNotes,
  });

  final String? name;
  final String? email;
  final String? status;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? preferredContactMethod;
  final String? preferredContactWindow;
  final String? serviceNotes;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (status != null) data['status'] = status;
    if (phoneNumber != null) data['phone_number'] = phoneNumber;
    if (address != null) data['address'] = address;
    if (city != null) data['city'] = city;
    if (state != null) data['state'] = state;
    if (zipCode != null) data['zip_code'] = zipCode;
    if (preferredContactMethod != null) {
      data['preferred_contact_method'] = preferredContactMethod;
    }
    if (preferredContactWindow != null) {
      data['preferred_contact_window'] = preferredContactWindow;
    }
    if (serviceNotes != null) data['service_notes'] = serviceNotes;
    return data;
  }
}
