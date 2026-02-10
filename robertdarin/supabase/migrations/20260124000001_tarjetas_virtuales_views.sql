-- =====================================================================
-- MIGRATION: Align tarjetas_virtuales with app models + add views
-- Date: 2026-01-24
-- Description: Adds missing columns used by TarjetasService and creates
--              v_tarjetas_completas + v_transacciones_completas views.
-- =====================================================================

BEGIN;

-- Expand tarjetas_virtuales to match app model fields
ALTER TABLE tarjetas_virtuales
  ADD COLUMN IF NOT EXISTS titular_id UUID REFERENCES tarjetas_titulares(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS external_card_id TEXT,
  ADD COLUMN IF NOT EXISTS numero_tarjeta_masked TEXT,
  ADD COLUMN IF NOT EXISTS ultimos_4_digitos TEXT,
  ADD COLUMN IF NOT EXISTS tipo TEXT DEFAULT 'virtual',
  ADD COLUMN IF NOT EXISTS red TEXT DEFAULT 'visa',
  ADD COLUMN IF NOT EXISTS categoria TEXT DEFAULT 'debito',
  ADD COLUMN IF NOT EXISTS nombre_tarjeta TEXT,
  ADD COLUMN IF NOT EXISTS moneda TEXT DEFAULT 'MXN',
  ADD COLUMN IF NOT EXISTS saldo_disponible NUMERIC(14,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_retenido NUMERIC(14,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS limite_diario NUMERIC(14,2) DEFAULT 10000,
  ADD COLUMN IF NOT EXISTS limite_mensual NUMERIC(14,2) DEFAULT 50000,
  ADD COLUMN IF NOT EXISTS limite_transaccion NUMERIC(14,2) DEFAULT 5000,
  ADD COLUMN IF NOT EXISTS uso_diario NUMERIC(14,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS uso_mensual NUMERIC(14,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS solo_nacional BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS permitir_ecommerce BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS permitir_atm BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS permitir_internacional BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS motivo_bloqueo TEXT,
  ADD COLUMN IF NOT EXISTS fecha_bloqueo TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS bloqueado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS etiqueta TEXT,
  ADD COLUMN IF NOT EXISTS notas TEXT,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

ALTER TABLE tarjetas_virtuales
  ALTER COLUMN numero_tarjeta DROP NOT NULL,
  ALTER COLUMN cvv_hash DROP NOT NULL;

UPDATE tarjetas_virtuales
SET saldo_disponible = COALESCE(saldo_disponible, saldo, 0),
    limite_mensual = COALESCE(limite_mensual, saldo_maximo, 50000)
WHERE saldo_disponible IS NULL OR limite_mensual IS NULL;

-- Expand tarjetas_titulares to match app model fields
ALTER TABLE tarjetas_titulares
  ADD COLUMN IF NOT EXISTS usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS empleado_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS tipo_persona TEXT DEFAULT 'fisica',
  ADD COLUMN IF NOT EXISTS nombre TEXT,
  ADD COLUMN IF NOT EXISTS apellido_paterno TEXT,
  ADD COLUMN IF NOT EXISTS apellido_materno TEXT,
  ADD COLUMN IF NOT EXISTS razon_social TEXT,
  ADD COLUMN IF NOT EXISTS ine_clave TEXT,
  ADD COLUMN IF NOT EXISTS calle TEXT,
  ADD COLUMN IF NOT EXISTS numero_exterior TEXT,
  ADD COLUMN IF NOT EXISTS numero_interior TEXT,
  ADD COLUMN IF NOT EXISTS colonia TEXT,
  ADD COLUMN IF NOT EXISTS municipio TEXT,
  ADD COLUMN IF NOT EXISTS lugar_nacimiento TEXT,
  ADD COLUMN IF NOT EXISTS nacionalidad TEXT DEFAULT 'Mexicana',
  ADD COLUMN IF NOT EXISTS kyc_nivel INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS kyc_fecha_aprobacion TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS kyc_motivo_rechazo TEXT,
  ADD COLUMN IF NOT EXISTS documento_ine_frontal_url TEXT,
  ADD COLUMN IF NOT EXISTS documento_ine_reverso_url TEXT,
  ADD COLUMN IF NOT EXISTS documento_comprobante_domicilio_url TEXT,
  ADD COLUMN IF NOT EXISTS selfie_url TEXT,
  ADD COLUMN IF NOT EXISTS bloqueado BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS motivo_bloqueo TEXT;

UPDATE tarjetas_titulares
SET nombre = COALESCE(nombre, nombre_completo)
WHERE nombre IS NULL AND nombre_completo IS NOT NULL;

-- Align tarjetas_alertas with app model fields
ALTER TABLE tarjetas_alertas
  ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS titular_id UUID REFERENCES tarjetas_titulares(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS transaccion_id UUID REFERENCES tarjetas_transacciones(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS fecha_leida TIMESTAMPTZ;

UPDATE tarjetas_alertas ta
SET fecha_leida = COALESCE(ta.fecha_leida, ta.fecha_lectura)
WHERE ta.fecha_leida IS NULL AND ta.fecha_lectura IS NOT NULL;

UPDATE tarjetas_alertas ta
SET negocio_id = tv.negocio_id,
    titular_id = COALESCE(ta.titular_id, tv.titular_id)
FROM tarjetas_virtuales tv
WHERE ta.tarjeta_id = tv.id
  AND (ta.negocio_id IS NULL OR ta.titular_id IS NULL);

-- Align tarjetas_recargas with app insert payload
ALTER TABLE tarjetas_recargas
  ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS tipo TEXT DEFAULT 'recarga',
  ADD COLUMN IF NOT EXISTS fecha_completado TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS saldo_anterior NUMERIC(14,2),
  ADD COLUMN IF NOT EXISTS saldo_posterior NUMERIC(14,2);

ALTER TABLE tarjetas_recargas
  ALTER COLUMN metodo_pago SET DEFAULT 'manual';

-- Expand tarjetas_transacciones for full view compatibility
ALTER TABLE tarjetas_transacciones
  ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS external_transaction_id TEXT,
  ADD COLUMN IF NOT EXISTS monto_original NUMERIC(14,2),
  ADD COLUMN IF NOT EXISTS moneda TEXT DEFAULT 'MXN',
  ADD COLUMN IF NOT EXISTS moneda_original TEXT,
  ADD COLUMN IF NOT EXISTS tipo_cambio NUMERIC(12,6),
  ADD COLUMN IF NOT EXISTS comercio_nombre TEXT,
  ADD COLUMN IF NOT EXISTS comercio_id TEXT,
  ADD COLUMN IF NOT EXISTS comercio_categoria TEXT,
  ADD COLUMN IF NOT EXISTS comercio_ciudad TEXT,
  ADD COLUMN IF NOT EXISTS comercio_pais TEXT,
  ADD COLUMN IF NOT EXISTS codigo_autorizacion TEXT,
  ADD COLUMN IF NOT EXISTS motivo_rechazo TEXT,
  ADD COLUMN IF NOT EXISTS codigo_rechazo TEXT,
  ADD COLUMN IF NOT EXISTS fecha_transaccion TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS fecha_liquidacion TIMESTAMPTZ;

UPDATE tarjetas_transacciones tt
SET negocio_id = tv.negocio_id,
    fecha_transaccion = COALESCE(tt.fecha_transaccion, tt.created_at),
    comercio_nombre = COALESCE(tt.comercio_nombre, tt.comercio),
    codigo_autorizacion = COALESCE(tt.codigo_autorizacion, tt.autorizacion)
FROM tarjetas_virtuales tv
WHERE tt.tarjeta_id = tv.id
  AND (tt.negocio_id IS NULL OR tt.fecha_transaccion IS NULL OR tt.comercio_nombre IS NULL OR tt.codigo_autorizacion IS NULL);

-- Views used by TarjetasService
CREATE OR REPLACE VIEW v_tarjetas_completas AS
SELECT
  tv.id,
  tv.negocio_id,
  tv.titular_id,
  tv.external_card_id,
  tv.numero_tarjeta_masked,
  tv.ultimos_4_digitos,
  tv.fecha_expiracion,
  tv.tipo,
  tv.red,
  tv.categoria,
  tv.nombre_tarjeta,
  tv.moneda,
  tv.saldo_disponible,
  tv.saldo_retenido,
  tv.limite_diario,
  tv.limite_mensual,
  tv.limite_transaccion,
  tv.uso_diario,
  tv.uso_mensual,
  tv.solo_nacional,
  tv.permitir_ecommerce,
  tv.permitir_atm,
  tv.permitir_internacional,
  tv.estado,
  tv.motivo_bloqueo,
  tv.fecha_bloqueo,
  tv.etiqueta,
  tv.notas,
  tv.created_at,
  tv.expires_at,
  t.nombre AS titular_nombre,
  t.apellido_paterno AS titular_apellido,
  t.email AS titular_email,
  t.telefono AS titular_telefono,
  t.kyc_status AS titular_kyc_status
FROM tarjetas_virtuales tv
LEFT JOIN tarjetas_titulares t ON t.id = tv.titular_id;

CREATE OR REPLACE VIEW v_transacciones_completas AS
SELECT
  tt.id,
  tv.negocio_id,
  tt.tarjeta_id,
  tt.external_transaction_id,
  tt.tipo,
  tt.estado,
  tt.monto,
  tt.monto_original,
  COALESCE(tt.moneda, tv.moneda, 'MXN') AS moneda,
  tt.moneda_original,
  tt.tipo_cambio,
  COALESCE(tt.comercio_nombre, tt.comercio) AS comercio_nombre,
  tt.comercio_id,
  tt.comercio_categoria,
  tt.comercio_ciudad,
  tt.comercio_pais,
  COALESCE(tt.codigo_autorizacion, tt.autorizacion) AS codigo_autorizacion,
  tt.referencia,
  tt.motivo_rechazo,
  tt.codigo_rechazo,
  tt.saldo_anterior,
  tt.saldo_posterior,
  COALESCE(tt.fecha_transaccion, tt.created_at) AS fecha_transaccion,
  tt.fecha_liquidacion,
  tt.created_at,
  tv.numero_tarjeta_masked,
  tv.nombre_tarjeta,
  tv.etiqueta AS tarjeta_etiqueta,
  t.nombre AS titular_nombre,
  t.email AS titular_email
FROM tarjetas_transacciones tt
JOIN tarjetas_virtuales tv ON tv.id = tt.tarjeta_id
LEFT JOIN tarjetas_titulares t ON t.id = tv.titular_id;

GRANT SELECT ON v_tarjetas_completas TO anon, authenticated, service_role;
GRANT SELECT ON v_transacciones_completas TO anon, authenticated, service_role;

COMMIT;
