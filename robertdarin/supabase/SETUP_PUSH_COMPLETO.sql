-- ═══════════════════════════════════════════════════════════════════════════════
-- SETUP COMPLETO PUSH NOTIFICATIONS - ROBERT DARIN FINTECH V10.64
-- ═══════════════════════════════════════════════════════════════════════════════
-- EJECUTA ESTO EN SUPABASE SQL EDITOR PARA CONFIGURAR TODO
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 1: Crear tabla dispositivos_fcm si no existe
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.dispositivos_fcm (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL,
    fcm_token TEXT NOT NULL,
    plataforma TEXT DEFAULT 'android',
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(usuario_id, fcm_token)
);

-- Índices para búsqueda rápida
CREATE INDEX IF NOT EXISTS idx_dispositivos_fcm_usuario ON dispositivos_fcm(usuario_id);
CREATE INDEX IF NOT EXISTS idx_dispositivos_fcm_activo ON dispositivos_fcm(activo);

-- RLS
ALTER TABLE dispositivos_fcm ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dispositivos_fcm_authenticated" ON dispositivos_fcm;
CREATE POLICY "dispositivos_fcm_authenticated" ON dispositivos_fcm
    FOR ALL USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 2: Crear tabla permisos_chat_qr si no existe
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.permisos_chat_qr (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID NOT NULL,
    empleado_id UUID,
    tiene_permiso BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE permisos_chat_qr ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "permisos_chat_qr_authenticated" ON permisos_chat_qr;
CREATE POLICY "permisos_chat_qr_authenticated" ON permisos_chat_qr
    FOR ALL USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 3: Crear función del trigger con manejo de errores robusto
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.trigger_send_chat_push()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    req_id bigint;
BEGIN
    -- Solo notificar mensajes de clientes
    IF NEW.emisor_tipo = 'cliente' THEN
        -- Intentar enviar usando net.http_post
        BEGIN
            SELECT net.http_post(
                url := 'https://qtfsxfvxqiihnofrpmmu.supabase.co/functions/v1/send-chat-push',
                body := json_build_object('record', row_to_json(NEW))::jsonb,
                headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0ZnN4ZnZ4cWlpaG5vZnJwbW11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczMjU5MDIsImV4cCI6MjA4MjkwMTkwMn0.D4LrG8FlnqfK0Zhi2Ex0z2UGeoVSr6u1XR2jnxis9Bg"}'::jsonb
            ) INTO req_id;
            
            RAISE LOG 'Push notification enviada para chat %, request_id: %', NEW.id, req_id;
        EXCEPTION WHEN OTHERS THEN
            -- No fallar el INSERT si hay error en push
            RAISE LOG 'Error enviando push notification: %', SQLERRM;
        END;
    END IF;
    
    RETURN NEW;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 4: Crear el trigger
-- ═══════════════════════════════════════════════════════════════════════════════
DROP TRIGGER IF EXISTS on_tarjetas_chat_insert ON tarjetas_chat;

CREATE TRIGGER on_tarjetas_chat_insert
    AFTER INSERT ON tarjetas_chat
    FOR EACH ROW
    EXECUTE FUNCTION trigger_send_chat_push();

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 5: Verificar instalación
-- ═══════════════════════════════════════════════════════════════════════════════
SELECT '✅ Setup completado' as status;

-- Verificar trigger
SELECT 
    '✅ Trigger instalado: ' || tgname as resultado
FROM pg_trigger 
WHERE tgrelid = 'public.tarjetas_chat'::regclass 
  AND tgname = 'on_tarjetas_chat_insert';

-- Verificar tabla dispositivos_fcm
SELECT 
    '✅ Tabla dispositivos_fcm: ' || count(*) || ' dispositivos activos' as resultado
FROM dispositivos_fcm 
WHERE activo = true;

-- Verificar pg_net (IMPORTANTE)
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
        THEN '✅ Extensión pg_net: HABILITADA'
        ELSE '❌ Extensión pg_net: NO HABILITADA - Ve a Database → Extensions y habilítala'
    END as resultado;
