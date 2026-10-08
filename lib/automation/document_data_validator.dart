/// Pure per-document-type data validation for automated request intake.
library;

class DocumentDataValidator {
  DocumentDataValidator._();

  static const supportedTypes = <String>{
    'barangay_clearance',
    'indigency',
    'barangay_id',
    'cedula',
  };

  static ValidationResult validate({
    required String documentType,
    required String purpose,
    required Map<String, dynamic> documentData,
  }) {
    final errors = <String>[];

    if (!supportedTypes.contains(documentType)) {
      errors.add('Unsupported document type: $documentType');
      return ValidationResult(errors);
    }

    if (purpose.trim().isEmpty) {
      errors.add('purpose is required');
    } else if (purpose.trim().length < 5) {
      errors.add('purpose must be at least 5 characters');
    }

    switch (documentType) {
      case 'barangay_clearance':
        // Uses citizen profile fields; documentData optional.
        break;
      case 'indigency':
        _require(errors, documentData, 'full_name');
        _require(errors, documentData, 'purpose');
        break;
      case 'barangay_id':
        _require(errors, documentData, 'full_name');
        _require(errors, documentData, 'address');
        _require(errors, documentData, 'contact_number');
        break;
      case 'cedula':
        _require(errors, documentData, 'first_name');
        _require(errors, documentData, 'last_name');
        _require(errors, documentData, 'address');
        _require(errors, documentData, 'birth_date');
        _require(errors, documentData, 'birth_place');
        _require(errors, documentData, 'gender');
        break;
    }

    return ValidationResult(errors);
  }

  static void _require(
    List<String> errors,
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];
    if (value == null || value.toString().trim().isEmpty) {
      errors.add('$key is required');
    }
  }
}

class ValidationResult {
  ValidationResult(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;

  String get summary => errors.join('; ');
}
