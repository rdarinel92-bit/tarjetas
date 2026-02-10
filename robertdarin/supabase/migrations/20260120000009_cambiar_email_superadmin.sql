-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Cambiar email del superadministrador
-- De: rdarinel92@gmail.com → A: rdarinel992@gmail.com
-- Fecha: 20 de Enero, 2026
-- ═══════════════════════════════════════════════════════════════════════════════

-- IMPORTANTE: Actualizar en auth.users (tabla de autenticación de Supabase)
UPDATE auth.users 
SET email = 'rdarinel992@gmail.com',
    email_confirmed_at = NOW()
WHERE email = 'rdarinel92@gmail.com';

-- Actualizar en tabla de usuarios si existe referencia
UPDATE public.usuarios 
SET email = 'rdarinel992@gmail.com'
WHERE email = 'rdarinel92@gmail.com';

-- Actualizar en tabla de empleados si existe referencia  
UPDATE public.empleados 
SET email = 'rdarinel992@gmail.com'
WHERE email = 'rdarinel92@gmail.com';

-- Log del cambio
DO $$
BEGIN
  RAISE NOTICE '✅ Email de superadmin actualizado a rdarinel992@gmail.com';
END $$;
