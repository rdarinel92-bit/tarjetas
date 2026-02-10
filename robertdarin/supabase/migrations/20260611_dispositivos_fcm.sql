-- ══════════════════════════════════════════════════════════════════════════════
-- DISPOSITIVOS FCM - Para Push Notifications reales
-- V10.56 - Enero 2026
-- ══════════════════════════════════════════════════════════════════════════════

-- Tabla para guardar tokens FCM de dispositivos
CREATE TABLE IF NOT EXISTS dispositivos_fcm (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    plataforma TEXT DEFAULT 'android',
    modelo_dispositivo TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(usuario_id, fcm_token)
);

-- Índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_dispositivos_fcm_usuario ON dispositivos_fcm(usuario_id);
CREATE INDEX IF NOT EXISTS idx_dispositivos_fcm_activo ON dispositivos_fcm(activo) WHERE activo = true;

-- RLS
ALTER TABLE dispositivos_fcm ENABLE ROW LEVEL SECURITY;

-- Política: usuarios autenticados pueden gestionar sus propios dispositivos
DROP POLICY IF EXISTS "dispositivos_fcm_usuario_select" ON dispositivos_fcm;
CREATE POLICY "dispositivos_fcm_usuario_select" ON dispositivos_fcm
    FOR SELECT USING (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "dispositivos_fcm_usuario_insert" ON dispositivos_fcm;
CREATE POLICY "dispositivos_fcm_usuario_insert" ON dispositivos_fcm
    FOR INSERT WITH CHECK (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "dispositivos_fcm_usuario_update" ON dispositivos_fcm;
CREATE POLICY "dispositivos_fcm_usuario_update" ON dispositivos_fcm
    FOR UPDATE USING (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "dispositivos_fcm_usuario_delete" ON dispositivos_fcm;
CREATE POLICY "dispositivos_fcm_usuario_delete" ON dispositivos_fcm
    FOR DELETE USING (auth.uid() = usuario_id);

-- Comentario descriptivo
COMMENT ON TABLE dispositivos_fcm IS 'Tokens FCM de dispositivos para push notifications - V10.56';
