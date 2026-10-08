-- ============================================
-- CREATE INITIAL ADMIN USER
-- ============================================
-- Since we're NOT using Supabase Auth, we store credentials directly
-- Password will be hashed using bcrypt in the application
-- ============================================

-- Enable pgcrypto extension for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create admin user with hashed password
-- Password: Admin@123456
-- Hash generated using: dart generate_admin_hash.dart
INSERT INTO users_profile (
  id,
  username,
  email,
  password_hash,
  full_name,
  address,
  age,
  date_of_birth,
  place_of_birth,
  civil_status,
  gender,
  phone_number,
  profile_photo_url,
  valid_id_url,
  is_approved,
  registration_status,
  role,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'admin',
  'admin@barangay.local',
  '67fb0d79f41794c9:e456c4f916973fa2dc96ad9f3d6e08a29985ad2e9782be69293bb8fe459ab14a',
  'System Administrator',
  'Barangay Hall',
  30,
  '1995-01-01',
  'Metro Manila',
  'Single',
  'Male',
  '09123456789',
  NULL,
  NULL,
  TRUE,
  'approved',
  'admin',
  NOW(),
  NOW()
);

-- ============================================
-- VERIFICATION
-- ============================================
-- Verify the admin user was created:
SELECT 
  id, 
  username, 
  email, 
  full_name, 
  role, 
  is_approved,
  registration_status,
  password_hash
FROM users_profile 
WHERE role = 'admin';

-- ============================================
-- LOGIN CREDENTIALS
-- ============================================
-- Username: admin
-- Email: admin@barangay.local
-- Password: Admin@123456
-- Hash: 67fb0d79f41794c9:e456c4f916973fa2dc96ad9f3d6e08a29985ad2e9782be69293bb8fe459ab14a
-- ============================================
