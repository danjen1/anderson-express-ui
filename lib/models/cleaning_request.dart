class CleaningRequestCreateInput {
  const CleaningRequestCreateInput({
    this.clientId,
    this.locationId,
    required this.requesterName,
    required this.requesterEmail,
    required this.requesterPhone,
    required this.requestedDate,
    required this.requestedTime,
    this.cleaningDetails,
  });

  final int? clientId;
  final int? locationId;
  final String requesterName;
  final String requesterEmail;
  final String requesterPhone;
  final String requestedDate;
  final String requestedTime;
  final String? cleaningDetails;

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'location_id': locationId,
      'requester_name': requesterName,
      'requester_email': requesterEmail,
      'requester_phone': requesterPhone,
      'requested_date': requestedDate,
      'requested_time': requestedTime,
      'cleaning_details': cleaningDetails,
    };
  }
}

class CleaningRequest {
  const CleaningRequest({
    required this.id,
    required this.clientId,
    this.locationId,
    required this.requesterName,
    required this.requesterEmail,
    required this.requesterPhone,
    required this.requestedDate,
    required this.requestedTime,
    this.cleaningDetails,
    required this.status,
    this.createdAt,
  });

  final int id;
  final int clientId;
  final int? locationId;
  final String requesterName;
  final String requesterEmail;
  final String requesterPhone;
  final String requestedDate;
  final String requestedTime;
  final String? cleaningDetails;
  final String status;
  final String? createdAt;

  factory CleaningRequest.fromJson(Map<String, dynamic> json) {
    return CleaningRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      clientId: (json['client_id'] as num?)?.toInt() ?? 0,
      locationId: (json['location_id'] as num?)?.toInt(),
      requesterName: (json['requester_name'] ?? '').toString(),
      requesterEmail: (json['requester_email'] ?? '').toString(),
      requesterPhone: (json['requester_phone'] ?? '').toString(),
      requestedDate: (json['requested_date'] ?? '').toString(),
      requestedTime: (json['requested_time'] ?? '').toString(),
      cleaningDetails: json['cleaning_details']?.toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
