-- ══════════════════════════════════════════════════════════════════════════════
-- SINCRONIZACIÓN SUPABASE - PARTE 2: MÓDULOS ESPECIALIZADOS
-- Robert Darin Fintech V10.30
-- 
-- EJECUTAR DESPUÉS DE sync_supabase_part1_core.sql
-- ══════════════════════════════════════════════════════════════════════════════

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: PRÉSTAMOS DIARIOS (ARQUILADO)
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS prestamos_diarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    cobrador_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
    monto_prestado NUMERIC(12,2) NOT NULL,
    monto_total NUMERIC(12,2) NOT NULL,
    numero_pagos INT NOT NULL DEFAULT 12,
    monto_pago_diario NUMERIC(12,2) NOT NULL,
    fecha_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin DATE,
    dias_pagados INT DEFAULT 0,
    monto_pagado NUMERIC(12,2) DEFAULT 0,
    saldo_pendiente NUMERIC(12,2),
    estado TEXT DEFAULT 'activo',
    variante TEXT DEFAULT 'clasico',
    dias_mora INT DEFAULT 0,
    ultimo_pago DATE,
    notas TEXT,
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pagos_diarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestamo_diario_id UUID REFERENCES prestamos_diarios(id) ON DELETE CASCADE,
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    monto NUMERIC(12,2) NOT NULL,
    numero_pago INT NOT NULL,
    fecha_pago TIMESTAMPTZ DEFAULT NOW(),
    metodo_pago TEXT DEFAULT 'efectivo',
    registrado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    nota TEXT,
    comprobante_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: AUDITORÍA LEGAL
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS expedientes_legales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
    numero_expediente TEXT,
    tipo_expediente TEXT DEFAULT 'cobranza',
    descripcion TEXT,
    estado TEXT DEFAULT 'abierto',
    fecha_apertura DATE DEFAULT CURRENT_DATE,
    fecha_cierre DATE,
    monto_reclamado NUMERIC(14,2),
    monto_recuperado NUMERIC(14,2) DEFAULT 0,
    abogado_responsable TEXT,
    juzgado TEXT,
    numero_juicio TEXT,
    proxima_audiencia TIMESTAMPTZ,
    observaciones TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS seguimiento_judicial (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expediente_id UUID REFERENCES expedientes_legales(id) ON DELETE CASCADE,
    fecha_evento TIMESTAMPTZ DEFAULT NOW(),
    tipo_evento TEXT NOT NULL,
    descripcion TEXT,
    resultado TEXT,
    documento_url TEXT,
    realizado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS documentos_legales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expediente_id UUID REFERENCES expedientes_legales(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    tipo TEXT,
    archivo_url TEXT NOT NULL,
    descripcion TEXT,
    fecha_documento DATE DEFAULT CURRENT_DATE,
    subido_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: COMPROBANTES Y AUDITORÍA
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS comprobantes_prestamo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
    tipo_comprobante TEXT NOT NULL,
    archivo_url TEXT NOT NULL,
    descripcion TEXT,
    verificado BOOLEAN DEFAULT FALSE,
    verificado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    fecha_verificacion TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auditoria_acciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    tabla TEXT NOT NULL,
    registro_id UUID NOT NULL,
    accion TEXT NOT NULL,
    datos_antes JSONB,
    datos_despues JSONB,
    ip_address TEXT,
    user_agent TEXT,
    dispositivo TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS login_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    email TEXT,
    ip_address TEXT,
    user_agent TEXT,
    dispositivo TEXT,
    ubicacion TEXT,
    exito BOOLEAN DEFAULT true,
    motivo_fallo TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: MIS PROPIEDADES
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS mis_propiedades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo_propiedad TEXT DEFAULT 'terreno',
    nombre TEXT NOT NULL,
    descripcion TEXT,
    direccion TEXT,
    superficie_m2 NUMERIC(12,2),
    precio_compra NUMERIC(14,2),
    precio_actual NUMERIC(14,2),
    estado_pago TEXT DEFAULT 'pendiente',
    total_pagado NUMERIC(14,2) DEFAULT 0,
    saldo_pendiente NUMERIC(14,2),
    fecha_compra DATE,
    fecha_liquidacion DATE,
    vendedor TEXT,
    notas TEXT,
    documentos JSONB DEFAULT '[]',
    imagenes JSONB DEFAULT '[]',
    ubicacion_lat DECIMAL(10, 8),
    ubicacion_lng DECIMAL(11, 8),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pagos_propiedades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    propiedad_id UUID REFERENCES mis_propiedades(id) ON DELETE CASCADE,
    monto NUMERIC(14,2) NOT NULL,
    fecha_pago TIMESTAMPTZ DEFAULT NOW(),
    metodo_pago TEXT DEFAULT 'efectivo',
    comprobante_url TEXT,
    nota TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: COLABORADORES
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS colaboradores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    puesto TEXT,
    departamento TEXT,
    fecha_ingreso DATE DEFAULT CURRENT_DATE,
    salario NUMERIC(12,2),
    tipo_contrato TEXT DEFAULT 'tiempo_completo',
    activo BOOLEAN DEFAULT true,
    foto_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS colaborador_documentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID REFERENCES colaboradores(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    tipo TEXT,
    archivo_url TEXT NOT NULL,
    fecha_subida TIMESTAMPTZ DEFAULT NOW(),
    fecha_vencimiento DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS colaborador_asistencias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID REFERENCES colaboradores(id) ON DELETE CASCADE,
    fecha DATE DEFAULT CURRENT_DATE,
    hora_entrada TIME,
    hora_salida TIME,
    tipo TEXT DEFAULT 'normal',
    notas TEXT,
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS colaborador_nominas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID REFERENCES colaboradores(id) ON DELETE CASCADE,
    periodo_inicio DATE NOT NULL,
    periodo_fin DATE NOT NULL,
    salario_base NUMERIC(12,2) NOT NULL,
    deducciones NUMERIC(12,2) DEFAULT 0,
    bonos NUMERIC(12,2) DEFAULT 0,
    total_pagar NUMERIC(12,2) NOT NULL,
    estado TEXT DEFAULT 'pendiente',
    fecha_pago TIMESTAMPTZ,
    comprobante_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: NICE JOYERÍA MLM
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS nice_productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    codigo TEXT,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    categoria TEXT,
    precio_publico NUMERIC(12,2) NOT NULL,
    precio_distribuidor NUMERIC(12,2),
    costo NUMERIC(12,2),
    stock INT DEFAULT 0,
    imagen_url TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS nice_distribuidores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    codigo_distribuidor TEXT UNIQUE,
    nombre TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    nivel INT DEFAULT 1,
    patrocinador_id UUID REFERENCES nice_distribuidores(id) ON DELETE SET NULL,
    fecha_ingreso DATE DEFAULT CURRENT_DATE,
    activo BOOLEAN DEFAULT true,
    volumen_personal NUMERIC(14,2) DEFAULT 0,
    volumen_grupo NUMERIC(14,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS nice_ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    distribuidor_id UUID REFERENCES nice_distribuidores(id) ON DELETE CASCADE,
    cliente_nombre TEXT,
    cliente_telefono TEXT,
    total NUMERIC(14,2) NOT NULL,
    comision NUMERIC(12,2) DEFAULT 0,
    estado TEXT DEFAULT 'pendiente',
    fecha_venta TIMESTAMPTZ DEFAULT NOW(),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS nice_venta_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venta_id UUID REFERENCES nice_ventas(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES nice_productos(id) ON DELETE SET NULL,
    cantidad INT NOT NULL DEFAULT 1,
    precio_unitario NUMERIC(12,2) NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS nice_comisiones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    distribuidor_id UUID REFERENCES nice_distribuidores(id) ON DELETE CASCADE,
    venta_id UUID REFERENCES nice_ventas(id) ON DELETE SET NULL,
    tipo TEXT NOT NULL,
    monto NUMERIC(12,2) NOT NULL,
    nivel_generacion INT DEFAULT 1,
    descripcion TEXT,
    estado TEXT DEFAULT 'pendiente',
    fecha_pago TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS nice_inventario_movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID REFERENCES nice_productos(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    cantidad INT NOT NULL,
    stock_anterior INT,
    stock_nuevo INT,
    motivo TEXT,
    referencia_id UUID,
    registrado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: CLIMAS (AIRES ACONDICIONADOS)
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS climas_equipos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    marca TEXT,
    modelo TEXT,
    capacidad_btu INT,
    tipo TEXT,
    numero_serie TEXT,
    ubicacion TEXT,
    fecha_instalacion DATE,
    garantia_hasta DATE,
    estado TEXT DEFAULT 'activo',
    notas TEXT,
    foto_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS climas_servicios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipo_id UUID REFERENCES climas_equipos(id) ON DELETE CASCADE,
    tipo_servicio TEXT NOT NULL,
    descripcion TEXT,
    fecha_servicio TIMESTAMPTZ DEFAULT NOW(),
    fecha_programada TIMESTAMPTZ,
    tecnico_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
    costo NUMERIC(12,2),
    estado TEXT DEFAULT 'programado',
    observaciones TEXT,
    evidencia_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS climas_refacciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    codigo TEXT,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    precio NUMERIC(12,2),
    stock INT DEFAULT 0,
    stock_minimo INT DEFAULT 5,
    proveedor TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS climas_servicio_refacciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    servicio_id UUID REFERENCES climas_servicios(id) ON DELETE CASCADE,
    refaccion_id UUID REFERENCES climas_refacciones(id) ON DELETE SET NULL,
    cantidad INT NOT NULL DEFAULT 1,
    precio_unitario NUMERIC(12,2),
    subtotal NUMERIC(12,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: PURIFICADORA DE AGUA
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS purificadora_clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    nombre TEXT NOT NULL,
    telefono TEXT,
    direccion TEXT,
    referencias TEXT,
    tipo_cliente TEXT DEFAULT 'regular',
    garrafones_prestados INT DEFAULT 0,
    saldo_garrafones INT DEFAULT 0,
    credito_disponible NUMERIC(12,2) DEFAULT 0,
    activo BOOLEAN DEFAULT true,
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS purificadora_rutas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    repartidor_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
    dias_servicio TEXT[],
    activa BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS purificadora_ruta_clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ruta_id UUID REFERENCES purificadora_rutas(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES purificadora_clientes(id) ON DELETE CASCADE,
    orden INT DEFAULT 0,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS purificadora_ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES purificadora_clientes(id) ON DELETE SET NULL,
    ruta_id UUID REFERENCES purificadora_rutas(id) ON DELETE SET NULL,
    repartidor_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
    garrafones_vendidos INT DEFAULT 0,
    garrafones_prestados INT DEFAULT 0,
    garrafones_devueltos INT DEFAULT 0,
    precio_unitario NUMERIC(8,2) NOT NULL,
    total NUMERIC(12,2) NOT NULL,
    metodo_pago TEXT DEFAULT 'efectivo',
    es_credito BOOLEAN DEFAULT false,
    fecha_venta TIMESTAMPTZ DEFAULT NOW(),
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS purificadora_inventario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    garrafones_disponibles INT DEFAULT 0,
    garrafones_en_ruta INT DEFAULT 0,
    garrafones_prestados_total INT DEFAULT 0,
    litros_agua_disponibles NUMERIC(12,2) DEFAULT 0,
    fecha_corte DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: VENTAS GENERAL
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    codigo TEXT,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    categoria TEXT,
    precio NUMERIC(12,2) NOT NULL,
    costo NUMERIC(12,2),
    stock INT DEFAULT 0,
    stock_minimo INT DEFAULT 10,
    unidad TEXT DEFAULT 'pieza',
    imagen_url TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    vendedor_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
    total NUMERIC(14,2) NOT NULL,
    descuento NUMERIC(12,2) DEFAULT 0,
    impuestos NUMERIC(12,2) DEFAULT 0,
    metodo_pago TEXT DEFAULT 'efectivo',
    estado TEXT DEFAULT 'completada',
    notas TEXT,
    fecha_venta TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS venta_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venta_id UUID REFERENCES ventas(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES productos(id) ON DELETE SET NULL,
    cantidad INT NOT NULL DEFAULT 1,
    precio_unitario NUMERIC(12,2) NOT NULL,
    descuento NUMERIC(12,2) DEFAULT 0,
    subtotal NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: FACTURACIÓN
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS facturas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    serie TEXT DEFAULT 'A',
    folio INT NOT NULL,
    uuid_cfdi TEXT UNIQUE,
    tipo_comprobante TEXT DEFAULT 'I',
    forma_pago TEXT,
    metodo_pago TEXT,
    uso_cfdi TEXT DEFAULT 'G03',
    subtotal NUMERIC(14,2) NOT NULL,
    descuento NUMERIC(14,2) DEFAULT 0,
    impuestos NUMERIC(14,2) DEFAULT 0,
    total NUMERIC(14,2) NOT NULL,
    estado TEXT DEFAULT 'emitida',
    fecha_emision TIMESTAMPTZ DEFAULT NOW(),
    fecha_timbrado TIMESTAMPTZ,
    xml_url TEXT,
    pdf_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS factura_conceptos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    factura_id UUID REFERENCES facturas(id) ON DELETE CASCADE,
    clave_producto TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    cantidad NUMERIC(12,4) NOT NULL,
    unidad TEXT DEFAULT 'E48',
    precio_unitario NUMERIC(14,4) NOT NULL,
    descuento NUMERIC(14,2) DEFAULT 0,
    subtotal NUMERIC(14,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS datos_fiscales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    rfc TEXT NOT NULL,
    razon_social TEXT NOT NULL,
    regimen_fiscal TEXT NOT NULL,
    codigo_postal TEXT NOT NULL,
    direccion_fiscal TEXT,
    email_facturacion TEXT,
    es_principal BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- MÓDULO: QR COBROS
-- ██████████████████████████████████████████████████████████████████████████████

CREATE TABLE IF NOT EXISTS qr_cobros (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    tipo TEXT DEFAULT 'general',
    monto_fijo NUMERIC(12,2),
    monto_minimo NUMERIC(12,2),
    monto_maximo NUMERIC(12,2),
    referencia_tipo TEXT,
    referencia_id UUID,
    codigo_qr TEXT UNIQUE NOT NULL,
    activo BOOLEAN DEFAULT true,
    usos INT DEFAULT 0,
    max_usos INT,
    fecha_expiracion TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS qr_transacciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    qr_cobro_id UUID REFERENCES qr_cobros(id) ON DELETE SET NULL,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    monto NUMERIC(12,2) NOT NULL,
    metodo_pago TEXT NOT NULL,
    referencia_pago TEXT,
    estado TEXT DEFAULT 'completada',
    datos_adicionales JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- RLS Y POLÍTICAS PARA NUEVAS TABLAS
-- ██████████████████████████████████████████████████████████████████████████████

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' 
    LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(t) || ' ENABLE ROW LEVEL SECURITY;';
    END LOOP;
END $$;

-- Políticas para tablas de módulos especializados
DO $$ 
BEGIN 
    -- PRESTAMOS DIARIOS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'prestamos_diarios_auth') THEN
        CREATE POLICY "prestamos_diarios_auth" ON prestamos_diarios FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'pagos_diarios_auth') THEN
        CREATE POLICY "pagos_diarios_auth" ON pagos_diarios FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- AUDITORÍA LEGAL
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'expedientes_legales_auth') THEN
        CREATE POLICY "expedientes_legales_auth" ON expedientes_legales FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'seguimiento_judicial_auth') THEN
        CREATE POLICY "seguimiento_judicial_auth" ON seguimiento_judicial FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'documentos_legales_auth') THEN
        CREATE POLICY "documentos_legales_auth" ON documentos_legales FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- PROPIEDADES
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'mis_propiedades_own') THEN
        CREATE POLICY "mis_propiedades_own" ON mis_propiedades FOR ALL USING (auth.uid() = usuario_id OR es_admin_o_superior());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'pagos_propiedades_auth') THEN
        CREATE POLICY "pagos_propiedades_auth" ON pagos_propiedades FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- COLABORADORES
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'colaboradores_auth') THEN
        CREATE POLICY "colaboradores_auth" ON colaboradores FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- NICE
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'nice_productos_auth') THEN
        CREATE POLICY "nice_productos_auth" ON nice_productos FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'nice_distribuidores_auth') THEN
        CREATE POLICY "nice_distribuidores_auth" ON nice_distribuidores FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'nice_ventas_auth') THEN
        CREATE POLICY "nice_ventas_auth" ON nice_ventas FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- CLIMAS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'climas_equipos_auth') THEN
        CREATE POLICY "climas_equipos_auth" ON climas_equipos FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'climas_servicios_auth') THEN
        CREATE POLICY "climas_servicios_auth" ON climas_servicios FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- PURIFICADORA
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'purificadora_clientes_auth') THEN
        CREATE POLICY "purificadora_clientes_auth" ON purificadora_clientes FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'purificadora_ventas_auth') THEN
        CREATE POLICY "purificadora_ventas_auth" ON purificadora_ventas FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- VENTAS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'productos_auth') THEN
        CREATE POLICY "productos_auth" ON productos FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'ventas_auth') THEN
        CREATE POLICY "ventas_auth" ON ventas FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- FACTURACIÓN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'facturas_auth') THEN
        CREATE POLICY "facturas_auth" ON facturas FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'datos_fiscales_auth') THEN
        CREATE POLICY "datos_fiscales_auth" ON datos_fiscales FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- QR
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'qr_cobros_auth') THEN
        CREATE POLICY "qr_cobros_auth" ON qr_cobros FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'qr_transacciones_auth') THEN
        CREATE POLICY "qr_transacciones_auth" ON qr_transacciones FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- AUDITORÍA
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_acciones_admin') THEN
        CREATE POLICY "auditoria_acciones_admin" ON auditoria_acciones FOR SELECT USING (es_admin_o_superior());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_acciones_insert') THEN
        CREATE POLICY "auditoria_acciones_insert" ON auditoria_acciones FOR INSERT WITH CHECK (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'login_history_own') THEN
        CREATE POLICY "login_history_own" ON login_history FOR SELECT USING (usuario_id = auth.uid() OR es_admin_o_superior());
    END IF;
END $$;

-- Índices para módulos especializados
CREATE INDEX IF NOT EXISTS idx_prestamos_diarios_cliente ON prestamos_diarios(cliente_id);
CREATE INDEX IF NOT EXISTS idx_prestamos_diarios_negocio ON prestamos_diarios(negocio_id);
CREATE INDEX IF NOT EXISTS idx_prestamos_diarios_estado ON prestamos_diarios(estado);
CREATE INDEX IF NOT EXISTS idx_pagos_diarios_prestamo ON pagos_diarios(prestamo_diario_id);
CREATE INDEX IF NOT EXISTS idx_expedientes_cliente ON expedientes_legales(cliente_id);
CREATE INDEX IF NOT EXISTS idx_expedientes_estado ON expedientes_legales(estado);
CREATE INDEX IF NOT EXISTS idx_mis_propiedades_usuario ON mis_propiedades(usuario_id);
CREATE INDEX IF NOT EXISTS idx_colaboradores_negocio ON colaboradores(negocio_id);
CREATE INDEX IF NOT EXISTS idx_nice_distribuidores_patron ON nice_distribuidores(patrocinador_id);
CREATE INDEX IF NOT EXISTS idx_nice_ventas_dist ON nice_ventas(distribuidor_id);
CREATE INDEX IF NOT EXISTS idx_climas_equipos_cliente ON climas_equipos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_servicios_equipo ON climas_servicios(equipo_id);
CREATE INDEX IF NOT EXISTS idx_purificadora_ventas_cliente ON purificadora_ventas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_facturas_cliente ON facturas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_facturas_negocio ON facturas(negocio_id);
CREATE INDEX IF NOT EXISTS idx_qr_cobros_negocio ON qr_cobros(negocio_id);

-- Verificación
SELECT 'MÓDULOS ESPECIALIZADOS SINCRONIZADOS' AS status, COUNT(*) AS tablas_totales
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
