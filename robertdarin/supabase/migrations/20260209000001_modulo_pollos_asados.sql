-- ══════════════════════════════════════════════════════════════════════════════
-- MÓDULO: POLLOS ASADOS - Sistema de Pedidos
-- Fecha: 2026-02-09
-- Descripción: Sistema completo para venta de pollos asados con pedidos web
-- ══════════════════════════════════════════════════════════════════════════════

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SECCIÓN 1: CONFIGURACIÓN DEL NEGOCIO DE POLLOS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE TABLE IF NOT EXISTS pollos_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Info del negocio
    nombre_negocio VARCHAR(150) NOT NULL DEFAULT 'Pollos Asados',
    slogan TEXT DEFAULT '¡Los más sabrosos de la ciudad!',
    telefono VARCHAR(20),
    whatsapp VARCHAR(20),
    direccion TEXT,
    
    -- Horario
    horario_apertura TIME DEFAULT '10:00',
    horario_cierre TIME DEFAULT '21:00',
    dias_abierto TEXT[] DEFAULT ARRAY['lunes','martes','miercoles','jueves','viernes','sabado','domingo'],
    
    -- Configuración de pedidos
    tiempo_preparacion_min INTEGER DEFAULT 20, -- minutos
    pedido_minimo DECIMAL(10,2) DEFAULT 0,
    acepta_pedidos_web BOOLEAN DEFAULT true,
    acepta_efectivo BOOLEAN DEFAULT true,
    acepta_transferencia BOOLEAN DEFAULT true,
    acepta_tarjeta BOOLEAN DEFAULT false,
    
    -- Delivery
    tiene_delivery BOOLEAN DEFAULT true,
    costo_delivery DECIMAL(10,2) DEFAULT 30.00,
    radio_delivery_km DECIMAL(5,2) DEFAULT 5.00,
    delivery_gratis_desde DECIMAL(10,2) DEFAULT 300.00,
    
    -- Branding
    logo_url TEXT,
    color_primario VARCHAR(7) DEFAULT '#FF6B00',
    color_secundario VARCHAR(7) DEFAULT '#FFD93D',
    
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(negocio_id)
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SECCIÓN 2: MENÚ / PRODUCTOS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE TABLE IF NOT EXISTS pollos_productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Producto
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    categoria VARCHAR(50) DEFAULT 'pollos', -- pollos, complementos, bebidas, combos
    
    -- Precios
    precio DECIMAL(10,2) NOT NULL,
    precio_promocion DECIMAL(10,2),
    en_promocion BOOLEAN DEFAULT false,
    
    -- Inventario
    disponible BOOLEAN DEFAULT true,
    stock_limitado BOOLEAN DEFAULT false,
    stock_actual INTEGER DEFAULT 0,
    
    -- Imagen
    imagen_url TEXT,
    
    -- Orden en menú
    orden INTEGER DEFAULT 0,
    destacado BOOLEAN DEFAULT false,
    
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Productos iniciales de ejemplo
INSERT INTO pollos_productos (nombre, descripcion, categoria, precio, orden, destacado) VALUES
    ('Pollo Entero', 'Pollo asado completo, jugoso y dorado', 'pollos', 180.00, 1, true),
    ('Medio Pollo', 'Media pieza de pollo asado', 'pollos', 95.00, 2, true),
    ('Cuarto de Pollo', 'Cuarto de pollo (pierna o pechuga)', 'pollos', 55.00, 3, false),
    ('Pechuga Asada', 'Pechuga de pollo jugosa', 'pollos', 70.00, 4, false),
    ('Pierna con Muslo', 'Pierna completa con muslo', 'pollos', 50.00, 5, false),
    ('Papas Fritas', 'Porción grande de papas', 'complementos', 35.00, 10, false),
    ('Ensalada', 'Ensalada fresca de la casa', 'complementos', 25.00, 11, false),
    ('Tortillas (5 pzas)', 'Tortillas de maíz recién hechas', 'complementos', 15.00, 12, false),
    ('Arroz', 'Porción de arroz rojo', 'complementos', 20.00, 13, false),
    ('Frijoles', 'Porción de frijoles charros', 'complementos', 20.00, 14, false),
    ('Salsa Verde', 'Salsa verde picante', 'complementos', 10.00, 15, false),
    ('Salsa Roja', 'Salsa roja especial', 'complementos', 10.00, 16, false),
    ('Refresco 600ml', 'Coca-Cola, Fanta, Sprite', 'bebidas', 25.00, 20, false),
    ('Agua 600ml', 'Agua natural o mineralizada', 'bebidas', 18.00, 21, false),
    ('Combo Familiar', '2 Pollos + Papas + 4 Refrescos', 'combos', 450.00, 30, true),
    ('Combo Individual', 'Medio Pollo + Papas + Refresco', 'combos', 140.00, 31, true)
ON CONFLICT DO NOTHING;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SECCIÓN 3: PEDIDOS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE TABLE IF NOT EXISTS pollos_pedidos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Número de pedido (auto-generado)
    numero_pedido SERIAL,
    
    -- Cliente
    cliente_nombre VARCHAR(100) NOT NULL,
    cliente_telefono VARCHAR(20) NOT NULL,
    cliente_email VARCHAR(100),
    
    -- Tipo de pedido
    tipo_entrega VARCHAR(20) DEFAULT 'recoger' CHECK (tipo_entrega IN ('recoger', 'delivery')),
    
    -- Dirección (si es delivery)
    direccion_entrega TEXT,
    referencia_direccion TEXT,
    
    -- Totales
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
    costo_delivery DECIMAL(10,2) DEFAULT 0,
    descuento DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL DEFAULT 0,
    
    -- Estado del pedido
    estado VARCHAR(30) DEFAULT 'pendiente' CHECK (estado IN (
        'pendiente',      -- Recién recibido
        'confirmado',     -- Aceptado por el negocio
        'preparando',     -- En cocina
        'listo',          -- Listo para recoger/entregar
        'en_camino',      -- En ruta de delivery
        'entregado',      -- Completado
        'cancelado'       -- Cancelado
    )),
    
    -- Pago
    metodo_pago VARCHAR(20) DEFAULT 'efectivo' CHECK (metodo_pago IN ('efectivo', 'transferencia', 'tarjeta')),
    pagado BOOLEAN DEFAULT false,
    
    -- Tiempos
    hora_pedido TIMESTAMPTZ DEFAULT NOW(),
    hora_confirmacion TIMESTAMPTZ,
    hora_listo TIMESTAMPTZ,
    hora_entrega TIMESTAMPTZ,
    tiempo_estimado_min INTEGER, -- Minutos estimados
    
    -- Notas
    notas_cliente TEXT,
    notas_internas TEXT,
    
    -- Origen
    origen VARCHAR(20) DEFAULT 'web' CHECK (origen IN ('web', 'telefono', 'local', 'whatsapp')),
    
    -- Token para seguimiento público
    token_seguimiento VARCHAR(20) DEFAULT UPPER(SUBSTRING(MD5(RANDOM()::TEXT), 1, 8)),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_pollos_pedidos_negocio ON pollos_pedidos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_pollos_pedidos_estado ON pollos_pedidos(estado);
CREATE INDEX IF NOT EXISTS idx_pollos_pedidos_fecha ON pollos_pedidos(hora_pedido DESC);
CREATE INDEX IF NOT EXISTS idx_pollos_pedidos_token ON pollos_pedidos(token_seguimiento);
CREATE INDEX IF NOT EXISTS idx_pollos_pedidos_telefono ON pollos_pedidos(cliente_telefono);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SECCIÓN 4: DETALLE DE PEDIDOS (PRODUCTOS)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE TABLE IF NOT EXISTS pollos_pedido_detalle (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES pollos_pedidos(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES pollos_productos(id),
    
    -- Producto (copia para histórico)
    producto_nombre VARCHAR(100) NOT NULL,
    
    -- Cantidad y precio
    cantidad INTEGER NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    
    -- Notas especiales
    notas TEXT, -- Ej: "Sin salsa", "Extra tortillas"
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pollos_detalle_pedido ON pollos_pedido_detalle(pedido_id);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SECCIÓN 5: ESTADÍSTICAS DIARIAS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE TABLE IF NOT EXISTS pollos_estadisticas_dia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    
    -- Contadores
    total_pedidos INTEGER DEFAULT 0,
    pedidos_completados INTEGER DEFAULT 0,
    pedidos_cancelados INTEGER DEFAULT 0,
    
    -- Ventas
    venta_total DECIMAL(12,2) DEFAULT 0,
    venta_delivery DECIMAL(12,2) DEFAULT 0,
    venta_local DECIMAL(12,2) DEFAULT 0,
    
    -- Productos
    pollos_vendidos INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(negocio_id, fecha)
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SECCIÓN 6: RLS POLICIES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Habilitar RLS
ALTER TABLE pollos_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE pollos_productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pollos_pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pollos_pedido_detalle ENABLE ROW LEVEL SECURITY;
ALTER TABLE pollos_estadisticas_dia ENABLE ROW LEVEL SECURITY;

-- Políticas para config
CREATE POLICY pollos_config_select ON pollos_config FOR SELECT USING (true);
CREATE POLICY pollos_config_manage ON pollos_config FOR ALL USING (auth.role() = 'authenticated');

-- Políticas para productos (todos pueden ver, autenticados pueden modificar)
CREATE POLICY pollos_productos_select ON pollos_productos FOR SELECT USING (activo = true OR auth.role() = 'authenticated');
CREATE POLICY pollos_productos_manage ON pollos_productos FOR ALL USING (auth.role() = 'authenticated');

-- Políticas para pedidos (anónimos pueden insertar, ver por token)
CREATE POLICY pollos_pedidos_insert ON pollos_pedidos FOR INSERT WITH CHECK (true);
CREATE POLICY pollos_pedidos_select_public ON pollos_pedidos FOR SELECT USING (true);
CREATE POLICY pollos_pedidos_manage ON pollos_pedidos FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY pollos_pedidos_delete ON pollos_pedidos FOR DELETE USING (auth.role() = 'authenticated');

-- Políticas para detalle
CREATE POLICY pollos_detalle_insert ON pollos_pedido_detalle FOR INSERT WITH CHECK (true);
CREATE POLICY pollos_detalle_select ON pollos_pedido_detalle FOR SELECT USING (true);
CREATE POLICY pollos_detalle_manage ON pollos_pedido_detalle FOR ALL USING (auth.role() = 'authenticated');

-- Políticas para estadísticas
CREATE POLICY pollos_stats_all ON pollos_estadisticas_dia FOR ALL USING (auth.role() = 'authenticated');

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SECCIÓN 7: FUNCIÓN PARA CALCULAR TOTAL DEL PEDIDO
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE OR REPLACE FUNCTION calcular_total_pedido_pollos()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE pollos_pedidos
    SET subtotal = (
        SELECT COALESCE(SUM(subtotal), 0) 
        FROM pollos_pedido_detalle 
        WHERE pedido_id = NEW.pedido_id
    ),
    total = (
        SELECT COALESCE(SUM(subtotal), 0) 
        FROM pollos_pedido_detalle 
        WHERE pedido_id = NEW.pedido_id
    ) + COALESCE((SELECT costo_delivery FROM pollos_pedidos WHERE id = NEW.pedido_id), 0)
      - COALESCE((SELECT descuento FROM pollos_pedidos WHERE id = NEW.pedido_id), 0)
    WHERE id = NEW.pedido_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calcular_total_pollos
AFTER INSERT OR UPDATE OR DELETE ON pollos_pedido_detalle
FOR EACH ROW EXECUTE FUNCTION calcular_total_pedido_pollos();

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIN DEL MÓDULO POLLOS ASADOS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
