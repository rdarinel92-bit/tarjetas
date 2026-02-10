-- ══════════════════════════════════════════════════════════════════════════════
-- DATOS SEMILLA: Sucursales, Roles y Permisos Básicos
-- Estos datos son necesarios para que la app funcione correctamente
-- ══════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════════
-- SUCURSALES
-- ════════════════════════════════════════════════════════════════════════════════
INSERT INTO sucursales (nombre, direccion, telefono, email)
VALUES 
    ('Sucursal Principal', 'Dirección Principal', '555-0001', 'principal@robertdarin.com'),
    ('Sucursal Norte', 'Av. Norte #100', '555-0002', 'norte@robertdarin.com'),
    ('Sucursal Sur', 'Av. Sur #200', '555-0003', 'sur@robertdarin.com')
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════════
-- ROLES (si no existen)
-- ════════════════════════════════════════════════════════════════════════════════
INSERT INTO roles (nombre, descripcion)
VALUES 
    ('superadmin', 'Acceso total al sistema'),
    ('admin', 'Administrador de sucursal'),
    ('operador', 'Operador de préstamos'),
    ('contador', 'Contabilidad y reportes'),
    ('recursos_humanos', 'Gestión de personal'),
    ('cliente', 'Cliente del sistema'),
    ('aval', 'Aval de préstamos')
ON CONFLICT (nombre) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════════
-- PERMISOS (si no existen)
-- ════════════════════════════════════════════════════════════════════════════════
INSERT INTO permisos (clave_permiso, descripcion)
VALUES 
    ('ver_dashboard', 'Ver panel principal'),
    ('gestionar_clientes', 'CRUD de clientes'),
    ('gestionar_prestamos', 'CRUD de préstamos'),
    ('gestionar_tandas', 'CRUD de tandas'),
    ('gestionar_avales', 'CRUD de avales'),
    ('gestionar_pagos', 'Registrar pagos'),
    ('gestionar_empleados', 'CRUD de empleados'),
    ('ver_reportes', 'Ver reportes'),
    ('ver_auditoria', 'Ver auditoría'),
    ('gestionar_usuarios', 'CRUD de usuarios'),
    ('gestionar_roles', 'CRUD de roles'),
    ('gestionar_sucursales', 'CRUD de sucursales'),
    ('configuracion_global', 'Configuración del sistema'),
    ('acceso_control_center', 'Acceso al centro de control')
ON CONFLICT (clave_permiso) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════════
-- ASIGNAR PERMISOS A ROLES
-- ════════════════════════════════════════════════════════════════════════════════

-- SUPERADMIN: Todos los permisos
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id 
FROM roles r, permisos p 
WHERE r.nombre = 'superadmin'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ADMIN: Casi todos los permisos excepto control center
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id 
FROM roles r, permisos p 
WHERE r.nombre = 'admin' 
  AND p.clave_permiso NOT IN ('acceso_control_center', 'configuracion_global')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- OPERADOR: Permisos operativos
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id 
FROM roles r, permisos p 
WHERE r.nombre = 'operador' 
  AND p.clave_permiso IN ('ver_dashboard', 'gestionar_clientes', 'gestionar_prestamos', 'gestionar_pagos', 'gestionar_avales', 'gestionar_tandas')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- CONTADOR: Reportes y pagos
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id 
FROM roles r, permisos p 
WHERE r.nombre = 'contador' 
  AND p.clave_permiso IN ('ver_dashboard', 'ver_reportes', 'gestionar_pagos', 'ver_auditoria')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- RECURSOS HUMANOS: Empleados
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id 
FROM roles r, permisos p 
WHERE r.nombre = 'recursos_humanos' 
  AND p.clave_permiso IN ('ver_dashboard', 'gestionar_empleados', 'ver_reportes')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- CLIENTE: Solo dashboard
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id 
FROM roles r, permisos p 
WHERE r.nombre = 'cliente' 
  AND p.clave_permiso IN ('ver_dashboard')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ════════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    sucursal_count INT;
    rol_count INT;
    permiso_count INT;
BEGIN
    SELECT COUNT(*) INTO sucursal_count FROM sucursales;
    SELECT COUNT(*) INTO rol_count FROM roles;
    SELECT COUNT(*) INTO permiso_count FROM permisos;
    
    RAISE NOTICE '══════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ DATOS SEMILLA INSERTADOS';
    RAISE NOTICE '══════════════════════════════════════════════════════════';
    RAISE NOTICE '  Sucursales: %', sucursal_count;
    RAISE NOTICE '  Roles: %', rol_count;
    RAISE NOTICE '  Permisos: %', permiso_count;
    RAISE NOTICE '══════════════════════════════════════════════════════════';
END $$;
