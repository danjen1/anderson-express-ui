class AuthUser {
  const AuthUser({
    required this.id,
    required this.accessLevel,
    required this.subjectType,
    required this.subjectId,
    required this.isAdmin,
    required this.isEmployee,
    required this.isClient,
  });

  final int id;
  final String accessLevel;
  final String subjectType;
  final String subjectId;
  final bool isAdmin;
  final bool isEmployee;
  final bool isClient;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      accessLevel: json['access_level']?.toString() ?? '',
      subjectType: json['subject_type']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      isAdmin: json['is_admin'] == true,
      isEmployee: json['is_employee'] == true,
      isClient: json['is_client'] == true,
    );
  }
}
