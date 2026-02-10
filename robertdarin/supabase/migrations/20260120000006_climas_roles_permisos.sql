-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: ROLES Y PERMISOS PARA MÓDULO CLIMAS
-- Fecha: 2026-01-20
-- ══════════════════════════════════════════════════════════════════════════════

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 1. CREAR ROLES PARA CLIMAS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles (id, nombre, descripcion) VALUES 
    (gen_random_uuid(), 'TECNICO_CLIMAS', 'Técnico de aires acondicionados con acceso a órdenes de servicio'),
    (gen_random_uuid(), 'ADMIN_CLIMAS', 'Administrador del módulo de Climas con acceso total al módulo'),
    (gen_random_uuid(), 'CLIENTE_CLIMAS', 'Cliente del servicio de aires acondicionados')
ON CONFLICT (nombre) DO UPDATE SET descripcion = EXCLUDED.descripcion;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 2. CREAR PERMISOS PARA MÓDULO CLIMAS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO permisos (id, clave_permiso, descripcion) VALUES 
    -- Permisos generales del módulo
    (gen_random_uuid(), 'ver_climas_dashboard', 'Ver dashboard del módulo Climas'),
    (gen_random_uuid(), 'gestionar_climas_ordenes', 'Crear, editar y gestionar órdenes de servicio de climas'),
    (gen_random_uuid(), 'gestionar_climas_equipos', 'Registrar y administrar equipos de aire acondicionado'),
    (gen_random_uuid(), 'gestionar_climas_clientes', 'Administrar clientes del módulo Climas'),
    (gen_random_uuid(), 'gestionar_climas_tecnicos', 'Administrar técnicos del módulo Climas'),
    
    -- Permisos de técnico
    (gen_random_uuid(), 'climas_tecnico_ver_ordenes', 'Técnico: Ver órdenes asignadas'),
    (gen_random_uuid(), 'climas_tecnico_ejecutar_ordenes', 'Técnico: Ejecutar y completar órdenes de servicio'),
    (gen_random_uuid(), 'climas_tecnico_checklist', 'Técnico: Completar checklists de servicio'),
    (gen_random_uuid(), 'climas_tecnico_fotos', 'Técnico: Subir fotos de antes/después'),
    (gen_random_uuid(), 'climas_tecnico_firmas', 'Técnico: Capturar firmas de cliente'),
    (gen_random_uuid(), 'climas_tecnico_materiales', 'Técnico: Registrar materiales usados'),
    (gen_random_uuid(), 'climas_tecnico_ver_comisiones', 'Técnico: Ver sus propias comisiones'),
    
    -- Permisos de cliente
    (gen_random_uuid(), 'climas_cliente_solicitar', 'Cliente: Solicitar servicios'),
    (gen_random_uuid(), 'climas_cliente_ver_equipos', 'Cliente: Ver sus equipos registrados'),
    (gen_random_uuid(), 'climas_cliente_ver_historial', 'Cliente: Ver historial de servicios'),
    (gen_random_uuid(), 'climas_cliente_ver_garantias', 'Cliente: Ver garantías activas'),
    (gen_random_uuid(), 'climas_cliente_mensajes', 'Cliente: Enviar mensajes sobre servicios'),
    (gen_random_uuid(), 'climas_cliente_calificar', 'Cliente: Calificar servicios recibidos'),
    
    -- Permisos administrativos
    (gen_random_uuid(), 'climas_admin_configuracion', 'Admin: Configurar módulo Climas'),
    (gen_random_uuid(), 'climas_admin_reportes', 'Admin: Ver reportes y estadísticas de Climas'),
    (gen_random_uuid(), 'climas_admin_zonas', 'Admin: Gestionar zonas de cobertura'),
    (gen_random_uuid(), 'climas_admin_precios', 'Admin: Configurar precios y cotizaciones'),
    (gen_random_uuid(), 'climas_admin_comisiones', 'Admin: Gestionar comisiones de técnicos'),
    (gen_random_uuid(), 'climas_admin_productos', 'Admin: Gestionar inventario y productos'),
    (gen_random_uuid(), 'climas_admin_calendario', 'Admin: Gestionar calendario y disponibilidad')
ON CONFLICT (clave_permiso) DO UPDATE SET descripcion = EXCLUDED.descripcion;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 3. ASIGNAR PERMISOS AL ROL TECNICO_CLIMAS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'TECNICO_CLIMAS'
AND p.clave_permiso IN (
    'ver_climas_dashboard',
    'climas_tecnico_ver_ordenes',
    'climas_tecnico_ejecutar_ordenes',
    'climas_tecnico_checklist',
    'climas_tecnico_fotos',
    'climas_tecnico_firmas',
    'climas_tecnico_materiales',
    'climas_tecnico_ver_comisiones'
)
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 4. ASIGNAR PERMISOS AL ROL ADMIN_CLIMAS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'ADMIN_CLIMAS'
AND p.clave_permiso LIKE 'climas%' OR p.clave_permiso LIKE 'ver_climas%' OR p.clave_permiso LIKE 'gestionar_climas%'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 5. ASIGNAR PERMISOS AL ROL CLIENTE_CLIMAS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'CLIENTE_CLIMAS'
AND p.clave_permiso IN (
    'ver_climas_dashboard',
    'climas_cliente_solicitar',
    'climas_cliente_ver_equipos',
    'climas_cliente_ver_historial',
    'climas_cliente_ver_garantias',
    'climas_cliente_mensajes',
    'climas_cliente_calificar'
)
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 6. ASIGNAR TODOS LOS PERMISOS DE CLIMAS AL SUPERADMIN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'superadmin'
AND (p.clave_permiso LIKE 'climas%' OR p.clave_permiso LIKE 'ver_climas%' OR p.clave_permiso LIKE 'gestionar_climas%')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 7. ASIGNAR PERMISOS BÁSICOS A LOS ROLES DE CLIMAS (ver dashboard general)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Técnico y Admin también pueden ver dashboard general
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre IN ('TECNICO_CLIMAS', 'ADMIN_CLIMAS', 'CLIENTE_CLIMAS')
AND p.clave_permiso = 'ver_dashboard'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN DE MIGRACIÓN
-- ══════════════════════════════════════════════════════════════════════════════
