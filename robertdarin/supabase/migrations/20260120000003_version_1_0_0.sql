-- ============================================
-- MIGRACIÓN: Actualizar versión a 1.0.0
-- Fecha: 2026-01-20
-- Descripción: Actualiza la versión del sistema a 1.0.0
-- ============================================

-- Actualizar versión en configuracion_global
UPDATE public.configuracion_global 
SET version = '1.0.0', 
    updated_at = NOW() 
WHERE id = '86330fd5-4fd9-4d6c-81a0-577f9c03fc00';

-- Verificar actualización
DO $$
DECLARE
  v_version TEXT;
BEGIN
  SELECT version INTO v_version FROM public.configuracion_global LIMIT 1;
  RAISE NOTICE 'Versión actualizada a: %', v_version;
END $$;
