-- ══════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN COMPLETA SUPABASE - Robert Darin Fintech
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. CONTAR TABLAS EXISTENTES
SELECT 'TABLAS EXISTENTES' as categoria, COUNT(*) as cantidad
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'

UNION ALL

-- 2. CONTAR TABLAS CON RLS
SELECT 'TABLAS CON RLS' as categoria, COUNT(*) as cantidad
FROM pg_tables t
JOIN pg_class c ON t.tablename = c.relname
WHERE t.schemaname = 'public' AND c.relrowsecurity = true

UNION ALL

-- 3. CONTAR POLÍTICAS
SELECT 'POLÍTICAS RLS' as categoria, COUNT(*) as cantidad
FROM pg_policies WHERE schemaname = 'public'

UNION ALL

-- 4. CONTAR FUNCIONES
SELECT 'FUNCIONES' as categoria, COUNT(*) as cantidad
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'

UNION ALL

-- 5. CONTAR ÍNDICES
SELECT 'ÍNDICES' as categoria, COUNT(*) as cantidad
FROM pg_indexes WHERE schemaname = 'public'

UNION ALL

-- 6. CONTAR TRIGGERS
SELECT 'TRIGGERS' as categoria, COUNT(*) as cantidad
FROM information_schema.triggers WHERE trigger_schema = 'public';

-- ══════════════════════════════════════════════════════════════════════════════
-- LISTA DETALLADA DE TABLAS
-- ══════════════════════════════════════════════════════════════════════════════

SELECT tablename, 
       CASE WHEN c.relrowsecurity THEN '✅' ELSE '❌' END as rls_enabled,
       (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = t.tablename) as policies
FROM pg_tables t
JOIN pg_class c ON t.tablename = c.relname
WHERE t.schemaname = 'public'
ORDER BY tablename;

-- ══════════════════════════════════════════════════════════════════════════════
-- VERIFICAR TABLAS CRÍTICAS
-- ══════════════════════════════════════════════════════════════════════════════

SELECT 
    t.name as tabla_requerida,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = t.name
    ) THEN '✅ EXISTE' ELSE '❌ FALTA' END as estado
FROM (VALUES 
    ('roles'),
    ('usuarios'),
    ('negocios'),
    ('clientes'),
    ('prestamos'),
    ('amortizaciones'),
    ('pagos'),
    ('tandas'),
    ('tanda_participantes'),
    ('avales'),
    ('sucursales'),
    ('empleados'),
    ('notificaciones'),
    ('chat_conversaciones'),
    ('chat_mensajes'),
    ('configuracion_global'),
    ('prestamos_diarios'),
    ('pagos_diarios'),
    ('expedientes_legales'),
    ('facturas'),
    ('qr_cobros'),
    ('nice_productos'),
    ('climas_equipos'),
    ('purificadora_clientes'),
    ('colaboradores')
) AS t(name);

-- ══════════════════════════════════════════════════════════════════════════════
-- VERIFICAR USUARIO SUPERADMIN
-- ══════════════════════════════════════════════════════════════════════════════

SELECT 
    u.email,
    r.nombre as rol,
    'Usuario: ' || COALESCE(u.nombre_completo, 'Sin nombre') as info
FROM usuarios u
JOIN usuarios_roles ur ON u.id = ur.usuario_id
JOIN roles r ON ur.rol_id = r.id
WHERE u.email = 'rdarinel92@gmail.com';

-- ══════════════════════════════════════════════════════════════════════════════
-- VERIFICAR NEGOCIO PRINCIPAL
-- ══════════════════════════════════════════════════════════════════════════════

SELECT id, nombre, tipo, activo, created_at
FROM negocios
LIMIT 5;
