/// Entity-type markers for the `reference_type` column on `notifications`.
/// Paired with `reference_id` so a tap can deep-link to the exact item.
class NotificationRefs {
  const NotificationRefs._();
  static const String documentRequest = 'document_request';
  static const String incidentReport = 'incident_report';
  static const String announcement = 'announcement';
  static const String userRegistration = 'user_registration';
}
