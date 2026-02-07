class JobTask {
  JobTask({
    required this.id,
    required this.jobId,
    required this.name,
    required this.category,
    required this.required,
    required this.completed,
    this.displayOrder,
    this.completedAt,
    this.notes,
  });

  final String id;
  final int jobId;
  final String name;
  final String category;
  final bool required;
  final bool completed;
  final int? displayOrder;
  final String? completedAt;
  final String? notes;

  factory JobTask.fromJson(Map<String, dynamic> json) {
    return JobTask(
      id: json['id'].toString(),
      jobId: int.tryParse(json['job_id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      required: json['required'] == true,
      completed: json['completed'] == true,
      displayOrder: int.tryParse('${json['display_order'] ?? ''}'),
      completedAt: json['completed_at']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class JobTaskUpdateInput {
  const JobTaskUpdateInput({this.completed, this.notes});

  final bool? completed;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {'completed': completed, 'notes': notes}
      ..removeWhere((_, value) => value == null);
  }
}
