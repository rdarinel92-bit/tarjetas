-- ═══════════════════════════════════════════════════════════════════════════════
-- EJECUTAR DESPUÉS DE CREAR EL USUARIO EN AUTHENTICATION
-- Email: rdarinel992@gmail.com
-- ═══════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
    v_user_id UUID;
    v_rol_id UUID;
BEGIN
    -- Obtener ID del usuario recién creado
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'rdarinel992@gmail.com';
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '❌ Usuario rdarinel992@gmail.com no encontrado. Créalo primero en Authentication → Users';
    END IF;
    
    -- Insertar en tabla usuarios
    INSERT INTO usuarios (id, email, nombre_completo, activo, created_at, updated_at)
    VALUES (v_user_id, 'rdarinel992@gmail.com', 'Robert Darin (Superadmin)', true, NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
        nombre_completo = 'Robert Darin (Superadmin)',
        activo = true,
        updated_at = NOW();
    
    -- Obtener rol superadmin
    SELECT id INTO v_rol_id FROM roles WHERE nombre = 'superadmin';
    
    -- Limpiar y asignar rol
    DELETE FROM usuarios_roles WHERE usuario_id = v_user_id;
    INSERT INTO usuarios_roles (usuario_id, rol_id) VALUES (v_user_id, v_rol_id);
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ SUPERADMIN CONFIGURADO CORRECTAMENTE';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE 'Email: rdarinel992@gmail.com';
    RAISE NOTICE 'Rol: superadmin';
    RAISE NOTICE '';
    RAISE NOTICE '🎉 Ya puedes hacer login en la app!';
END $$;

-- Verificar
SELECT u.email, u.nombre_completo, r.nombre as rol, u.activo
FROM usuarios u
JOIN usuarios_roles ur ON ur.usuario_id = u.id
JOIN roles r ON ur.rol_id = r.id
WHERE u.email = 'rdarinel992@gmail.com';
