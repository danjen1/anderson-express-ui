class Job {
  Job({
    required this.id,
    required this.jobNumber,
    required this.profileId,
    required this.locationId,
    required this.scheduledDate,
    required this.status,
    this.clientName,
    this.locationAddress,
    this.locationCity,
    this.locationState,
    this.locationZipCode,
    this.locationType,
    this.locationLatitude,
    this.locationLongitude,
    this.completedAt,
    this.actualDurationMinutes,
    this.notes,
  });

  final String id;
  final String jobNumber;
  final int profileId;
  final int locationId;
  final String scheduledDate;
  final String status;
  final String? clientName;
  final String? locationAddress;
  final String? locationCity;
  final String? locationState;
  final String? locationZipCode;
  final String? locationType;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? completedAt;
  final int? actualDurationMinutes;
  final String? notes;

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'].toString(),
      jobNumber: json['job_number']?.toString() ?? '',
      profileId: int.tryParse(json['profile_id'].toString()) ?? 0,
      locationId: int.tryParse(json['location_id'].toString()) ?? 0,
      scheduledDate: json['scheduled_date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      clientName: json['client_name']?.toString(),
      locationAddress: json['location_address']?.toString(),
      locationCity: json['location_city']?.toString(),
      locationState: json['location_state']?.toString(),
      locationZipCode: json['location_zip_code']?.toString(),
      locationType: json['location_type']?.toString(),
      locationLatitude: json['location_latitude'] == null
          ? null
          : double.tryParse(json['location_latitude'].toString()),
      locationLongitude: json['location_longitude'] == null
          ? null
          : double.tryParse(json['location_longitude'].toString()),
      completedAt: json['completed_at']?.toString(),
      actualDurationMinutes: json['actual_duration_minutes'] == null
          ? null
          : int.tryParse(json['actual_duration_minutes'].toString()),
      notes: json['notes']?.toString(),
    );
  }
}

class JobCreateInput {
  const JobCreateInput({
    required this.profileId,
    required this.locationId,
    required this.scheduledDate,
  });

  final int profileId;
  final int locationId;
  final String scheduledDate;

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'location_id': locationId,
      'scheduled_date': scheduledDate,
    };
  }
}
