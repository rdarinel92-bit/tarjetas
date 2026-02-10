-- ═══════════════════════════════════════════════════════════════════════════════
-- EJECUTAR EN: Supabase Dashboard > SQL Editor
-- Paso 1 de 2: DIAGNÓSTICO
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. Verificar tu usuario existe en tabla usuarios
SELECT '1. TU USUARIO EN TABLA USUARIOS:' as paso;
SELECT id, email, nombre_completo FROM usuarios WHERE email = 'rdarinel92@gmail.com';

-- 2. Verificar si tienes rol asignado
SELECT '2. TU ROL ASIGNADO:' as paso;
SELECT 
    u.email, 
    r.nombre as rol
FROM usuarios u
LEFT JOIN usuarios_roles ur ON u.id = ur.usuario_id
LEFT JOIN roles r ON ur.rol_id = r.id
WHERE u.email = 'rdarinel92@gmail.com';

-- 3. Verificar si existe la función crear_empleado_completo
SELECT '3. FUNCIÓN RPC:' as paso;
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'crear_empleado_completo';

-- 4. Ver políticas RLS en empleados
SELECT '4. POLÍTICAS RLS EN EMPLEADOS:' as paso;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'empleados';
