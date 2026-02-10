-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Tabla tarjetas_config para configuración de proveedores
-- Robert Darin Platform v10.52
-- Fecha: 21 de Enero, 2026
-- ═══════════════════════════════════════════════════════════════════════════════

-- Tabla de configuración de proveedores de tarjetas (Stripe, Rapyd, Pomelo, etc.)
CREATE TABLE IF NOT EXISTS tarjetas_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID NOT NULL REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Proveedor activo
    proveedor TEXT NOT NULL DEFAULT 'stripe' CHECK (proveedor IN ('stripe', 'rapyd', 'pomelo', 'galileo')),
    
    -- Credenciales API (encriptadas en producción)
    api_key TEXT,
    api_secret TEXT,
    webhook_secret TEXT,
    api_base_url TEXT,
    webhook_url TEXT,
    account_id TEXT,
    program_id TEXT,
    
    -- Configuración de modo
    modo_pruebas BOOLEAN DEFAULT true,
    
    -- Límites por defecto
    limite_diario_default NUMERIC(14,2) DEFAULT 10000.00,
    limite_mensual_default NUMERIC(14,2) DEFAULT 50000.00,
    limite_transaccion_default NUMERIC(14,2) DEFAULT 5000.00,
    
    -- Configuración visual
    tipo_tarjeta_default TEXT DEFAULT 'virtual',
    red_default TEXT DEFAULT 'visa' CHECK (red_default IN ('visa', 'mastercard', 'amex')),
    moneda_default TEXT DEFAULT 'MXN',
    nombre_programa TEXT DEFAULT 'Robert Darin Cards',
    logo_url TEXT,
    color_tarjeta TEXT DEFAULT '#1E3A8A',
    
    -- Estado
    activo BOOLEAN DEFAULT false,
    verificado BOOLEAN DEFAULT false,
    fecha_verificacion TIMESTAMPTZ,
    verificado_por UUID REFERENCES usuarios(id),
    
    -- Metadatos
    notas TEXT,
    metadata JSONB DEFAULT '{}',
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Solo una configuración activa por negocio
    UNIQUE(negocio_id)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_tarjetas_config_negocio ON tarjetas_config(negocio_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_config_proveedor ON tarjetas_config(proveedor);
CREATE INDEX IF NOT EXISTS idx_tarjetas_config_activo ON tarjetas_config(activo) WHERE activo = true;

-- RLS
ALTER TABLE tarjetas_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tarjetas_config_select" ON tarjetas_config
    FOR SELECT USING (
        auth.role() = 'authenticated' AND (
            negocio_id IN (SELECT negocio_id FROM usuarios WHERE id = auth.uid()) OR
            negocio_id IN (SELECT negocio_id FROM empleados WHERE usuario_id = auth.uid())
        )
    );

CREATE POLICY "tarjetas_config_admin" ON tarjetas_config
    FOR ALL USING (
        auth.role() = 'authenticated' AND (
            negocio_id IN (
                SELECT un.negocio_id FROM usuarios_negocios un 
                WHERE un.usuario_id = auth.uid() AND un.rol_negocio IN ('superadmin', 'admin')
            )
        )
    );

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_tarjetas_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_tarjetas_config_updated_at ON tarjetas_config;
CREATE TRIGGER trigger_tarjetas_config_updated_at
    BEFORE UPDATE ON tarjetas_config
    FOR EACH ROW
    EXECUTE FUNCTION update_tarjetas_config_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════════
-- Agregar campos faltantes a tarjetas_digitales para compatibilidad con el modelo
-- ═══════════════════════════════════════════════════════════════════════════════

-- Campo saldo_disponible si no existe
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tarjetas_digitales' AND column_name = 'saldo_disponible') THEN
        ALTER TABLE tarjetas_digitales ADD COLUMN saldo_disponible NUMERIC(14,2) DEFAULT 0;
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- Actualizar tarjetas_titulares con campos del modelo TarjetaTitularModel
-- ═══════════════════════════════════════════════════════════════════════════════

-- Agregar negocio_id si no existe
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tarjetas_titulares' AND column_name = 'negocio_id') THEN
        ALTER TABLE tarjetas_titulares ADD COLUMN negocio_id UUID REFERENCES negocios(id);
    END IF;
END $$;

-- Agregar cliente_id si no existe
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tarjetas_titulares' AND column_name = 'cliente_id') THEN
        ALTER TABLE tarjetas_titulares ADD COLUMN cliente_id UUID REFERENCES clientes(id);
    END IF;
END $$;

-- Agregar external_id para el ID del proveedor
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tarjetas_titulares' AND column_name = 'external_id') THEN
        ALTER TABLE tarjetas_titulares ADD COLUMN external_id TEXT;
    END IF;
END $$;

-- Agregar kyc_status
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tarjetas_titulares' AND column_name = 'kyc_status') THEN
        ALTER TABLE tarjetas_titulares ADD COLUMN kyc_status TEXT DEFAULT 'pendiente';
    END IF;
END $$;

-- Agregar activo
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tarjetas_titulares' AND column_name = 'activo') THEN
        ALTER TABLE tarjetas_titulares ADD COLUMN activo BOOLEAN DEFAULT true;
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- Agregar campos a tarjetas_log para el servicio
-- ═══════════════════════════════════════════════════════════════════════════════

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tarjetas_log' AND column_name = 'negocio_id') THEN
        ALTER TABLE tarjetas_log ADD COLUMN negocio_id UUID REFERENCES negocios(id);
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tarjetas_log' AND column_name = 'resultado') THEN
        ALTER TABLE tarjetas_log ADD COLUMN resultado TEXT DEFAULT 'success';
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- Comentarios
-- ═══════════════════════════════════════════════════════════════════════════════

COMMENT ON TABLE tarjetas_config IS 'Configuración de proveedores de tarjetas por negocio (Stripe, Rapyd, etc.)';
COMMENT ON COLUMN tarjetas_config.proveedor IS 'Proveedor activo: stripe, rapyd, pomelo, galileo';
COMMENT ON COLUMN tarjetas_config.api_key IS 'API Key del proveedor (encriptar en producción)';
COMMENT ON COLUMN tarjetas_config.api_secret IS 'API Secret del proveedor (encriptar en producción)';
COMMENT ON COLUMN tarjetas_config.modo_pruebas IS 'true=sandbox/test, false=producción';
