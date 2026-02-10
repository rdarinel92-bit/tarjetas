-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN V10.64: MEJORAS EDITOR DE TARJETAS
-- Fecha: 2026-02-09
-- Nuevas funcionalidades: Logo, plantillas, fuentes, gradientes, estadísticas, etc.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 1: NUEVOS CAMPOS PARA TARJETAS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Agregar campo para fuente tipográfica
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS font VARCHAR(50) DEFAULT 'poppins';

-- Agregar campo para tipo de gradiente
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS gradient_type VARCHAR(30) DEFAULT 'none'
    CHECK (gradient_type IN ('none', 'linear', 'radial', 'diagonal', 'sunset', 'ocean', 'forest'));

-- Agregar campo para textura de fondo
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS background_texture VARCHAR(50) DEFAULT 'none'
    CHECK (background_texture IN ('none', 'marble', 'wood', 'metal', 'leather', 'carbon', 'fabric', 'paper'));

-- Agregar campo para efecto de texto
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS text_effect VARCHAR(30) DEFAULT 'none'
    CHECK (text_effect IN ('none', 'shadow', 'glow', 'outline', 'emboss', 'gold'));

-- Agregar campo para layout
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS layout VARCHAR(30) DEFAULT 'horizontal'
    CHECK (layout IN ('horizontal', 'vertical', 'centered', 'split', 'minimal', 'bold'));

-- Redes sociales adicionales
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS youtube TEXT;
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS sitio_web TEXT;

-- Ubicación GPS
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS latitud DOUBLE PRECISION;
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS longitud DOUBLE PRECISION;

-- Sistema de promociones temporales
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS promocion_activa BOOLEAN DEFAULT FALSE;
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS promocion_texto TEXT;
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS promocion_descuento INTEGER;
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS promocion_fecha_inicio DATE;
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS promocion_fecha_fin DATE;

-- Sistema de citas/agendar
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS permite_agendar BOOLEAN DEFAULT FALSE;
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS calendario_url TEXT;

-- Múltiples destinos QR
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS qr_destinos JSONB DEFAULT '[]'::JSONB;
-- Formato: [{"tipo": "whatsapp", "valor": "+52...", "etiqueta": "Ventas"}, ...]

-- Versiones/Historial
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;
ALTER TABLE tarjetas_servicio ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES tarjetas_servicio(id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 2: ACTUALIZAR CONSTRAINT DE TEMPLATE (más opciones)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Primero eliminar constraint existente si existe
DO $$
BEGIN
    ALTER TABLE tarjetas_servicio DROP CONSTRAINT IF EXISTS tarjetas_servicio_template_check;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Agregar nuevo constraint con más plantillas
ALTER TABLE tarjetas_servicio ADD CONSTRAINT tarjetas_servicio_template_check 
    CHECK (template IN (
        -- Básicos
        'profesional', 'moderno', 'minimalista', 'clasico', 'premium', 'corporativo',
        -- Nuevos
        'elegante', 'creativo', 'tech', 'nature', 'luxury', 'retro', 'neon', 'gradient'
    ));

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 3: TABLA PARA ESTADÍSTICAS DETALLADAS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tarjetas_servicio_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_servicio(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    
    -- Contadores diarios
    escaneos INTEGER DEFAULT 0,
    clicks_whatsapp INTEGER DEFAULT 0,
    clicks_llamada INTEGER DEFAULT 0,
    clicks_email INTEGER DEFAULT 0,
    clicks_ubicacion INTEGER DEFAULT 0,
    clicks_redes INTEGER DEFAULT 0,
    formularios_enviados INTEGER DEFAULT 0,
    
    -- Dispositivos
    android_count INTEGER DEFAULT 0,
    ios_count INTEGER DEFAULT 0,
    web_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(tarjeta_id, fecha)
);

-- Índices para estadísticas
CREATE INDEX IF NOT EXISTS idx_ts_stats_tarjeta ON tarjetas_servicio_stats(tarjeta_id);
CREATE INDEX IF NOT EXISTS idx_ts_stats_fecha ON tarjetas_servicio_stats(fecha DESC);

-- RLS para estadísticas
ALTER TABLE tarjetas_servicio_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stats_select_authenticated" ON tarjetas_servicio_stats;
CREATE POLICY "stats_select_authenticated" ON tarjetas_servicio_stats 
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "stats_all_authenticated" ON tarjetas_servicio_stats;
CREATE POLICY "stats_all_authenticated" ON tarjetas_servicio_stats 
    FOR ALL USING (auth.role() = 'authenticated');

-- Permitir inserciones anónimas (para tracking desde web)
DROP POLICY IF EXISTS "stats_insert_anon" ON tarjetas_servicio_stats;
CREATE POLICY "stats_insert_anon" ON tarjetas_servicio_stats 
    FOR INSERT WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 4: TABLA PARA HISTORIAL DE VERSIONES
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tarjetas_servicio_versiones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_servicio(id) ON DELETE CASCADE,
    version INTEGER NOT NULL,
    snapshot JSONB NOT NULL,  -- Copia completa del estado en ese momento
    motivo TEXT,  -- Ej: "Cambio de colores", "Actualización de servicios"
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_ts_versiones_tarjeta ON tarjetas_servicio_versiones(tarjeta_id);
CREATE INDEX IF NOT EXISTS idx_ts_versiones_version ON tarjetas_servicio_versiones(version DESC);

-- RLS
ALTER TABLE tarjetas_servicio_versiones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "versiones_authenticated" ON tarjetas_servicio_versiones;
CREATE POLICY "versiones_authenticated" ON tarjetas_servicio_versiones 
    FOR ALL USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 5: FUNCIÓN PARA INCREMENTAR ESTADÍSTICAS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION incrementar_stat_tarjeta(
    p_tarjeta_id UUID,
    p_tipo VARCHAR,
    p_dispositivo VARCHAR DEFAULT 'web'
) RETURNS VOID AS $$
BEGIN
    -- Insertar o actualizar stats del día
    INSERT INTO tarjetas_servicio_stats (tarjeta_id, fecha, escaneos)
    VALUES (p_tarjeta_id, CURRENT_DATE, 0)
    ON CONFLICT (tarjeta_id, fecha) DO NOTHING;
    
    -- Incrementar contador específico
    CASE p_tipo
        WHEN 'escaneo' THEN
            UPDATE tarjetas_servicio_stats SET escaneos = escaneos + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        WHEN 'whatsapp' THEN
            UPDATE tarjetas_servicio_stats SET clicks_whatsapp = clicks_whatsapp + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        WHEN 'llamada' THEN
            UPDATE tarjetas_servicio_stats SET clicks_llamada = clicks_llamada + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        WHEN 'email' THEN
            UPDATE tarjetas_servicio_stats SET clicks_email = clicks_email + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        WHEN 'ubicacion' THEN
            UPDATE tarjetas_servicio_stats SET clicks_ubicacion = clicks_ubicacion + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        WHEN 'redes' THEN
            UPDATE tarjetas_servicio_stats SET clicks_redes = clicks_redes + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        WHEN 'formulario' THEN
            UPDATE tarjetas_servicio_stats SET formularios_enviados = formularios_enviados + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        ELSE
            NULL;
    END CASE;
    
    -- Incrementar contador de dispositivo
    CASE p_dispositivo
        WHEN 'android' THEN
            UPDATE tarjetas_servicio_stats SET android_count = android_count + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        WHEN 'ios' THEN
            UPDATE tarjetas_servicio_stats SET ios_count = ios_count + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        WHEN 'web' THEN
            UPDATE tarjetas_servicio_stats SET web_count = web_count + 1 WHERE tarjeta_id = p_tarjeta_id AND fecha = CURRENT_DATE;
        ELSE
            NULL;
    END CASE;
    
    -- Actualizar contador total en tarjeta
    IF p_tipo = 'escaneo' THEN
        UPDATE tarjetas_servicio 
        SET escaneos_total = escaneos_total + 1, 
            ultimo_escaneo = NOW()
        WHERE id = p_tarjeta_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 6: FUNCIÓN PARA GUARDAR VERSIÓN ANTES DE EDITAR
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION guardar_version_tarjeta()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo guardar si hubo cambios significativos
    IF (OLD.nombre_negocio IS DISTINCT FROM NEW.nombre_negocio OR
        OLD.color_primario IS DISTINCT FROM NEW.color_primario OR
        OLD.template IS DISTINCT FROM NEW.template OR
        OLD.servicios IS DISTINCT FROM NEW.servicios) THEN
        
        INSERT INTO tarjetas_servicio_versiones (tarjeta_id, version, snapshot, motivo, created_by)
        VALUES (
            OLD.id,
            COALESCE(OLD.version, 1),
            to_jsonb(OLD),
            'Auto-guardado antes de edición',
            auth.uid()
        );
        
        -- Incrementar versión
        NEW.version := COALESCE(OLD.version, 1) + 1;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear trigger para auto-guardar versiones
DROP TRIGGER IF EXISTS tr_tarjeta_version ON tarjetas_servicio;
CREATE TRIGGER tr_tarjeta_version
    BEFORE UPDATE ON tarjetas_servicio
    FOR EACH ROW
    EXECUTE FUNCTION guardar_version_tarjeta();

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 7: BUCKET DE STORAGE PARA LOGOS
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('tarjetas-logos', 'tarjetas-logos', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'])
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'];

-- Políticas de storage para logos
DROP POLICY IF EXISTS "logos_public_read" ON storage.objects;
CREATE POLICY "logos_public_read" ON storage.objects 
    FOR SELECT USING (bucket_id = 'tarjetas-logos');

DROP POLICY IF EXISTS "logos_auth_upload" ON storage.objects;
CREATE POLICY "logos_auth_upload" ON storage.objects 
    FOR INSERT WITH CHECK (bucket_id = 'tarjetas-logos' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "logos_auth_update" ON storage.objects;
CREATE POLICY "logos_auth_update" ON storage.objects 
    FOR UPDATE USING (bucket_id = 'tarjetas-logos' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "logos_auth_delete" ON storage.objects;
CREATE POLICY "logos_auth_delete" ON storage.objects 
    FOR DELETE USING (bucket_id = 'tarjetas-logos' AND auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════════
-- FIN MIGRACIÓN V10.64
-- ═══════════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE 'MIGRACIÓN V10.64 COMPLETADA: Mejoras Editor Tarjetas';
    RAISE NOTICE '- Nuevos campos: font, gradient, texture, effects, layout';
    RAISE NOTICE '- Promociones temporales con fechas';
    RAISE NOTICE '- Sistema de estadísticas detalladas';
    RAISE NOTICE '- Historial de versiones automático';
    RAISE NOTICE '- Bucket de storage para logos';
    RAISE NOTICE '- 14 plantillas de diseño disponibles';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
END $$;
