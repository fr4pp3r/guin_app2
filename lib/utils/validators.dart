import 'package:guin_app/l10n/app_l10n.dart';

class Validators {
  // Email validator
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.authEmailRequired;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return AppL10n.current.utilEmailInvalid;
    }

    return null;
  }

  // Password validator
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.authPasswordRequired;
    }

    if (value.length < 6) {
      return AppL10n.current.utilPasswordMinLength;
    }

    return null;
  }

  // Confirm password validator
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.utilConfirmPasswordRequired;
    }

    if (value != password) {
      return AppL10n.current.authPasswordsDoNotMatch;
    }

    return null;
  }

  // Required field validator
  static String? validateRequired(
    String? value, [
    String fieldName = 'This field',
  ]) {
    if (value == null || value.isEmpty) {
      if (fieldName == AppL10n.current.utilThisField ||
          fieldName == 'This field') {
        return AppL10n.current.utilThisFieldRequired;
      }
      return AppL10n.current.utilFieldNameRequired(fieldName);
    }
    return null;
  }

  // Username validator
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.authUsernameRequired;
    }

    if (value.length < 3) {
      return AppL10n.current.utilUsernameMinLength;
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return AppL10n.current.utilUsernameInvalidChars;
    }

    return null;
  }

  // Age validator
  static String? validateAge(String? value) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.utilAgeRequired;
    }

    final age = int.tryParse(value);
    if (age == null) {
      return AppL10n.current.utilAgeInvalid;
    }

    if (age < 1 || age > 150) {
      return AppL10n.current.utilAgeRange;
    }

    return null;
  }

  // Phone number validator
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.authPhoneRequired;
    }

    // Remove spaces, dashes, and parentheses
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it's a valid Philippine mobile number
    final phoneRegex = RegExp(r'^(09|\+639)\d{9}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return AppL10n.current.utilPhoneInvalid;
    }

    return null;
  }

  // Full name validator
  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.utilFullNameRequired;
    }

    if (value.length < 2) {
      return AppL10n.current.utilFullNameMinLength;
    }

    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegex.hasMatch(value)) {
      return AppL10n.current.utilFullNameInvalidChars;
    }

    return null;
  }

  // Address validator
  static String? validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.authAddressRequired;
    }

    if (value.length < 10) {
      return AppL10n.current.utilAddressMinLength;
    }

    return null;
  }

  // Purpose validator (for document requests)
  static String? validatePurpose(String? value) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.utilPurposeRequired;
    }

    if (value.length < 10) {
      return AppL10n.current.utilDetailsMinLength;
    }

    return null;
  }

  // Rejection reason validator
  static String? validateRejectionReason(String? value) {
    if (value == null || value.isEmpty) {
      return AppL10n.current.utilRejectionReasonRequired;
    }

    if (value.length < 10) {
      return AppL10n.current.utilDetailsMinLength;
    }

    return null;
  }
}
