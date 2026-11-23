/// Value types for the face gate (official-enrolled face auto-approval).
///
/// These are the client-side shapes of the `face-match` edge function's
/// responses. Parsing is defensive on purpose (house convention): the edge
/// function is a remote contract — an unexpected shape degrades to a default
/// instead of throwing.
class FaceGateResult {
  /// Outcome of one face `verify` call. [matched] is authoritative — the
  /// decision threshold lives only in the edge function, never here.
  const FaceGateResult({
    required this.matched,
    required this.score,
    this.reason,
    this.enrollmentId,
  });

  factory FaceGateResult.fromJson(Map<String, dynamic> json) {
    return FaceGateResult(
      matched: json['matched'] is bool ? json['matched'] as bool : false,
      score: json['score'] is num ? (json['score'] as num).toDouble() : 0.0,
      reason: json['reason'] is String ? json['reason'] as String : null,
      enrollmentId:
          json['enrollmentId'] is String ? json['enrollmentId'] as String : null,
    );
  }

  final bool matched;
  final double score;

  /// Machine reason when not matched, e.g. `not_enrolled`.
  final String? reason;

  /// The enrollment row the best score came from (absent when not enrolled).
  final String? enrollmentId;
}

/// One official-enrolled face sample, as returned by the `list` action.
class FaceEnrollment {
  const FaceEnrollment({
    required this.id,
    required this.fullName,
    required this.dob,
    required this.createdAt,
    this.photoUrl,
  });

  factory FaceEnrollment.fromJson(Map<String, dynamic> json) {
    return FaceEnrollment(
      id: json['id'] is String ? json['id'] as String : '',
      fullName: json['fullName'] is String ? json['fullName'] as String : '',
      dob: json['dob'] is String ? json['dob'] as String : '',
      createdAt:
          json['createdAt'] is String ? json['createdAt'] as String : '',
      photoUrl: json['photoUrl'] is String ? json['photoUrl'] as String : null,
    );
  }

  final String id;
  final String fullName;

  /// `YYYY-MM-DD` as stored on the enrollment row.
  final String dob;
  final String createdAt;

  /// 1-hour signed URL to the enrolled photo (null when signing failed).
  final String? photoUrl;
}
