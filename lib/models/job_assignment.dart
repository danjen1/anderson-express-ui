class JobAssignment {
  JobAssignment({
    required this.id,
    required this.jobId,
    required this.employeeId,
    this.employeeName,
    this.startTime,
    this.endTime,
    required this.isActive,
  });

  final String id;
  final int jobId;
  final String employeeId;
  final String? employeeName;
  final String? startTime;
  final String? endTime;
  final bool isActive;

  factory JobAssignment.fromJson(Map<String, dynamic> json) {
    return JobAssignment(
      id: json['id'].toString(),
      jobId: int.tryParse(json['job_id'].toString()) ?? 0,
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      isActive: json['is_active'] == true,
    );
  }
}

class JobAssignmentCreateInput {
  const JobAssignmentCreateInput({required this.employeeId});

  final String employeeId;

  Map<String, dynamic> toJson() {
    return {'employee_id': employeeId};
  }
}
