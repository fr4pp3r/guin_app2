/// Shared constants for document processing automation.
library;

class AutomationConstants {
  AutomationConstants._();

  /// Notes marker written when a transition was performed by automation.
  static const systemNotesPrefix = '[automation]';

  /// Default invoice due window in days when creating invoices.
  static const invoiceDueDays = 7;

  /// Document type display helpers used in notifications.
  static const documentTypeLabels = <String, String>{
    'barangay_clearance': 'Barangay Clearance',
    'indigency': 'Certificate of Indigency',
    'barangay_id': 'Barangay ID',
    'cedula': 'Community Tax Certificate',
  };

  static String labelFor(String documentType) =>
      documentTypeLabels[documentType] ?? documentType;
}
