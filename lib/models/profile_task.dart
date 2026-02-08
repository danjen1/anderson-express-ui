class ProfileTask {
  ProfileTask({
    required this.id,
    required this.cleaningProfileId,
    required this.taskDefinitionId,
    required this.required,
    this.displayOrder,
    this.taskMetadata,
  });

  final String id;
  final int cleaningProfileId;
  final int taskDefinitionId;
  final bool required;
  final int? displayOrder;
  final Map<String, dynamic>? taskMetadata;

  factory ProfileTask.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['task_metadata'];
    return ProfileTask(
      id: json['id'].toString(),
      cleaningProfileId:
          int.tryParse(json['cleaning_profile_id'].toString()) ?? 0,
      taskDefinitionId:
          int.tryParse(json['task_definition_id'].toString()) ?? 0,
      required: json['required'] == true,
      displayOrder: int.tryParse('${json['display_order'] ?? ''}'),
      taskMetadata: rawMetadata is Map<String, dynamic> ? rawMetadata : null,
    );
  }
}

class ProfileTaskCreateInput {
  const ProfileTaskCreateInput({
    required this.taskDefinitionId,
    this.required = true,
    this.displayOrder,
    this.taskMetadata,
  });

  final int taskDefinitionId;
  final bool required;
  final int? displayOrder;
  final Map<String, dynamic>? taskMetadata;

  Map<String, dynamic> toJson() {
    return {
      'task_definition_id': taskDefinitionId,
      'required': required,
      'display_order': displayOrder,
      'task_metadata': taskMetadata,
    };
  }
}

class ProfileTaskUpdateInput {
  const ProfileTaskUpdateInput({
    this.required,
    this.displayOrder,
    this.taskMetadata,
  });

  final bool? required;
  final int? displayOrder;
  final Map<String, dynamic>? taskMetadata;

  Map<String, dynamic> toJson() {
    return {
      'required': required,
      'display_order': displayOrder,
      'task_metadata': taskMetadata,
    };
  }
}
