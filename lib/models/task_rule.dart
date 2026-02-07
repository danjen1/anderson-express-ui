class TaskRule {
  TaskRule({
    required this.id,
    required this.taskDefinitionId,
    required this.appliesWhen,
    required this.required,
    this.displayOrder,
    this.notesTemplate,
  });

  final String id;
  final int taskDefinitionId;
  final Map<String, dynamic> appliesWhen;
  final bool required;
  final int? displayOrder;
  final String? notesTemplate;

  factory TaskRule.fromJson(Map<String, dynamic> json) {
    final rawApplies = json['applies_when'];
    return TaskRule(
      id: json['id'].toString(),
      taskDefinitionId:
          int.tryParse(json['task_definition_id'].toString()) ?? 0,
      appliesWhen: rawApplies is Map<String, dynamic> ? rawApplies : const {},
      required: json['required'] == true,
      displayOrder: int.tryParse('${json['display_order'] ?? ''}'),
      notesTemplate: json['notes_template']?.toString(),
    );
  }
}

class TaskRuleCreateInput {
  const TaskRuleCreateInput({
    required this.taskDefinitionId,
    required this.appliesWhen,
    this.required = true,
    this.displayOrder,
    this.notesTemplate,
  });

  final int taskDefinitionId;
  final Map<String, dynamic> appliesWhen;
  final bool required;
  final int? displayOrder;
  final String? notesTemplate;

  Map<String, dynamic> toJson() {
    return {
      'task_definition_id': taskDefinitionId,
      'applies_when': appliesWhen,
      'required': required,
      'display_order': displayOrder,
      'notes_template': notesTemplate,
    };
  }
}
