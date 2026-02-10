-- ============================================================================
-- MIGRACIÓN: Completar asignación de rol superadmin
-- Fecha: 2026-01-17
-- ============================================================================

-- PASO 1: Crear el registro en tabla usuarios primero (FK requerida)
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

-- PASO 2: Ahora sí asignar el rol superadmin
INSERT INTO usuarios_roles (usuario_id, rol_id)
SELECT 
    u.id AS usuario_id,
    r.id AS rol_id
FROM auth.users u
CROSS JOIN roles r
WHERE u.email = 'rdarinel92@gmail.com'
  AND r.nombre = 'superadmin'
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- Verificación
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
        RAISE NOTICE '✅ Rol superadmin asignado correctamente';
    ELSE
        RAISE WARNING '⚠️ No se pudo asignar el rol';
    END IF;
END $$;
