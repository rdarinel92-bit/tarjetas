-- ═══════════════════════════════════════════════════════════════════════════════
-- DIAGNÓSTICO RÁPIDO - CHAT TARJETAS QR
-- Ejecuta CADA QUERY por separado en Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. ¿HAY MENSAJES EN LA TABLA?
SELECT count(*) as total_mensajes FROM tarjetas_chat;

-- 2. VER LOS ÚLTIMOS 10 MENSAJES
SELECT 
    id,
    tarjeta_id,
    negocio_id,
    visitante_nombre,
    LEFT(mensaje, 50) as mensaje,
    es_respuesta,
    created_at
FROM tarjetas_chat 
ORDER BY created_at DESC 
LIMIT 10;

-- 3. VERIFICAR POLÍTICAS RLS
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename = 'tarjetas_chat';

-- 4. VERIFICAR TU USUARIO
SELECT id, email, created_at FROM auth.users WHERE email ILIKE '%rdarinel%';

-- 5. VERIFICAR NEGOCIOS DEL USUARIO
SELECT 
    n.id as negocio_id,
    n.nombre,
    n.owner_email
FROM negocios n
WHERE n.activo = true
ORDER BY n.created_at DESC
LIMIT 10;

-- 6. SI NO HAY POLÍTICAS, CREARLAS:
/*
-- Primero verificar RLS está activado
ALTER TABLE tarjetas_chat ENABLE ROW LEVEL SECURITY;

-- Política para visitantes anónimos (web) - solo INSERT de mensajes no-respuesta
DROP POLICY IF EXISTS tarjetas_chat_anon_insert ON tarjetas_chat;
CREATE POLICY tarjetas_chat_anon_insert ON tarjetas_chat 
    FOR INSERT TO anon 
    WITH CHECK (es_respuesta = FALSE);

-- Política para visitantes anónimos - SELECT limitado
DROP POLICY IF EXISTS tarjetas_chat_anon_select ON tarjetas_chat;
CREATE POLICY tarjetas_chat_anon_select ON tarjetas_chat 
    FOR SELECT TO anon 
    USING (TRUE);

-- Política para usuarios autenticados - acceso total
DROP POLICY IF EXISTS tarjetas_chat_authenticated ON tarjetas_chat;
CREATE POLICY tarjetas_chat_authenticated ON tarjetas_chat 
    FOR ALL TO authenticated 
    USING (TRUE);
*/

-- 7. INSERTAR UN MENSAJE DE PRUEBA (para verificar que funciona)
/*
INSERT INTO tarjetas_chat (
    tarjeta_id,
    negocio_id,
    visitante_id,
    visitante_nombre,
    mensaje,
    es_respuesta
) VALUES (
    (SELECT id FROM tarjetas_servicio LIMIT 1),
    (SELECT negocio_id FROM tarjetas_servicio LIMIT 1),
    'test-visitor-123',
    'Visitante Prueba',
    'Mensaje de prueba desde SQL',
    false
) RETURNING *;
*/
