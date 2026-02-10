-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Unificar Sistema de Tarjetas
-- Fecha: 2026-01-21
-- Descripción: Asegura compatibilidad entre tarjetas_digitales y transacciones
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Agregar columnas faltantes a tarjetas_digitales para ser compatible
ALTER TABLE tarjetas_digitales 
ADD COLUMN IF NOT EXISTS saldo_disponible NUMERIC(14,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS pin_hash TEXT,
ADD COLUMN IF NOT EXISTS intentos_fallidos INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS ultimo_uso TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS cvv_hash TEXT;

-- 2. Crear tabla de transacciones que referencie tarjetas_digitales si no existe correctamente
-- Primero verificamos y creamos la tabla de transacciones correcta
CREATE TABLE IF NOT EXISTS tarjetas_digitales_transacciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_digitales(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- compra, retiro, transferencia, recarga, devolucion, cargo, abono, reembolso
    monto NUMERIC(14,2) NOT NULL,
    concepto TEXT,
    descripcion TEXT,
    comercio TEXT,
    referencia TEXT,
    autorizacion TEXT,
    saldo_anterior NUMERIC(14,2),
    saldo_posterior NUMERIC(14,2),
    estado TEXT DEFAULT 'completada', -- pendiente, completada, rechazada, reversada
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
DROP POLICY IF EXISTS "tarjetas_digitales_trans_access" ON tarjetas_digitales_transacciones;
CREATE POLICY "tarjetas_digitales_trans_access" ON tarjetas_digitales_transacciones FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_td_trans_tarjeta ON tarjetas_digitales_transacciones(tarjeta_id);
CREATE INDEX IF NOT EXISTS idx_td_trans_fecha ON tarjetas_digitales_transacciones(fecha);
CREATE INDEX IF NOT EXISTS idx_td_trans_tipo ON tarjetas_digitales_transacciones(tipo);

-- 3. Crear tabla de recargas para tarjetas_digitales
CREATE TABLE IF NOT EXISTS tarjetas_digitales_recargas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_digitales(id) ON DELETE CASCADE,
    monto NUMERIC(14,2) NOT NULL,
    metodo_pago TEXT NOT NULL, -- efectivo, transferencia, oxxo, tarjeta, stripe
    referencia_pago TEXT,
    comprobante_url TEXT,
    estado TEXT DEFAULT 'pendiente', -- pendiente, completada, rechazada
    fecha_verificacion TIMESTAMPTZ,
    verificado_por UUID REFERENCES usuarios(id),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_digitales_recargas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tarjetas_digitales_recargas_access" ON tarjetas_digitales_recargas;
CREATE POLICY "tarjetas_digitales_recargas_access" ON tarjetas_digitales_recargas FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_td_recargas_tarjeta ON tarjetas_digitales_recargas(tarjeta_id);

-- 4. Crear tabla de solicitudes de tarjetas
CREATE TABLE IF NOT EXISTS tarjetas_solicitudes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    solicitante_id UUID REFERENCES usuarios(id),
    tipo_tarjeta TEXT DEFAULT 'virtual', -- virtual, fisica
    marca_preferida TEXT DEFAULT 'visa', -- visa, mastercard
    limite_solicitado NUMERIC(14,2),
    motivo TEXT,
    estado TEXT DEFAULT 'pendiente', -- pendiente, aprobada, rechazada, emitida
    fecha_revision TIMESTAMPTZ,
    revisado_por UUID REFERENCES usuarios(id),
    motivo_rechazo TEXT,
    tarjeta_emitida_id UUID REFERENCES tarjetas_digitales(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_solicitudes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tarjetas_solicitudes_access" ON tarjetas_solicitudes;
CREATE POLICY "tarjetas_solicitudes_access" ON tarjetas_solicitudes FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_tarjetas_solicitudes_negocio ON tarjetas_solicitudes(negocio_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_solicitudes_cliente ON tarjetas_solicitudes(cliente_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_solicitudes_estado ON tarjetas_solicitudes(estado);

-- 5. Función para actualizar saldo después de transacción
CREATE OR REPLACE FUNCTION fn_actualizar_saldo_tarjeta()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado = 'completada' THEN
        IF NEW.tipo IN ('recarga', 'abono', 'reembolso', 'devolucion') THEN
            -- Aumentar saldo
            UPDATE tarjetas_digitales 
            SET saldo_disponible = COALESCE(saldo_disponible, 0) + NEW.monto,
                ultimo_uso = NOW(),
                updated_at = NOW()
            WHERE id = NEW.tarjeta_id;
        ELSIF NEW.tipo IN ('compra', 'retiro', 'cargo', 'transferencia') THEN
            -- Disminuir saldo
            UPDATE tarjetas_digitales 
            SET saldo_disponible = COALESCE(saldo_disponible, 0) - NEW.monto,
                ultimo_uso = NOW(),
                updated_at = NOW()
            WHERE id = NEW.tarjeta_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar saldo
DROP TRIGGER IF EXISTS trg_actualizar_saldo_tarjeta ON tarjetas_digitales_transacciones;
CREATE TRIGGER trg_actualizar_saldo_tarjeta
    AFTER INSERT ON tarjetas_digitales_transacciones
    FOR EACH ROW
    EXECUTE FUNCTION fn_actualizar_saldo_tarjeta();

-- 6. Función para procesar recarga aprobada
CREATE OR REPLACE FUNCTION fn_procesar_recarga_tarjeta()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado = 'completada' AND OLD.estado = 'pendiente' THEN
        -- Crear transacción de recarga
        INSERT INTO tarjetas_digitales_transacciones (
            tarjeta_id, tipo, monto, concepto, estado, referencia
        ) VALUES (
            NEW.tarjeta_id, 'recarga', NEW.monto, 
            'Recarga de saldo - ' || COALESCE(NEW.metodo_pago, 'N/A'),
            'completada', NEW.referencia_pago
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_procesar_recarga ON tarjetas_digitales_recargas;
CREATE TRIGGER trg_procesar_recarga
    AFTER UPDATE ON tarjetas_digitales_recargas
    FOR EACH ROW
    EXECUTE FUNCTION fn_procesar_recarga_tarjeta();

-- 7. Vista unificada para facilitar consultas
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

-- 8. Agregar permisos granulares para tarjetas (si no existen)
INSERT INTO permisos (clave_permiso, descripcion)
SELECT * FROM (VALUES
    ('ver_tarjetas', 'Ver tarjetas asignadas'),
    ('gestionar_tarjetas', 'Crear y editar tarjetas'),
    ('aprobar_solicitudes_tarjeta', 'Aprobar solicitudes de tarjetas'),
    ('recargar_tarjetas', 'Realizar recargas a tarjetas'),
    ('bloquear_tarjetas', 'Bloquear/desbloquear tarjetas'),
    ('ver_transacciones_tarjeta', 'Ver transacciones de tarjetas')
) AS v(clave_permiso, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM permisos WHERE clave_permiso = v.clave_permiso
);

COMMIT;
