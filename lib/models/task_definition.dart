class TaskDefinition {
  TaskDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    this.description,
  });

  final String id;
  final String code;
  final String name;
  final String category;
  final String? description;

  factory TaskDefinition.fromJson(Map<String, dynamic> json) {
    return TaskDefinition(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}

class TaskDefinitionCreateInput {
  const TaskDefinitionCreateInput({
    required this.code,
    required this.name,
    required this.category,
    this.description,
  });

  final String code;
  final String name;
  final String category;
  final String? description;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'category': category,
      'description': description,
    };
  }
}
