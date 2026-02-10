-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Limpiar duplicados y configurar superadmin único
-- Email correcto: rdarinel992@gmail.com
-- Fecha: 21 Enero 2026
-- ═══════════════════════════════════════════════════════════════════════════════

-- PASO 1: Eliminar usuarios duplicados/incorrectos de todas las tablas relacionadas

-- 1A. Eliminar de usuarios_roles
DELETE FROM usuarios_roles 
WHERE usuario_id IN (
    SELECT id FROM usuarios 
    WHERE email ILIKE '%rdarinel%' 
    AND email != 'rdarinel992@gmail.com'
);

-- 1B. Eliminar de usuarios_negocios
DELETE FROM usuarios_negocios 
WHERE usuario_id IN (
    SELECT id FROM usuarios 
    WHERE email ILIKE '%rdarinel%' 
    AND email != 'rdarinel992@gmail.com'
);

-- 1C. Eliminar de tabla usuarios
DELETE FROM usuarios 
WHERE email ILIKE '%rdarinel%' 
AND email != 'rdarinel992@gmail.com';

-- PASO 2: Configurar superadmin si existe en auth.users
DO $$
DECLARE
    v_user_id UUID;
    v_rol_id UUID;
    v_email TEXT := 'rdarinel992@gmail.com';
BEGIN
    -- Buscar usuario en auth.users
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
    
    IF v_user_id IS NOT NULL THEN
        -- Asegurar en tabla usuarios
        INSERT INTO usuarios (id, email, nombre_completo, activo, created_at, updated_at)
        VALUES (v_user_id, v_email, 'Robert Darin (Superadmin)', true, NOW(), NOW())
        ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            nombre_completo = 'Robert Darin (Superadmin)',
            activo = true,
            updated_at = NOW();
        
        -- Obtener rol superadmin
        SELECT id INTO v_rol_id FROM roles WHERE nombre = 'superadmin';
        
        IF v_rol_id IS NOT NULL THEN
            -- Limpiar roles existentes y asignar superadmin
            DELETE FROM usuarios_roles WHERE usuario_id = v_user_id;
            INSERT INTO usuarios_roles (usuario_id, rol_id, created_at)
            VALUES (v_user_id, v_rol_id, NOW());
            
            RAISE NOTICE '✅ Superadmin % configurado correctamente', v_email;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ Usuario % no existe en auth.users - crear manualmente', v_email;
    END IF;
END $$;
