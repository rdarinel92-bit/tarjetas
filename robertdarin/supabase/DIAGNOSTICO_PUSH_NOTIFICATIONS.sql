-- ═══════════════════════════════════════════════════════════════════════════════
-- DIAGNÓSTICO COMPLETO - PUSH NOTIFICATIONS CHAT QR
-- Robert Darin Fintech V10.64
-- Ejecuta CADA sección por separado en Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 1: VERIFICAR EXTENSIÓN pg_net (CRÍTICO)
-- Esta extensión permite hacer llamadas HTTP desde triggers
-- ═══════════════════════════════════════════════════════════════════════════════
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_net';
-- Si retorna 0 filas, la extensión NO está instalada. Ve a:
-- Database → Extensions → Busca "pg_net" → Habilita

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 2: VERIFICAR TRIGGER EXISTE
-- ═══════════════════════════════════════════════════════════════════════════════
SELECT 
    t.tgname as trigger_name,
    t.tgrelid::regclass as table_name,
    p.proname as function_name,
    CASE WHEN t.tgenabled = 'O' THEN 'ENABLED' ELSE 'DISABLED' END as status
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgrelid = 'public.tarjetas_chat'::regclass
  AND NOT t.tgisinternal;
-- Si retorna 0 filas, el trigger NO existe. Ejecuta el PASO 7.

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 3: VERIFICAR TABLA dispositivos_fcm
-- ═══════════════════════════════════════════════════════════════════════════════
SELECT count(*) as total_tokens FROM dispositivos_fcm WHERE activo = true;

-- Ver tokens actuales:
SELECT 
    d.usuario_id,
    u.email,
    d.fcm_token,
    d.plataforma,
    d.activo,
    d.created_at
FROM dispositivos_fcm d
LEFT JOIN auth.users u ON d.usuario_id = u.id
WHERE d.activo = true
ORDER BY d.created_at DESC;
-- Si tu email no aparece aquí, el token no se guardó al hacer login.
-- Solución: Cerrar sesión y volver a iniciar sesión en la app.

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 4: VERIFICAR NEGOCIO TIENE owner_email CORRECTO
-- ═══════════════════════════════════════════════════════════════════════════════
SELECT 
    n.id,
    n.nombre,
    n.owner_email,
    u.id as usuario_id
FROM negocios n
LEFT JOIN auth.users u ON n.owner_email = u.email;
-- El owner_email debe coincidir con un usuario en auth.users

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 5: VER ÚLTIMOS MENSAJES DE CHAT
-- ═══════════════════════════════════════════════════════════════════════════════
SELECT 
    id,
    tarjeta_id,
    negocio_id,
    emisor_tipo,
    emisor_nombre,
    LEFT(mensaje, 50) as mensaje,
    created_at
FROM tarjetas_chat 
ORDER BY created_at DESC 
LIMIT 10;
-- Nota: Solo mensajes con emisor_tipo = 'cliente' activan notificaciones

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 6: VERIFICAR permisos_chat_qr (OPCIONAL - empleados adicionales)
-- ═══════════════════════════════════════════════════════════════════════════════
SELECT 
    p.negocio_id,
    n.nombre as negocio,
    p.empleado_id,
    e.nombre as empleado,
    p.tiene_permiso
FROM permisos_chat_qr p
LEFT JOIN negocios n ON p.negocio_id = n.id
LEFT JOIN empleados e ON p.empleado_id = e.id
WHERE p.tiene_permiso = true;
-- Esta tabla es para empleados además del dueño. El dueño siempre recibe.

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 7: CREAR TRIGGER SI NO EXISTE (EJECUTAR SI FALTA)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Primero habilita pg_net desde el Dashboard: Database → Extensions → pg_net
-- Luego ejecuta:

/*
-- Eliminar función anterior si existe
DROP FUNCTION IF EXISTS public.trigger_send_chat_push() CASCADE;

-- Crear la función del trigger
CREATE OR REPLACE FUNCTION public.trigger_send_chat_push()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public, extensions
LANGUAGE plpgsql
AS $$
BEGIN
  -- Solo notificar mensajes de clientes
  IF NEW.emisor_tipo = 'cliente' THEN
    PERFORM extensions.http_post(
      url := 'https://qtfsxfvxqiihnofrpmmu.supabase.co/functions/v1/send-chat-push',
      body := json_build_object('record', row_to_json(NEW))::text,
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0ZnN4ZnZ4cWlpaG5vZnJwbW11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczMjU5MDIsImV4cCI6MjA4MjkwMTkwMn0.D4LrG8FlnqfK0Zhi2Ex0z2UGeoVSr6u1XR2jnxis9Bg"}'::jsonb
    );
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- No fallar si hay error, solo loguear
  RAISE WARNING 'Error en trigger_send_chat_push: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Crear el trigger
DROP TRIGGER IF EXISTS on_tarjetas_chat_insert ON tarjetas_chat;
CREATE TRIGGER on_tarjetas_chat_insert
  AFTER INSERT ON tarjetas_chat
  FOR EACH ROW
  EXECUTE FUNCTION trigger_send_chat_push();
  
SELECT 'Trigger creado exitosamente' as resultado;
*/

-- ═══════════════════════════════════════════════════════════════════════════════
-- PASO 8: PROBAR MANUALMENTE (SIMULAR MENSAJE DE CLIENTE)
-- ═══════════════════════════════════════════════════════════════════════════════
/*
-- Reemplaza los IDs con IDs reales de tu base de datos
INSERT INTO tarjetas_chat (
    tarjeta_id,
    negocio_id, 
    emisor_tipo,
    emisor_nombre,
    mensaje
) VALUES (
    'REEMPLAZA-CON-TARJETA-ID',
    'REEMPLAZA-CON-NEGOCIO-ID',
    'cliente',
    'Cliente Prueba',
    'Mensaje de prueba para verificar push notification'
);
*/
