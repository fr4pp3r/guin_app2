-- ============================================
-- SUPABASE STORAGE BUCKETS SETUP
-- ============================================
-- Run this script in your Supabase SQL Editor to create storage buckets
-- ============================================

-- Create profile-photos bucket (public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-photos',
  'profile-photos',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Create valid-ids bucket (public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'valid-ids',
  'valid-ids',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Create documents bucket (public) for generated PDFs
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documents',
  'documents',
  true,
  10485760, -- 10MB limit
  ARRAY['application/pdf']
) ON CONFLICT (id) DO NOTHING;

-- Create payment-receipts bucket (public) for GCash receipt uploads
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'payment-receipts',
  'payment-receipts',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- ============================================
-- STORAGE POLICIES (RLS Disabled for simplicity)
-- ============================================

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Public Access for profile-photos" ON storage.objects;
DROP POLICY IF EXISTS "Public Access for valid-ids" ON storage.objects;
DROP POLICY IF EXISTS "Public Access for documents" ON storage.objects;
DROP POLICY IF EXISTS "Public Access for payment-receipts" ON storage.objects;

-- Allow all operations on profile-photos bucket
CREATE POLICY "Public Access for profile-photos"
ON storage.objects FOR ALL
USING (bucket_id = 'profile-photos');

-- Allow all operations on valid-ids bucket
CREATE POLICY "Public Access for valid-ids"
ON storage.objects FOR ALL
USING (bucket_id = 'valid-ids');

-- Allow all operations on documents bucket
CREATE POLICY "Public Access for documents"
ON storage.objects FOR ALL
USING (bucket_id = 'documents');

-- Allow all operations on payment-receipts bucket
CREATE POLICY "Public Access for payment-receipts"
ON storage.objects FOR ALL
USING (bucket_id = 'payment-receipts');

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
FROM storage.buckets
WHERE id IN ('profile-photos', 'valid-ids', 'documents', 'payment-receipts');

-- Expected output:
-- | id                | name              | public | file_size_limit | allowed_mime_types                              |
-- |-------------------|-------------------|--------|------------------|-------------------------------------------------|
-- | profile-photos    | profile-photos    | true   | 5242880         | {image/jpeg,image/jpg,image/png,image/webp}     |
-- | valid-ids         | valid-ids         | true   | 5242880         | {image/jpeg,image/jpg,image/png,image/webp}     |
-- | documents         | documents         | true   | 10485760        | {application/pdf}                               |
-- | payment-receipts  | payment-receipts  | true   | 5242880         | {image/jpeg,image/jpg,image/png,image/webp}     |
