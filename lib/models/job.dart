class Job {
  Job({
    required this.id,
    required this.jobNumber,
    required this.profileId,
    required this.locationId,
    required this.scheduledDate,
    required this.status,
    this.notes,
  });

  final String id;
  final String jobNumber;
  final int profileId;
  final int locationId;
  final String scheduledDate;
  final String status;
  final String? notes;

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'].toString(),
      jobNumber: json['job_number']?.toString() ?? '',
      profileId: int.tryParse(json['profile_id'].toString()) ?? 0,
      locationId: int.tryParse(json['location_id'].toString()) ?? 0,
      scheduledDate: json['scheduled_date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
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
