-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Asignar rol superadmin al nuevo correo
-- Fecha: 20 de Enero 2026
-- Cambio: El superadmin ahora usa rdarinel992@gmail.com
-- ═══════════════════════════════════════════════════════════════════════════════

-- PASO 1: Insertar/actualizar usuario en tabla usuarios si ya existe en auth.users
INSERT INTO usuarios (id, email, nombre_completo, activo, created_at, updated_at)
SELECT 
    id,
    email,
    COALESCE(raw_user_meta_data->>'full_name', 'Super Administrador'),
    true,
    NOW(),
    NOW()
FROM auth.users
WHERE email = 'rdarinel992@gmail.com'
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    nombre_completo = COALESCE(EXCLUDED.nombre_completo, usuarios.nombre_completo),
    activo = true,
    updated_at = NOW();

-- PASO 2: Asignar rol superadmin al usuario rdarinel992@gmail.com
INSERT INTO usuarios_roles (usuario_id, rol_id)
SELECT 
    u.id as usuario_id,
    r.id as rol_id
FROM usuarios u
CROSS JOIN roles r
WHERE u.email = 'rdarinel992@gmail.com' 
AND r.nombre = 'superadmin'
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- PASO 3: Verificar la asignación
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM usuarios_roles ur
    JOIN usuarios u ON ur.usuario_id = u.id
    JOIN roles r ON ur.rol_id = r.id
    WHERE u.email = 'rdarinel992@gmail.com' AND r.nombre = 'superadmin';
    
    IF v_count > 0 THEN
        RAISE NOTICE '✅ Rol superadmin asignado correctamente a rdarinel992@gmail.com';
    ELSE
        RAISE NOTICE '⚠️ No se pudo asignar el rol (el usuario puede no existir aún en auth.users)';
    END IF;
END $$;
