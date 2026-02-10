-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: LIMPIEZA DE ROLES DUPLICADOS Y CONFIGURACIÓN COMPLETA DE PERMISOS
-- Fecha: 2026-01-20
-- ══════════════════════════════════════════════════════════════════════════════

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 1. ELIMINAR ROLES DUPLICADOS (mantener solo el primero de cada nombre)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Primero eliminar permisos de roles duplicados
DELETE FROM roles_permisos 
WHERE rol_id IN (
    SELECT r.id FROM roles r
    WHERE r.id NOT IN (
        SELECT DISTINCT ON (nombre) id FROM roles ORDER BY nombre, created_at ASC
    )
);

-- Luego eliminar los roles duplicados
DELETE FROM roles 
WHERE id NOT IN (
    SELECT DISTINCT ON (nombre) id FROM roles ORDER BY nombre, created_at ASC
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 2. CREAR PERMISOS ADICIONALES PARA OTROS MÓDULOS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO permisos (id, clave_permiso, descripcion) VALUES 
    -- Permisos módulo Purificadora
    (gen_random_uuid(), 'ver_purificadora_dashboard', 'Ver dashboard de Purificadora'),
    (gen_random_uuid(), 'gestionar_purificadora_rutas', 'Gestionar rutas de reparto'),
    (gen_random_uuid(), 'gestionar_purificadora_clientes', 'Gestionar clientes de agua'),
    (gen_random_uuid(), 'gestionar_purificadora_pedidos', 'Gestionar pedidos de agua'),
    (gen_random_uuid(), 'purificadora_repartidor_ver_rutas', 'Repartidor: Ver rutas asignadas'),
    (gen_random_uuid(), 'purificadora_repartidor_entregas', 'Repartidor: Registrar entregas'),
    (gen_random_uuid(), 'purificadora_cliente_pedir', 'Cliente: Solicitar agua'),
    (gen_random_uuid(), 'purificadora_cliente_historial', 'Cliente: Ver historial de pedidos'),
    
    -- Permisos módulo Ventas/Nice
    (gen_random_uuid(), 'ver_ventas_dashboard', 'Ver dashboard de Ventas'),
    (gen_random_uuid(), 'gestionar_ventas_productos', 'Gestionar productos de venta'),
    (gen_random_uuid(), 'gestionar_ventas_pedidos', 'Gestionar pedidos de venta'),
    (gen_random_uuid(), 'gestionar_ventas_clientes', 'Gestionar clientes de ventas'),
    (gen_random_uuid(), 'vendedor_ver_catalogo', 'Vendedor: Ver catálogo de productos'),
    (gen_random_uuid(), 'vendedor_crear_pedidos', 'Vendedor: Crear pedidos'),
    (gen_random_uuid(), 'vendedor_ver_comisiones', 'Vendedor: Ver sus comisiones')
ON CONFLICT (clave_permiso) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 3. ASIGNAR PERMISOS AL ROL REPARTIDOR_PURIFICADORA
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p
WHERE r.nombre = 'REPARTIDOR_PURIFICADORA'
AND p.clave_permiso IN (
    'ver_dashboard',
    'ver_purificadora_dashboard',
    'purificadora_repartidor_ver_rutas',
    'purificadora_repartidor_entregas'
)
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 4. ASIGNAR PERMISOS AL ROL CLIENTE_PURIFICADORA
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p
WHERE r.nombre = 'CLIENTE_PURIFICADORA'
AND p.clave_permiso IN (
    'ver_dashboard',
    'ver_purificadora_dashboard',
    'purificadora_cliente_pedir',
    'purificadora_cliente_historial'
)
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 5. ASIGNAR PERMISOS AL ROL VENDEDORA_NICE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p
WHERE r.nombre = 'VENDEDORA_NICE'
AND p.clave_permiso IN (
    'ver_dashboard',
    'ver_ventas_dashboard',
    'vendedor_ver_catalogo',
    'vendedor_crear_pedidos',
    'vendedor_ver_comisiones',
    'gestionar_clientes'
)
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 6. ASIGNAR PERMISOS AL ROL VENDEDOR_VENTAS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p
WHERE r.nombre = 'VENDEDOR_VENTAS'
AND p.clave_permiso IN (
    'ver_dashboard',
    'ver_ventas_dashboard',
    'vendedor_ver_catalogo',
    'vendedor_crear_pedidos',
    'vendedor_ver_comisiones',
    'gestionar_clientes'
)
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 7. ASEGURAR QUE SUPERADMIN TIENE TODOS LOS PERMISOS NUEVOS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p
WHERE r.nombre = 'superadmin'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 8. ASEGURAR QUE TODOS LOS ROLES TIENEN AL MENOS ver_dashboard
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p
WHERE p.clave_permiso = 'ver_dashboard'
AND r.nombre != 'superadmin'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN DE MIGRACIÓN
-- ══════════════════════════════════════════════════════════════════════════════
