-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Crear Sucursal Inicial
-- Fecha: 2026-01-14
-- Descripción: Crea una sucursal principal si no existe para permitir el alta de empleados
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Asegurar que existe el negocio principal
INSERT INTO negocios (nombre, tipo, activo)
SELECT 'Robert Darin Fintech', 'fintech', true
WHERE NOT EXISTS (SELECT 1 FROM negocios WHERE tipo = 'fintech' LIMIT 1);

-- 2. Crear sucursal principal (REQUERIDA para dar de alta empleados)
INSERT INTO sucursales (negocio_id, nombre, codigo, direccion, telefono, activa)
SELECT 
    n.id,
    'Sucursal Principal',
    'SUC-001',
    'Oficina Central',
    '5512345678',
    true
FROM negocios n 
WHERE n.tipo = 'fintech'
AND NOT EXISTS (SELECT 1 FROM sucursales WHERE codigo = 'SUC-001');

-- 3. Verificar que existen los roles base
INSERT INTO roles (nombre, descripcion) VALUES 
    ('superadmin', 'Administrador total del sistema con acceso a todas las funciones'),
    ('admin', 'Administrador de negocio con acceso a operaciones y reportes'),
    ('operador', 'Operador/Cobrador con acceso a funciones operativas diarias'),
    ('cliente', 'Cliente del sistema con acceso solo a su información'),
    ('contador', 'Contador/Contabilidad con acceso a finanzas, reportes y nómina'),
    ('recursos_humanos', 'Recursos Humanos con acceso a empleados, nómina y expedientes'),
    ('aval', 'Aval/Garante con acceso a ver préstamos que garantiza')
ON CONFLICT (nombre) DO NOTHING;

-- 4. Verificar que existen los permisos base
INSERT INTO permisos (clave_permiso, descripcion) VALUES 
    ('ver_dashboard', 'Ver panel principal'),
    ('gestionar_clientes', 'Crear, editar y ver clientes'),
    ('gestionar_prestamos', 'Crear, editar y ver préstamos'),
    ('gestionar_tandas', 'Crear, editar y ver tandas'),
    ('gestionar_avales', 'Crear, editar y ver avales'),
    ('gestionar_pagos', 'Registrar y ver pagos'),
    ('gestionar_empleados', 'Crear, editar y ver empleados'),
    ('ver_reportes', 'Acceso a reportes y estadísticas'),
    ('ver_auditoria', 'Ver registros de auditoría'),
    ('gestionar_usuarios', 'Crear, editar usuarios y asignar roles'),
    ('gestionar_roles', 'Crear y modificar roles y permisos'),
    ('gestionar_sucursales', 'Crear, editar y ver sucursales'),
    ('configuracion_global', 'Modificar configuración del sistema'),
    ('acceso_control_center', 'Acceso al centro de control total')
ON CONFLICT (clave_permiso) DO NOTHING;

-- 5. Asignar todos los permisos al rol superadmin
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'superadmin'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 6. Asignar permisos al rol admin
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'admin'
AND p.clave_permiso NOT IN ('acceso_control_center', 'gestionar_roles', 'configuracion_global')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 7. Asignar permisos al rol operador
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'operador'
AND p.clave_permiso IN ('ver_dashboard', 'gestionar_clientes', 'gestionar_prestamos', 
                 'gestionar_tandas', 'gestionar_avales', 'gestionar_pagos')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 8. Verificación final
DO $$
BEGIN
    -- Verificar que hay sucursales
    IF NOT EXISTS (SELECT 1 FROM sucursales LIMIT 1) THEN
        RAISE EXCEPTION 'ERROR: No se pudo crear la sucursal inicial';
    END IF;
    
    -- Verificar que hay roles
    IF NOT EXISTS (SELECT 1 FROM roles LIMIT 1) THEN
        RAISE EXCEPTION 'ERROR: No se pudieron crear los roles';
    END IF;
    
    RAISE NOTICE '✅ Sucursal inicial y roles creados correctamente';
END $$;
