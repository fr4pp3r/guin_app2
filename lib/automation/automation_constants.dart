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
    'business_clearance': 'Barangay Business Clearance',
    'certification': 'Barangay Certification',
    'oath_undertaking': 'Oath of Undertaking',
    'indigency': 'Certificate of Indigency',
    'good_moral': 'Certificate of Good Moral Character',
    'residency': 'Certificate of Residency',
    'cedula': 'Cedula',
    'barangay_id': 'Barangay ID',
  };

  static String labelFor(String documentType) =>
      documentTypeLabels[documentType] ?? documentType;
}
