-- ═══════════════════════════════════════════════════════════════════════════════
-- Migración: Crear bucket de storage para fondos de pantalla
-- Fecha: 2026-01-14
-- Descripción: Configura el bucket de Supabase Storage para wallpapers de la app
-- ═══════════════════════════════════════════════════════════════════════════════

-- Crear bucket para fondos de pantalla si no existe
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'fondos',
    'fondos',
    true,
    5242880, -- 5MB límite
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Política para permitir lectura pública de fondos
DROP POLICY IF EXISTS "fondos_public_read" ON storage.objects;
CREATE POLICY "fondos_public_read" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'fondos');

-- Política para permitir que usuarios autenticados suban fondos
DROP POLICY IF EXISTS "fondos_auth_upload" ON storage.objects;
CREATE POLICY "fondos_auth_upload" 
ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'fondos' 
    AND auth.role() = 'authenticated'
);

-- Política para permitir que superadmins eliminen fondos
DROP POLICY IF EXISTS "fondos_superadmin_delete" ON storage.objects;
CREATE POLICY "fondos_superadmin_delete" 
ON storage.objects FOR DELETE 
USING (
    bucket_id = 'fondos' 
    AND auth.role() = 'authenticated'
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- Agregar campos adicionales a tarjetas_digitales si no existen
-- ═══════════════════════════════════════════════════════════════════════════════

-- Campo para registrar quién bloqueó la tarjeta
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tarjetas_digitales' AND column_name = 'bloqueada_por'
    ) THEN
        ALTER TABLE tarjetas_digitales ADD COLUMN bloqueada_por UUID REFERENCES usuarios(id);
    END IF;
END $$;

-- Campo para fecha de bloqueo
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tarjetas_digitales' AND column_name = 'fecha_bloqueo'
    ) THEN
        ALTER TABLE tarjetas_digitales ADD COLUMN fecha_bloqueo TIMESTAMPTZ;
    END IF;
END $$;

-- Campo para últimos 4 dígitos (para mostrar en UI)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tarjetas_digitales' AND column_name = 'ultimos_cuatro'
    ) THEN
        ALTER TABLE tarjetas_digitales ADD COLUMN ultimos_cuatro VARCHAR(4);
    END IF;
END $$;

-- Índice para búsqueda rápida
CREATE INDEX IF NOT EXISTS idx_tarjetas_ultimos_cuatro ON tarjetas_digitales(ultimos_cuatro);
CREATE INDEX IF NOT EXISTS idx_tarjetas_estado ON tarjetas_digitales(estado);

-- ═══════════════════════════════════════════════════════════════════════════════
-- Verificación
-- ═══════════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
    RAISE NOTICE '✅ Bucket de fondos configurado correctamente';
    RAISE NOTICE '✅ Campos de bloqueo de tarjetas agregados';
END $$;
