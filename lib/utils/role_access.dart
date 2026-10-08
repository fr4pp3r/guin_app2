class AppRoles {
  static const String captain = 'captain';
  static const String secretary = 'secretary';
  static const String treasurer = 'treasurer';
  static const String kagawadRepresentative = 'kagawad_representative';
  static const String barangayTanod = 'barangay_tanod';
  static const String citizen = 'citizen';
  static const String legacyAdmin = 'admin';

  static const Set<String> officialRoles = {
    captain,
    secretary,
    treasurer,
    kagawadRepresentative,
    barangayTanod,
    legacyAdmin,
  };

  static bool isOfficial(String role) => officialRoles.contains(role);
  static bool canManageUsers(String role) =>
      role == captain || role == legacyAdmin;

  // ── Workflow-specific permissions ────────────────────────────────────
  // Secretary: draft generation, revision requests, verified-for-payment
  static bool canGenerateDrafts(String role) =>
      role == secretary || role == legacyAdmin;
  static bool canReviewDocuments(String role) =>
      role == secretary || role == legacyAdmin;
  static bool canReleaseDocuments(String role) =>
      role == secretary || role == legacyAdmin;

  // Treasurer: payment verification only
  static bool canVerifyPayments(String role) =>
      role == treasurer || role == legacyAdmin;

  // Captain / Kagawad: final approval
  static bool canApproveDocuments(String role) =>
      role == captain || role == kagawadRepresentative || role == legacyAdmin;
  static bool isCaptain(String role) => role == captain;
  static bool isKagawad(String role) => role == kagawadRepresentative;

  // Admin: document deletion
  static bool canDeleteDocuments(String role) =>
      role == captain || role == legacyAdmin;

  // Tanod: incident reports
  static bool canManageReports(String role) =>
      role == captain ||
      role == barangayTanod ||
      role == kagawadRepresentative ||
      role == legacyAdmin;
  static bool canRevealSensitiveReporter(String role) =>
      role == captain || role == legacyAdmin;

  static String displayName(String role) {
    switch (role) {
      case captain:
        return 'Barangay Captain';
      case secretary:
        return 'Secretary';
      case treasurer:
        return 'Treasurer';
      case kagawadRepresentative:
        return 'Kagawad Representative';
      case barangayTanod:
        return 'Barangay Tanod';
      case legacyAdmin:
        return 'Administrator';
      default:
        return 'Citizen';
    }
  }
}
