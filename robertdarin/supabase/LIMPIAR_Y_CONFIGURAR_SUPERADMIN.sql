-- ═══════════════════════════════════════════════════════════════════════════════
-- LIMPIEZA COMPLETA Y CONFIGURACIÓN SUPERADMIN
-- Email correcto: rdarinel992@gmail.com
-- EJECUTAR EN: Supabase Dashboard → SQL Editor
-- Fecha: 21 Enero 2026
-- ═══════════════════════════════════════════════════════════════════════════════

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║ PASO 1: ELIMINAR USUARIOS DUPLICADOS/INCORRECTOS                             ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- 1A. Eliminar de usuarios_roles los usuarios incorrectos
DELETE FROM usuarios_roles 
WHERE usuario_id IN (
    SELECT id FROM usuarios 
    WHERE email ILIKE '%rdarinel%' 
    AND email != 'rdarinel992@gmail.com'
);

-- 1B. Eliminar de usuarios_negocios los usuarios incorrectos
DELETE FROM usuarios_negocios 
WHERE usuario_id IN (
    SELECT id FROM usuarios 
    WHERE email ILIKE '%rdarinel%' 
    AND email != 'rdarinel992@gmail.com'
);

-- 1C. Eliminar de tabla usuarios los incorrectos
DELETE FROM usuarios 
WHERE email ILIKE '%rdarinel%' 
AND email != 'rdarinel992@gmail.com';

-- 1D. Eliminar de auth.identities los usuarios incorrectos
DELETE FROM auth.identities 
WHERE user_id IN (
    SELECT id FROM auth.users 
    WHERE email ILIKE '%rdarinel%' 
    AND email != 'rdarinel992@gmail.com'
);

-- 1E. Eliminar de auth.users los usuarios incorrectos
DELETE FROM auth.users 
WHERE email ILIKE '%rdarinel%' 
AND email != 'rdarinel992@gmail.com';

RAISE NOTICE '✅ Usuarios duplicados/incorrectos eliminados';

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║ PASO 2: VERIFICAR SI EL USUARIO CORRECTO EXISTE                              ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

DO $$
DECLARE
    v_user_id UUID;
    v_rol_id UUID;
    v_email TEXT := 'rdarinel992@gmail.com';
    v_count INTEGER;
BEGIN
    -- Buscar usuario en auth.users
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE '';
        RAISE NOTICE '═══════════════════════════════════════════════════════════════';
        RAISE NOTICE '⚠️  USUARIO NO EXISTE EN AUTH.USERS';
        RAISE NOTICE '═══════════════════════════════════════════════════════════════';
        RAISE NOTICE '';
        RAISE NOTICE '📌 DEBES CREAR EL USUARIO MANUALMENTE:';
        RAISE NOTICE '';
        RAISE NOTICE '1. Ve a Supabase Dashboard';
        RAISE NOTICE '2. Click en "Authentication" (menú izquierdo)';
        RAISE NOTICE '3. Click en "Users"';
        RAISE NOTICE '4. Click en "Add user" → "Create new user"';
        RAISE NOTICE '5. Email: %', v_email;
        RAISE NOTICE '6. Password: (tu contraseña segura)';
        RAISE NOTICE '7. ✅ Marca "Auto Confirm User"';
        RAISE NOTICE '8. Click "Create user"';
        RAISE NOTICE '';
        RAISE NOTICE 'DESPUÉS DE CREAR EL USUARIO, VUELVE A EJECUTAR ESTE SCRIPT';
        RAISE NOTICE '═══════════════════════════════════════════════════════════════';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Usuario encontrado en auth.users: %', v_user_id;
    
    -- ════════════════════════════════════════════════════════════════════
    -- PASO 3: ASEGURAR EN TABLA USUARIOS
    -- ════════════════════════════════════════════════════════════════════
    INSERT INTO usuarios (id, email, nombre_completo, activo, created_at, updated_at)
    VALUES (v_user_id, v_email, 'Robert Darin (Superadmin)', true, NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        nombre_completo = 'Robert Darin (Superadmin)',
        activo = true,
        updated_at = NOW();
    
    RAISE NOTICE '✅ Usuario configurado en tabla usuarios';
    
    -- ════════════════════════════════════════════════════════════════════
    -- PASO 4: OBTENER O CREAR ROL SUPERADMIN
    -- ════════════════════════════════════════════════════════════════════
    SELECT id INTO v_rol_id FROM roles WHERE nombre = 'superadmin';
    
    IF v_rol_id IS NULL THEN
        INSERT INTO roles (nombre, descripcion, activo, created_at)
        VALUES ('superadmin', 'Super Administrador del Sistema', true, NOW())
        RETURNING id INTO v_rol_id;
        RAISE NOTICE '✅ Rol superadmin creado';
    ELSE
        RAISE NOTICE '✅ Rol superadmin existe: %', v_rol_id;
    END IF;
    
    -- ════════════════════════════════════════════════════════════════════
    -- PASO 5: LIMPIAR ROLES DUPLICADOS Y ASIGNAR SUPERADMIN
    -- ════════════════════════════════════════════════════════════════════
    -- Eliminar cualquier rol duplicado del usuario
    DELETE FROM usuarios_roles WHERE usuario_id = v_user_id;
    
    -- Asignar solo el rol superadmin
    INSERT INTO usuarios_roles (usuario_id, rol_id, created_at)
    VALUES (v_user_id, v_rol_id, NOW());
    
    RAISE NOTICE '✅ Rol superadmin asignado (único)';
    
    -- ════════════════════════════════════════════════════════════════════
    -- RESUMEN FINAL
    -- ════════════════════════════════════════════════════════════════════
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ CONFIGURACIÓN COMPLETADA';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE 'Email: %', v_email;
    RAISE NOTICE 'User ID: %', v_user_id;
    RAISE NOTICE 'Rol: superadmin';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '🎉 Ya puedes hacer login en la app con:';
    RAISE NOTICE '   Email: %', v_email;
    RAISE NOTICE '   Password: (tu contraseña)';
END $$;

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║ VERIFICACIÓN FINAL                                                            ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- Ver todos los usuarios rdarinel que quedaron
SELECT 
    '📋 AUTH.USERS' as tabla,
    id,
    email,
    created_at
FROM auth.users
WHERE email ILIKE '%rdarinel%';

-- Ver en tabla usuarios
SELECT 
    '📋 USUARIOS' as tabla,
    id,
    email,
    nombre_completo,
    activo
FROM usuarios
WHERE email ILIKE '%rdarinel%';

-- Ver roles asignados
SELECT 
    '📋 ROLES ASIGNADOS' as tabla,
    u.email,
    r.nombre as rol
FROM usuarios_roles ur
JOIN usuarios u ON ur.usuario_id = u.id
JOIN roles r ON ur.rol_id = r.id
WHERE u.email ILIKE '%rdarinel%';
