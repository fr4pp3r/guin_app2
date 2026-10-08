-- ============================================
-- MIGRATION SCRIPT - Updates existing schema to new version
-- ============================================
-- Run this INSTEAD of the full schema if you already have tables created
-- This will preserve existing data while adding new features

-- ============================================
-- STEP 1: Drop existing ENUMs and recreate with new values
-- ============================================

-- Drop dependent objects first
ALTER TABLE document_requests DROP CONSTRAINT IF EXISTS document_requests_document_type_check;
ALTER TABLE document_requests DROP CONSTRAINT IF EXISTS document_requests_request_status_check;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Drop and recreate document_type enum
DROP TYPE IF EXISTS document_type CASCADE;
CREATE TYPE document_type AS ENUM ('barangay_clearance', 'indigency', 'barangay_id', 'cedula');

-- Drop and recreate request_status enum
DROP TYPE IF EXISTS request_status CASCADE;
CREATE TYPE request_status AS ENUM ('pending_payment', 'pending_review', 'approved', 'rejected');

-- Drop and recreate payment_status enum (new)
DROP TYPE IF EXISTS payment_status CASCADE;
CREATE TYPE payment_status AS ENUM ('pending', 'verified', 'rejected');

-- Drop and recreate notification_type enum
DROP TYPE IF EXISTS notification_type CASCADE;
CREATE TYPE notification_type AS ENUM (
  'registration_approved', 
  'registration_rejected', 
  'request_approved', 
  'request_rejected',
  'request_submitted',
  'payment_verified',
  'payment_rejected'
);

-- ============================================
-- STEP 2: Add new columns to existing tables
-- ============================================

-- Add new columns to users_profile
ALTER TABLE users_profile 
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS date_of_birth DATE,
  ADD COLUMN IF NOT EXISTS place_of_birth TEXT,
  ADD COLUMN IF NOT EXISTS civil_status TEXT,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS valid_id_url TEXT;

-- Update existing users to have default email if null
UPDATE users_profile SET email = username || '@temp.com' WHERE email IS NULL;

-- Make email NOT NULL after populating
ALTER TABLE users_profile ALTER COLUMN email SET NOT NULL;

-- Add new columns to document_requests
ALTER TABLE document_requests
  ADD COLUMN IF NOT EXISTS document_data JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS payment_amount DECIMAL(10,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS payment_receipt_url TEXT,
  ADD COLUMN IF NOT EXISTS payment_status payment_status DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS payment_verified_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS payment_verified_by UUID REFERENCES users_profile(id),
  ADD COLUMN IF NOT EXISTS payment_rejection_reason TEXT;

-- Update document_data to NOT NULL after adding default
ALTER TABLE document_requests ALTER COLUMN document_data SET NOT NULL;
ALTER TABLE document_requests ALTER COLUMN payment_amount SET NOT NULL;

-- Convert old 'pending' status to 'pending_payment'
UPDATE document_requests SET request_status = 'pending_payment'::request_status 
WHERE request_status::text = 'pending';

-- Re-add the enum type to columns
ALTER TABLE document_requests 
  ALTER COLUMN document_type TYPE document_type USING document_type::text::document_type,
  ALTER COLUMN request_status TYPE request_status USING request_status::text::request_status;

ALTER TABLE notifications
  ALTER COLUMN type TYPE notification_type USING type::text::notification_type;

-- ============================================
-- STEP 3: Create new tables
-- ============================================

-- Barangay Configuration Table
CREATE TABLE IF NOT EXISTS barangay_config (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  gcash_name TEXT NOT NULL,
  gcash_number TEXT NOT NULL,
  barangay_name TEXT NOT NULL,
  barangay_address TEXT NOT NULL,
  barangay_captain TEXT,
  contact_number TEXT,
  email TEXT,
  logo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Document Fees Table
CREATE TABLE IF NOT EXISTS document_fees (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_type document_type NOT NULL UNIQUE,
  fee_amount DECIMAL(10,2) NOT NULL CHECK (fee_amount >= 0),
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Barangay ID Details
CREATE TABLE IF NOT EXISTS barangay_id_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES document_requests(id) ON DELETE CASCADE,
  emergency_contact_name TEXT NOT NULL,
  emergency_contact_number TEXT NOT NULL,
  blood_type TEXT,
  occupation TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indigency Certificate Details
CREATE TABLE IF NOT EXISTS indigency_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES document_requests(id) ON DELETE CASCADE,
  monthly_income DECIMAL(10,2),
  number_of_dependents INTEGER,
  employment_status TEXT,
  specific_purpose TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cedula Details
CREATE TABLE IF NOT EXISTS cedula_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES document_requests(id) ON DELETE CASCADE,
  citizenship TEXT NOT NULL,
  profession_occupation TEXT NOT NULL,
  height_cm DECIMAL(5,2),
  weight_kg DECIMAL(5,2),
  tin_number TEXT,
  community_tax_due DECIMAL(10,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- STEP 4: Add new indexes
-- ============================================

CREATE INDEX IF NOT EXISTS idx_users_profile_email ON users_profile(email);
CREATE INDEX IF NOT EXISTS idx_document_requests_payment_status ON document_requests(payment_status);
CREATE INDEX IF NOT EXISTS idx_barangay_id_details_request_id ON barangay_id_details(request_id);
CREATE INDEX IF NOT EXISTS idx_indigency_details_request_id ON indigency_details(request_id);
CREATE INDEX IF NOT EXISTS idx_cedula_details_request_id ON cedula_details(request_id);

-- ============================================
-- STEP 5: Add new triggers
-- ============================================

-- Trigger for barangay_config updated_at
DROP TRIGGER IF EXISTS update_barangay_config_updated_at ON barangay_config;
CREATE TRIGGER update_barangay_config_updated_at
BEFORE UPDATE ON barangay_config
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Trigger for document_fees updated_at
DROP TRIGGER IF EXISTS update_document_fees_updated_at ON document_fees;
CREATE TRIGGER update_document_fees_updated_at
BEFORE UPDATE ON document_fees
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Update the notification trigger to handle payment notifications
DROP TRIGGER IF EXISTS trigger_request_notification ON document_requests;

CREATE OR REPLACE FUNCTION notify_request_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify on payment verification
  IF NEW.payment_status != OLD.payment_status THEN
    IF NEW.payment_status = 'verified' THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        NEW.user_id,
        'Payment Verified',
        CONCAT('Your payment for ', REPLACE(NEW.document_type::TEXT, '_', ' '), ' has been verified. Your request is now being processed.'),
        'payment_verified'
      );
      -- Update request status to pending_review when payment is verified
      NEW.request_status = 'pending_review';
    ELSIF NEW.payment_status = 'rejected' THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        NEW.user_id,
        'Payment Rejected',
        CONCAT('Your payment for ', REPLACE(NEW.document_type::TEXT, '_', ' '), ' has been rejected. Reason: ', COALESCE(NEW.payment_rejection_reason, 'No reason provided')),
        'payment_rejected'
      );
    END IF;
  END IF;

  -- Notify on request approval/rejection
  IF NEW.request_status != OLD.request_status THEN
    IF NEW.request_status = 'approved' THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        NEW.user_id,
        'Document Request Approved',
        CONCAT('Your request for ', REPLACE(NEW.document_type::TEXT, '_', ' '), ' has been approved. You can now download your document.'),
        'request_approved'
      );
    ELSIF NEW.request_status = 'rejected' THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        NEW.user_id,
        'Document Request Rejected',
        CONCAT('Your request for ', REPLACE(NEW.document_type::TEXT, '_', ' '), ' has been rejected. Reason: ', COALESCE(NEW.rejection_reason, 'No reason provided')),
        'request_rejected'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_request_notification
AFTER UPDATE ON document_requests
FOR EACH ROW
WHEN (OLD.request_status IS DISTINCT FROM NEW.request_status OR OLD.payment_status IS DISTINCT FROM NEW.payment_status)
EXECUTE FUNCTION notify_request_status();

-- ============================================
-- STEP 6: Enable RLS on new tables
-- ============================================

ALTER TABLE barangay_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE barangay_id_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE indigency_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE cedula_details ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 7: Add RLS policies for new tables
-- ============================================

-- Barangay Config Policies
DROP POLICY IF EXISTS "Everyone can view barangay config" ON barangay_config;
CREATE POLICY "Everyone can view barangay config"
ON barangay_config FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Admins can update barangay config" ON barangay_config;
CREATE POLICY "Admins can update barangay config"
ON barangay_config FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users_profile
    WHERE id = auth.uid() AND role = 'admin'
  )
);

DROP POLICY IF EXISTS "Admins can insert barangay config" ON barangay_config;
CREATE POLICY "Admins can insert barangay config"
ON barangay_config FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_profile
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Document Fees Policies
DROP POLICY IF EXISTS "Everyone can view document fees" ON document_fees;
CREATE POLICY "Everyone can view document fees"
ON document_fees FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Admins can update document fees" ON document_fees;
CREATE POLICY "Admins can update document fees"
ON document_fees FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users_profile
    WHERE id = auth.uid() AND role = 'admin'
  )
);

DROP POLICY IF EXISTS "Admins can insert document fees" ON document_fees;
CREATE POLICY "Admins can insert document fees"
ON document_fees FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_profile
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Barangay ID Details Policies
DROP POLICY IF EXISTS "Users can view own barangay id details" ON barangay_id_details;
CREATE POLICY "Users can view own barangay id details"
ON barangay_id_details FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM document_requests
    WHERE id = barangay_id_details.request_id AND user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admins can view all barangay id details" ON barangay_id_details;
CREATE POLICY "Admins can view all barangay id details"
ON barangay_id_details FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users_profile
    WHERE id = auth.uid() AND role = 'admin'
  )
);

DROP POLICY IF EXISTS "Users can insert own barangay id details" ON barangay_id_details;
CREATE POLICY "Users can insert own barangay id details"
ON barangay_id_details FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM document_requests
    WHERE id = barangay_id_details.request_id AND user_id = auth.uid()
  )
);

-- Indigency Details Policies
DROP POLICY IF EXISTS "Users can view own indigency details" ON indigency_details;
CREATE POLICY "Users can view own indigency details"
ON indigency_details FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM document_requests
    WHERE id = indigency_details.request_id AND user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admins can view all indigency details" ON indigency_details;
CREATE POLICY "Admins can view all indigency details"
ON indigency_details FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users_profile
    WHERE id = auth.uid() AND role = 'admin'
  )
);

DROP POLICY IF EXISTS "Users can insert own indigency details" ON indigency_details;
CREATE POLICY "Users can insert own indigency details"
ON indigency_details FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM document_requests
    WHERE id = indigency_details.request_id AND user_id = auth.uid()
  )
);

-- Cedula Details Policies
DROP POLICY IF EXISTS "Users can view own cedula details" ON cedula_details;
CREATE POLICY "Users can view own cedula details"
ON cedula_details FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM document_requests
    WHERE id = cedula_details.request_id AND user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admins can view all cedula details" ON cedula_details;
CREATE POLICY "Admins can view all cedula details"
ON cedula_details FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users_profile
    WHERE id = auth.uid() AND role = 'admin'
  )
);

DROP POLICY IF EXISTS "Users can insert own cedula details" ON cedula_details;
CREATE POLICY "Users can insert own cedula details"
ON cedula_details FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM document_requests
    WHERE id = cedula_details.request_id AND user_id = auth.uid()
  )
);

-- ============================================
-- STEP 8: Insert initial data
-- ============================================

-- Insert default document fees
INSERT INTO document_fees (document_type, fee_amount, description) VALUES
  ('barangay_clearance', 50.00, 'Barangay Clearance Fee'),
  ('indigency', 0.00, 'Certificate of Indigency (Free)'),
  ('barangay_id', 100.00, 'Barangay ID Fee'),
  ('cedula', 75.00, 'Cedula/Community Tax Certificate Fee')
ON CONFLICT (document_type) DO NOTHING;

-- Insert default barangay configuration (UPDATE THESE VALUES!)
INSERT INTO barangay_config (
  barangay_name, 
  barangay_address, 
  gcash_name, 
  gcash_number,
  barangay_captain,
  contact_number,
  email
) VALUES (
  'Barangay Name Here',
  'Barangay Address Here',
  'Juan Dela Cruz', -- Replace with actual GCash account name
  '09123456789',    -- Replace with actual GCash number
  'Captain Name',
  '09123456789',
  'barangay@email.com'
);

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
-- Next steps:
-- 1. Update barangay_config with actual GCash details
-- 2. Update document_fees with correct amounts
-- 3. Create storage buckets: valid-ids, payment-receipts
-- 4. Update any existing user profiles with missing required fields
