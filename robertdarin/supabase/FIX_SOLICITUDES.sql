-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX: Permitir campos opcionales en tarjetas_servicio_solicitudes
-- Ejecutar en Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════════

-- Hacer nombre y telefono opcionales (algunos formularios no los tienen)
ALTER TABLE tarjetas_servicio_solicitudes 
ALTER COLUMN nombre DROP NOT NULL;

ALTER TABLE tarjetas_servicio_solicitudes 
ALTER COLUMN telefono DROP NOT NULL;

-- Verificar políticas de inserción para anónimos
DROP POLICY IF EXISTS tarjetas_servicio_solicitudes_anon_insert ON tarjetas_servicio_solicitudes;
CREATE POLICY tarjetas_servicio_solicitudes_anon_insert ON tarjetas_servicio_solicitudes 
    FOR INSERT TO anon WITH CHECK (true);

-- También permitir SELECT para que puedan ver si se guardó
DROP POLICY IF EXISTS tarjetas_servicio_solicitudes_anon_select ON tarjetas_servicio_solicitudes;
CREATE POLICY tarjetas_servicio_solicitudes_anon_select ON tarjetas_servicio_solicitudes 
    FOR SELECT TO anon USING (true);

SELECT '✅ Tabla tarjetas_servicio_solicitudes actualizada' as resultado;
