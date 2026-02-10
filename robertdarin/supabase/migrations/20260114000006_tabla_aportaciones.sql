-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: TABLA APORTACIONES DE CAPITAL V10.25
-- ═══════════════════════════════════════════════════════════════════════════════
-- Tabla para registrar aportaciones de inversionistas, socios y familiares
-- ═══════════════════════════════════════════════════════════════════════════════

-- Crear tabla de aportaciones
CREATE TABLE IF NOT EXISTS aportaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID NOT NULL REFERENCES colaboradores(id) ON DELETE RESTRICT,
    monto DECIMAL(15,2) NOT NULL CHECK (monto > 0),
    concepto TEXT DEFAULT 'Aportación de capital',
    fecha_aportacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tipo TEXT DEFAULT 'efectivo' CHECK (tipo IN ('efectivo', 'transferencia', 'cheque', 'especie', 'otro')),
    referencia TEXT, -- Número de referencia bancaria/cheque
    comprobante_url TEXT, -- URL del comprobante en storage
    notas TEXT,
    registrado_por UUID REFERENCES auth.users(id),
    negocio_id UUID REFERENCES negocios(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_aportaciones_colaborador ON aportaciones(colaborador_id);
CREATE INDEX IF NOT EXISTS idx_aportaciones_fecha ON aportaciones(fecha_aportacion DESC);
CREATE INDEX IF NOT EXISTS idx_aportaciones_negocio ON aportaciones(negocio_id);

-- Habilitar RLS
ALTER TABLE aportaciones ENABLE ROW LEVEL SECURITY;

-- Política de acceso
CREATE POLICY "aportaciones_authenticated" ON aportaciones 
    FOR ALL USING (auth.role() = 'authenticated');

-- Función para actualizar updated_at si no existe
CREATE OR REPLACE FUNCTION actualizar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para updated_at
CREATE TRIGGER set_updated_at_aportaciones
    BEFORE UPDATE ON aportaciones
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_updated_at();

-- Comentarios
COMMENT ON TABLE aportaciones IS 'Registro de aportaciones de capital de inversionistas, socios y familiares';
COMMENT ON COLUMN aportaciones.colaborador_id IS 'FK al colaborador que realiza la aportación';
COMMENT ON COLUMN aportaciones.monto IS 'Monto de la aportación en pesos mexicanos';
COMMENT ON COLUMN aportaciones.tipo IS 'Método de aportación: efectivo, transferencia, cheque, especie, otro';
