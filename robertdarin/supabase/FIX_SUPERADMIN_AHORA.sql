-- ═══════════════════════════════════════════════════════════════════════════════
-- SOLUCIÓN: Crear usuario superadmin con email rdarinel992@gmail.com
-- EJECUTAR EN: Supabase Dashboard → SQL Editor
-- Fecha: 21 Enero 2026
-- ═══════════════════════════════════════════════════════════════════════════════

-- ⚠️ IMPORTANTE: Este script NO puede crear usuarios en auth.users directamente
-- El usuario DEBE registrarse primero en la app o en el Dashboard de Supabase.

-- OPCIÓN A: Si el usuario ya se registró con rdarinel992@gmail.com
-- Ejecuta este script para asignarle el rol superadmin:

DO $$
DECLARE
    v_user_id UUID;
    v_rol_id UUID;
    v_email TEXT := 'rdarinel992@gmail.com';
BEGIN
    -- Buscar usuario en auth.users
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE '❌ Usuario % NO encontrado en auth.users', v_email;
        RAISE NOTICE '';
        RAISE NOTICE '📌 SOLUCIÓN:';
        RAISE NOTICE '1. Ve a Supabase Dashboard → Authentication → Users';
        RAISE NOTICE '2. Click en "Add user" → "Create new user"';
        RAISE NOTICE '3. Email: %', v_email;
        RAISE NOTICE '4. Password: (tu contraseña)';
        RAISE NOTICE '5. Marca "Auto Confirm User"';
        RAISE NOTICE '6. Vuelve a ejecutar este script';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Usuario encontrado: %', v_user_id;
    
    -- Asegurar registro en tabla usuarios
    INSERT INTO usuarios (id, email, nombre_completo, activo, created_at, updated_at)
    VALUES (v_user_id, v_email, 'Super Administrador', true, NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        activo = true,
        updated_at = NOW();
    
    RAISE NOTICE '✅ Usuario agregado/actualizado en tabla usuarios';
    
    -- Obtener rol superadmin
    SELECT id INTO v_rol_id FROM roles WHERE nombre = 'superadmin';
    
    IF v_rol_id IS NULL THEN
        RAISE NOTICE '❌ Rol superadmin no existe. Creándolo...';
        INSERT INTO roles (nombre, descripcion, activo)
        VALUES ('superadmin', 'Administrador del sistema', true)
        RETURNING id INTO v_rol_id;
    END IF;
    
    -- Asignar rol
    INSERT INTO usuarios_roles (usuario_id, rol_id)
    VALUES (v_user_id, v_rol_id)
    ON CONFLICT (usuario_id, rol_id) DO NOTHING;
    
    RAISE NOTICE '✅ Rol superadmin asignado';
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ CONFIGURACIÓN COMPLETADA PARA %', v_email;
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
END $$;

-- Verificar resultado final
SELECT 
    'RESULTADO FINAL' as verificacion,
    u.email,
    u.nombre_completo,
    r.nombre as rol,
    u.activo
FROM usuarios u
LEFT JOIN usuarios_roles ur ON ur.usuario_id = u.id
LEFT JOIN roles r ON ur.rol_id = r.id
WHERE u.email ILIKE '%rdarinel%';
