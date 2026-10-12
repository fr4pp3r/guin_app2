class IncidentReport {
  final String id;
  final String? reportNumber;
  final String? submittedBy;
  final String reportType;
  final String title;
  final String description;
  final String location;
  final DateTime incidentDateTime;
  final bool isSensitive;
  final bool isAnonymous;
  final String identityVisibility;
  final String priority;
  final String status;
  final String? receivedBy;
  final String? assignedTo;
  final String? escalatedTo;
  final String? resolvedBy;
  final String? resolutionSummary;
  final DateTime createdAt;

  IncidentReport({
    required this.id,
    this.reportNumber,
    this.submittedBy,
    required this.reportType,
    required this.title,
    required this.description,
    required this.location,
    required this.incidentDateTime,
    required this.isSensitive,
    required this.isAnonymous,
    required this.identityVisibility,
    required this.priority,
    required this.status,
    this.receivedBy,
    this.assignedTo,
    this.escalatedTo,
    this.resolvedBy,
    this.resolutionSummary,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_number': reportNumber,
      'submitted_by': submittedBy,
      'report_type': reportType,
      'title': title,
      'description': description,
      'location': location,
      'incident_datetime': incidentDateTime.toIso8601String(),
      'is_sensitive': isSensitive,
      'is_anonymous': isAnonymous,
      'identity_visibility': identityVisibility,
      'priority': priority,
      'status': status,
      'received_by': receivedBy,
      'assigned_to': assignedTo,
      'escalated_to': escalatedTo,
      'resolved_by': resolvedBy,
      'resolution_summary': resolutionSummary,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory IncidentReport.fromJson(Map<String, dynamic> json) {
    return IncidentReport(
      id: json['id'] as String,
      reportNumber: json['report_number'] as String?,
      submittedBy: json['submitted_by'] as String?,
      reportType: json['report_type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      incidentDateTime: DateTime.parse(json['incident_datetime'] as String),
      isSensitive: json['is_sensitive'] as bool? ?? false,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      identityVisibility: json['identity_visibility'] as String? ?? 'visible',
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'submitted',
      receivedBy: json['received_by'] as String?,
      assignedTo: json['assigned_to'] as String?,
      escalatedTo: json['escalated_to'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      resolutionSummary: json['resolution_summary'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
