-- Fix documents bucket to be public
UPDATE storage.buckets 
SET public = true 
WHERE id = 'documents';

-- Verify the change
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'documents';
