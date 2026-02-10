-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Control Total de Tarjetas para Superadmin
-- Fecha: 2026-01-21
-- Descripción: Asegura que superadmin tenga TODOS los permisos de tarjetas
-- ═══════════════════════════════════════════════════════════════════════════

-- 0. Crear tabla tarjetas_solicitudes si no existe
CREATE TABLE IF NOT EXISTS tarjetas_solicitudes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    solicitante_id UUID REFERENCES usuarios(id),
    tipo_tarjeta TEXT DEFAULT 'virtual',
    marca_preferida TEXT DEFAULT 'visa',
    limite_solicitado NUMERIC(14,2),
    motivo TEXT,
    estado TEXT DEFAULT 'pendiente',
    fecha_revision TIMESTAMPTZ,
    revisado_por UUID REFERENCES usuarios(id),
    motivo_rechazo TEXT,
    tarjeta_emitida_id UUID REFERENCES tarjetas_digitales(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_solicitudes ENABLE ROW LEVEL SECURITY;

-- Crear tablas de transacciones y recargas si no existen
CREATE TABLE IF NOT EXISTS tarjetas_digitales_transacciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_digitales(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    monto NUMERIC(14,2) NOT NULL,
    concepto TEXT,
    descripcion TEXT,
    comercio TEXT,
    referencia TEXT,
    autorizacion TEXT,
    saldo_anterior NUMERIC(14,2),
    saldo_posterior NUMERIC(14,2),
    estado TEXT DEFAULT 'completada',
    fecha TIMESTAMPTZ DEFAULT NOW(),
    fecha_procesamiento TIMESTAMPTZ,
    ip_origen TEXT,
    dispositivo TEXT,
    ubicacion_lat DECIMAL(10,8),
    ubicacion_lng DECIMAL(11,8),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_digitales_transacciones ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS tarjetas_digitales_recargas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_digitales(id) ON DELETE CASCADE,
    monto NUMERIC(14,2) NOT NULL,
    metodo_pago TEXT NOT NULL,
    referencia_pago TEXT,
    comprobante_url TEXT,
    estado TEXT DEFAULT 'pendiente',
    fecha_verificacion TIMESTAMPTZ,
    verificado_por UUID REFERENCES usuarios(id),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_digitales_recargas ENABLE ROW LEVEL SECURITY;

-- 1. Crear permisos adicionales de tarjetas si no existen
INSERT INTO permisos (clave_permiso, descripcion)
SELECT * FROM (VALUES
    ('ver_tarjetas', 'Ver tarjetas asignadas'),
    ('gestionar_tarjetas', 'Crear y editar tarjetas'),
    ('aprobar_solicitudes_tarjeta', 'Aprobar solicitudes de tarjetas'),
    ('recargar_tarjetas', 'Realizar recargas a tarjetas'),
    ('bloquear_tarjetas', 'Bloquear/desbloquear tarjetas'),
    ('ver_transacciones_tarjeta', 'Ver transacciones de tarjetas'),
    ('eliminar_tarjetas', 'Eliminar tarjetas'),
    ('configurar_tarjetas', 'Configurar límites y opciones de tarjetas'),
    ('emitir_tarjetas', 'Emitir nuevas tarjetas a clientes'),
    ('cancelar_tarjetas', 'Cancelar tarjetas permanentemente'),
    ('ver_solicitudes_tarjeta', 'Ver todas las solicitudes de tarjetas'),
    ('rechazar_solicitudes_tarjeta', 'Rechazar solicitudes de tarjetas'),
    ('exportar_tarjetas', 'Exportar reportes de tarjetas'),
    ('ver_todas_tarjetas', 'Ver todas las tarjetas del sistema')
) AS v(clave_permiso, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM permisos WHERE clave_permiso = v.clave_permiso
);

-- 2. Asignar TODOS los permisos de tarjetas a superadmin
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'superadmin'
  AND p.clave_permiso LIKE '%tarjeta%'
  AND NOT EXISTS (
    SELECT 1 FROM roles_permisos rp WHERE rp.rol_id = r.id AND rp.permiso_id = p.id
  );

-- 3. Asignar permisos de gestión a admin también
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'admin'
  AND p.clave_permiso IN (
    'ver_tarjetas', 'gestionar_tarjetas', 'ver_transacciones_tarjeta',
    'bloquear_tarjetas', 'ver_solicitudes_tarjeta', 'aprobar_solicitudes_tarjeta',
    'recargar_tarjetas', 'emitir_tarjetas', 'ver_todas_tarjetas'
  )
  AND NOT EXISTS (
    SELECT 1 FROM roles_permisos rp WHERE rp.rol_id = r.id AND rp.permiso_id = p.id
  );

-- 4. Asegurar que cliente solo pueda ver sus propias tarjetas
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'cliente'
  AND p.clave_permiso IN ('ver_tarjetas', 'ver_transacciones_tarjeta', 'bloquear_tarjetas')
  AND NOT EXISTS (
    SELECT 1 FROM roles_permisos rp WHERE rp.rol_id = r.id AND rp.permiso_id = p.id
  );

-- 5. Crear política RLS mejorada para tarjetas_digitales
DROP POLICY IF EXISTS "tarjetas_digitales_superadmin_full" ON tarjetas_digitales;
CREATE POLICY "tarjetas_digitales_superadmin_full" ON tarjetas_digitales
    FOR ALL 
    USING (
        -- Superadmin y admin pueden ver todas
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin')
        )
        OR
        -- Clientes solo pueden ver las suyas
        EXISTS (
            SELECT 1 FROM clientes c
            WHERE c.id = tarjetas_digitales.cliente_id
            AND c.usuario_id = auth.uid()
        )
    );

-- 6. Política para tarjetas_solicitudes
DROP POLICY IF EXISTS "tarjetas_solicitudes_policy" ON tarjetas_solicitudes;
CREATE POLICY "tarjetas_solicitudes_policy" ON tarjetas_solicitudes
    FOR ALL 
    USING (
        -- Superadmin y admin ven todas
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin')
        )
        OR
        -- Cliente ve solo las suyas
        solicitante_id = auth.uid()
        OR
        EXISTS (
            SELECT 1 FROM clientes c
            WHERE c.id = tarjetas_solicitudes.cliente_id
            AND c.usuario_id = auth.uid()
        )
    );

-- 7. Política para transacciones
DROP POLICY IF EXISTS "tarjetas_transacciones_policy" ON tarjetas_digitales_transacciones;
CREATE POLICY "tarjetas_transacciones_policy" ON tarjetas_digitales_transacciones
    FOR ALL 
    USING (
        -- Superadmin y admin ven todas
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin')
        )
        OR
        -- Cliente ve solo las de sus tarjetas
        EXISTS (
            SELECT 1 FROM tarjetas_digitales td
            JOIN clientes c ON td.cliente_id = c.id
            WHERE td.id = tarjetas_digitales_transacciones.tarjeta_id
            AND c.usuario_id = auth.uid()
        )
    );

-- 8. Política para recargas
DROP POLICY IF EXISTS "tarjetas_recargas_policy" ON tarjetas_digitales_recargas;
CREATE POLICY "tarjetas_recargas_policy" ON tarjetas_digitales_recargas
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin')
        )
        OR
        EXISTS (
            SELECT 1 FROM tarjetas_digitales td
            JOIN clientes c ON td.cliente_id = c.id
            WHERE td.id = tarjetas_digitales_recargas.tarjeta_id
            AND c.usuario_id = auth.uid()
        )
    );

COMMIT;
