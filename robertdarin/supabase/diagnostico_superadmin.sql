-- ═══════════════════════════════════════════════════════════════════════════════
-- DIAGNÓSTICO COMPLETO DE AUTENTICACIÓN SUPERADMIN
-- Fecha: 21 Enero 2026
-- Email a verificar: rdarinel992@gmail.com (con doble 9)
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1️⃣ VERIFICAR USUARIOS EN AUTH.USERS
SELECT 
    '1. AUTH.USERS' as paso,
    id,
    email,
    created_at,
    last_sign_in_at,
    email_confirmed_at
FROM auth.users
WHERE email ILIKE '%rdarinel%'
ORDER BY created_at DESC;

-- 2️⃣ VERIFICAR TABLA USUARIOS
SELECT 
    '2. TABLA USUARIOS' as paso,
    id,
    email,
    nombre_completo,
    activo,
    created_at
FROM usuarios
WHERE email ILIKE '%rdarinel%';

-- 3️⃣ VERIFICAR ROLES DISPONIBLES
SELECT 
    '3. ROLES DISPONIBLES' as paso,
    id,
    nombre,
    descripcion
FROM roles
WHERE nombre IN ('superadmin', 'admin', 'cliente')
ORDER BY nombre;

-- 4️⃣ VERIFICAR ASIGNACIÓN EN USUARIOS_ROLES
SELECT 
    '4. USUARIOS_ROLES' as paso,
    ur.id,
    ur.usuario_id,
    u.email,
    r.nombre as rol_nombre
FROM usuarios_roles ur
JOIN usuarios u ON ur.usuario_id = u.id
JOIN roles r ON ur.rol_id = r.id
WHERE u.email ILIKE '%rdarinel%';

-- 5️⃣ VERIFICAR SI EXISTE EN USUARIOS_NEGOCIOS
SELECT 
    '5. USUARIOS_NEGOCIOS' as paso,
    un.id,
    un.usuario_id,
    u.email,
    un.negocio_id,
    un.rol_negocio,
    un.activo
FROM usuarios_negocios un
JOIN usuarios u ON un.usuario_id = u.id
WHERE u.email ILIKE '%rdarinel%';

-- 6️⃣ CONTEOS RESUMEN
SELECT 
    '6. RESUMEN' as paso,
    (SELECT COUNT(*) FROM auth.users WHERE email ILIKE '%rdarinel%') as en_auth_users,
    (SELECT COUNT(*) FROM usuarios WHERE email ILIKE '%rdarinel%') as en_tabla_usuarios,
    (SELECT COUNT(*) 
     FROM usuarios_roles ur 
     JOIN usuarios u ON ur.usuario_id = u.id 
     WHERE u.email ILIKE '%rdarinel%') as roles_asignados;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SOLUCIÓN: SI EL USUARIO EXISTE EN AUTH.USERS PERO NO TIENE ROL
-- ═══════════════════════════════════════════════════════════════════════════════

-- Descomentar y ejecutar si necesitas asignar el rol:

/*
-- PASO A: Asegurar usuario en tabla usuarios
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
    activo = true,
    updated_at = NOW();

-- PASO B: Asignar rol superadmin
INSERT INTO usuarios_roles (usuario_id, rol_id)
SELECT 
    u.id,
    r.id
FROM usuarios u
CROSS JOIN roles r
WHERE u.email = 'rdarinel992@gmail.com' 
AND r.nombre = 'superadmin'
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- PASO C: Verificar resultado
SELECT 
    u.email,
    r.nombre as rol
FROM usuarios_roles ur
JOIN usuarios u ON ur.usuario_id = u.id
JOIN roles r ON ur.rol_id = r.id
WHERE u.email = 'rdarinel992@gmail.com';
*/
