class Employee {
  const Employee({
    required this.id,
    required this.employeeNumber,
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
  });

  final String id;
  final String employeeNumber;
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

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: (json['id'] ?? '').toString(),
      employeeNumber: (json['employee_number'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      email: json['email']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
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

class EmployeeCreateInput {
  const EmployeeCreateInput({
    required this.name,
    required this.email,
    this.accessLevel = 'USER',
    this.phoneNumber,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String email;
  final String accessLevel;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'access_level': accessLevel,
    'phone_number': phoneNumber,
    'address': address,
    'city': city,
    'state': state,
    'zip_code': zipCode,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class EmployeeUpdateInput {
  const EmployeeUpdateInput({
    this.name,
    this.email,
    this.phoneNumber,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
  });

  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (phoneNumber != null) data['phone_number'] = phoneNumber;
    if (address != null) data['address'] = address;
    if (city != null) data['city'] = city;
    if (state != null) data['state'] = state;
    if (zipCode != null) data['zip_code'] = zipCode;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    return data;
  }
}
