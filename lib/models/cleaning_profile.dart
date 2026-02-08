class CleaningProfile {
  CleaningProfile({
    required this.id,
    required this.locationId,
    required this.name,
    this.notes,
  });

  final String id;
  final int locationId;
  final String name;
  final String? notes;

  factory CleaningProfile.fromJson(Map<String, dynamic> json) {
    return CleaningProfile(
      id: json['id'].toString(),
      locationId: int.tryParse(json['location_id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      notes: json['notes']?.toString(),
    );
  }
}

class CleaningProfileCreateInput {
  const CleaningProfileCreateInput({
    required this.locationId,
    required this.name,
    this.notes,
  });

  final int locationId;
  final String name;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {'location_id': locationId, 'name': name, 'notes': notes};
  }
}

class CleaningProfileUpdateInput {
  const CleaningProfileUpdateInput({this.locationId, this.name, this.notes});

  final int? locationId;
  final String? name;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {'location_id': locationId, 'name': name, 'notes': notes};
  }
}
