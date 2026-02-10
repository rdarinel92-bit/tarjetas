-- Migration: create storage bucket for climas equipment photos
-- Date: 2026-01-25
-- Description: bucket + policies for climas_equipos images

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'climas_equipos',
    'climas_equipos',
    true,
    5242880, -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Public read
DROP POLICY IF EXISTS "climas_equipos_public_read" ON storage.objects;
CREATE POLICY "climas_equipos_public_read"
ON storage.objects FOR SELECT
USING (bucket_id = 'climas_equipos');

-- Authenticated upload
DROP POLICY IF EXISTS "climas_equipos_auth_upload" ON storage.objects;
CREATE POLICY "climas_equipos_auth_upload"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'climas_equipos'
  AND auth.role() = 'authenticated'
);

-- Authenticated delete
DROP POLICY IF EXISTS "climas_equipos_auth_delete" ON storage.objects;
CREATE POLICY "climas_equipos_auth_delete"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'climas_equipos'
  AND auth.role() = 'authenticated'
);
