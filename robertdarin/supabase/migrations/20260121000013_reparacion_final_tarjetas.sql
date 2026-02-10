-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Reparación final de tarjetas
-- Fecha: 2026-01-21
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Crear vista unificada
CREATE OR REPLACE VIEW v_tarjetas_cliente AS
SELECT 
    t.id,
    t.cliente_id,
    t.negocio_id,
    t.codigo_tarjeta,
    t.ultimos_4,
    t.marca,
    t.tipo,
    t.estado,
    t.saldo_disponible,
    t.limite_diario,
    t.limite_mensual,
    t.fecha_vencimiento,
    t.activa,
    t.created_at,
    c.nombre AS cliente_nombre,
    c.telefono AS cliente_telefono,
    c.usuario_id AS cliente_usuario_id
FROM tarjetas_digitales t
LEFT JOIN clientes c ON t.cliente_id = c.id
WHERE t.activa = true;

-- 2. Asignar permisos de tarjetas a superadmin y admin
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre IN ('superadmin', 'admin')
  AND p.clave_permiso IN (
    'ver_tarjetas', 'gestionar_tarjetas', 'aprobar_solicitudes_tarjeta',
    'recargar_tarjetas', 'bloquear_tarjetas', 'ver_transacciones_tarjeta'
  )
  AND NOT EXISTS (
    SELECT 1 FROM roles_permisos rp WHERE rp.rol_id = r.id AND rp.permiso_id = p.id
  );

-- 3. Asignar permiso ver_tarjetas a cliente
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'cliente'
  AND p.clave_permiso IN ('ver_tarjetas', 'ver_transacciones_tarjeta')
  AND NOT EXISTS (
    SELECT 1 FROM roles_permisos rp WHERE rp.rol_id = r.id AND rp.permiso_id = p.id
  );

COMMIT;
