-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Corregir permisos de roles para que sean coherentes
-- Fecha: 2026-01-21
-- Problema: Todos los roles tienen permisos de CLIMAS mezclados incorrectamente
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. ELIMINAR TODOS LOS PERMISOS INCORRECTOS DE ROLES_PERMISOS
-- Limpiamos la tabla y reconstruimos con los permisos correctos

DELETE FROM roles_permisos;

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. ASIGNAR PERMISOS CORRECTOS A CADA ROL
-- ══════════════════════════════════════════════════════════════════════════════

-- ============================================================================
-- SUPERADMIN - Acceso a TODO
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'superadmin';

-- ============================================================================
-- ADMIN - Acceso a todo excepto control_center y configuración global
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'admin'
AND p.clave_permiso NOT IN ('acceso_control_center', 'configuracion_global');

-- ============================================================================
-- OPERADOR - Permisos básicos de operación diaria (SIN CLIMAS/PURIFICADORA/VENTAS)
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'operador'
AND p.clave_permiso IN (
    'ver_dashboard',
    'gestionar_clientes',
    'gestionar_prestamos',
    'gestionar_tandas',
    'gestionar_avales',
    'gestionar_pagos',
    'clientes.ver',
    'clientes.crear',
    'clientes.editar',
    'prestamos.ver',
    'prestamos.crear',
    'pagos.ver',
    'pagos.registrar',
    'tandas.ver',
    'tandas.crear',
    'tandas.administrar'
);

-- ============================================================================
-- CLIENTE - Solo ver su información (SIN CLIMAS/PURIFICADORA/VENTAS)
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'cliente'
AND p.clave_permiso IN (
    'ver_dashboard',
    'prestamos.ver',
    'pagos.ver',
    'tandas.ver'
);

-- ============================================================================
-- CONTADOR - Solo finanzas y reportes (SIN CLIMAS/PURIFICADORA/VENTAS)
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'contador'
AND p.clave_permiso IN (
    'ver_dashboard',
    'gestionar_prestamos',
    'gestionar_tandas',
    'gestionar_pagos',
    'ver_reportes',
    'ver_auditoria',
    'prestamos.ver',
    'pagos.ver',
    'tandas.ver',
    'reportes.ver',
    'reportes.exportar',
    'auditoria.ver'
);

-- ============================================================================
-- RECURSOS HUMANOS - Solo gestión de personal (SIN CLIMAS/PURIFICADORA/VENTAS)
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'recursos_humanos'
AND p.clave_permiso IN (
    'ver_dashboard',
    'gestionar_empleados',
    'ver_reportes',
    'usuarios.ver',
    'usuarios.crear',
    'usuarios.editar',
    'gestionar_usuarios',
    'reportes.ver'
);

-- ============================================================================
-- AVAL - Solo ver lo que avala (SIN CLIMAS/PURIFICADORA/VENTAS)
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'aval'
AND p.clave_permiso IN (
    'ver_dashboard',
    'prestamos.ver'
);

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. ROLES ESPECIALIZADOS - CADA UNO SOLO CON SUS PERMISOS
-- ══════════════════════════════════════════════════════════════════════════════

-- ============================================================================
-- VENDEDORA_NICE - SOLO permisos de NICE JOYERÍA (NO CLIMAS)
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'vendedora_nice'
AND p.clave_permiso IN (
    'ver_dashboard',
    'ver_ventas_dashboard',
    'vendedor_ver_catalogo',
    'vendedor_crear_pedidos',
    'vendedor_ver_comisiones',
    'gestionar_ventas_pedidos'
);

-- ============================================================================
-- TECNICO_CLIMAS - SOLO permisos de técnico de CLIMAS
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'tecnico_climas'
AND p.clave_permiso IN (
    'ver_climas_dashboard',
    'climas_tecnico_ver_ordenes',
    'climas_tecnico_ejecutar_ordenes',
    'climas_tecnico_checklist',
    'climas_tecnico_fotos',
    'climas_tecnico_firmas',
    'climas_tecnico_materiales',
    'climas_tecnico_ver_comisiones'
);

-- ============================================================================
-- ADMIN_CLIMAS - Permisos de administración de CLIMAS
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'admin_climas'
AND p.clave_permiso IN (
    'ver_climas_dashboard',
    'gestionar_climas_ordenes',
    'gestionar_climas_equipos',
    'gestionar_climas_clientes',
    'gestionar_climas_tecnicos',
    'climas_tecnico_ver_ordenes',
    'climas_tecnico_ejecutar_ordenes',
    'climas_admin_configuracion',
    'climas_admin_reportes',
    'climas_admin_zonas',
    'climas_admin_precios',
    'climas_admin_comisiones',
    'climas_admin_productos',
    'climas_admin_calendario'
);

-- ============================================================================
-- CLIENTE_CLIMAS - SOLO permisos de cliente de CLIMAS
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'cliente_climas'
AND p.clave_permiso IN (
    'ver_climas_dashboard',
    'climas_cliente_solicitar',
    'climas_cliente_ver_equipos',
    'climas_cliente_ver_historial',
    'climas_cliente_ver_garantias',
    'climas_cliente_mensajes',
    'climas_cliente_calificar'
);

-- ============================================================================
-- REPARTIDOR_PURIFICADORA - SOLO permisos de repartidor de PURIFICADORA
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'repartidor_purificadora'
AND p.clave_permiso IN (
    'ver_purificadora_dashboard',
    'purificadora_repartidor_ver_rutas',
    'purificadora_repartidor_entregas'
);

-- ============================================================================
-- CLIENTE_PURIFICADORA - SOLO permisos de cliente de PURIFICADORA
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'cliente_purificadora'
AND p.clave_permiso IN (
    'ver_purificadora_dashboard',
    'purificadora_cliente_pedir',
    'purificadora_cliente_historial'
);

-- ============================================================================
-- VENDEDOR_VENTAS - SOLO permisos de vendedor general
-- ============================================================================
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'vendedor_ventas'
AND p.clave_permiso IN (
    'ver_dashboard',
    'ver_ventas_dashboard',
    'gestionar_ventas_productos',
    'gestionar_ventas_pedidos',
    'gestionar_ventas_clientes',
    'vendedor_ver_catalogo',
    'vendedor_crear_pedidos',
    'vendedor_ver_comisiones'
);

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. VERIFICACIÓN - Mostrar conteo de permisos por rol
-- ══════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    rol_record RECORD;
    count_permisos INTEGER;
BEGIN
    RAISE NOTICE '═══════════════════════════════════════════════════════';
    RAISE NOTICE 'RESUMEN DE PERMISOS ASIGNADOS POR ROL:';
    RAISE NOTICE '═══════════════════════════════════════════════════════';
    
    FOR rol_record IN SELECT id, nombre FROM roles ORDER BY nombre
    LOOP
        SELECT COUNT(*) INTO count_permisos 
        FROM roles_permisos 
        WHERE rol_id = rol_record.id;
        
        RAISE NOTICE 'Rol: % → % permisos', rol_record.nombre, count_permisos;
    END LOOP;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════';
END $$;
