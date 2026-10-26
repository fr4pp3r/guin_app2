CiteEase ERD — Relationship Index
Times New Roman, 12pt | All relationships from setup.sql + documented FKs

R1: users_profile (1) —< document_requests (M)    
   FK/Join: user_id, created_by, reviewed_by, reviewed_by_secretary, payment_verified_by, approved_by, released_by, printed_by

R2: users_profile (1) —< payments (M)    
   FK/Join: user_id, encoded_by, verified_by

R3: users_profile (1) —< notifications (M)    
   FK/Join: user_id

R4: users_profile (1) —< announcements (M)    
   FK/Join: created_by

R5: users_profile (1) —< emergency_hotlines (M)    
   FK/Join: created_by

R6: users_profile (1) —< audit_logs (M)    
   FK/Join: actor_user_id

R7: users_profile (1) —< kyc_guarantors (M)    
   FK/Join: indigent_user_id, guarantor_user_id, reviewed_by

R8: users_profile (1) —< users_profile (M)    
   FK/Join: kyc_reviewed_by

R9: users_profile (1) —< incident_reports (M)    
   FK/Join: submitted_by, received_by, assigned_to, escalated_to, resolved_by

R10: users_profile (1) —< incident_updates (M)    
   FK/Join: updated_by

R11: users_profile (1) —< incident_attachments (M)    
   FK/Join: uploaded_by

R12: users_profile (1) —< identity_access_logs (M)    
   FK/Join: accessed_by

R13: users_profile (1) —< document_versions (M)    
   FK/Join: generated_by

R14: users_profile (1) —< document_verifications (M)    
   FK/Join: released_by, revoked_by

R15: users_profile (1) —< document_print_copies (M)    
   FK/Join: issued_by

R16: document_requests (1) —< barangay_id_details (M)  [1:1-app]  
   FK/Join: request_id

R17: document_requests (1) —< indigency_details (M)  [1:1-app]  
   FK/Join: request_id

R18: document_requests (1) —< cedula_details (M)  [1:1-app]  
   FK/Join: request_id

R19: document_requests (1) —< payments (M)    
   FK/Join: request_id

R20: document_requests (1) —< document_versions (M)    
   FK/Join: request_id

R21: document_requests (1) —< document_verifications (M)    
   FK/Join: request_id

R22: document_requests (1) —< document_print_copies (M)    
   FK/Join: request_id

R23: document_requests (1) —< audit_logs (M)    
   FK/Join: request_id

R24: incident_reports (1) —< incident_updates (M)    
   FK/Join: incident_report_id

R25: incident_reports (1) —< incident_attachments (M)    
   FK/Join: incident_report_id

R26: incident_reports (1) —< identity_access_logs (M)    
   FK/Join: incident_report_id

R27: document_fees (1) —< document_requests (M)    [logical/no-FK]
   FK/Join: document_type

R28: users_profile (1) —< role_permissions (M)    [logical/no-FK]
   FK/Join: role = role_key

R29: document_verifications (1) —< document_print_copies (M)    [logical/no-FK]
   FK/Join: document_id

Entities: 21 tables (21). Columns marked * = added by migration (20261017_name_fields, 20261018_id_back_url).
(deprecated) = unused/deprecated by schema notes.
