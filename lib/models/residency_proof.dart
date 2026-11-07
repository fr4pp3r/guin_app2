/// A single self-service residency proof upload (utility bill / secondary ID)
/// stored in `document_residency_proofs`.
///
/// The image lives in the `residency-proofs` Supabase storage bucket; this row
/// only keeps the URL plus the audit trail. Statuses are plain TEXT —
/// 'pending' | 'confirmed' | 'rejected' — matching the CHECK constraint in
/// `supabase/migrations/20261029_residency_proofs.sql`.
class ResidencyProof {
  ResidencyProof({
    required this.id,
    required this.userId,
    required this.proofUrl,
    required this.status,
    this.auditorNotes,
    required this.createdAt,
    this.verifiedAt,
  });

  final String id;
  final String userId;
  final String proofUrl;
  final String status; // 'pending', 'confirmed', 'rejected'
  final String? auditorNotes;
  final DateTime createdAt;
  final DateTime? verifiedAt;

  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String rejected = 'rejected';

  static const Set<String> _statuses = {pending, confirmed, rejected};

  factory ResidencyProof.fromJson(Map<String, dynamic> json) {
    return ResidencyProof(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      proofUrl: json['proof_url'] as String,
      status: _knownStatus(json['status']),
      auditorNotes: json['auditor_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      verifiedAt: _timestamp(json['verified_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'proof_url': proofUrl,
      'status': status,
      'auditor_notes': auditorNotes,
      'created_at': createdAt.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
    };
  }

  /// copyWith preserves nullable semantics: passing nothing keeps the value,
  /// passing an explicit null clears it. Uses a const sentinel type so the
  /// distinction is compile-time safe.
  ResidencyProof copyWith({
    String? id,
    String? userId,
    String? proofUrl,
    String? status,
    Object? auditorNotes = _unset,
    DateTime? createdAt,
    Object? verifiedAt = _unset,
  }) {
    return ResidencyProof(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      proofUrl: proofUrl ?? this.proofUrl,
      status: status ?? this.status,
      auditorNotes: auditorNotes == _unset
          ? this.auditorNotes
          : auditorNotes as String?,
      createdAt: createdAt ?? this.createdAt,
      verifiedAt: verifiedAt == _unset ? this.verifiedAt : verifiedAt as DateTime?,
    );
  }

  static String _knownStatus(Object? value) {
    if (value is String && _statuses.contains(value)) return value;
    return pending;
  }

  static DateTime? _timestamp(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// Const sentinel: distinguishes "argument not supplied" from an explicit null
/// in [ResidencyProof.copyWith], so nullable fields can be cleared.
class _Unset {
  const _Unset();
}

const _unset = _Unset();