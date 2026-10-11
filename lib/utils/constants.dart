import 'package:flutter/material.dart';

// App Colors
class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color secondary = Color(0xFF03A9F4);
  static const Color accent = Color(0xFFFF9800);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}

// App Strings
class AppStrings {
  static const String appName = 'Barangay E-Document System';

  // Auth
  static const String login = 'Login';
  static const String register = 'Register';
  static const String logout = 'Logout';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String username = 'Username';
  static const String fullName = 'Full Name';
  static const String address = 'Address';
  static const String age = 'Age';
  static const String phoneNumber = 'Phone Number';
  static const String profilePhoto = 'Profile Photo';

  // Messages
  static const String registrationPending =
      'Your registration is pending approval';
  static const String registrationApproved =
      'Your registration has been approved!';
  static const String registrationRejected =
      'Your registration has been rejected';
  static const String loginSuccess = 'Login successful';
  static const String logoutSuccess = 'Logged out successfully';
  static const String requestSubmitted = 'Request submitted successfully';

  // Document Types
  static const String barangayClearance = 'Barangay Clearance';
  static const String certificateOfIndigency = 'Certificate of Indigency';
  static const String barangayId = 'Barangay ID';

  // Status
  static const String pending = 'Pending';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';

  // Buttons
  static const String submit = 'Submit';
  static const String cancel = 'Cancel';
  static const String approve = 'Approve';
  static const String reject = 'Reject';
  static const String download = 'Download';
  static const String upload = 'Upload';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String view = 'View';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String refresh = 'Refresh';
}

// Document Types
enum DocumentType {
  barangayClearance,
  indigency,
  barangayId,
  cedula,
  businessClearance,
  certification,
  oathUndertaking,
  goodMoral,
  residency;

  String get value {
    switch (this) {
      case DocumentType.barangayClearance:
        return 'barangay_clearance';
      case DocumentType.businessClearance:
        return 'business_clearance';
      case DocumentType.certification:
        return 'certification';
      case DocumentType.oathUndertaking:
        return 'oath_undertaking';
      case DocumentType.indigency:
        return 'indigency';
      case DocumentType.goodMoral:
        return 'good_moral';
      case DocumentType.residency:
        return 'residency';
      case DocumentType.cedula:
        return 'cedula';
      case DocumentType.barangayId:
        return 'barangay_id';
    }
  }

  String get displayName {
    switch (this) {
      case DocumentType.barangayClearance:
        return 'Barangay Clearance';
      case DocumentType.businessClearance:
        return 'Barangay Business Clearance';
      case DocumentType.certification:
        return 'Barangay Certification';
      case DocumentType.oathUndertaking:
        return 'Oath of Undertaking';
      case DocumentType.indigency:
        return 'Certificate of Indigency';
      case DocumentType.goodMoral:
        return 'Certificate of Good Moral Character';
      case DocumentType.residency:
        return 'Certificate of Residency';
      case DocumentType.cedula:
        return 'Cedula';
      case DocumentType.barangayId:
        return 'Barangay ID';
    }
  }

  static DocumentType fromString(String value) {
    switch (value) {
      case 'barangay_clearance':
        return DocumentType.barangayClearance;
      case 'business_clearance':
        return DocumentType.businessClearance;
      case 'certification':
        return DocumentType.certification;
      case 'oath_undertaking':
        return DocumentType.oathUndertaking;
      case 'indigency':
        return DocumentType.indigency;
      case 'good_moral':
        return DocumentType.goodMoral;
      case 'residency':
        return DocumentType.residency;
      case 'cedula':
        return DocumentType.cedula;
      case 'barangay_id':
        return DocumentType.barangayId;
      default:
        throw Exception('Invalid document type: $value');
    }
  }
}

// Registration Status
enum RegistrationStatus {
  pending,
  approved,
  rejected;

  String get value => name;

  static RegistrationStatus fromString(String value) {
    return RegistrationStatus.values.firstWhere((e) => e.name == value);
  }
}

// Request Status
enum RequestStatus {
  pendingPayment,
  paymentSubmitted,
  paymentVerified,
  pendingReview,
  generated,
  pendingSecretaryReview,
  needsRevision,
  approved,
  approvedForRelease,
  released,
  archived,
  cancelled,
  rejected;

  String get value {
    switch (this) {
      case RequestStatus.pendingPayment:
        return 'pending_payment';
      case RequestStatus.paymentSubmitted:
        return 'payment_submitted';
      case RequestStatus.paymentVerified:
        return 'payment_verified';
      case RequestStatus.pendingReview:
        return 'pending_review';
      case RequestStatus.generated:
        return 'generated';
      case RequestStatus.pendingSecretaryReview:
        return 'pending_secretary_review';
      case RequestStatus.needsRevision:
        return 'needs_revision';
      case RequestStatus.approved:
        return 'approved';
      case RequestStatus.approvedForRelease:
        return 'approved_for_release';
      case RequestStatus.released:
        return 'released';
      case RequestStatus.archived:
        return 'archived';
      case RequestStatus.cancelled:
        return 'cancelled';
      case RequestStatus.rejected:
        return 'rejected';
    }
  }

  Color get color {
    switch (this) {
      case RequestStatus.pendingPayment:
      case RequestStatus.paymentSubmitted:
      case RequestStatus.pendingReview:
      case RequestStatus.pendingSecretaryReview:
      case RequestStatus.needsRevision:
        return AppColors.warning;
      case RequestStatus.paymentVerified:
      case RequestStatus.generated:
      case RequestStatus.approved:
      case RequestStatus.approvedForRelease:
        return AppColors.success;
      case RequestStatus.released:
        return AppColors.primary;
      case RequestStatus.rejected:
      case RequestStatus.cancelled:
        return AppColors.error;
      case RequestStatus.archived:
        return AppColors.textSecondary;
    }
  }

  static RequestStatus fromString(String value) {
    return RequestStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RequestStatus.pendingReview,
    );
  }
}

// User Role
enum UserRole {
  captain,
  secretary,
  treasurer,
  kagawadRepresentative,
  barangayTanod,
  citizen,
  admin;

  String get value {
    switch (this) {
      case UserRole.captain:
        return 'captain';
      case UserRole.secretary:
        return 'secretary';
      case UserRole.treasurer:
        return 'treasurer';
      case UserRole.kagawadRepresentative:
        return 'kagawad_representative';
      case UserRole.barangayTanod:
        return 'barangay_tanod';
      case UserRole.citizen:
        return 'citizen';
      case UserRole.admin:
        return 'admin';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.captain:
        return 'Barangay Captain';
      case UserRole.secretary:
        return 'Secretary';
      case UserRole.treasurer:
        return 'Treasurer';
      case UserRole.kagawadRepresentative:
        return 'Kagawad Representative';
      case UserRole.barangayTanod:
        return 'Barangay Tanod';
      case UserRole.citizen:
        return 'Citizen';
      case UserRole.admin:
        return 'Administrator';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'captain':
        return UserRole.captain;
      case 'secretary':
        return UserRole.secretary;
      case 'treasurer':
        return UserRole.treasurer;
      case 'kagawad_representative':
        return UserRole.kagawadRepresentative;
      case 'barangay_tanod':
        return UserRole.barangayTanod;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.citizen;
    }
  }
}

// Storage Buckets
class StorageBuckets {
  static const String profilePhotos = 'profile-photos';
  static const String documents = 'documents';
}

// App Sizes
class AppSizes {
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  static const double borderRadius = 12.0;
  static const double iconSize = 24.0;
  static const double iconSizeS = 18.0;
  static const double iconSizeL = 32.0;

  static const double avatarSize = 100.0;
  static const double avatarSizeS = 50.0;
  static const double avatarSizeL = 150.0;
}

// Error Messages
class ErrorMessages {
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError =
      'Network error. Please check your connection.';
  static const String authError = 'Authentication error. Please login again.';
  static const String invalidEmail = 'Please enter a valid email';
  static const String invalidPassword =
      'Password must be at least 6 characters';
  static const String passwordMismatch = 'Passwords do not match';
  static const String requiredField = 'This field is required';
  static const String invalidAge = 'Please enter a valid age';
  static const String invalidPhone = 'Please enter a valid phone number';
}
