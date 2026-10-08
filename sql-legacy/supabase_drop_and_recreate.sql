-- ============================================
-- DROP AND RECREATE SCHEMA
-- ============================================
-- WARNING: This will DELETE ALL existing data!
-- Only run this if you want to start fresh.
-- ============================================

-- ============================================
-- STEP 1: Drop all existing tables (in correct order due to foreign keys)
-- ============================================

DROP TABLE IF EXISTS barangay_id_details CASCADE;
DROP TABLE IF EXISTS indigency_details CASCADE;
DROP TABLE IF EXISTS cedula_details CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS document_requests CASCADE;
DROP TABLE IF EXISTS document_fees CASCADE;
DROP TABLE IF EXISTS barangay_config CASCADE;
DROP TABLE IF EXISTS users_profile CASCADE;

-- ============================================
-- STEP 2: Drop all existing types/enums
-- ============================================

DROP TYPE IF EXISTS notification_type CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TYPE IF EXISTS request_status CASCADE;
DROP TYPE IF EXISTS document_type CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS registration_status CASCADE;

-- ============================================
-- STEP 3: Drop all existing functions
-- ============================================

DROP FUNCTION IF EXISTS notify_admin_new_request() CASCADE;
DROP FUNCTION IF EXISTS notify_request_status() CASCADE;
DROP FUNCTION IF EXISTS notify_registration_status() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- ============================================
-- NOW RUN THE FULL SCHEMA
-- ============================================
-- After running this, execute the complete supabase_schema.sql file
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- ENUMS
-- ============================================

-- Registration status enum
CREATE TYPE registration_status AS ENUM ('pending', 'approved', 'rejected');

-- User role enum
CREATE TYPE user_role AS ENUM ('admin', 'citizen');

-- Document type enum
CREATE TYPE document_type AS ENUM ('barangay_clearance', 'indigency', 'barangay_id', 'cedula');

-- Request status enum
CREATE TYPE request_status AS ENUM ('pending_payment', 'pending_review', 'approved', 'rejected');

-- Payment status enum
CREATE TYPE payment_status AS ENUM ('pending', 'verified', 'rejected');

-- Notification type enum
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
-- TABLES
-- ============================================

-- Barangay Configuration Table
CREATE TABLE barangay_config (
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
CREATE TABLE document_fees (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_type document_type NOT NULL UNIQUE,
  fee_amount DECIMAL(10,2) NOT NULL CHECK (fee_amount >= 0),
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Users Profile Table
CREATE TABLE users_profile (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL, -- Hashed password (bcrypt)
  full_name TEXT NOT NULL,
  address TEXT NOT NULL,
  age INTEGER NOT NULL CHECK (age >= 0 AND age <= 150),
  date_of_birth DATE NOT NULL,
  place_of_birth TEXT NOT NULL,
  civil_status TEXT NOT NULL,
  gender TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  profile_photo_url TEXT,
  valid_id_url TEXT, -- For registration verification
  is_approved BOOLEAN DEFAULT FALSE,
  registration_status registration_status DEFAULT 'pending',
  rejection_reason TEXT,
  role user_role DEFAULT 'citizen',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Document Requests Table
CREATE TABLE document_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users_profile(id) ON DELETE CASCADE,
  document_type document_type NOT NULL,
  purpose TEXT NOT NULL,
  
  -- Document-specific fields (JSON for flexibility)
  document_data JSONB NOT NULL, -- Stores specific info for each document type
  
  -- Request status
  request_status request_status DEFAULT 'pending_payment',
  rejection_reason TEXT,
  
  -- Payment information
  payment_amount DECIMAL(10,2) NOT NULL,
  payment_receipt_url TEXT, -- URL to uploaded GCash receipt
  payment_status payment_status DEFAULT 'pending',
  payment_verified_at TIMESTAMP WITH TIME ZONE,
  payment_verified_by UUID REFERENCES users_profile(id),
  payment_rejection_reason TEXT,
  
  -- Generated document
  document_url TEXT, -- URL to the generated soft copy
  
  -- Timestamps
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  reviewed_by UUID REFERENCES users_profile(id)
);

-- Barangay ID Requests (specific fields for Barangay ID)
CREATE TABLE barangay_id_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES document_requests(id) ON DELETE CASCADE,
  emergency_contact_name TEXT NOT NULL,
  emergency_contact_number TEXT NOT NULL,
  blood_type TEXT,
  occupation TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indigency Certificate Details
CREATE TABLE indigency_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES document_requests(id) ON DELETE CASCADE,
  monthly_income DECIMAL(10,2),
  number_of_dependents INTEGER,
  employment_status TEXT,
  specific_purpose TEXT NOT NULL, -- Why they need indigency certificate
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cedula Details
CREATE TABLE cedula_details (
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

-- Notifications Table
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users_profile(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type notification_type NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- INDEXES for better query performance
-- ============================================

CREATE INDEX idx_users_profile_username ON users_profile(username);
CREATE INDEX idx_users_profile_email ON users_profile(email);
CREATE INDEX idx_users_profile_registration_status ON users_profile(registration_status);
CREATE INDEX idx_users_profile_role ON users_profile(role);
CREATE INDEX idx_document_requests_user_id ON document_requests(user_id);
CREATE INDEX idx_document_requests_status ON document_requests(request_status);
CREATE INDEX idx_document_requests_payment_status ON document_requests(payment_status);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_barangay_id_details_request_id ON barangay_id_details(request_id);
CREATE INDEX idx_indigency_details_request_id ON indigency_details(request_id);
CREATE INDEX idx_cedula_details_request_id ON cedula_details(request_id);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for users_profile updated_at
CREATE TRIGGER update_users_profile_updated_at
BEFORE UPDATE ON users_profile
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Trigger for barangay_config updated_at
CREATE TRIGGER update_barangay_config_updated_at
BEFORE UPDATE ON barangay_config
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Trigger for document_fees updated_at
CREATE TRIGGER update_document_fees_updated_at
BEFORE UPDATE ON document_fees
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Function to create notification on registration approval/rejection
CREATE OR REPLACE FUNCTION notify_registration_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.registration_status != OLD.registration_status THEN
    IF NEW.registration_status = 'approved' THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        NEW.id,
        'Registration Approved',
        'Congratulations! Your registration has been approved. You can now login and request documents.',
        'registration_approved'
      );
    ELSIF NEW.registration_status = 'rejected' THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        NEW.id,
        'Registration Rejected',
        CONCAT('Your registration has been rejected. Reason: ', COALESCE(NEW.rejection_reason, 'No reason provided')),
        'registration_rejected'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for registration status notification
CREATE TRIGGER trigger_registration_notification
AFTER UPDATE ON users_profile
FOR EACH ROW
WHEN (OLD.registration_status IS DISTINCT FROM NEW.registration_status)
EXECUTE FUNCTION notify_registration_status();

-- Function to create notification on document request status change
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

-- Trigger for document request status notification
CREATE TRIGGER trigger_request_notification
AFTER UPDATE ON document_requests
FOR EACH ROW
WHEN (OLD.request_status IS DISTINCT FROM NEW.request_status OR OLD.payment_status IS DISTINCT FROM NEW.payment_status)
EXECUTE FUNCTION notify_request_status();

-- Function to notify admin on new document request
CREATE OR REPLACE FUNCTION notify_admin_new_request()
RETURNS TRIGGER AS $$
DECLARE
  admin_id UUID;
BEGIN
  -- Get all admin users
  FOR admin_id IN SELECT id FROM users_profile WHERE role = 'admin'
  LOOP
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      admin_id,
      'New Document Request',
      CONCAT('A new request for ', REPLACE(NEW.document_type::TEXT, '_', ' '), ' has been submitted.'),
      'request_submitted'
    );
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for notifying admin on new request
CREATE TRIGGER trigger_admin_new_request_notification
AFTER INSERT ON document_requests
FOR EACH ROW
EXECUTE FUNCTION notify_admin_new_request();

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================
-- NOTE: Since we're NOT using Supabase Auth, RLS is DISABLED
-- Security will be handled at the application level
-- Make sure to use proper validation in your Flutter services!
-- ============================================

-- Keep RLS disabled - authentication is handled by the app
-- ALTER TABLE users_profile ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE document_requests ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE barangay_config ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE document_fees ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE barangay_id_details ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE indigency_details ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE cedula_details ENABLE ROW LEVEL SECURITY;

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================
-- NOTE: Since we're NOT using Supabase Auth, RLS is DISABLED
-- Security will be handled at the application level
-- Make sure to use proper validation in your Flutter services!
-- ============================================

-- Keep RLS disabled - authentication is handled by the app
-- ALTER TABLE users_profile ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE document_requests ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE barangay_config ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE document_fees ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE barangay_id_details ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE indigency_details ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE cedula_details ENABLE ROW LEVEL SECURITY;

-- All RLS policies are commented out since we're not using Supabase Auth
-- Security is managed in the application layer

-- ============================================
-- INITIAL DATA (Required Setup)
-- ============================================

-- Insert default document fees (Adjust amounts as needed)
INSERT INTO document_fees (document_type, fee_amount, description) VALUES
  ('barangay_clearance', 50.00, 'Barangay Clearance Fee'),
  ('indigency', 0.00, 'Certificate of Indigency (Free)'),
  ('barangay_id', 100.00, 'Barangay ID Fee'),
  ('cedula', 75.00, 'Cedula/Community Tax Certificate Fee')
ON CONFLICT (document_type) DO NOTHING;

-- Insert default barangay configuration (UPDATE THESE VALUES)
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
-- COMPLETE! 
-- ============================================
-- Don't forget to:
-- 1. Create storage buckets (profile-photos, valid-ids, payment-receipts, documents)
-- 2. Update barangay_config with actual values
-- 3. Create your first admin user and update their role
-- ============================================
