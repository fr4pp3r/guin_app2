/// Pure pipeline rules for document request automation.
///
/// These rules are intentionally free of Supabase so they can be unit-tested
/// without a live backend. Human decisions (captain approve/reject, treasurer
/// payment confirm/reject, secretary revision) are still required at their
/// stages — automation only advances mechanical transitions.
library;

import 'package:guin_app/models/document_request.dart';

class PipelineRules {
  PipelineRules._();

  static const Set<String> legacyStatuses = {
    DocStatus.pendingReview,
    DocStatus.pendingPayment,
  };

  /// Allowed mechanical / human-confirmed transitions.
  static const Map<String, Set<String>> _transitions = {
    DocStatus.submitted: {
      DocStatus.draftGenerated,
      DocStatus.needsRevision,
      DocStatus.cancelled,
    },
    DocStatus.draftGenerated: {
      DocStatus.invoiced,
      DocStatus.forApproval,
      DocStatus.needsRevision,
      DocStatus.cancelled,
    },
    DocStatus.needsRevision: {
      DocStatus.submitted,
      DocStatus.cancelled,
    },
    DocStatus.verifiedForPayment: {
      DocStatus.invoiced,
      DocStatus.forApproval,
    },
    DocStatus.invoiced: {
      DocStatus.paymentSubmitted,
      DocStatus.pendingPayment, // legacy read path
      DocStatus.cancelled,
    },
    DocStatus.paymentSubmitted: {
      DocStatus.forApproval,
      DocStatus.paymentConfirmed,
      DocStatus.paymentRejected,
    },
    DocStatus.pendingPayment: {
      DocStatus.paymentSubmitted,
      DocStatus.paymentRejected,
    },
    DocStatus.paymentRejected: {
      DocStatus.paymentSubmitted,
      DocStatus.invoiced,
      DocStatus.cancelled,
    },
    DocStatus.paymentConfirmed: {
      DocStatus.forApproval,
    },
    DocStatus.forApproval: {
      DocStatus.released,
      DocStatus.approved,
      DocStatus.approvedForRelease,
      DocStatus.rejected,
    },
    DocStatus.approved: {
      DocStatus.approvedForRelease,
      DocStatus.released,
    },
    DocStatus.approvedForRelease: {
      DocStatus.released,
    },
    DocStatus.released: <String>{},
    DocStatus.rejected: <String>{},
    DocStatus.cancelled: <String>{},
  };

  static bool canTransition(String from, String to) {
    final targets = _transitions[from];
    if (targets == null) return false;
    return targets.contains(to);
  }

  /// Map legacy status values onto the canonical pipeline.
  static String canonicalizeStatus(String status) {
    if (status == DocStatus.pendingPayment) {
      return DocStatus.paymentSubmitted;
    }
    return status;
  }

  static bool isLegacyStatus(String status) => legacyStatuses.contains(status);

  /// After a draft is generated: free docs go to for_approval; paid docs invoice.
  static String nextStatusAfterDraft({required bool feeRequired}) {
    return feeRequired ? DocStatus.invoiced : DocStatus.forApproval;
  }

  static bool isInvoiceOverdue({
    required String status,
    required DateTime? dueDate,
    required DateTime now,
  }) {
    if (status != DocStatus.invoiced) return false;
    if (dueDate == null) return false;
    return now.isAfter(dueDate);
  }

  static PaymentReceiptPreCheck preCheckPaymentReceipt({
    required String? receiptUrl,
    required double expectedAmount,
    required double recordedAmount,
  }) {
    final errors = <String>[];
    if (receiptUrl == null || receiptUrl.trim().isEmpty) {
      errors.add('Payment receipt is missing');
    }
    if (!FeeAmountsMatch(expectedAmount, recordedAmount)) {
      errors.add('Payment amount does not match the assessed fee');
    }
    return PaymentReceiptPreCheck(errors);
  }
}

bool FeeAmountsMatch(double a, double b) => (a - b).abs() < 0.01;

class PaymentReceiptPreCheck {
  PaymentReceiptPreCheck(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}
