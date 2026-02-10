-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Actualizar nombre de la aplicación a UNIKO
-- Cambia todas las referencias de "Robert Darin" a "Uniko"
-- Fecha: 20 de Enero, 2026
-- ═══════════════════════════════════════════════════════════════════════════════

-- Actualizar nombre en negocios principales
UPDATE public.negocios
SET nombre = 'Uniko',
    razon_social = CASE 
        WHEN razon_social LIKE '%Robert Darin%' 
        THEN REPLACE(razon_social, 'Robert Darin', 'Uniko')
        ELSE razon_social
    END
WHERE nombre LIKE '%Robert Darin%';

-- Log del cambio
DO $$
BEGIN
  RAISE NOTICE '✅ Nombre de la aplicación actualizado a UNIKO';
  RAISE NOTICE '📱 Slogan: Tu negocio, simplificado';
END $$;
