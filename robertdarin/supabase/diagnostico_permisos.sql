-- ═══════════════════════════════════════════════════════════════════════════════
-- DIAGNÓSTICO DE PERMISOS - Ejecutar en Supabase SQL Editor
-- Robert Darin Fintech - Enero 2026
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. VER TODOS LOS USUARIOS Y SUS ROLES
SELECT 
    u.id,
    u.email,
    u.nombre_completo,
    r.nombre as rol,
    ur.created_at as rol_asignado_en
FROM usuarios u
LEFT JOIN usuarios_roles ur ON u.id = ur.usuario_id
LEFT JOIN roles r ON ur.rol_id = r.id
ORDER BY u.created_at;

-- 2. VERIFICAR SI EL SUPERADMIN TIENE ROL ASIGNADO
-- Reemplaza el email con el tuyo
SELECT 
    u.id,
    u.email,
    CASE WHEN ur.rol_id IS NULL THEN '❌ SIN ROL' ELSE '✅ CON ROL' END as estado,
    r.nombre as rol_nombre
FROM usuarios u
LEFT JOIN usuarios_roles ur ON u.id = ur.usuario_id
LEFT JOIN roles r ON ur.rol_id = r.id
WHERE u.email = 'rdarinel92@gmail.com';

-- 3. VER TODOS LOS ROLES DISPONIBLES
SELECT * FROM roles ORDER BY nombre;

-- 4. VERIFICAR POLÍTICAS RLS EN EMPLEADOS
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual
FROM pg_policies 
WHERE tablename = 'empleados';

-- 5. VERIFICAR POLÍTICAS RLS EN USUARIOS
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd
FROM pg_policies 
WHERE tablename = 'usuarios';

-- ═══════════════════════════════════════════════════════════════════════════════
-- SOLUCIÓN: Si el superadmin no tiene rol asignado, ejecuta esto:
-- ═══════════════════════════════════════════════════════════════════════════════

-- Primero encuentra el ID del rol superadmin
-- SELECT id, nombre FROM roles WHERE nombre = 'superadmin';

-- Luego asigna el rol (reemplaza los UUIDs):
-- INSERT INTO usuarios_roles (usuario_id, rol_id)
-- SELECT u.id, r.id
-- FROM usuarios u, roles r
-- WHERE u.email = 'rdarinel92@gmail.com' 
-- AND r.nombre = 'superadmin'
-- ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SOLUCIÓN RÁPIDA: Asignar superadmin al primer usuario registrado
-- ═══════════════════════════════════════════════════════════════════════════════

-- Ejecutar esto para asegurar que el superadmin tenga su rol:
INSERT INTO usuarios_roles (usuario_id, rol_id)
SELECT u.id, r.id
FROM usuarios u
CROSS JOIN roles r
WHERE u.email = 'rdarinel92@gmail.com' 
AND r.nombre = 'superadmin'
AND NOT EXISTS (
    SELECT 1 FROM usuarios_roles ur2 
    WHERE ur2.usuario_id = u.id AND ur2.rol_id = r.id
);

-- Verificar que se asignó:
SELECT 
    u.email, 
    r.nombre as rol
FROM usuarios u
JOIN usuarios_roles ur ON u.id = ur.usuario_id
JOIN roles r ON ur.rol_id = r.id
WHERE u.email = 'rdarinel92@gmail.com';
