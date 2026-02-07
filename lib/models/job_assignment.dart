class JobAssignment {
  JobAssignment({
    required this.id,
    required this.jobId,
    required this.employeeId,
    required this.isActive,
  });

  final String id;
  final int jobId;
  final String employeeId;
  final bool isActive;

  factory JobAssignment.fromJson(Map<String, dynamic> json) {
    return JobAssignment(
      id: json['id'].toString(),
      jobId: int.tryParse(json['job_id'].toString()) ?? 0,
      employeeId: json['employee_id']?.toString() ?? '',
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
