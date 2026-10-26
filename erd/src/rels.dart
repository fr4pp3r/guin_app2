/// CiteEase ERD — relationship data.
/// 26 FK relationships + 3 logical (shared-column) associations.
/// Every relationship carries a stable R-id used on the diagram and in the
/// Relationship Index page.
library;

class Rel {
  final String id;
  final String parent; // "1" side
  final String child; // "M" side
  final List<String> cols; // FK columns on child, or join columns
  final bool logical; // true = shared column, no FK constraint
  final bool dagger; // true = app writes one row, schema allows many
  const Rel(this.id, this.parent, this.child, this.cols,
      {this.logical = false, this.dagger = false});

  String get card => '1:M';
}

const fkList = <Rel>[
  Rel('R1', 'users_profile', 'document_requests', [
    'user_id', 'created_by', 'reviewed_by', 'reviewed_by_secretary',
    'payment_verified_by', 'approved_by', 'released_by', 'printed_by',
  ]),
  Rel('R2', 'users_profile', 'payments',
      ['user_id', 'encoded_by', 'verified_by']),
  Rel('R3', 'users_profile', 'notifications', ['user_id']),
  Rel('R4', 'users_profile', 'announcements', ['created_by']),
  Rel('R5', 'users_profile', 'emergency_hotlines', ['created_by']),
  Rel('R6', 'users_profile', 'audit_logs', ['actor_user_id']),
  Rel('R7', 'users_profile', 'kyc_guarantors',
      ['indigent_user_id', 'guarantor_user_id', 'reviewed_by']),
  Rel('R8', 'users_profile', 'users_profile', ['kyc_reviewed_by']),
  Rel('R9', 'users_profile', 'incident_reports', [
    'submitted_by', 'received_by', 'assigned_to', 'escalated_to', 'resolved_by',
  ]),
  Rel('R10', 'users_profile', 'incident_updates', ['updated_by']),
  Rel('R11', 'users_profile', 'incident_attachments', ['uploaded_by']),
  Rel('R12', 'users_profile', 'identity_access_logs', ['accessed_by']),
  Rel('R13', 'users_profile', 'document_versions', ['generated_by']),
  Rel('R14', 'users_profile', 'document_verifications',
      ['released_by', 'revoked_by']),
  Rel('R15', 'users_profile', 'document_print_copies', ['issued_by']),
  Rel('R16', 'document_requests', 'barangay_id_details', ['request_id'],
      dagger: true),
  Rel('R17', 'document_requests', 'indigency_details', ['request_id'],
      dagger: true),
  Rel('R18', 'document_requests', 'cedula_details', ['request_id'],
      dagger: true),
  Rel('R19', 'document_requests', 'payments', ['request_id']),
  Rel('R20', 'document_requests', 'document_versions', ['request_id']),
  Rel('R21', 'document_requests', 'document_verifications', ['request_id']),
  Rel('R22', 'document_requests', 'document_print_copies', ['request_id']),
  Rel('R23', 'document_requests', 'audit_logs', ['request_id']),
  Rel('R24', 'incident_reports', 'incident_updates', ['incident_report_id']),
  Rel('R25', 'incident_reports', 'incident_attachments', ['incident_report_id']),
  Rel('R26', 'incident_reports', 'identity_access_logs', ['incident_report_id']),
  Rel('R27', 'document_fees', 'document_requests', ['document_type'],
      logical: true),
  Rel('R28', 'users_profile', 'role_permissions', ['role = role_key'],
      logical: true),
  Rel('R29', 'document_verifications', 'document_print_copies', ['document_id'],
      logical: true),
];

Rel rel(String id) => fkList.firstWhere((r) => r.id == id);
