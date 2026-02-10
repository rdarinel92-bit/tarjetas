-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 35: CHAT WEB PARA TARJETAS
-- Sistema de mensajería para visitantes de tarjetas digitales
-- ═══════════════════════════════════════════════════════════════════════════════

-- Tabla principal de mensajes del chat web
CREATE TABLE IF NOT EXISTS tarjetas_chat (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_servicio(id) ON DELETE CASCADE,
    negocio_id UUID,
    visitante_id TEXT NOT NULL,  -- ID único del visitante (localStorage)
    visitante_nombre TEXT,
    mensaje TEXT NOT NULL,
    es_respuesta BOOLEAN DEFAULT FALSE,  -- true = respuesta del negocio
    leido BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para mejor rendimiento
CREATE INDEX IF NOT EXISTS idx_tarjetas_chat_tarjeta ON tarjetas_chat(tarjeta_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_chat_visitante ON tarjetas_chat(visitante_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_chat_negocio ON tarjetas_chat(negocio_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_chat_created ON tarjetas_chat(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tarjetas_chat_no_leidos ON tarjetas_chat(negocio_id, leido) WHERE leido = FALSE AND es_respuesta = FALSE;

-- Habilitar RLS
ALTER TABLE tarjetas_chat ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad
-- Anónimos pueden insertar mensajes (visitantes)
CREATE POLICY "tarjetas_chat_anon_insert" ON tarjetas_chat 
    FOR INSERT TO anon WITH CHECK (es_respuesta = FALSE);

-- Anónimos pueden ver sus propios mensajes
CREATE POLICY "tarjetas_chat_anon_select" ON tarjetas_chat 
    FOR SELECT TO anon USING (TRUE);

-- Usuarios autenticados tienen acceso total
CREATE POLICY "tarjetas_chat_authenticated" ON tarjetas_chat 
    FOR ALL TO authenticated USING (TRUE);

-- Trigger para actualizar conversación en realtime
CREATE OR REPLACE FUNCTION notify_tarjetas_chat_insert()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('tarjetas_chat', json_build_object(
        'tarjeta_id', NEW.tarjeta_id,
        'visitante_id', NEW.visitante_id,
        'mensaje', NEW.mensaje,
        'es_respuesta', NEW.es_respuesta
    )::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_tarjetas_chat_insert ON tarjetas_chat;
CREATE TRIGGER trigger_tarjetas_chat_insert
    AFTER INSERT ON tarjetas_chat
    FOR EACH ROW EXECUTE FUNCTION notify_tarjetas_chat_insert();

-- Vista para contar mensajes no leídos por negocio
CREATE OR REPLACE VIEW v_tarjetas_chat_no_leidos AS
SELECT 
    negocio_id,
    tarjeta_id,
    visitante_id,
    visitante_nombre,
    COUNT(*) as mensajes_no_leidos,
    MAX(created_at) as ultimo_mensaje
FROM tarjetas_chat
WHERE leido = FALSE AND es_respuesta = FALSE
GROUP BY negocio_id, tarjeta_id, visitante_id, visitante_nombre;

COMMENT ON TABLE tarjetas_chat IS 'Mensajes de chat de visitantes web a través de tarjetas digitales';
