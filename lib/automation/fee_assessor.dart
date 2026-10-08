/// Pure fee assessment for document requests.
library;

class FeeAssessor {
  FeeAssessor._();

  static FeeAssessment assess({
    required String documentType,
    required Map<String, double> feesByType,
  }) {
    if (!feesByType.containsKey(documentType)) {
      return FeeAssessment(
        documentType: documentType,
        feeAmount: 0,
        paymentRequired: false,
        feeMissing: true,
        isValid: true,
      );
    }

    final fee = feesByType[documentType] ?? 0;
    if (fee < 0) {
      return FeeAssessment(
        documentType: documentType,
        feeAmount: fee,
        paymentRequired: false,
        feeMissing: false,
        isValid: false,
      );
    }

    return FeeAssessment(
      documentType: documentType,
      feeAmount: fee,
      paymentRequired: fee > 0,
      feeMissing: false,
      isValid: true,
    );
  }

  static bool amountsMatch(double a, double b) => (a - b).abs() < 0.01;
}

class FeeAssessment {
  FeeAssessment({
    required this.documentType,
    required this.feeAmount,
    required this.paymentRequired,
    required this.feeMissing,
    required this.isValid,
  });

  final String documentType;
  final double feeAmount;
  final bool paymentRequired;
  final bool feeMissing;
  final bool isValid;
}
