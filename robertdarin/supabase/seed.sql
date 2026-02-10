-- ============================================================================
-- SEED DATA: Datos iniciales para Robert Darin Fintech
-- ============================================================================

-- Nota: Los roles y permisos ya se crean en la migración base.
-- Este seed agrega datos necesarios para el funcionamiento de la app.

-- ============================================================================
-- 1. NEGOCIO PRINCIPAL (REQUERIDO)
-- ============================================================================
INSERT INTO negocios (id, nombre, tipo, rfc, razon_social, telefono, email, activo, configuracion)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'Robert Darin Fintech',
  'fintech',
  'XAXX010101000',
  'Robert Darin Servicios Financieros SA de CV',
  '5551234567',
  'contacto@robertdarin.com',
  true,
  '{"moneda": "MXN", "interes_default": 10, "mora_default": 5}'::jsonb
) ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 2. SUCURSALES (REQUERIDAS PARA EMPLEADOS)
-- ============================================================================
INSERT INTO sucursales (id, negocio_id, nombre, direccion, telefono, activa)
VALUES 
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Sucursal Matriz', 'Av. Principal 123, Centro', '5551234567', true),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Sucursal Norte', 'Blvd. Norte 456, Col. Industrial', '5559876543', true),
  ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Sucursal Sur', 'Calle Sur 789, Zona Comercial', '5555551234', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 3. CONFIGURACIÓN DE MORAS POR DEFECTO
-- ============================================================================
INSERT INTO configuracion_moras (
  negocio_id,
  prestamos_dias_gracia,
  prestamos_mora_diaria,
  prestamos_mora_maxima,
  tandas_dias_gracia,
  tandas_mora_diaria
)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  3,    -- días de gracia préstamos
  1.0,  -- mora diaria préstamos %
  30.0, -- mora máxima préstamos %
  1,    -- días de gracia tandas
  2.0   -- mora diaria tandas %
) ON CONFLICT DO NOTHING;

-- ============================================================================
-- 4. ASIGNAR PERMISOS A ROLES
-- ============================================================================

-- Asignar permisos a roles
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'superadmin'
ON CONFLICT DO NOTHING;

-- Admin tiene casi todos los permisos excepto control_center
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'admin' 
AND p.clave_permiso NOT IN ('control_center', 'usuarios', 'roles')
ON CONFLICT DO NOTHING;

-- Operador tiene permisos básicos
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'operador' 
AND p.clave_permiso IN ('dashboard', 'clientes', 'prestamos', 'pagos', 'cobros', 'chat', 'calendario')
ON CONFLICT DO NOTHING;

-- Cliente solo ve dashboard y chat
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'cliente' 
AND p.clave_permiso IN ('dashboard', 'chat', 'notificaciones')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- FIN SEED
-- ============================================================================
