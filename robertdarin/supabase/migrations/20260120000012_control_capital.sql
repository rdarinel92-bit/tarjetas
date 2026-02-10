-- =====================================================
-- MIGRACIÓN: Control de Capital e Inversiones
-- Fecha: 2026-01-20
-- Descripción: Sistema para control de capital,
--              envíos de dinero y registro de inversiones
-- =====================================================

-- =====================================================
-- SECCIÓN 1: TABLA DE ENVÍOS DE CAPITAL
-- Registra cada envío de dinero para inversión
-- =====================================================
CREATE TABLE IF NOT EXISTS envios_capital (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Información del envío
    fecha_envio DATE NOT NULL DEFAULT CURRENT_DATE,
    monto DECIMAL(12,2) NOT NULL CHECK (monto > 0),
    moneda VARCHAR(3) DEFAULT 'MXN', -- MXN, USD
    tipo_cambio DECIMAL(8,4), -- Si envía USD, registrar tipo de cambio
    monto_mxn DECIMAL(12,2), -- Monto convertido a MXN
    
    -- Método de envío
    metodo_envio VARCHAR(50) DEFAULT 'transferencia', -- transferencia, efectivo, remesa, otro
    referencia VARCHAR(100), -- Número de referencia/confirmación
    banco_origen VARCHAR(100),
    banco_destino VARCHAR(100),
    
    -- Destinatario
    empleado_id UUID REFERENCES empleados(id),
    nombre_receptor VARCHAR(150),
    
    -- Propósito
    categoria VARCHAR(50) DEFAULT 'inversion', -- inversion, operacion, compra_equipo, nomina, otro
    proposito TEXT, -- Descripción detallada
    
    -- Estado
    estado VARCHAR(20) DEFAULT 'enviado', -- enviado, recibido, aplicado
    fecha_recibido TIMESTAMPTZ,
    confirmado_por UUID REFERENCES usuarios(id),
    
    -- Comprobante
    comprobante_url TEXT,
    
    -- Auditoría
    notas TEXT,
    created_by UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- SECCIÓN 2: TABLA DE ACTIVOS/INVERSIONES
-- Registra equipos, propiedades y otros activos
-- =====================================================
CREATE TABLE IF NOT EXISTS activos_capital (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Información del activo
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    tipo VARCHAR(50) NOT NULL, -- equipo_clima, vehiculo, herramienta, propiedad, efectivo, otro
    
    -- Valores
    costo_adquisicion DECIMAL(12,2) NOT NULL DEFAULT 0,
    valor_actual DECIMAL(12,2), -- Valor depreciado o actual
    fecha_adquisicion DATE,
    
    -- Ubicación/Asignación
    ubicacion VARCHAR(200),
    asignado_a UUID REFERENCES empleados(id),
    
    -- Estado
    estado VARCHAR(20) DEFAULT 'activo', -- activo, vendido, dañado, perdido
    
    -- Referencia a otras tablas si aplica
    equipo_clima_id UUID, -- Si es un equipo de climas
    propiedad_id UUID, -- Si es una propiedad
    
    -- Auditoría
    notas TEXT,
    created_by UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- SECCIÓN 3: TABLA DE MOVIMIENTOS DE CAPITAL
-- Registro de entradas y salidas de capital
-- =====================================================
CREATE TABLE IF NOT EXISTS movimientos_capital (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    tipo VARCHAR(20) NOT NULL, -- entrada, salida
    categoria VARCHAR(50) NOT NULL, -- envio, prestamo, cobro, gasto, compra, venta, otro
    
    monto DECIMAL(12,2) NOT NULL,
    descripcion TEXT,
    
    -- Referencias opcionales
    envio_id UUID REFERENCES envios_capital(id),
    prestamo_id UUID,
    activo_id UUID REFERENCES activos_capital(id),
    
    -- Auditoría
    created_by UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- SECCIÓN 4: VISTA RESUMEN DE CAPITAL
-- Vista consolidada del capital total
-- (Nota: Usa solo tablas que existen)
-- =====================================================
-- DROP VIEW IF EXISTS vista_resumen_capital;
-- Vista comentada porque algunas tablas pueden no existir
-- Se calculará dinámicamente desde la app

-- =====================================================
-- SECCIÓN 5: ÍNDICES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_envios_capital_negocio ON envios_capital(negocio_id);
CREATE INDEX IF NOT EXISTS idx_envios_capital_fecha ON envios_capital(fecha_envio DESC);
CREATE INDEX IF NOT EXISTS idx_envios_capital_empleado ON envios_capital(empleado_id);
CREATE INDEX IF NOT EXISTS idx_activos_capital_negocio ON activos_capital(negocio_id);
CREATE INDEX IF NOT EXISTS idx_activos_capital_tipo ON activos_capital(tipo);
CREATE INDEX IF NOT EXISTS idx_movimientos_capital_negocio ON movimientos_capital(negocio_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_capital_fecha ON movimientos_capital(fecha DESC);

-- =====================================================
-- SECCIÓN 6: RLS (Row Level Security)
-- =====================================================
ALTER TABLE envios_capital ENABLE ROW LEVEL SECURITY;
ALTER TABLE activos_capital ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos_capital ENABLE ROW LEVEL SECURITY;

-- Políticas para envios_capital
CREATE POLICY "envios_capital_select" ON envios_capital
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "envios_capital_insert" ON envios_capital
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "envios_capital_update" ON envios_capital
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "envios_capital_delete" ON envios_capital
    FOR DELETE USING (auth.role() = 'authenticated');

-- Políticas para activos_capital
CREATE POLICY "activos_capital_select" ON activos_capital
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "activos_capital_insert" ON activos_capital
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "activos_capital_update" ON activos_capital
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "activos_capital_delete" ON activos_capital
    FOR DELETE USING (auth.role() = 'authenticated');

-- Políticas para movimientos_capital
CREATE POLICY "movimientos_capital_select" ON movimientos_capital
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "movimientos_capital_insert" ON movimientos_capital
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- =====================================================
-- SECCIÓN 7: FUNCIÓN PARA CALCULAR CAPITAL TOTAL
-- (Simplificada - sin dependencias de tablas que pueden no existir)
-- =====================================================
CREATE OR REPLACE FUNCTION calcular_capital_total(p_negocio_id UUID)
RETURNS TABLE (
    capital_prestamos DECIMAL,
    capital_activos DECIMAL,
    total_enviado DECIMAL,
    capital_total DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE((SELECT SUM(monto) FROM prestamos WHERE negocio_id = p_negocio_id AND estado IN ('activo', 'vigente')), 0)::DECIMAL,
        COALESCE((SELECT SUM(valor_actual) FROM activos_capital WHERE negocio_id = p_negocio_id AND estado = 'activo'), 0)::DECIMAL,
        COALESCE((SELECT SUM(monto_mxn) FROM envios_capital WHERE negocio_id = p_negocio_id), 0)::DECIMAL,
        (
            COALESCE((SELECT SUM(monto) FROM prestamos WHERE negocio_id = p_negocio_id AND estado IN ('activo', 'vigente')), 0) +
            COALESCE((SELECT SUM(valor_actual) FROM activos_capital WHERE negocio_id = p_negocio_id AND estado = 'activo'), 0)
        )::DECIMAL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE envios_capital IS 'Registro de envíos de dinero para inversión';
COMMENT ON TABLE activos_capital IS 'Registro de activos y equipos de la empresa';
COMMENT ON TABLE movimientos_capital IS 'Historial de movimientos de capital';
