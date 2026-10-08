/// Pure eligibility rules for released documents: expiry + single-use/use limits.
library;

enum DocumentAccessDecision {
  allowed,
  notFound,
  revoked,
  expired,
  used,
  useLimitReached,
}

class DocumentAccessState {
  final String status; // 'valid' | 'revoked' | 'expired' | 'used'
  final DateTime? expiresAt;
  final bool singleUse;
  final int? maxUses;
  final int useCount;
  const DocumentAccessState({
    required this.status,
    this.expiresAt,
    this.singleUse = false,
    this.maxUses,
    this.useCount = 0,
  });
}

class DocumentAccessRules {
  /// Default validity window for a released document.
  static const Duration defaultValidity = Duration(days: 30);

  /// Evaluate whether a document may still be verified/used.
  /// Order: revoked -> already used -> expired -> single-use consumed -> limit reached -> allowed.
  static DocumentAccessDecision evaluate(
    DocumentAccessState state, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (state.status == 'revoked') return DocumentAccessDecision.revoked;
    if (state.status == 'used') return DocumentAccessDecision.used;
    if (state.status == 'expired') return DocumentAccessDecision.expired;
    if (state.expiresAt != null && clock.isAfter(state.expiresAt!)) {
      return DocumentAccessDecision.expired;
    }
    if (state.singleUse && state.useCount >= 1) {
      return DocumentAccessDecision.used;
    }
    if (state.maxUses != null && state.useCount >= state.maxUses!) {
      return DocumentAccessDecision.useLimitReached;
    }
    return DocumentAccessDecision.allowed;
  }

  static bool isUsable(DocumentAccessState state, {DateTime? now}) =>
      evaluate(state, now: now) == DocumentAccessDecision.allowed;

  static int? remainingUses(DocumentAccessState state) {
    if (state.maxUses == null) return null;
    final left = state.maxUses! - state.useCount;
    return left < 0 ? 0 : left;
  }

  /// Compute an expiry timestamp from a base time + validity window.
  static DateTime computeExpiry({DateTime? from, Duration? validity}) =>
      (from ?? DateTime.now()).add(validity ?? defaultValidity);

  /// Human-readable label for a decision (used by UI).
  static String describe(DocumentAccessDecision d) {
    switch (d) {
      case DocumentAccessDecision.allowed:
        return 'Valid';
      case DocumentAccessDecision.notFound:
        return 'Not found';
      case DocumentAccessDecision.revoked:
        return 'Revoked';
      case DocumentAccessDecision.expired:
        return 'Expired';
      case DocumentAccessDecision.used:
        return 'Already used';
      case DocumentAccessDecision.useLimitReached:
        return 'Usage limit reached';
    }
  }
}
