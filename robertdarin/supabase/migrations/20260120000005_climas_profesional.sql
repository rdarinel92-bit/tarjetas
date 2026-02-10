-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: MÓDULO CLIMAS PROFESIONAL V10.50
-- Fecha: 20 de Enero, 2026
-- Descripción: 22 nuevas tablas para mejoras profesionales del módulo Climas
-- ══════════════════════════════════════════════════════════════════════════════

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PARA EL CLIENTE: Portal de autoservicio
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Solicitudes de servicio (cliente puede solicitar desde la app)
CREATE TABLE IF NOT EXISTS climas_solicitudes_cliente (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    equipo_id UUID REFERENCES climas_equipos(id) ON DELETE SET NULL,
    tipo_solicitud TEXT DEFAULT 'mantenimiento', -- mantenimiento, reparacion, emergencia, cotizacion
    urgencia TEXT DEFAULT 'normal', -- normal, urgente, emergencia
    descripcion TEXT NOT NULL,
    fotos JSONB DEFAULT '[]', -- Fotos del problema
    disponibilidad_fecha DATE,
    disponibilidad_horario TEXT, -- mañana, tarde, todo_el_dia
    estado TEXT DEFAULT 'nueva', -- nueva, vista, programada, rechazada
    orden_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE SET NULL, -- Cuando se convierte en orden
    respuesta_negocio TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Recordatorios de mantenimiento para cliente
CREATE TABLE IF NOT EXISTS climas_recordatorios_mantenimiento (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    equipo_id UUID REFERENCES climas_equipos(id) ON DELETE CASCADE,
    fecha_programada DATE NOT NULL,
    tipo TEXT DEFAULT 'mantenimiento_preventivo',
    descripcion TEXT,
    notificado BOOLEAN DEFAULT FALSE,
    fecha_notificacion TIMESTAMPTZ,
    aceptado BOOLEAN,
    orden_generada_id UUID REFERENCES climas_ordenes_servicio(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Garantías de cliente (registro detallado)
CREATE TABLE IF NOT EXISTS climas_garantias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    equipo_id UUID REFERENCES climas_equipos(id) ON DELETE CASCADE,
    orden_instalacion_id UUID REFERENCES climas_ordenes_servicio(id),
    numero_garantia TEXT,
    tipo_garantia TEXT, -- fabricante, extendida, servicio
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    cobertura TEXT, -- descripcion de qué cubre
    documento_url TEXT,
    activa BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Facturas/Comprobantes para cliente
CREATE TABLE IF NOT EXISTS climas_comprobantes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    orden_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE SET NULL,
    tipo TEXT DEFAULT 'factura', -- factura, nota_venta, presupuesto
    folio TEXT NOT NULL,
    fecha DATE DEFAULT CURRENT_DATE,
    subtotal DECIMAL(14,2) DEFAULT 0,
    iva DECIMAL(14,2) DEFAULT 0,
    total DECIMAL(14,2) DEFAULT 0,
    pagado BOOLEAN DEFAULT FALSE,
    fecha_pago DATE,
    metodo_pago TEXT,
    documento_url TEXT, -- PDF
    xml_url TEXT, -- Para facturas electrónicas
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat/Mensajes cliente-negocio
CREATE TABLE IF NOT EXISTS climas_mensajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    orden_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE SET NULL,
    remitente TEXT NOT NULL, -- cliente, negocio, tecnico
    remitente_nombre TEXT,
    mensaje TEXT NOT NULL,
    tipo TEXT DEFAULT 'texto', -- texto, imagen, ubicacion
    adjunto_url TEXT,
    leido BOOLEAN DEFAULT FALSE,
    fecha_leido TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PARA EL TÉCNICO: App de campo profesional
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Checklist de servicio (que el técnico debe completar)
CREATE TABLE IF NOT EXISTS climas_checklist_servicio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL, -- "Checklist Mantenimiento", "Checklist Instalación"
    tipo_servicio TEXT, -- Para qué tipo de servicio aplica
    items JSONB NOT NULL, -- Array de items a revisar
    obligatorio BOOLEAN DEFAULT TRUE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Respuestas de checklist por orden
CREATE TABLE IF NOT EXISTS climas_checklist_respuestas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    orden_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE CASCADE,
    checklist_id UUID REFERENCES climas_checklist_servicio(id) ON DELETE CASCADE,
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE SET NULL,
    respuestas JSONB NOT NULL, -- {item_id: {valor, observacion, foto}}
    completado BOOLEAN DEFAULT FALSE,
    fecha_completado TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Registro de tiempo del técnico
CREATE TABLE IF NOT EXISTS climas_registro_tiempo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    orden_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE CASCADE,
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- entrada, salida, pausa_inicio, pausa_fin
    ubicacion_lat DECIMAL(10,8),
    ubicacion_lng DECIMAL(11,8),
    foto_evidencia TEXT, -- Selfie de llegada/salida
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Productos/Refacciones - Agregar columnas faltantes si la tabla existe
DO $$ 
BEGIN
    -- Agregar columnas faltantes a climas_productos si existe
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'climas_productos') THEN
        -- categoria
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'climas_productos' AND column_name = 'categoria') THEN
            ALTER TABLE climas_productos ADD COLUMN categoria TEXT;
        END IF;
        -- subcategoria
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'climas_productos' AND column_name = 'subcategoria') THEN
            ALTER TABLE climas_productos ADD COLUMN subcategoria TEXT;
        END IF;
        -- marca
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'climas_productos' AND column_name = 'marca') THEN
            ALTER TABLE climas_productos ADD COLUMN marca TEXT;
        END IF;
        -- modelo
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'climas_productos' AND column_name = 'modelo') THEN
            ALTER TABLE climas_productos ADD COLUMN modelo TEXT;
        END IF;
        -- precio_instalacion
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'climas_productos' AND column_name = 'precio_instalacion') THEN
            ALTER TABLE climas_productos ADD COLUMN precio_instalacion DECIMAL(14,2) DEFAULT 0;
        END IF;
        -- ubicacion_almacen
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'climas_productos' AND column_name = 'ubicacion_almacen') THEN
            ALTER TABLE climas_productos ADD COLUMN ubicacion_almacen TEXT;
        END IF;
        -- proveedor_principal
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'climas_productos' AND column_name = 'proveedor_principal') THEN
            ALTER TABLE climas_productos ADD COLUMN proveedor_principal TEXT;
        END IF;
        -- imagen_url
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'climas_productos' AND column_name = 'imagen_url') THEN
            ALTER TABLE climas_productos ADD COLUMN imagen_url TEXT;
        END IF;
    ELSE
        -- Crear tabla completa si no existe
        CREATE TABLE climas_productos (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
            codigo TEXT,
            nombre TEXT NOT NULL,
            descripcion TEXT,
            categoria TEXT,
            subcategoria TEXT,
            marca TEXT,
            modelo TEXT,
            unidad TEXT DEFAULT 'pieza',
            precio_compra DECIMAL(14,2) DEFAULT 0,
            precio_venta DECIMAL(14,2) DEFAULT 0,
            precio_instalacion DECIMAL(14,2) DEFAULT 0,
            stock INTEGER DEFAULT 0,
            stock_minimo INTEGER DEFAULT 5,
            ubicacion_almacen TEXT,
            proveedor_principal TEXT,
            imagen_url TEXT,
            activo BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );
    END IF;
END $$;

-- Inventario móvil del técnico (refacciones en su camioneta)
CREATE TABLE IF NOT EXISTS climas_inventario_tecnico (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES climas_productos(id) ON DELETE CASCADE,
    cantidad INTEGER DEFAULT 0,
    cantidad_minima INTEGER DEFAULT 1, -- Alerta cuando baja de esto
    ultima_recarga DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Solicitudes de refacciones (técnico pide material)
CREATE TABLE IF NOT EXISTS climas_solicitudes_refacciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE CASCADE,
    orden_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE SET NULL,
    items JSONB NOT NULL, -- [{producto_id, cantidad, urgente}]
    estado TEXT DEFAULT 'pendiente', -- pendiente, aprobada, entregada, rechazada
    notas TEXT,
    respuesta_admin TEXT,
    fecha_aprobacion TIMESTAMPTZ,
    fecha_entrega TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Problemas/Incidencias reportadas
CREATE TABLE IF NOT EXISTS climas_incidencias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    orden_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE SET NULL,
    tecnico_id UUID REFERENCES climas_tecnicos(id),
    cliente_id UUID REFERENCES climas_clientes(id),
    tipo TEXT NOT NULL, -- cliente_ausente, acceso_negado, equipo_inaccesible, material_faltante, otro
    descripcion TEXT NOT NULL,
    fotos JSONB DEFAULT '[]',
    gravedad TEXT DEFAULT 'media', -- baja, media, alta
    estado TEXT DEFAULT 'abierta', -- abierta, en_revision, resuelta
    resolucion TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Capacitaciones/Certificaciones de técnicos
CREATE TABLE IF NOT EXISTS climas_certificaciones_tecnico (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL, -- "Certificación Carrier", "Curso Refrigerantes R410A"
    institucion TEXT,
    fecha_obtencion DATE,
    fecha_vencimiento DATE,
    documento_url TEXT,
    estado TEXT DEFAULT 'vigente', -- vigente, por_vencer, vencida
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PARA EL ADMINISTRADOR: Gestión avanzada
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Movimientos de inventario
CREATE TABLE IF NOT EXISTS climas_movimientos_inventario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES climas_productos(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- entrada, salida, ajuste, transferencia
    cantidad INTEGER NOT NULL,
    stock_anterior INTEGER,
    stock_nuevo INTEGER,
    orden_id UUID REFERENCES climas_ordenes_servicio(id),
    tecnico_id UUID REFERENCES climas_tecnicos(id),
    motivo TEXT,
    documento_referencia TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Métricas de técnicos (para evaluación)
CREATE TABLE IF NOT EXISTS climas_metricas_tecnico (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE CASCADE,
    periodo TEXT NOT NULL, -- '2026-01', '2026-W03' (semana)
    ordenes_completadas INTEGER DEFAULT 0,
    ordenes_canceladas INTEGER DEFAULT 0,
    tiempo_promedio_servicio INTEGER DEFAULT 0, -- minutos
    calificacion_promedio DECIMAL(3,2) DEFAULT 0,
    ingresos_generados DECIMAL(14,2) DEFAULT 0,
    comision_generada DECIMAL(14,2) DEFAULT 0,
    incidencias_reportadas INTEGER DEFAULT 0,
    puntualidad_porcentaje DECIMAL(5,2) DEFAULT 100,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tecnico_id, periodo)
);

-- Zonas de servicio (para asignación inteligente)
CREATE TABLE IF NOT EXISTS climas_zonas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL, -- "Zona Norte", "Centro Histórico"
    descripcion TEXT,
    colonias TEXT[], -- Array de colonias que cubre
    codigos_postales TEXT[], -- Array de CPs
    poligono JSONB, -- Coordenadas del polígono en mapa
    color TEXT DEFAULT '#00D9FF',
    activa BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Asignación de zonas a técnicos
CREATE TABLE IF NOT EXISTS climas_tecnico_zonas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE CASCADE,
    zona_id UUID REFERENCES climas_zonas(id) ON DELETE CASCADE,
    es_principal BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tecnico_id, zona_id)
);

-- Precios por tipo de servicio
CREATE TABLE IF NOT EXISTS climas_precios_servicio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL, -- "Mantenimiento Básico", "Instalación 1 Ton"
    tipo_servicio TEXT, -- mantenimiento, instalacion, reparacion
    descripcion TEXT,
    incluye TEXT[], -- Array de lo que incluye
    precio_base DECIMAL(14,2) DEFAULT 0,
    tiempo_estimado INTEGER DEFAULT 60, -- minutos
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cotizaciones detalladas
CREATE TABLE IF NOT EXISTS climas_cotizaciones_v2 (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE SET NULL,
    folio TEXT,
    fecha DATE DEFAULT CURRENT_DATE,
    vigencia_dias INTEGER DEFAULT 15,
    items JSONB NOT NULL, -- [{descripcion, cantidad, precio_unitario, total}]
    subtotal DECIMAL(14,2) DEFAULT 0,
    descuento DECIMAL(14,2) DEFAULT 0,
    iva DECIMAL(14,2) DEFAULT 0,
    total DECIMAL(14,2) DEFAULT 0,
    notas TEXT,
    estado TEXT DEFAULT 'enviada', -- borrador, enviada, aceptada, rechazada, vencida
    fecha_respuesta DATE,
    orden_generada_id UUID REFERENCES climas_ordenes_servicio(id),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Agenda/Calendario de servicios
CREATE TABLE IF NOT EXISTS climas_calendario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    orden_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE CASCADE,
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME,
    duracion_estimada INTEGER DEFAULT 60, -- minutos
    confirmado BOOLEAN DEFAULT FALSE,
    recordatorio_enviado BOOLEAN DEFAULT FALSE,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Comisiones de técnicos
CREATE TABLE IF NOT EXISTS climas_comisiones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE CASCADE,
    orden_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE SET NULL,
    periodo TEXT, -- '2026-01'
    tipo TEXT DEFAULT 'servicio', -- servicio, venta, bono
    base_calculo DECIMAL(14,2) DEFAULT 0, -- Monto sobre el que se calcula
    porcentaje DECIMAL(5,2) DEFAULT 0,
    monto DECIMAL(14,2) DEFAULT 0,
    estado TEXT DEFAULT 'pendiente', -- pendiente, aprobada, pagada
    fecha_pago DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Configuración del módulo
CREATE TABLE IF NOT EXISTS climas_configuracion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    config_key TEXT NOT NULL,
    config_value JSONB,
    descripcion TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(negocio_id, config_key)
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ÍNDICES PARA PERFORMANCE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE INDEX IF NOT EXISTS idx_climas_solicitudes_cliente ON climas_solicitudes_cliente(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_solicitudes_estado ON climas_solicitudes_cliente(estado);
CREATE INDEX IF NOT EXISTS idx_climas_recordatorios_fecha ON climas_recordatorios_mantenimiento(fecha_programada);
CREATE INDEX IF NOT EXISTS idx_climas_garantias_cliente ON climas_garantias(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_garantias_equipo ON climas_garantias(equipo_id);
CREATE INDEX IF NOT EXISTS idx_climas_comprobantes_cliente ON climas_comprobantes(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_mensajes_cliente ON climas_mensajes(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_mensajes_orden ON climas_mensajes(orden_id);
CREATE INDEX IF NOT EXISTS idx_climas_registro_tiempo_orden ON climas_registro_tiempo(orden_id);
CREATE INDEX IF NOT EXISTS idx_climas_inventario_tecnico ON climas_inventario_tecnico(tecnico_id);
CREATE INDEX IF NOT EXISTS idx_climas_productos_negocio ON climas_productos(negocio_id);
-- Solo crear índice de categoría si la columna existe
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'climas_productos' AND column_name = 'categoria') THEN
        CREATE INDEX IF NOT EXISTS idx_climas_productos_categoria ON climas_productos(categoria);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_climas_movimientos_producto ON climas_movimientos_inventario(producto_id);
CREATE INDEX IF NOT EXISTS idx_climas_metricas_tecnico ON climas_metricas_tecnico(tecnico_id, periodo);
CREATE INDEX IF NOT EXISTS idx_climas_calendario_fecha ON climas_calendario(fecha);
CREATE INDEX IF NOT EXISTS idx_climas_calendario_tecnico ON climas_calendario(tecnico_id);
CREATE INDEX IF NOT EXISTS idx_climas_cotizaciones_v2_cliente ON climas_cotizaciones_v2(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_comisiones_tecnico ON climas_comisiones(tecnico_id);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RLS (ROW LEVEL SECURITY)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ALTER TABLE climas_solicitudes_cliente ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_recordatorios_mantenimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_garantias ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_comprobantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_mensajes ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_checklist_servicio ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_checklist_respuestas ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_registro_tiempo ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_inventario_tecnico ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_solicitudes_refacciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_incidencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_certificaciones_tecnico ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_movimientos_inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_metricas_tecnico ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_zonas ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_tecnico_zonas ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_precios_servicio ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_cotizaciones_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_calendario ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_comisiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_configuracion ENABLE ROW LEVEL SECURITY;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- POLÍTICAS DE ACCESO
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE POLICY "climas_solicitudes_access" ON climas_solicitudes_cliente FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_recordatorios_access" ON climas_recordatorios_mantenimiento FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_garantias_access" ON climas_garantias FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_comprobantes_access" ON climas_comprobantes FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_mensajes_access" ON climas_mensajes FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_checklist_access" ON climas_checklist_servicio FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_checklist_resp_access" ON climas_checklist_respuestas FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_registro_tiempo_access" ON climas_registro_tiempo FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_inv_tecnico_access" ON climas_inventario_tecnico FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_sol_refacciones_access" ON climas_solicitudes_refacciones FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_incidencias_access" ON climas_incidencias FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_cert_tecnico_access" ON climas_certificaciones_tecnico FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_productos_access" ON climas_productos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_mov_inv_access" ON climas_movimientos_inventario FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_metricas_access" ON climas_metricas_tecnico FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_zonas_access" ON climas_zonas FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_tecnico_zonas_access" ON climas_tecnico_zonas FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_precios_access" ON climas_precios_servicio FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_cotizaciones_v2_access" ON climas_cotizaciones_v2 FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_calendario_access" ON climas_calendario FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_comisiones_access" ON climas_comisiones FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_config_access" ON climas_configuracion FOR ALL USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN MIGRACIÓN CLIMAS PROFESIONAL V10.50
-- ══════════════════════════════════════════════════════════════════════════════
