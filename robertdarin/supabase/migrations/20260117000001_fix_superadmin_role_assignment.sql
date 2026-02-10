-- ============================================================================
-- MIGRACIÓN: Asignar rol de superadmin al usuario principal
-- Fecha: 2026-01-17
-- Problema: La tabla usuarios_roles está vacía, la función es_admin_o_superior()
--           no puede verificar permisos y bloquea INSERT en tabla usuarios
-- ============================================================================

-- PASO 1: Primero crear el registro en la tabla usuarios (requerido por FK)
INSERT INTO usuarios (id, email, nombre_completo, activo)
SELECT 
    id,
    email,
    COALESCE(raw_user_meta_data->>'full_name', 'Robert Darin'),
    true
FROM auth.users
WHERE email = 'rdarinel92@gmail.com'
ON CONFLICT (id) DO UPDATE SET
    activo = true,
    updated_at = NOW();

-- PASO 2: Asignar rol superadmin al usuario rdarinel92@gmail.com
INSERT INTO usuarios_roles (usuario_id, rol_id)
SELECT 
    u.id AS usuario_id,
    r.id AS rol_id
FROM auth.users u
CROSS JOIN roles r
WHERE u.email = 'rdarinel92@gmail.com'
  AND r.nombre = 'superadmin'
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- Verificar que se asignó correctamente
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM usuarios_roles ur
    JOIN roles r ON r.id = ur.rol_id
    JOIN auth.users u ON u.id = ur.usuario_id
    WHERE u.email = 'rdarinel92@gmail.com' AND r.nombre = 'superadmin';
    
    IF v_count > 0 THEN
        RAISE NOTICE '✅ Rol superadmin asignado correctamente a rdarinel92@gmail.com';
    ELSE
        RAISE WARNING '⚠️ No se pudo asignar el rol superadmin';
    END IF;
END $$;

-- Mostrar estado final
SELECT 
    u.email,
    r.nombre AS rol,
    ur.created_at AS asignado_en
FROM usuarios_roles ur
JOIN roles r ON r.id = ur.rol_id
JOIN auth.users u ON u.id = ur.usuario_id
ORDER BY ur.created_at;
