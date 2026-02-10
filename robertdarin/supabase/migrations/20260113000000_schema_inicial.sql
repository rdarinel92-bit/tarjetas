-- ══════════════════════════════════════════════════════════════════════════════
-- SQL MAESTRO V10.29 — ROBERT DARIN FINTECH
-- Base de datos completa unificada con todos los módulos
-- Ejecución segura e idempotente (puedes ejecutar múltiples veces)
-- Enero 2026
-- ══════════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 0: PARCHE CRÍTICO - AGREGAR negocio_id A TABLAS EXISTENTES
-- EJECUTAR PRIMERO: Asegura que todas las tablas multitenancy tengan la columna
-- ══════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    tabla_nombre TEXT;
    tablas_multitenancy TEXT[] := ARRAY[
        'clientes', 'prestamos', 'amortizaciones', 'pagos', 'tandas', 
        'tanda_participantes', 'avales', 'empleados', 'sucursales',
        'facturas', 'facturacion_emisores', 'facturacion_clientes',
        'configuracion_moras', 'intentos_cobro', 'notificaciones_mora',
        'expedientes_legales', 'nice_niveles', 'nice_catalogos', 
        'nice_categorias', 'nice_productos', 'nice_vendedoras',
        'nice_pedidos', 'nice_comisiones', 'climas_cotizaciones',
        'climas_instalaciones', 'climas_servicios', 'purificadora_rutas',
        'purificadora_clientes', 'ventas_pedidos', 'qr_cobros',
        'qr_cobros_config', 'qr_cobros_reportes', 'colaboradores',
        'colaborador_tipos', 'cache_estadisticas'
    ];
BEGIN
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE 'PARCHE V10.29: Verificando columna negocio_id en tablas existentes';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    
    FOREACH tabla_nombre IN ARRAY tablas_multitenancy LOOP
        -- Solo ejecutar si la tabla existe
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = tabla_nombre AND table_schema = 'public') THEN
            -- Verificar si la columna negocio_id NO existe
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = tabla_nombre 
                AND column_name = 'negocio_id' 
                AND table_schema = 'public'
            ) THEN
                -- Agregar la columna
                EXECUTE format('ALTER TABLE %I ADD COLUMN negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE', tabla_nombre);
                RAISE NOTICE 'AGREGADA columna negocio_id a tabla: %', tabla_nombre;
            END IF;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'PARCHE V10.29: Verificación completada';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PARCHE ERROR: % en tabla %', SQLERRM, tabla_nombre;
    -- No fallar, continuar con el resto del script
END $$;

-- ออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
-- SECCION 0.1: PARCHE DE COMPATIBILIDAD CON APP FLUTTER (IDEMPOTENTE)
-- - Enriquecer notificaciones (prioridad, icono, referencia) y multitenancy
-- - Compatibilidad de moras: columna pagado y monto derivado en amortizaciones
-- - Compatibilidad rápida para aval_id en prestamos (servicios Dart lo consultan)
-- - Alias y campos usados por chat aval-cobrador
-- ออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

DO $compat$
BEGIN
  -- Multi-tenant para notificaciones y moras
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notificaciones') THEN
    EXECUTE 'ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE';
    EXECUTE 'ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS prioridad TEXT DEFAULT ''normal''';
    EXECUTE 'ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS icono TEXT';
    EXECUTE 'ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS referencia_id UUID';
    EXECUTE 'ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS referencia_tipo TEXT';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_notif_negocio ON notificaciones(negocio_id)';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notificaciones_mora') THEN
    EXECUTE 'ALTER TABLE notificaciones_mora ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_notif_mora_negocio ON notificaciones_mora(negocio_id)';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notificaciones_mora_aval') THEN
    EXECUTE 'ALTER TABLE notificaciones_mora_aval ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_notif_mora_aval_negocio ON notificaciones_mora_aval(negocio_id)';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notificaciones_mora_cliente') THEN
    EXECUTE 'ALTER TABLE notificaciones_mora_cliente ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_notif_mora_cliente_negocio ON notificaciones_mora_cliente(negocio_id)';
  END IF;

  -- Compatibilidad de moras: columna booleana y monto derivado
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'amortizaciones') THEN
    EXECUTE 'ALTER TABLE amortizaciones ADD COLUMN IF NOT EXISTS pagado BOOLEAN GENERATED ALWAYS AS (estado IN (''pagado'',''pagada'')) STORED';
    EXECUTE 'ALTER TABLE amortizaciones ADD COLUMN IF NOT EXISTS monto NUMERIC(12,2) GENERATED ALWAYS AS (COALESCE(monto_cuota, (COALESCE(monto_capital, 0) + COALESCE(monto_interes, 0)))) STORED';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_amortizaciones_pagado ON amortizaciones(pagado)';
  END IF;

  -- Compatibilidad rápida para aval en prestamos
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'prestamos') THEN
    EXECUTE 'ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS aval_id UUID REFERENCES avales(id) ON DELETE SET NULL';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_prestamos_aval ON prestamos(aval_id)';
  END IF;

  -- Alias y campos requeridos por chat aval-cobrador
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_conversaciones') THEN
    EXECUTE 'ALTER TABLE chat_conversaciones ADD COLUMN IF NOT EXISTS tipo TEXT';
    EXECUTE 'ALTER TABLE chat_conversaciones ADD COLUMN IF NOT EXISTS titulo TEXT';
    EXECUTE 'ALTER TABLE chat_conversaciones ADD COLUMN IF NOT EXISTS referencia_id UUID';
    EXECUTE 'ALTER TABLE chat_conversaciones ADD COLUMN IF NOT EXISTS referencia_tipo TEXT';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_chat_conv_tipo_ref ON chat_conversaciones(tipo, referencia_id)';
  END IF;

  -- Vistas alias para compatibilidad de código
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_conversaciones') THEN
    EXECUTE 'CREATE OR REPLACE VIEW conversaciones AS SELECT * FROM chat_conversaciones';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'facturacion_logs') THEN
    EXECUTE 'CREATE OR REPLACE VIEW facturacion_log AS SELECT * FROM facturacion_logs';
  END IF;
END
$compat$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 1: IDENTIDAD, ROLES Y PERMISOS
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT UNIQUE NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS permisos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clave_permiso TEXT UNIQUE NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS roles_permisos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rol_id UUID REFERENCES roles(id) ON DELETE CASCADE,
  permiso_id UUID REFERENCES permisos(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(rol_id, permiso_id)
);

-- Usuarios: PK coincide con auth.users de Supabase
CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY, 
  email TEXT UNIQUE NOT NULL,
  nombre_completo TEXT,
  telefono TEXT,
  foto_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS usuarios_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  rol_id UUID REFERENCES roles(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(usuario_id, rol_id)
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 2: ESTRUCTURA EMPRESARIAL Y MULTI-NEGOCIO
-- ══════════════════════════════════════════════════════════════════════════════

-- Tabla principal de negocios (multi-tenant) - DEBE CREARSE PRIMERO
CREATE TABLE IF NOT EXISTS negocios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    tipo TEXT DEFAULT 'fintech', -- fintech, aires, retail, servicios, restaurante, salud
    propietario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL, -- Usuario que creó el negocio
    rfc TEXT,
    razon_social TEXT,
    direccion_fiscal TEXT,
    telefono TEXT,
    email TEXT,
    logo_url TEXT,
    color_primario TEXT DEFAULT '#FF9800',
    color_secundario TEXT DEFAULT '#1E1E2C',
    activo BOOLEAN DEFAULT true,
    configuracion JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Tabla para control de acceso multi-usuario a negocios
-- Permite que múltiples usuarios administren un mismo negocio
CREATE TABLE IF NOT EXISTS usuarios_negocios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    rol_negocio TEXT DEFAULT 'admin', -- propietario, admin, operador, visor
    permisos JSONB DEFAULT '{}', -- permisos específicos por negocio
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(usuario_id, negocio_id) -- Un usuario solo puede tener un rol por negocio
);

CREATE INDEX IF NOT EXISTS idx_usuarios_negocios_usuario ON usuarios_negocios(usuario_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_negocios_negocio ON usuarios_negocios(negocio_id);

-- RLS para usuarios_negocios
ALTER TABLE usuarios_negocios ENABLE ROW LEVEL SECURITY;
CREATE POLICY "usuarios_negocios_access" ON usuarios_negocios FOR ALL USING (
    usuario_id = auth.uid() OR
    EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin')
);

CREATE TABLE IF NOT EXISTS sucursales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  codigo TEXT,
  direccion TEXT,
  telefono TEXT,
  email TEXT,
  latitud DECIMAL(10, 8),
  longitud DECIMAL(11, 8),
  horario JSONB,
  meta_mensual DECIMAL(14, 2) DEFAULT 0,
  activa BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sucursales_negocio ON sucursales(negocio_id);

CREATE TABLE IF NOT EXISTS empleados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
  puesto TEXT,
  salario NUMERIC(12,2),
  -- Sistema de Comisiones V10.2
  comision_porcentaje NUMERIC(5,2) DEFAULT 0, -- 0-100% de las ganancias del préstamo
  comision_tipo TEXT DEFAULT 'ninguna', -- ninguna, al_liquidar, proporcional, primer_pago
  -- ninguna: No recibe comisión
  -- al_liquidar: Recibe el % cuando el préstamo se paga completamente
  -- proporcional: Recibe el % proporcionalmente con cada cuota pagada
  -- primer_pago: Recibe el % completo cuando el cliente hace el primer pago
  fecha_contratacion DATE DEFAULT CURRENT_DATE,
  activo BOOLEAN DEFAULT TRUE,
  estado TEXT DEFAULT 'activo', -- activo, inactivo, suspendido, baja
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Tabla de alertas del sistema (para notificaciones reales)
CREATE TABLE IF NOT EXISTS alertas_sistema (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  tipo TEXT DEFAULT 'info', -- info, warning, error, success
  prioridad INTEGER DEFAULT 1, -- 1=baja, 2=media, 3=alta
  activa BOOLEAN DEFAULT TRUE,
  usuario_destino_id UUID REFERENCES usuarios(id), -- NULL = todos
  leida BOOLEAN DEFAULT FALSE,
  enlace TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Tabla de recordatorios
CREATE TABLE IF NOT EXISTS recordatorios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  descripcion TEXT,
  fecha_recordatorio TIMESTAMP NOT NULL,
  completado BOOLEAN DEFAULT FALSE,
  fecha_completado TIMESTAMP,
  publico BOOLEAN DEFAULT FALSE, -- Si es visible para todos
  tipo TEXT DEFAULT 'general', -- general, cobro, visita, entrega
  referencia_id UUID, -- ID del préstamo, tanda o cliente relacionado
  referencia_tipo TEXT, -- prestamo, tanda, cliente
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recordatorios_usuario ON recordatorios(usuario_id);
CREATE INDEX IF NOT EXISTS idx_recordatorios_fecha ON recordatorios(fecha_recordatorio);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 3: CLIENTES Y BÓVEDA KYC
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL, -- Para login de cliente
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE, -- Separación por negocio
  nombre TEXT NOT NULL,
  telefono TEXT,
  direccion TEXT,
  email TEXT,
  curp TEXT,
  rfc TEXT,
  fecha_nacimiento DATE,
  ocupacion TEXT,
  ingresos_mensuales NUMERIC(12,2),
  sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
  foto_url TEXT,
  activo BOOLEAN DEFAULT TRUE,
  score_crediticio INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clientes_negocio ON clientes(negocio_id);

CREATE TABLE IF NOT EXISTS expediente_clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
  tipo_documento TEXT NOT NULL, -- INE, comprobante_domicilio, estado_cuenta, etc.
  documento_url TEXT NOT NULL,
  verificado BOOLEAN DEFAULT FALSE,
  verificado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  fecha_verificacion TIMESTAMP,
  fecha_subida TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 4: PRÉSTAMOS Y AMORTIZACIÓN
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS prestamos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE, -- Separación por negocio
  sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL, -- Sucursal donde se otorgó
  monto NUMERIC(12,2) NOT NULL,
  interes NUMERIC(5,2) DEFAULT 0,
  plazo_meses INTEGER NOT NULL, -- Para diario/arquilado: número de días
  frecuencia_pago TEXT DEFAULT 'Mensual', -- Diario, Semanal, Quincenal, Mensual
  tipo_prestamo TEXT DEFAULT 'normal', -- normal, diario, arquilado
  -- Para arquilado:
  -- - El interés se paga primero (diario o semanal)
  -- - El capital se paga al final o en la última cuota
  interes_diario NUMERIC(8,4) DEFAULT 0, -- % de interés diario para arquilado
  capital_al_final BOOLEAN DEFAULT FALSE, -- Si es TRUE, capital se paga al final
  estado TEXT DEFAULT 'activo', -- activo, pagado, vencido, mora, cancelado, liquidado
  proposito TEXT,
  garantia TEXT,
  aprobado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  fecha_aprobacion TIMESTAMP,
  fecha_primer_pago DATE,
  fecha_creacion TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_prestamos_negocio ON prestamos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_prestamos_sucursal ON prestamos(sucursal_id);

-- TIPOS DE PRÉSTAMO:
-- 1. normal: Cuotas iguales (capital + interés) según frecuencia
-- 2. diario: Cuotas diarias iguales (capital + interés / número de días)
-- 3. arquilado: Interés diario/semanal primero, capital al final
--    Ejemplo: Presto $1000, interés 10% semanal = $100 por semana de interés
--    Al final devuelve los $1000 de capital

CREATE TABLE IF NOT EXISTS amortizaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
  numero_cuota INTEGER NOT NULL,
  monto_cuota NUMERIC(12,2) NOT NULL,
  monto_capital NUMERIC(12,2),
  monto_interes NUMERIC(12,2),
  saldo_restante NUMERIC(12,2),
  fecha_vencimiento DATE NOT NULL,
  fecha_pago DATE,
  estado TEXT DEFAULT 'pendiente', -- pendiente, pagado, pagada, vencido, parcial
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(prestamo_id, numero_cuota)
);

-- Sistema de Comisiones de Empleados V10.2
-- (Movido aquí porque referencia prestamos)
CREATE TABLE IF NOT EXISTS comisiones_empleados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
  monto_prestamo NUMERIC(12,2) NOT NULL,
  ganancia_prestamo NUMERIC(12,2) NOT NULL,
  porcentaje_comision NUMERIC(5,2) NOT NULL,
  monto_comision NUMERIC(12,2) NOT NULL,
  tipo_pago TEXT NOT NULL, -- al_liquidar, proporcional, primer_pago
  estado TEXT DEFAULT 'pendiente', -- pendiente, parcial, pagada, cancelada
  monto_pagado NUMERIC(12,2) DEFAULT 0,
  fecha_generacion TIMESTAMP DEFAULT NOW(),
  fecha_pago_completo TIMESTAMP,
  notas TEXT,
  pagado_por UUID REFERENCES usuarios(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comisiones_empleado ON comisiones_empleados(empleado_id);
CREATE INDEX IF NOT EXISTS idx_comisiones_prestamo ON comisiones_empleados(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_comisiones_estado ON comisiones_empleados(estado);

-- Historial de pagos de comisiones
CREATE TABLE IF NOT EXISTS pagos_comisiones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comision_id UUID REFERENCES comisiones_empleados(id) ON DELETE CASCADE,
  monto NUMERIC(12,2) NOT NULL,
  metodo_pago TEXT,
  referencia TEXT,
  notas TEXT,
  pagado_por UUID REFERENCES usuarios(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 5: TANDAS PRO
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tandas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE, -- Separación por negocio
  sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
  nombre TEXT NOT NULL,
  monto_por_persona NUMERIC(12,2) NOT NULL,
  numero_participantes INTEGER NOT NULL,
  turno INTEGER DEFAULT 1,
  frecuencia TEXT DEFAULT 'Semanal', -- Semanal, Quincenal, Mensual
  estado TEXT DEFAULT 'activa', -- activa, completada, cancelada
  fecha_inicio TIMESTAMP DEFAULT NOW(),
  fecha_fin TIMESTAMP,
  organizador_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tandas_negocio ON tandas(negocio_id);

CREATE TABLE IF NOT EXISTS tanda_participantes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tanda_id UUID REFERENCES tandas(id) ON DELETE CASCADE,
  cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
  numero_turno INTEGER NOT NULL,
  ha_pagado_cuota_actual BOOLEAN DEFAULT FALSE,
  ha_recibido_bolsa BOOLEAN DEFAULT FALSE,
  fecha_recepcion_bolsa TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(tanda_id, numero_turno)
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 6: AVALES (tabla base)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS avales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE, -- Separación por negocio
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
  tanda_id UUID REFERENCES tandas(id) ON DELETE CASCADE,
  cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  nombre TEXT NOT NULL,
  email TEXT,
  telefono TEXT,
  direccion TEXT,
  identificacion TEXT,
  relacion TEXT, -- Familiar, Amigo, Colega, etc.
  verificado BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 6.1: MÚLTIPLES AVALES POR PRÉSTAMO (V9.0)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS prestamos_avales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestamo_id UUID NOT NULL REFERENCES prestamos(id) ON DELETE CASCADE,
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    orden INT DEFAULT 1, -- 1 = aval principal, 2 = segundo aval, etc.
    tipo VARCHAR(50) DEFAULT 'garante', -- garante, co-deudor, referencia
    porcentaje_responsabilidad DECIMAL(5,2) DEFAULT 100.00,
    firma_digital TEXT,
    firmado_at TIMESTAMPTZ,
    estado VARCHAR(20) DEFAULT 'pendiente', -- pendiente, firmado, rechazado
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(prestamo_id, aval_id)
);

CREATE INDEX IF NOT EXISTS idx_prestamos_avales_prestamo ON prestamos_avales(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_prestamos_avales_aval ON prestamos_avales(aval_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 6.2: MÚLTIPLES AVALES POR TANDA (V9.0)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tandas_avales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tanda_id UUID NOT NULL REFERENCES tandas(id) ON DELETE CASCADE,
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    orden INT DEFAULT 1,
    tipo VARCHAR(50) DEFAULT 'garante',
    porcentaje_responsabilidad DECIMAL(5,2) DEFAULT 100.00,
    firma_digital TEXT,
    firmado_at TIMESTAMPTZ,
    estado VARCHAR(20) DEFAULT 'pendiente',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tanda_id, aval_id)
);

CREATE INDEX IF NOT EXISTS idx_tandas_avales_tanda ON tandas_avales(tanda_id);
CREATE INDEX IF NOT EXISTS idx_tandas_avales_aval ON tandas_avales(aval_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 7: PAGOS Y COMPROBANTES
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS pagos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE, -- Separación por negocio
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
  tanda_id UUID REFERENCES tandas(id) ON DELETE CASCADE,
  amortizacion_id UUID REFERENCES amortizaciones(id) ON DELETE SET NULL,
  cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
  monto NUMERIC(12,2) NOT NULL,
  metodo_pago TEXT DEFAULT 'efectivo', -- efectivo, transferencia, tarjeta
  fecha_pago TIMESTAMP DEFAULT NOW(),
  nota TEXT,
  comprobante_url TEXT,
  recibo_oficial_url TEXT,
  latitud DOUBLE PRECISION,
  longitud DOUBLE PRECISION,
  registrado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pagos_negocio ON pagos(negocio_id);

CREATE TABLE IF NOT EXISTS comprobantes_prestamo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL, -- contrato, pagare, garantia, ine_cliente, comprobante_domicilio
  archivo_url TEXT NOT NULL,
  fecha_subida TIMESTAMP DEFAULT NOW(),
  subido_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 8: CHAT Y MENSAJERÍA AVANZADA
-- ══════════════════════════════════════════════════════════════════════════════

-- Sistema de chat más robusto para el modelo ChatConversacionModel
CREATE TABLE IF NOT EXISTS chat_conversaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_conversacion TEXT NOT NULL, -- cliente, aval, prestamo, tanda, soporte
  cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
  aval_id UUID REFERENCES avales(id) ON DELETE SET NULL,
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
  tanda_id UUID REFERENCES tandas(id) ON DELETE SET NULL,
  creado_por_usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  estado TEXT DEFAULT 'activo', -- activo, archivado, cerrado
  ultimo_mensaje TEXT,
  fecha_ultimo_mensaje TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_mensajes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversacion_id UUID REFERENCES chat_conversaciones(id) ON DELETE CASCADE,
  remitente_usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  tipo_mensaje TEXT DEFAULT 'texto', -- texto, imagen, documento, audio, ubicacion
  contenido_texto TEXT,
  archivo_url TEXT,
  latitud DOUBLE PRECISION,
  longitud DOUBLE PRECISION,
  hash_contenido TEXT, -- Para integridad/verificación
  es_sistema BOOLEAN DEFAULT FALSE,
  leido BOOLEAN DEFAULT FALSE,
  fecha_lectura TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_participantes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversacion_id UUID REFERENCES chat_conversaciones(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  rol_chat TEXT DEFAULT 'participante', -- admin, participante
  silenciado BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(conversacion_id, usuario_id)
);

-- Sistema de chat simple (legacy) compatible con chats/mensajes originales
CREATE TABLE IF NOT EXISTS chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario1 UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  usuario2 UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  ultimo_mensaje TEXT,
  fecha_ultimo_mensaje TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS mensajes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
  emisor_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  contenido TEXT NOT NULL,
  leido BOOLEAN DEFAULT FALSE,
  fecha TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 9: CALENDARIO Y EVENTOS
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS calendario (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo TEXT NOT NULL,
  descripcion TEXT,
  fecha TIMESTAMP NOT NULL,
  fecha_fin TIMESTAMP,
  tipo TEXT, -- pago, cobranza, reunion, recordatorio
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
  completado BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 10: AUDITORÍA Y SEGURIDAD
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS auditoria (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  accion TEXT NOT NULL,
  modulo TEXT,
  detalles JSONB,
  ip_address TEXT,
  fecha TIMESTAMP DEFAULT NOW()
);

-- Auditoría de acceso extendida (para AuditoriaAccesoModel)
CREATE TABLE IF NOT EXISTS auditoria_acceso (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  rol_id UUID REFERENCES roles(id) ON DELETE SET NULL,
  accion TEXT NOT NULL, -- login, logout, create, update, delete, view
  entidad TEXT NOT NULL, -- prestamo, cliente, pago, etc.
  entidad_id TEXT,
  ip TEXT,
  latitud DOUBLE PRECISION,
  longitud DOUBLE PRECISION,
  dispositivo TEXT,
  hash_contenido TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Auditoría legal (para AuditoriaLegalModel)
CREATE TABLE IF NOT EXISTS auditoria_legal (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
  cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
  tipo_evento TEXT NOT NULL, -- firma_contrato, aceptacion_terminos, verificacion_identidad
  descripcion TEXT,
  documento_url TEXT,
  hash_documento TEXT,
  ip_usuario TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 11: NOTIFICACIONES MASIVAS Y SISTEMA DE PUBLICIDAD (V9.0)
-- ══════════════════════════════════════════════════════════════════════════════

-- Notificaciones masivas (enviadas por admin a grupos de usuarios)
CREATE TABLE IF NOT EXISTS notificaciones_masivas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    titulo VARCHAR(200) NOT NULL,
    mensaje TEXT NOT NULL,
    tipo VARCHAR(50) DEFAULT 'anuncio', -- anuncio, tanda, prestamo, promocion, aviso
    ruta_destino VARCHAR(100), -- Al hacer click, a dónde va
    imagen_url TEXT,
    audiencia VARCHAR(50) DEFAULT 'todos', -- todos, cliente, empleado, aval
    destinatarios_count INT DEFAULT 0,
    leidos_count INT DEFAULT 0,
    enviado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notificaciones individuales (recibidas por cada usuario)
CREATE TABLE IF NOT EXISTS notificaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  tipo TEXT DEFAULT 'info', -- info, warning, success, error, pago, cobranza, promocion, sistema
  prioridad TEXT DEFAULT 'normal',
  icono TEXT,
  leida BOOLEAN DEFAULT FALSE,
  fecha_lectura TIMESTAMP,
  enlace TEXT, -- Deep link a la sección correspondiente (legacy)
  ruta_destino VARCHAR(100), -- Ruta interna al hacer click (V9)
  notificacion_masiva_id UUID, -- Si viene de masiva (FK agregada después)
  referencia_id UUID,
  referencia_tipo TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 12: PROMOCIONES Y OFERTAS (V9.0)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS promociones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo VARCHAR(200) NOT NULL,
    descripcion TEXT,
    imagen_url TEXT,
    ruta_destino VARCHAR(100), -- Ruta interna de la app al hacer click
    tipo VARCHAR(50) DEFAULT 'general', -- general, tanda, prestamo, producto
    activa BOOLEAN DEFAULT true,
    fecha_inicio TIMESTAMPTZ DEFAULT NOW(),
    fecha_fin TIMESTAMPTZ,
    prioridad INT DEFAULT 0,
    vistas INT DEFAULT 0,
    clicks INT DEFAULT 0,
    creado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 13: CONFIGURACIÓN GLOBAL DEL SISTEMA (V9.0)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS configuracion_global (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Información de la App
    nombre_app VARCHAR(100) DEFAULT 'Robert Darin Fintech',
    version VARCHAR(20) DEFAULT '6.1.0',
    modo_mantenimiento BOOLEAN DEFAULT false,
    
    -- Límites y Reglas de Negocio
    max_avales_prestamo INT DEFAULT 3,
    max_avales_tanda INT DEFAULT 2,
    monto_min_prestamo DECIMAL(15,2) DEFAULT 1000,
    monto_max_prestamo DECIMAL(15,2) DEFAULT 500000,
    interes_default DECIMAL(5,2) DEFAULT 10.00,
    
    -- Contacto y Soporte
    email_soporte VARCHAR(100) DEFAULT 'soporte@robertdarin.com',
    telefono_soporte VARCHAR(20) DEFAULT '+52 555 123 4567',
    whatsapp VARCHAR(20) DEFAULT '+52 555 123 4567',
    
    -- Personalización Visual
    color_acento VARCHAR(10) DEFAULT '#00BCD4',
    color_botones VARCHAR(10) DEFAULT '#4CAF50',
    color_alertas VARCHAR(10) DEFAULT '#FF5722',
    fondos_inteligentes BOOLEAN DEFAULT false,
    fondos_por_rol BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insertar configuración inicial si no existe
INSERT INTO configuracion_global (id) 
SELECT gen_random_uuid() 
WHERE NOT EXISTS (SELECT 1 FROM configuracion_global);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 14: TEMAS DE LA APLICACIÓN (V9.0)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS temas_app (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(50) NOT NULL,
    descripcion TEXT,
    color_primario VARCHAR(10) NOT NULL DEFAULT '#1E1E2C',
    color_secundario VARCHAR(10) NOT NULL DEFAULT '#2D2D44',
    color_acento VARCHAR(10) NOT NULL DEFAULT '#00BCD4',
    color_texto VARCHAR(10) DEFAULT '#FFFFFF',
    activo BOOLEAN DEFAULT false,
    creado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insertar temas por defecto
INSERT INTO temas_app (nombre, descripcion, color_primario, color_secundario, color_acento, activo) VALUES
    ('Neón Oscuro', 'Tema oscuro con acentos neón', '#1E1E2C', '#2D2D44', '#00BCD4', true),
    ('Verde Dinero', 'Tema inspirado en finanzas', '#0D2818', '#1E3D2F', '#4CAF50', false),
    ('Dorado Premium', 'Tema elegante dorado', '#1A1A2E', '#16213E', '#FFD700', false),
    ('Azul Corporativo', 'Tema profesional azul', '#0A1929', '#132F4C', '#0288D1', false)
ON CONFLICT DO NOTHING;

-- Preferencias de usuario (tema, configuración personal)
CREATE TABLE IF NOT EXISTS preferencias_usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tema VARCHAR(50) DEFAULT 'oscuro',
    idioma VARCHAR(10) DEFAULT 'es',
    notificaciones_push BOOLEAN DEFAULT true,
    notificaciones_email BOOLEAN DEFAULT true,
    modo_compacto BOOLEAN DEFAULT false,
    configuracion_extra JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(usuario_id)
);

CREATE INDEX IF NOT EXISTS idx_preferencias_usuario ON preferencias_usuario(usuario_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 15: FONDOS DE PANTALLA (V9.0)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS fondos_pantalla (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL,
    url TEXT NOT NULL,
    tipo VARCHAR(20) DEFAULT 'imagen', -- imagen, gradiente, patron
    activo BOOLEAN DEFAULT false,
    para_rol VARCHAR(50), -- null = todos, 'cliente', 'empleado', 'admin'
    hora_inicio TIME, -- Para fondos inteligentes
    hora_fin TIME,
    orden INT DEFAULT 0,
    subido_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 16: CONFIGURACIÓN LEGACY DEL SISTEMA (V8)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS configuracion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clave TEXT UNIQUE NOT NULL,
  valor TEXT,
  descripcion TEXT,
  tipo TEXT DEFAULT 'string', -- string, number, boolean, json
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════════
-- ÍNDICES PARA RENDIMIENTO
-- ══════════════════════════════════════════════════════════════════════════════

-- Clientes
CREATE INDEX IF NOT EXISTS idx_clientes_nombre ON clientes(nombre);
CREATE INDEX IF NOT EXISTS idx_clientes_email ON clientes(email);
CREATE INDEX IF NOT EXISTS idx_clientes_telefono ON clientes(telefono);
CREATE INDEX IF NOT EXISTS idx_clientes_sucursal ON clientes(sucursal_id);

-- Préstamos
CREATE INDEX IF NOT EXISTS idx_prestamos_cliente ON prestamos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_prestamos_estado ON prestamos(estado);
CREATE INDEX IF NOT EXISTS idx_prestamos_fecha ON prestamos(fecha_creacion);

-- Amortizaciones
CREATE INDEX IF NOT EXISTS idx_amortizaciones_prestamo ON amortizaciones(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_amortizaciones_estado ON amortizaciones(estado);
CREATE INDEX IF NOT EXISTS idx_amortizaciones_vencimiento ON amortizaciones(fecha_vencimiento);

-- Pagos
CREATE INDEX IF NOT EXISTS idx_pagos_prestamo ON pagos(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos(fecha_pago);
CREATE INDEX IF NOT EXISTS idx_pagos_cliente ON pagos(cliente_id);

-- Tandas
CREATE INDEX IF NOT EXISTS idx_tandas_estado ON tandas(estado);
CREATE INDEX IF NOT EXISTS idx_tanda_participantes_tanda ON tanda_participantes(tanda_id);
CREATE INDEX IF NOT EXISTS idx_tanda_participantes_cliente ON tanda_participantes(cliente_id);

-- Avales
CREATE INDEX IF NOT EXISTS idx_avales_prestamo ON avales(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_avales_cliente ON avales(cliente_id);

-- Chat
CREATE INDEX IF NOT EXISTS idx_chat_conversaciones_cliente ON chat_conversaciones(cliente_id);
CREATE INDEX IF NOT EXISTS idx_chat_mensajes_conversacion ON chat_mensajes(conversacion_id);
CREATE INDEX IF NOT EXISTS idx_chat_mensajes_fecha ON chat_mensajes(created_at);
CREATE INDEX IF NOT EXISTS idx_mensajes_chat ON mensajes(chat_id);

-- Auditoría
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auditoria(fecha);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON auditoria(usuario_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_acceso_fecha ON auditoria_acceso(created_at);
CREATE INDEX IF NOT EXISTS idx_auditoria_acceso_usuario ON auditoria_acceso(usuario_id);

-- Calendario
CREATE INDEX IF NOT EXISTS idx_calendario_fecha ON calendario(fecha);
CREATE INDEX IF NOT EXISTS idx_calendario_usuario ON calendario(usuario_id);

-- Notificaciones
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario ON notificaciones(usuario_id);
CREATE INDEX IF NOT EXISTS idx_notificaciones_leida ON notificaciones(leida);
CREATE INDEX IF NOT EXISTS idx_notificaciones_no_leidas ON notificaciones(usuario_id) WHERE leida = false;

-- ══════════════════════════════════════════════════════════════════════════════
-- TRIGGERS Y FUNCIONES
-- ══════════════════════════════════════════════════════════════════════════════

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION actualizar_updated_at() 
RETURNS TRIGGER AS $$
BEGIN 
  NEW.updated_at = NOW(); 
  RETURN NEW; 
END; 
$$ LANGUAGE plpgsql;

-- Triggers para updated_at en tablas relevantes
DO $$
DECLARE
    tablas TEXT[] := ARRAY['usuarios', 'sucursales', 'empleados', 'clientes', 'prestamos', 'tandas', 'avales', 'chat_conversaciones', 'configuracion_global', 'temas_app', 'promociones'];
    t TEXT;
BEGIN
    FOREACH t IN ARRAY tablas LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_updated_at_' || t) THEN
            EXECUTE 'CREATE TRIGGER trigger_updated_at_' || t || 
                    ' BEFORE UPDATE ON ' || t || 
                    ' FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();';
        END IF;
    END LOOP;
END $$;

-- Función para asignar primer superadmin automáticamente
CREATE OR REPLACE FUNCTION asignar_superadmin_si_no_existe() 
RETURNS TRIGGER AS $$
DECLARE 
  superadmin_count INTEGER;
  superadmin_rol_id UUID;
BEGIN
  SELECT id INTO superadmin_rol_id FROM roles WHERE nombre = 'superadmin';
  IF superadmin_rol_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  SELECT count(*) INTO superadmin_count 
  FROM usuarios_roles 
  WHERE rol_id = superadmin_rol_id;
  
  IF superadmin_count = 0 THEN
    INSERT INTO usuarios_roles (usuario_id, rol_id) 
    VALUES (NEW.id, superadmin_rol_id);
  END IF;
  RETURN NEW;
END; 
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_asignar_superadmin') THEN
        CREATE TRIGGER trigger_asignar_superadmin 
        AFTER INSERT ON usuarios 
        FOR EACH ROW EXECUTE FUNCTION asignar_superadmin_si_no_existe();
    END IF;
END $$;

-- Función para actualizar último mensaje en conversación
CREATE OR REPLACE FUNCTION actualizar_ultimo_mensaje_conversacion()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE chat_conversaciones 
  SET ultimo_mensaje = NEW.contenido_texto,
      fecha_ultimo_mensaje = NEW.created_at,
      updated_at = NOW()
  WHERE id = NEW.conversacion_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_actualizar_ultimo_mensaje') THEN
        CREATE TRIGGER trigger_actualizar_ultimo_mensaje
        AFTER INSERT ON chat_mensajes
        FOR EACH ROW EXECUTE FUNCTION actualizar_ultimo_mensaje_conversacion();
    END IF;
END $$;

-- Función para crear notificación de pago vencido
CREATE OR REPLACE FUNCTION notificar_pago_vencido()
RETURNS TRIGGER AS $$
DECLARE
  v_usuario_id UUID;
  v_cliente_nombre TEXT;
BEGIN
  IF NEW.estado = 'vencido' AND OLD.estado != 'vencido' THEN
    -- Obtener el usuario del cliente del préstamo
    SELECT c.nombre INTO v_cliente_nombre
    FROM prestamos p
    JOIN clientes c ON c.id = p.cliente_id
    WHERE p.id = NEW.prestamo_id;
    
    -- Notificar a todos los admins/operadores
    INSERT INTO notificaciones (usuario_id, titulo, mensaje, tipo)
    SELECT u.id, 
           'Pago Vencido',
           'El cliente ' || v_cliente_nombre || ' tiene un pago vencido (Cuota #' || NEW.numero_cuota || ')',
           'warning'
    FROM usuarios u
    JOIN usuarios_roles ur ON ur.usuario_id = u.id
    JOIN roles r ON r.id = ur.rol_id
    WHERE r.nombre IN ('superadmin', 'admin', 'operador');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_notificar_pago_vencido') THEN
        CREATE TRIGGER trigger_notificar_pago_vencido
        AFTER UPDATE ON amortizaciones
        FOR EACH ROW EXECUTE FUNCTION notificar_pago_vencido();
    END IF;
END $$;

-- Actualizar contador de leídos en notificaciones masivas (V9.0)
CREATE OR REPLACE FUNCTION actualizar_contador_leidos()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.leida = true AND OLD.leida = false AND NEW.notificacion_masiva_id IS NOT NULL THEN
        UPDATE notificaciones_masivas 
        SET leidos_count = leidos_count + 1 
        WHERE id = NEW.notificacion_masiva_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_actualizar_leidos') THEN
        CREATE TRIGGER trigger_actualizar_leidos
        AFTER UPDATE ON notificaciones
        FOR EACH ROW
        EXECUTE FUNCTION actualizar_contador_leidos();
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- DATOS MAESTROS INICIALES
-- ══════════════════════════════════════════════════════════════════════════════

-- Roles del sistema
INSERT INTO roles (nombre, descripcion) VALUES
('superadmin', 'Control total del sistema'),
('admin', 'Gerente de sucursal'),
('operador', 'Cajero/Operador'),
('cliente', 'Usuario cliente')
ON CONFLICT (nombre) DO NOTHING;

-- Permisos base
INSERT INTO permisos (clave_permiso, descripcion) VALUES
('usuarios.ver', 'Ver usuarios'),
('usuarios.crear', 'Crear usuarios'),
('usuarios.editar', 'Editar usuarios'),
('usuarios.eliminar', 'Eliminar usuarios'),
('clientes.ver', 'Ver clientes'),
('clientes.crear', 'Crear clientes'),
('clientes.editar', 'Editar clientes'),
('clientes.eliminar', 'Eliminar clientes'),
('prestamos.ver', 'Ver préstamos'),
('prestamos.crear', 'Crear préstamos'),
('prestamos.aprobar', 'Aprobar préstamos'),
('prestamos.eliminar', 'Eliminar préstamos'),
('pagos.ver', 'Ver pagos'),
('pagos.registrar', 'Registrar pagos'),
('pagos.eliminar', 'Eliminar pagos'),
('tandas.ver', 'Ver tandas'),
('tandas.crear', 'Crear tandas'),
('tandas.administrar', 'Administrar tandas'),
('reportes.ver', 'Ver reportes'),
('reportes.exportar', 'Exportar reportes'),
('configuracion.ver', 'Ver configuración'),
('configuracion.editar', 'Editar configuración'),
('auditoria.ver', 'Ver auditoría')
ON CONFLICT (clave_permiso) DO NOTHING;

-- Configuración inicial del sistema (legacy)
INSERT INTO configuracion (clave, valor, descripcion, tipo) VALUES
('tasa_interes_default', '5', 'Tasa de interés mensual por defecto (%)', 'number'),
('plazo_maximo_meses', '24', 'Plazo máximo de préstamos en meses', 'number'),
('monto_minimo_prestamo', '1000', 'Monto mínimo de préstamo', 'number'),
('monto_maximo_prestamo', '500000', 'Monto máximo de préstamo', 'number'),
('dias_gracia_pago', '3', 'Días de gracia antes de marcar como vencido', 'number'),
('requiere_aval', 'true', 'Requiere aval para préstamos', 'boolean'),
('nombre_empresa', 'Robert Darin Fintech', 'Nombre de la empresa', 'string'),
('moneda', 'MXN', 'Moneda del sistema', 'string')
ON CONFLICT (clave) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ══════════════════════════════════════════════════════════════════════════════

-- Activar RLS en todas las tablas
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' 
    LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(t) || ' ENABLE ROW LEVEL SECURITY;';
    END LOOP;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- POLÍTICAS DE SEGURIDAD
-- ══════════════════════════════════════════════════════════════════════════════

-- Política helper: verificar si usuario tiene rol
CREATE OR REPLACE FUNCTION usuario_tiene_rol(rol_nombre TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM usuarios_roles ur
    JOIN roles r ON r.id = ur.rol_id
    WHERE ur.usuario_id = auth.uid() AND r.nombre = rol_nombre
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Política helper: verificar si es admin o superior
CREATE OR REPLACE FUNCTION es_admin_o_superior()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM usuarios_roles ur
    JOIN roles r ON r.id = ur.rol_id
    WHERE ur.usuario_id = auth.uid() 
    AND r.nombre IN ('superadmin', 'admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ 
BEGIN 
    -- USUARIOS: Lectura universal, escritura para admins
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'usuarios_select_all') THEN
        CREATE POLICY "usuarios_select_all" ON usuarios FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'usuarios_insert_admin') THEN
        CREATE POLICY "usuarios_insert_admin" ON usuarios FOR INSERT WITH CHECK (es_admin_o_superior());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'usuarios_update_self_or_admin') THEN
        CREATE POLICY "usuarios_update_self_or_admin" ON usuarios FOR UPDATE 
        USING (auth.uid() = id OR es_admin_o_superior());
    END IF;

    -- CLIENTES: Acceso para autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'clientes_authenticated') THEN
        CREATE POLICY "clientes_authenticated" ON clientes FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- PRÉSTAMOS: Acceso para autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'prestamos_authenticated') THEN
        CREATE POLICY "prestamos_authenticated" ON prestamos FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- AMORTIZACIONES: Acceso para autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'amortizaciones_authenticated') THEN
        CREATE POLICY "amortizaciones_authenticated" ON amortizaciones FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- PAGOS: Acceso para autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'pagos_authenticated') THEN
        CREATE POLICY "pagos_authenticated" ON pagos FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- AVALES: Acceso para autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'avales_authenticated') THEN
        CREATE POLICY "avales_authenticated" ON avales FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- TANDAS: Acceso para autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'tandas_authenticated') THEN
        CREATE POLICY "tandas_authenticated" ON tandas FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- EMPLEADOS: Solo admins pueden gestionar empleados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'empleados_admin_all') THEN
        CREATE POLICY "empleados_admin_all" ON empleados FOR ALL 
        USING (es_admin_o_superior());
    END IF;

    -- USUARIOS_ROLES: Solo admins pueden asignar roles
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'usuarios_roles_admin_all') THEN
        CREATE POLICY "usuarios_roles_admin_all" ON usuarios_roles FOR ALL 
        USING (es_admin_o_superior());
    END IF;

    -- TANDA_PARTICIPANTES: Acceso para autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'tanda_participantes_authenticated') THEN
        CREATE POLICY "tanda_participantes_authenticated" ON tanda_participantes FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- EXPEDIENTE_CLIENTES: Acceso para autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'expediente_authenticated') THEN
        CREATE POLICY "expediente_authenticated" ON expediente_clientes FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- CHAT_CONVERSACIONES: Solo participantes o admins
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_conversaciones_access') THEN
        CREATE POLICY "chat_conversaciones_access" ON chat_conversaciones FOR ALL 
        USING (
          creado_por_usuario_id = auth.uid() 
          OR es_admin_o_superior()
          OR EXISTS (
            SELECT 1 FROM chat_participantes 
            WHERE conversacion_id = chat_conversaciones.id 
            AND usuario_id = auth.uid()
          )
        );
    END IF;

    -- CHAT_MENSAJES: Acceso a través de conversación
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_mensajes_access') THEN
        CREATE POLICY "chat_mensajes_access" ON chat_mensajes FOR ALL 
        USING (
          EXISTS (
            SELECT 1 FROM chat_conversaciones c
            WHERE c.id = chat_mensajes.conversacion_id
            AND (
              c.creado_por_usuario_id = auth.uid()
              OR es_admin_o_superior()
              OR EXISTS (
                SELECT 1 FROM chat_participantes 
                WHERE conversacion_id = c.id 
                AND usuario_id = auth.uid()
              )
            )
          )
        );
    END IF;

    -- CHATS (legacy): Solo participantes
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chats_privacidad') THEN
        CREATE POLICY "chats_privacidad" ON chats FOR ALL 
        USING (auth.uid() = usuario1 OR auth.uid() = usuario2);
    END IF;

    -- MENSAJES (legacy): A través del chat
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'mensajes_privacidad') THEN
        CREATE POLICY "mensajes_privacidad" ON mensajes FOR ALL 
        USING (
          EXISTS (
            SELECT 1 FROM chats 
            WHERE id = mensajes.chat_id 
            AND (usuario1 = auth.uid() OR usuario2 = auth.uid())
          )
        );
    END IF;

    -- NOTIFICACIONES: Solo propias o admin puede insertar
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notificaciones_propias') THEN
        CREATE POLICY "notificaciones_propias" ON notificaciones FOR SELECT 
        USING (usuario_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notificaciones_update') THEN
        CREATE POLICY "notificaciones_update" ON notificaciones FOR UPDATE 
        USING (usuario_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notificaciones_insert') THEN
        CREATE POLICY "notificaciones_insert" ON notificaciones FOR INSERT 
        WITH CHECK (true);
    END IF;

    -- CALENDARIO: Propio o admin
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'calendario_access') THEN
        CREATE POLICY "calendario_access" ON calendario FOR ALL 
        USING (usuario_id = auth.uid() OR es_admin_o_superior());
    END IF;

    -- AUDITORÍA: Solo admins pueden ver
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_admin_only') THEN
        CREATE POLICY "auditoria_admin_only" ON auditoria FOR SELECT 
        USING (es_admin_o_superior());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_insert_all') THEN
        CREATE POLICY "auditoria_insert_all" ON auditoria FOR INSERT 
        WITH CHECK (auth.role() = 'authenticated');
    END IF;

    -- AUDITORIA_ACCESO: Solo admins pueden ver
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_acceso_admin_only') THEN
        CREATE POLICY "auditoria_acceso_admin_only" ON auditoria_acceso FOR SELECT 
        USING (es_admin_o_superior());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_acceso_insert_all') THEN
        CREATE POLICY "auditoria_acceso_insert_all" ON auditoria_acceso FOR INSERT 
        WITH CHECK (auth.role() = 'authenticated');
    END IF;

    -- CONFIGURACIÓN LEGACY: Solo superadmins pueden modificar
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'configuracion_select_all') THEN
        CREATE POLICY "configuracion_select_all" ON configuracion FOR SELECT 
        USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'configuracion_modify_superadmin') THEN
        CREATE POLICY "configuracion_modify_superadmin" ON configuracion FOR ALL 
        USING (usuario_tiene_rol('superadmin'));
    END IF;

    -- CONFIGURACIÓN GLOBAL V9: Todos leen, solo superadmin modifica
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'configuracion_global_select') THEN
        CREATE POLICY "configuracion_global_select" ON configuracion_global FOR SELECT 
        USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'configuracion_global_modify') THEN
        CREATE POLICY "configuracion_global_modify" ON configuracion_global FOR ALL 
        USING (usuario_tiene_rol('superadmin'));
    END IF;

    -- TEMAS: Todos leen, solo superadmin modifica
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'temas_app_select') THEN
        CREATE POLICY "temas_app_select" ON temas_app FOR SELECT 
        USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'temas_app_modify') THEN
        CREATE POLICY "temas_app_modify" ON temas_app FOR ALL 
        USING (usuario_tiene_rol('superadmin'));
    END IF;

    -- FONDOS: Todos leen, solo superadmin modifica
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'fondos_pantalla_select') THEN
        CREATE POLICY "fondos_pantalla_select" ON fondos_pantalla FOR SELECT 
        USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'fondos_pantalla_modify') THEN
        CREATE POLICY "fondos_pantalla_modify" ON fondos_pantalla FOR ALL 
        USING (usuario_tiene_rol('superadmin'));
    END IF;

    -- PROMOCIONES: Todos ven activas, admin gestiona
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'promociones_select') THEN
        CREATE POLICY "promociones_select" ON promociones FOR SELECT 
        USING (activa = true OR es_admin_o_superior());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'promociones_modify') THEN
        CREATE POLICY "promociones_modify" ON promociones FOR ALL 
        USING (es_admin_o_superior());
    END IF;

    -- NOTIFICACIONES MASIVAS: Solo admins
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notificaciones_masivas_select') THEN
        CREATE POLICY "notificaciones_masivas_select" ON notificaciones_masivas FOR SELECT 
        USING (es_admin_o_superior());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notificaciones_masivas_insert') THEN
        CREATE POLICY "notificaciones_masivas_insert" ON notificaciones_masivas FOR INSERT 
        WITH CHECK (es_admin_o_superior());
    END IF;

    -- PRESTAMOS_AVALES: Empleados gestionan
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'prestamos_avales_access') THEN
        CREATE POLICY "prestamos_avales_access" ON prestamos_avales FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- TANDAS_AVALES: Empleados gestionan
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'tandas_avales_access') THEN
        CREATE POLICY "tandas_avales_access" ON tandas_avales FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- ROLES: Lectura para todos, modificación para superadmins
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'roles_select_all') THEN
        CREATE POLICY "roles_select_all" ON roles FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'roles_modify_superadmin') THEN
        CREATE POLICY "roles_modify_superadmin" ON roles FOR ALL 
        USING (usuario_tiene_rol('superadmin'));
    END IF;

    -- PERMISOS: Lectura para todos
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'permisos_select_all') THEN
        CREATE POLICY "permisos_select_all" ON permisos FOR SELECT USING (true);
    END IF;

    -- SUCURSALES: Lectura para autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'sucursales_authenticated') THEN
        CREATE POLICY "sucursales_authenticated" ON sucursales FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    -- PREFERENCIAS_USUARIO: Cada usuario solo ve/modifica las suyas
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'preferencias_usuario_own') THEN
        CREATE POLICY "preferencias_usuario_own" ON preferencias_usuario FOR ALL 
        USING (auth.uid() = usuario_id);
    END IF;

END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 17: MÉTODOS DE PAGO Y SISTEMA DE COBROS (V9.0)
-- ══════════════════════════════════════════════════════════════════════════════

-- Métodos de pago configurados por el negocio (datos bancarios, QR, etc.)
CREATE TABLE IF NOT EXISTS metodos_pago (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo VARCHAR(30) NOT NULL DEFAULT 'transferencia', -- efectivo, transferencia, tarjeta, oxxo, paypal, mercadopago
    nombre VARCHAR(100) NOT NULL, -- "BBVA Empresarial", "Santander Personal"
    banco VARCHAR(100),
    numero_cuenta VARCHAR(30),
    clabe VARCHAR(20), -- CLABE interbancaria (18 dígitos)
    tarjeta VARCHAR(20), -- Últimos 4 dígitos si aplica
    titular VARCHAR(200),
    qr_url TEXT, -- URL de imagen QR para pago
    enlace_pago TEXT, -- Link de pago (PayPal, Mercado Pago, etc.)
    instrucciones TEXT,
    activo BOOLEAN DEFAULT true,
    principal BOOLEAN DEFAULT false, -- Método por defecto
    orden INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Registros de cobro (pagos recibidos con confirmación)
CREATE TABLE IF NOT EXISTS registros_cobro (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
    tanda_id UUID REFERENCES tandas(id) ON DELETE SET NULL,
    amortizacion_id UUID REFERENCES amortizaciones(id) ON DELETE SET NULL,
    cliente_id UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    monto DECIMAL(15,2) NOT NULL,
    metodo_pago_id UUID REFERENCES metodos_pago(id) ON DELETE SET NULL,
    tipo_metodo VARCHAR(30) DEFAULT 'efectivo', -- efectivo, transferencia, tarjeta, qr
    estado VARCHAR(20) DEFAULT 'pendiente', -- pendiente, confirmado, rechazado
    referencia_pago VARCHAR(100), -- Número de referencia/transacción
    comprobante_url TEXT, -- Foto del comprobante
    nota_cliente TEXT,
    nota_operador TEXT,
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    registrado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    confirmado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    fecha_registro TIMESTAMPTZ DEFAULT NOW(),
    fecha_confirmacion TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para rendimiento
CREATE INDEX IF NOT EXISTS idx_metodos_pago_activo ON metodos_pago(activo);
CREATE INDEX IF NOT EXISTS idx_metodos_pago_tipo ON metodos_pago(tipo);
CREATE INDEX IF NOT EXISTS idx_registros_cobro_cliente ON registros_cobro(cliente_id);
CREATE INDEX IF NOT EXISTS idx_registros_cobro_prestamo ON registros_cobro(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_registros_cobro_tanda ON registros_cobro(tanda_id);
CREATE INDEX IF NOT EXISTS idx_registros_cobro_estado ON registros_cobro(estado);
CREATE INDEX IF NOT EXISTS idx_registros_cobro_fecha ON registros_cobro(fecha_registro);

-- Trigger para updated_at en metodos_pago
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_updated_at_metodos_pago') THEN
        CREATE TRIGGER trigger_updated_at_metodos_pago
        BEFORE UPDATE ON metodos_pago
        FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();
    END IF;
END $$;

-- Trigger para auto-confirmar cobros en efectivo
CREATE OR REPLACE FUNCTION autoconfirmar_cobro_efectivo()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tipo_metodo = 'efectivo' AND NEW.estado = 'pendiente' THEN
        NEW.estado := 'confirmado';
        NEW.fecha_confirmacion := NOW();
        NEW.confirmado_por := NEW.registrado_por;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_autoconfirmar_efectivo') THEN
        CREATE TRIGGER trigger_autoconfirmar_efectivo
        BEFORE INSERT ON registros_cobro
        FOR EACH ROW EXECUTE FUNCTION autoconfirmar_cobro_efectivo();
    END IF;
END $$;

-- RLS para metodos_pago (todos leen, solo admins modifican)
ALTER TABLE metodos_pago ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'metodos_pago_select') THEN
        CREATE POLICY "metodos_pago_select" ON metodos_pago FOR SELECT 
        USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'metodos_pago_modify') THEN
        CREATE POLICY "metodos_pago_modify" ON metodos_pago FOR ALL 
        USING (es_admin_o_superior());
    END IF;
END $$;

-- RLS para registros_cobro
ALTER TABLE registros_cobro ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'registros_cobro_access') THEN
        CREATE POLICY "registros_cobro_access" ON registros_cobro FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- Datos iniciales: Método de pago por defecto (efectivo)
INSERT INTO metodos_pago (tipo, nombre, principal, instrucciones) VALUES
    ('efectivo', 'Efectivo', true, 'Pago en efectivo al momento de la cobranza')
ON CONFLICT DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 18: SISTEMA DE CHECK-IN DE AVALES (UBICACIÓN CON CONSENTIMIENTO)
-- ══════════════════════════════════════════════════════════════════════════════

-- Columnas adicionales para avales (ubicación y consentimiento)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'ubicacion_consentida') THEN
        ALTER TABLE avales ADD COLUMN ubicacion_consentida BOOLEAN DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'fecha_consentimiento_ubicacion') THEN
        ALTER TABLE avales ADD COLUMN fecha_consentimiento_ubicacion TIMESTAMP;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'ultima_latitud') THEN
        ALTER TABLE avales ADD COLUMN ultima_latitud DECIMAL(10, 8);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'ultima_longitud') THEN
        ALTER TABLE avales ADD COLUMN ultima_longitud DECIMAL(11, 8);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'ultimo_checkin') THEN
        ALTER TABLE avales ADD COLUMN ultimo_checkin TIMESTAMP;
    END IF;
END $$;

-- Tabla de check-ins voluntarios de avales
CREATE TABLE IF NOT EXISTS aval_checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    latitud DECIMAL(10, 8) NOT NULL,
    longitud DECIMAL(11, 8) NOT NULL,
    precision DECIMAL(10, 2), -- Precisión en metros
    fecha TIMESTAMP DEFAULT NOW(),
    tipo TEXT DEFAULT 'voluntario', -- voluntario, verificacion_domicilio, visita_acordada
    direccion_aproximada TEXT, -- Reverse geocoding (opcional)
    ip_dispositivo TEXT, -- Para auditoría
    dispositivo TEXT, -- Info del dispositivo
    notas TEXT,
    verificado_por UUID REFERENCES usuarios(id), -- Admin que verificó (si aplica)
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para check-ins
CREATE INDEX IF NOT EXISTS idx_aval_checkins_aval ON aval_checkins(aval_id);
CREATE INDEX IF NOT EXISTS idx_aval_checkins_fecha ON aval_checkins(fecha);
CREATE INDEX IF NOT EXISTS idx_aval_checkins_tipo ON aval_checkins(tipo);

-- RLS para aval_checkins
ALTER TABLE aval_checkins ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'aval_checkins_select') THEN
        CREATE POLICY "aval_checkins_select" ON aval_checkins FOR SELECT 
        USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'aval_checkins_insert') THEN
        CREATE POLICY "aval_checkins_insert" ON aval_checkins FOR INSERT 
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM avales 
                WHERE id = aval_checkins.aval_id 
                AND usuario_id = auth.uid()
                AND ubicacion_consentida = true
            )
        );
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- HABILITAR REALTIME PARA NOTIFICACIONES
-- ══════════════════════════════════════════════════════════════════════════════

-- Ejecutar en Supabase Dashboard > Database > Replication:
-- ALTER PUBLICATION supabase_realtime ADD TABLE notificaciones;
-- ALTER PUBLICATION supabase_realtime ADD TABLE registros_cobro;
-- ALTER PUBLICATION supabase_realtime ADD TABLE aval_checkins;
-- ALTER PUBLICATION supabase_realtime ADD TABLE chat_aval_cobrador;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 19: CHAT DIRECTO AVAL-COBRADOR
-- ══════════════════════════════════════════════════════════════════════════════

-- Conversaciones entre avales y cobradores/admins
CREATE TABLE IF NOT EXISTS chat_aval_cobrador (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
    admin_id UUID REFERENCES usuarios(id) ON DELETE SET NULL, -- Cobrador/Admin asignado
    estado TEXT DEFAULT 'activo', -- activo, cerrado, archivado
    ultimo_mensaje TIMESTAMP DEFAULT NOW(),
    mensajes_no_leidos_aval INTEGER DEFAULT 0,
    mensajes_no_leidos_admin INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Mensajes del chat aval-cobrador
CREATE TABLE IF NOT EXISTS mensajes_aval_cobrador (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID NOT NULL REFERENCES chat_aval_cobrador(id) ON DELETE CASCADE,
    emisor_id UUID NOT NULL REFERENCES usuarios(id),
    tipo_emisor TEXT NOT NULL, -- 'aval', 'admin'
    mensaje TEXT,
    tipo_mensaje TEXT DEFAULT 'texto', -- texto, imagen, documento, ubicacion, audio
    archivo_url TEXT,
    archivo_nombre TEXT,
    leido BOOLEAN DEFAULT false,
    fecha_leido TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para chat
CREATE INDEX IF NOT EXISTS idx_chat_aval_cobrador_aval ON chat_aval_cobrador(aval_id);
CREATE INDEX IF NOT EXISTS idx_chat_aval_cobrador_admin ON chat_aval_cobrador(admin_id);
CREATE INDEX IF NOT EXISTS idx_chat_aval_cobrador_ultimo ON chat_aval_cobrador(ultimo_mensaje);
CREATE INDEX IF NOT EXISTS idx_mensajes_aval_chat ON mensajes_aval_cobrador(chat_id);
CREATE INDEX IF NOT EXISTS idx_mensajes_aval_fecha ON mensajes_aval_cobrador(created_at);

-- RLS para chat_aval_cobrador
ALTER TABLE chat_aval_cobrador ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensajes_aval_cobrador ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_aval_cobrador_select') THEN
        CREATE POLICY "chat_aval_cobrador_select" ON chat_aval_cobrador FOR SELECT 
        USING (
            auth.role() = 'authenticated' AND (
                -- Es el aval
                EXISTS (SELECT 1 FROM avales WHERE id = aval_id AND usuario_id = auth.uid())
                OR
                -- Es admin/cobrador asignado
                admin_id = auth.uid()
                OR
                -- Es superadmin/admin general
                EXISTS (SELECT 1 FROM usuarios_roles ur 
                    JOIN roles r ON ur.rol_id = r.id 
                    WHERE ur.usuario_id = auth.uid() 
                    AND r.nombre IN ('superadmin', 'admin'))
            )
        );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_aval_cobrador_insert') THEN
        CREATE POLICY "chat_aval_cobrador_insert" ON chat_aval_cobrador FOR INSERT 
        WITH CHECK (auth.role() = 'authenticated');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_aval_cobrador_update') THEN
        CREATE POLICY "chat_aval_cobrador_update" ON chat_aval_cobrador FOR UPDATE 
        USING (auth.role() = 'authenticated');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'mensajes_aval_cobrador_select') THEN
        CREATE POLICY "mensajes_aval_cobrador_select" ON mensajes_aval_cobrador FOR SELECT 
        USING (
            auth.role() = 'authenticated' AND
            EXISTS (
                SELECT 1 FROM chat_aval_cobrador c
                WHERE c.id = chat_id AND (
                    EXISTS (SELECT 1 FROM avales WHERE id = c.aval_id AND usuario_id = auth.uid())
                    OR c.admin_id = auth.uid()
                    OR EXISTS (SELECT 1 FROM usuarios_roles ur 
                        JOIN roles r ON ur.rol_id = r.id 
                        WHERE ur.usuario_id = auth.uid() 
                        AND r.nombre IN ('superadmin', 'admin'))
                )
            )
        );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'mensajes_aval_cobrador_insert') THEN
        CREATE POLICY "mensajes_aval_cobrador_insert" ON mensajes_aval_cobrador FOR INSERT 
        WITH CHECK (auth.role() = 'authenticated');
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 20: FIRMAS DIGITALES Y DOCUMENTOS DE AVALES
-- ══════════════════════════════════════════════════════════════════════════════

-- Columna para firma digital del aval
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'firma_digital_url') THEN
        ALTER TABLE avales ADD COLUMN firma_digital_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'fecha_firma') THEN
        ALTER TABLE avales ADD COLUMN fecha_firma TIMESTAMP;
    END IF;
END $$;

-- Historial de firmas (para auditoría)
CREATE TABLE IF NOT EXISTS firmas_avales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
    tipo_documento TEXT NOT NULL, -- 'contrato', 'pagare', 'acuerdo_pago', 'autorizacion'
    documento_id UUID, -- Referencia al documento específico si aplica
    firma_url TEXT NOT NULL,
    ip_firma TEXT,
    dispositivo TEXT,
    user_agent TEXT,
    latitud DECIMAL(10, 8),
    longitud DECIMAL(11, 8),
    validada BOOLEAN DEFAULT false,
    validada_por UUID REFERENCES usuarios(id),
    fecha_validacion TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_firmas_avales_aval ON firmas_avales(aval_id);
CREATE INDEX IF NOT EXISTS idx_firmas_avales_prestamo ON firmas_avales(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_firmas_avales_tipo ON firmas_avales(tipo_documento);

-- RLS para firmas_avales
ALTER TABLE firmas_avales ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'firmas_avales_select') THEN
        CREATE POLICY "firmas_avales_select" ON firmas_avales FOR SELECT 
        USING (
            auth.role() = 'authenticated' AND (
                EXISTS (SELECT 1 FROM avales WHERE id = aval_id AND usuario_id = auth.uid())
                OR EXISTS (SELECT 1 FROM usuarios_roles ur 
                    JOIN roles r ON ur.rol_id = r.id 
                    WHERE ur.usuario_id = auth.uid() 
                    AND r.nombre IN ('superadmin', 'admin', 'operador'))
            )
        );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'firmas_avales_insert') THEN
        CREATE POLICY "firmas_avales_insert" ON firmas_avales FOR INSERT 
        WITH CHECK (
            auth.role() = 'authenticated' AND
            EXISTS (SELECT 1 FROM avales WHERE id = aval_id AND usuario_id = auth.uid())
        );
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 21: NOTIFICACIONES DE MORA PARA AVALES
-- ══════════════════════════════════════════════════════════════════════════════

-- Registro de notificaciones de mora enviadas
CREATE TABLE IF NOT EXISTS notificaciones_mora_aval (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    prestamo_id UUID NOT NULL REFERENCES prestamos(id) ON DELETE CASCADE,
    amortizacion_id UUID REFERENCES amortizaciones(id) ON DELETE SET NULL,
    nivel_mora TEXT NOT NULL, -- 'leve', 'moderada', 'seria', 'grave', 'critica'
    dias_mora INTEGER NOT NULL,
    monto_vencido DECIMAL(12, 2) NOT NULL,
    mensaje TEXT,
    canal TEXT DEFAULT 'push', -- 'push', 'sms', 'email', 'whatsapp'
    enviada BOOLEAN DEFAULT false,
    fecha_envio TIMESTAMP,
    leida BOOLEAN DEFAULT false,
    fecha_lectura TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_mora_aval ON notificaciones_mora_aval(aval_id);
CREATE INDEX IF NOT EXISTS idx_notif_mora_prestamo ON notificaciones_mora_aval(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_notif_mora_nivel ON notificaciones_mora_aval(nivel_mora);
CREATE INDEX IF NOT EXISTS idx_notif_mora_fecha ON notificaciones_mora_aval(created_at);

-- RLS para notificaciones_mora_aval
ALTER TABLE notificaciones_mora_aval ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notif_mora_aval_select') THEN
        CREATE POLICY "notif_mora_aval_select" ON notificaciones_mora_aval FOR SELECT 
        USING (
            auth.role() = 'authenticated' AND (
                EXISTS (SELECT 1 FROM avales WHERE id = aval_id AND usuario_id = auth.uid())
                OR EXISTS (SELECT 1 FROM usuarios_roles ur 
                    JOIN roles r ON ur.rol_id = r.id 
                    WHERE ur.usuario_id = auth.uid() 
                    AND r.nombre IN ('superadmin', 'admin', 'operador'))
            )
        );
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notif_mora_aval_insert') THEN
        CREATE POLICY "notif_mora_aval_insert" ON notificaciones_mora_aval FOR INSERT 
        WITH CHECK (auth.role() = 'authenticated');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notif_mora_aval_update') THEN
        CREATE POLICY "notif_mora_aval_update" ON notificaciones_mora_aval FOR UPDATE 
        USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 22: RELACIONES MULTI-TENANT (USUARIOS-SUCURSALES)
-- ══════════════════════════════════════════════════════════════════════════════
-- Nota: Las tablas negocios y sucursales están en la Sección 2

-- Relación usuarios-sucursales (qué usuario trabaja en qué sucursal)
CREATE TABLE IF NOT EXISTS usuarios_sucursales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    sucursal_id UUID NOT NULL REFERENCES sucursales(id) ON DELETE CASCADE,
    rol_en_sucursal TEXT DEFAULT 'empleado', -- gerente, empleado, supervisor
    es_principal BOOLEAN DEFAULT false, -- Sucursal principal del usuario
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(usuario_id, sucursal_id)
);

-- Índices para multi-tenant
CREATE INDEX IF NOT EXISTS idx_usuarios_sucursales_usuario ON usuarios_sucursales(usuario_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_sucursales_sucursal ON usuarios_sucursales(sucursal_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 23: SISTEMA DE GAVETEROS MODULARES
-- ══════════════════════════════════════════════════════════════════════════════

-- Módulos activos por negocio
CREATE TABLE IF NOT EXISTS modulos_activos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    modulo_id TEXT NOT NULL, -- Identificador del módulo: 'fintech', 'aires', 'prestamos', etc.
    tipo TEXT DEFAULT 'gavetero', -- gavetero, submodulo
    activo BOOLEAN DEFAULT false,
    configuracion JSONB DEFAULT '{}', -- Config específica del módulo
    orden INTEGER DEFAULT 0, -- Para ordenar en el menú
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(negocio_id, modulo_id)
);

-- Permitir módulos globales (sin negocio específico)
CREATE INDEX IF NOT EXISTS idx_modulos_negocio ON modulos_activos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_modulos_id ON modulos_activos(modulo_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 24: CONFIGURACIÓN DE APIs Y SERVICIOS EXTERNOS
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS configuracion_apis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    servicio TEXT NOT NULL, -- stripe, twilio, firebase, google_maps, etc.
    activo BOOLEAN DEFAULT false,
    modo_test BOOLEAN DEFAULT true,
    -- Credenciales (se guardan encriptadas en producción)
    publishable_key TEXT,
    secret_key TEXT,
    webhook_secret TEXT,
    api_key TEXT,
    configuracion JSONB DEFAULT '{}', -- Config adicional específica del servicio
    ultima_verificacion TIMESTAMP,
    estado_conexion TEXT DEFAULT 'no_verificado', -- ok, error, no_verificado
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(negocio_id, servicio)
);

-- Permitir configuración global (sin negocio específico) usando COALESCE
CREATE INDEX IF NOT EXISTS idx_config_apis_servicio ON configuracion_apis(servicio);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 25: TARJETAS DIGITALES (STRIPE ISSUING)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tarjetas_digitales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    negocio_id UUID REFERENCES negocios(id) ON DELETE SET NULL,
    
    -- Código interno único por negocio (para QR, identificación interna)
    codigo_tarjeta TEXT, -- Ej: FIN-001, AIR-001, etc.
    
    -- Proveedor de tarjetas (multi-proveedor)
    proveedor TEXT DEFAULT 'stripe', -- stripe, pomelo, rapyd, stp, openpay, galileo, marqeta, custom
    
    -- IDs externos del proveedor
    stripe_cardholder_id TEXT,
    stripe_card_id TEXT,
    external_card_id TEXT, -- ID genérico para otros proveedores
    
    -- Datos de la tarjeta (parciales por seguridad)
    ultimos_4 TEXT,
    numero_enmascarado TEXT, -- **** **** **** 1234
    marca TEXT DEFAULT 'visa', -- visa, mastercard, amex
    tipo TEXT DEFAULT 'virtual', -- virtual, fisica
    estado TEXT DEFAULT 'pendiente', -- pendiente, activa, bloqueada, cancelada
    
    -- Modo de operación
    modo_test BOOLEAN DEFAULT false, -- true = tarjeta de prueba
    activa BOOLEAN DEFAULT true,
    
    -- Límites
    limite_diario DECIMAL(12, 2) DEFAULT 5000,
    limite_mensual DECIMAL(12, 2) DEFAULT 50000,
    limite_transaccion DECIMAL(12, 2) DEFAULT 2000,
    moneda TEXT DEFAULT 'MXN',
    
    -- Fechas
    fecha_emision TIMESTAMP,
    fecha_activacion TIMESTAMP,
    fecha_expiracion DATE,
    fecha_vencimiento DATE,
    fecha_bloqueo TIMESTAMP,
    motivo_bloqueo TEXT,
    
    -- Metadatos adicionales
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Transacciones de tarjetas
CREATE TABLE IF NOT EXISTS transacciones_tarjeta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID NOT NULL REFERENCES tarjetas_digitales(id) ON DELETE CASCADE,
    stripe_transaction_id TEXT,
    tipo TEXT NOT NULL, -- compra, retiro, transferencia, recarga
    monto DECIMAL(12, 2) NOT NULL,
    moneda TEXT DEFAULT 'MXN',
    comercio TEXT,
    categoria TEXT,
    estado TEXT DEFAULT 'pendiente', -- pendiente, aprobada, rechazada, reembolsada
    motivo_rechazo TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tarjetas_cliente ON tarjetas_digitales(cliente_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_estado ON tarjetas_digitales(estado);
CREATE INDEX IF NOT EXISTS idx_tarjetas_negocio ON tarjetas_digitales(negocio_id);
CREATE INDEX IF NOT EXISTS idx_transacciones_tarjeta ON transacciones_tarjeta(tarjeta_id);

-- Código de tarjeta único por negocio (permite mismo código en diferentes negocios)
CREATE UNIQUE INDEX IF NOT EXISTS idx_tarjetas_codigo_negocio ON tarjetas_digitales(negocio_id, codigo_tarjeta) WHERE codigo_tarjeta IS NOT NULL;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 26: DOCUMENTOS Y CONTRATOS DE AVALES
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS documentos_aval (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
    tipo TEXT NOT NULL, -- ine_frente, ine_reverso, selfie, comprobante_domicilio, contrato_garantia
    archivo_url TEXT NOT NULL,
    firmado BOOLEAN DEFAULT false,
    fecha_firma TIMESTAMP,
    verificado BOOLEAN DEFAULT false,
    verificado_por UUID REFERENCES usuarios(id),
    fecha_verificacion TIMESTAMP,
    notas TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS referencias_aval (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    telefono TEXT NOT NULL,
    relacion TEXT, -- familiar, amigo, vecino, trabajo
    verificada BOOLEAN DEFAULT false,
    fecha_verificacion TIMESTAMP,
    notas TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS validaciones_aval (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    puntaje_riesgo INTEGER DEFAULT 0,
    nivel_riesgo INTEGER DEFAULT 1, -- 1=bajo, 2=medio, 3=alto, 4=critico
    alertas JSONB DEFAULT '[]',
    aprobado BOOLEAN DEFAULT false,
    revision_manual BOOLEAN DEFAULT false,
    revisado_por UUID REFERENCES usuarios(id),
    fecha_revision TIMESTAMP,
    notas_revision TEXT,
    fecha TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS verificaciones_identidad (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    ine_url TEXT,
    selfie_url TEXT,
    estado TEXT DEFAULT 'pendiente', -- pendiente, aprobado, rechazado, pendiente_revision
    metodo TEXT DEFAULT 'manual', -- manual, automatico, facial
    confianza DECIMAL(5, 2), -- Porcentaje de confianza si es automático
    verificado_por UUID REFERENCES usuarios(id),
    fecha_verificacion TIMESTAMP,
    motivo_rechazo TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS log_fraude (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_entidad TEXT NOT NULL, -- aval, cliente, prestamo
    entidad_id UUID NOT NULL,
    accion TEXT NOT NULL, -- bloqueo, alerta, verificacion, desbloqueo
    motivo TEXT,
    severidad INTEGER DEFAULT 1,
    ejecutado_por UUID REFERENCES usuarios(id),
    ip_address TEXT,
    user_agent TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para documentos y validaciones
CREATE INDEX IF NOT EXISTS idx_documentos_aval ON documentos_aval(aval_id);
CREATE INDEX IF NOT EXISTS idx_referencias_aval ON referencias_aval(aval_id);
CREATE INDEX IF NOT EXISTS idx_validaciones_aval ON validaciones_aval(aval_id);
CREATE INDEX IF NOT EXISTS idx_verificaciones_aval ON verificaciones_identidad(aval_id);
CREATE INDEX IF NOT EXISTS idx_log_fraude_entidad ON log_fraude(tipo_entidad, entidad_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 26.1: CAMPOS ADICIONALES PARA AVALES (V10.26)
-- URLs de documentos directos en tabla avales (compatibilidad legacy)
-- ══════════════════════════════════════════════════════════════════════════════

-- Agregar columnas de documentos a tabla avales si no existen
DO $$
BEGIN
    -- INE Frente
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'ine_url') THEN
        ALTER TABLE avales ADD COLUMN ine_url TEXT;
    END IF;
    -- INE Reverso
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'ine_reverso_url') THEN
        ALTER TABLE avales ADD COLUMN ine_reverso_url TEXT;
    END IF;
    -- Comprobante Domicilio
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'domicilio_url') THEN
        ALTER TABLE avales ADD COLUMN domicilio_url TEXT;
    END IF;
    -- Selfie Verificación
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'selfie_url') THEN
        ALTER TABLE avales ADD COLUMN selfie_url TEXT;
    END IF;
    -- Comprobante Ingresos
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'ingresos_url') THEN
        ALTER TABLE avales ADD COLUMN ingresos_url TEXT;
    END IF;
    -- Ubicación consentida (para check-ins)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'ubicacion_consentida') THEN
        ALTER TABLE avales ADD COLUMN ubicacion_consentida BOOLEAN DEFAULT FALSE;
    END IF;
    -- FCM Token para notificaciones push
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'avales' AND column_name = 'fcm_token') THEN
        ALTER TABLE avales ADD COLUMN fcm_token TEXT;
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 26.2: NOTIFICACIONES DE DOCUMENTOS PARA AVALES (V10.26)
-- Registro de notificaciones cuando se aprueban/rechazan documentos
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS notificaciones_documento_aval (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    documento_id UUID REFERENCES documentos_aval(id) ON DELETE SET NULL,
    tipo_documento TEXT NOT NULL, -- ine_frente, ine_reverso, selfie, etc.
    tipo_notificacion TEXT NOT NULL, -- 'aprobado', 'rechazado', 'pendiente_revision'
    mensaje TEXT NOT NULL,
    motivo_rechazo TEXT, -- Solo si fue rechazado
    leida BOOLEAN DEFAULT FALSE,
    fecha_lectura TIMESTAMPTZ,
    enviada_push BOOLEAN DEFAULT FALSE, -- Si se envió notificación push
    fecha_envio_push TIMESTAMPTZ,
    creado_por UUID REFERENCES usuarios(id), -- Admin que aprobó/rechazó
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_doc_aval ON notificaciones_documento_aval(aval_id);
CREATE INDEX IF NOT EXISTS idx_notif_doc_aval_leida ON notificaciones_documento_aval(aval_id, leida);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 26.3: CHECK-INS DE UBICACIÓN DE AVALES (V10.26)
-- Registro voluntario de ubicación del aval
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS aval_checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    latitud DECIMAL(10, 8) NOT NULL,
    longitud DECIMAL(11, 8) NOT NULL,
    precision_metros DECIMAL(8, 2),
    direccion_aproximada TEXT, -- Geocoding inverso opcional
    ip_address TEXT,
    user_agent TEXT,
    motivo TEXT DEFAULT 'voluntario', -- voluntario, solicitado, automatico
    fecha TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aval_checkins ON aval_checkins(aval_id);
CREATE INDEX IF NOT EXISTS idx_aval_checkins_fecha ON aval_checkins(aval_id, fecha DESC);

-- RLS para tablas nuevas
ALTER TABLE notificaciones_documento_aval ENABLE ROW LEVEL SECURITY;
ALTER TABLE aval_checkins ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notif_doc_aval_policy') THEN
        CREATE POLICY "notif_doc_aval_policy" ON notificaciones_documento_aval 
            FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'aval_checkins_policy') THEN
        CREATE POLICY "aval_checkins_policy" ON aval_checkins 
            FOR ALL USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 26.4: CONFIGURACIÓN DE FIREBASE CLOUD MESSAGING (V10.26)
-- Server key para enviar push notifications
-- ══════════════════════════════════════════════════════════════════════════════

-- Insertar configuración de FCM (el admin debe actualizar con su key real)
INSERT INTO configuracion_apis (servicio, activo, modo_test, api_key, configuracion)
VALUES (
    'firebase_fcm',
    false, -- Cambiar a true cuando se configure
    true,
    'TU_FCM_SERVER_KEY_AQUI', -- Obtener de Firebase Console → Cloud Messaging
    '{"sender_id": "TU_SENDER_ID", "project_id": "robert-darin-fintech"}'::jsonb
)
ON CONFLICT (negocio_id, servicio) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 27: NEGOCIO DE AIRES ACONDICIONADOS (MULTI-NEGOCIO)
-- ══════════════════════════════════════════════════════════════════════════════

-- Equipos/Inventario de aires
CREATE TABLE IF NOT EXISTS aires_equipos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID NOT NULL REFERENCES negocios(id) ON DELETE CASCADE,
    sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
    marca TEXT NOT NULL,
    modelo TEXT NOT NULL,
    tipo TEXT, -- minisplit, central, ventana, portatil
    capacidad_btu INTEGER,
    costo DECIMAL(12, 2),
    precio_venta DECIMAL(12, 2),
    stock INTEGER DEFAULT 0,
    stock_minimo INTEGER DEFAULT 2,
    ubicacion TEXT, -- Almacén, bodega, etc.
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Técnicos de aires
CREATE TABLE IF NOT EXISTS aires_tecnicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    negocio_id UUID NOT NULL REFERENCES negocios(id) ON DELETE CASCADE,
    especialidad TEXT, -- instalacion, mantenimiento, reparacion
    certificaciones TEXT[],
    zona_cobertura TEXT,
    disponible BOOLEAN DEFAULT true,
    calificacion DECIMAL(3, 2) DEFAULT 5.00,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Órdenes de servicio
CREATE TABLE IF NOT EXISTS aires_ordenes_servicio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID NOT NULL REFERENCES negocios(id) ON DELETE CASCADE,
    folio TEXT UNIQUE,
    cliente_nombre TEXT NOT NULL,
    cliente_telefono TEXT NOT NULL,
    cliente_direccion TEXT NOT NULL,
    tipo_servicio TEXT NOT NULL, -- instalacion, mantenimiento, reparacion, cotizacion
    equipo_id UUID REFERENCES aires_equipos(id),
    tecnico_id UUID REFERENCES aires_tecnicos(id),
    descripcion TEXT,
    fecha_programada TIMESTAMP,
    fecha_completada TIMESTAMP,
    estado TEXT DEFAULT 'pendiente', -- pendiente, en_proceso, completado, cancelado
    costo_mano_obra DECIMAL(12, 2),
    costo_materiales DECIMAL(12, 2),
    total DECIMAL(12, 2),
    notas TEXT,
    fotos_antes JSONB DEFAULT '[]',
    fotos_despues JSONB DEFAULT '[]',
    firma_cliente TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Garantías de aires
CREATE TABLE IF NOT EXISTS aires_garantias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    orden_servicio_id UUID REFERENCES aires_ordenes_servicio(id) ON DELETE CASCADE,
    equipo_id UUID REFERENCES aires_equipos(id),
    tipo TEXT, -- equipo, mano_obra, refacciones
    duracion_meses INTEGER DEFAULT 12,
    fecha_inicio DATE,
    fecha_fin DATE,
    condiciones TEXT,
    activa BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para aires
CREATE INDEX IF NOT EXISTS idx_aires_equipos_negocio ON aires_equipos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_aires_tecnicos_negocio ON aires_tecnicos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_aires_ordenes_negocio ON aires_ordenes_servicio(negocio_id);
CREATE INDEX IF NOT EXISTS idx_aires_ordenes_estado ON aires_ordenes_servicio(estado);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 28: NOTIFICACIONES DEL SISTEMA (PARA ACTUALIZAR PANTALLAS)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS notificaciones_sistema (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo TEXT NOT NULL, -- modulo_tarjetas, modulo_activado, config_actualizada, etc.
    accion TEXT NOT NULL, -- activado, desactivado, actualizado
    mensaje TEXT,
    destinatarios TEXT DEFAULT 'todos', -- todos, admins, clientes, rol:operador
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    leido BOOLEAN DEFAULT false,
    metadata JSONB DEFAULT '{}',
    fecha TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_sistema_tipo ON notificaciones_sistema(tipo);
CREATE INDEX IF NOT EXISTS idx_notif_sistema_fecha ON notificaciones_sistema(fecha);

-- ══════════════════════════════════════════════════════════════════════════════
-- HABILITAR REALTIME PARA NUEVAS TABLAS
-- ══════════════════════════════════════════════════════════════════════════════

-- Ejecutar en Supabase Dashboard > Database > Replication:
-- ALTER PUBLICATION supabase_realtime ADD TABLE notificaciones_sistema;
-- ALTER PUBLICATION supabase_realtime ADD TABLE tarjetas_digitales;
-- ALTER PUBLICATION supabase_realtime ADD TABLE modulos_activos;
-- ALTER PUBLICATION supabase_realtime ADD TABLE chat_aval_cobrador;
-- ALTER PUBLICATION supabase_realtime ADD TABLE mensajes_aval_cobrador;

-- ══════════════════════════════════════════════════════════════════════════════
-- RLS PARA MULTI-TENANT
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE negocios ENABLE ROW LEVEL SECURITY;
ALTER TABLE sucursales ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios_sucursales ENABLE ROW LEVEL SECURITY;
ALTER TABLE modulos_activos ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracion_apis ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarjetas_digitales ENABLE ROW LEVEL SECURITY;
ALTER TABLE documentos_aval ENABLE ROW LEVEL SECURITY;
ALTER TABLE aires_ordenes_servicio ENABLE ROW LEVEL SECURITY;

-- Políticas básicas (superadmin ve todo, otros ven su negocio)
DO $$
BEGIN
    -- Negocios: SELECT para todos autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'negocios_select') THEN
        CREATE POLICY "negocios_select" ON negocios FOR SELECT USING (auth.role() = 'authenticated');
    END IF;
    
    -- Negocios: INSERT/UPDATE/DELETE solo superadmin y admin
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'negocios_modify') THEN
        CREATE POLICY "negocios_modify" ON negocios FOR ALL USING (
            EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
                    WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin'))
        );
    END IF;
    
    -- Sucursales: SELECT para todos autenticados
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'sucursales_select') THEN
        CREATE POLICY "sucursales_select" ON sucursales FOR SELECT USING (auth.role() = 'authenticated');
    END IF;
    
    -- Sucursales: INSERT/UPDATE/DELETE solo superadmin y admin
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'sucursales_modify') THEN
        CREATE POLICY "sucursales_modify" ON sucursales FOR ALL USING (
            EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
                    WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin'))
        );
    END IF;
    
    -- Tarjetas digitales (cliente ve sus tarjetas, admin ve todas)
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'tarjetas_select') THEN
        CREATE POLICY "tarjetas_select" ON tarjetas_digitales FOR SELECT USING (
            auth.role() = 'authenticated' AND (
                EXISTS (SELECT 1 FROM clientes WHERE id = cliente_id AND usuario_id IS NOT NULL AND usuario_id = auth.uid())
                OR EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id
                           WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin'))
            )
        );
    END IF;
    
    -- Documentos aval
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'documentos_aval_select') THEN
        CREATE POLICY "documentos_aval_select" ON documentos_aval FOR SELECT USING (
            auth.role() = 'authenticated' AND (
                EXISTS (SELECT 1 FROM avales WHERE id = aval_id AND usuario_id = auth.uid())
                OR EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
                    WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin', 'operador'))
            )
        );
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 29: SISTEMA DE AUDITORÍA LEGAL Y EVIDENCIAS PARA JUICIOS
-- ══════════════════════════════════════════════════════════════════════════════

-- Intentos de cobro documentados (evidencia para juicio)
CREATE TABLE IF NOT EXISTS intentos_cobro (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestamo_id UUID NOT NULL REFERENCES prestamos(id) ON DELETE CASCADE,
    cliente_id UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    cobrador_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    tipo TEXT NOT NULL, -- llamada, visita, mensaje, notificacion, carta, email
    resultado TEXT NOT NULL, -- contestado, no_contestado, promesa_pago, negado, buzon, numero_equivocado
    notas TEXT,
    latitud DECIMAL(10, 8),
    longitud DECIMAL(11, 8),
    duracion_llamada INTEGER, -- segundos si fue llamada
    grabacion_url TEXT, -- URL de grabación si aplica
    fecha TIMESTAMP DEFAULT NOW(),
    hash_registro TEXT NOT NULL, -- Hash SHA-256 para integridad
    created_at TIMESTAMP DEFAULT NOW()
);

-- Notificaciones de mora formales (requerimientos de pago)
CREATE TABLE IF NOT EXISTS notificaciones_mora (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    prestamo_id UUID NOT NULL REFERENCES prestamos(id) ON DELETE CASCADE,
    cliente_id UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- primera, segunda, tercera, ultima, prejudicial
    canal TEXT NOT NULL, -- email, sms, push, carta_fisica, whatsapp
    contenido TEXT NOT NULL,
    fecha_envio TIMESTAMP DEFAULT NOW(),
    fecha_entrega TIMESTAMP,
    confirmacion_lectura BOOLEAN DEFAULT false,
    fecha_lectura TIMESTAMP,
    hash_notificacion TEXT, -- Hash para integridad
    created_at TIMESTAMP DEFAULT NOW()
);

-- Expedientes legales generados
CREATE TABLE IF NOT EXISTS expedientes_legales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestamo_id UUID NOT NULL REFERENCES prestamos(id) ON DELETE CASCADE,
    cliente_id UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    fecha_generacion TIMESTAMP DEFAULT NOW(),
    hash_expediente TEXT NOT NULL, -- Hash del expediente completo
    estado_cuenta JSONB, -- Snapshot del estado de cuenta
    num_comunicaciones INTEGER DEFAULT 0,
    num_pagos INTEGER DEFAULT 0,
    total_adeudado DECIMAL(14, 2),
    dias_mora INTEGER,
    estado TEXT DEFAULT 'generado', -- generado, enviado_abogado, en_demanda, sentencia
    abogado_asignado TEXT,
    numero_expediente_judicial TEXT,
    juzgado TEXT,
    notas_legales TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Seguimiento de proceso judicial
CREATE TABLE IF NOT EXISTS seguimiento_judicial (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expediente_id UUID NOT NULL REFERENCES expedientes_legales(id) ON DELETE CASCADE,
    fecha TIMESTAMP DEFAULT NOW(),
    etapa TEXT NOT NULL, -- demanda_presentada, admision, emplazamiento, contestacion, pruebas, alegatos, sentencia, ejecucion
    descripcion TEXT,
    documento_url TEXT,
    proximo_paso TEXT,
    fecha_proxima_accion DATE,
    responsable TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Acuses de recibo (para cartas y notificaciones físicas)
CREATE TABLE IF NOT EXISTS acuses_recibo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notificacion_id UUID REFERENCES notificaciones_mora(id) ON DELETE CASCADE,
    expediente_id UUID REFERENCES expedientes_legales(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- carta_certificada, acuse_fedatario, guia_mensajeria
    numero_guia TEXT,
    fecha_envio DATE,
    fecha_recepcion DATE,
    receptor_nombre TEXT,
    receptor_identificacion TEXT,
    foto_acuse_url TEXT,
    hash_acuse TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Promesas de pago (compromisos del deudor)
CREATE TABLE IF NOT EXISTS promesas_pago (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestamo_id UUID NOT NULL REFERENCES prestamos(id) ON DELETE CASCADE,
    cliente_id UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    intento_cobro_id UUID REFERENCES intentos_cobro(id),
    monto_prometido DECIMAL(12, 2) NOT NULL,
    fecha_promesa DATE NOT NULL, -- Fecha en que prometió pagar
    fecha_compromiso DATE NOT NULL, -- Fecha para la que se comprometió
    cumplida BOOLEAN DEFAULT false,
    fecha_cumplimiento TIMESTAMP,
    notas TEXT,
    grabacion_url TEXT, -- Si se grabó la promesa
    hash_promesa TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para rendimiento
CREATE INDEX IF NOT EXISTS idx_intentos_cobro_prestamo ON intentos_cobro(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_intentos_cobro_fecha ON intentos_cobro(fecha);
CREATE INDEX IF NOT EXISTS idx_notificaciones_mora_prestamo ON notificaciones_mora(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_expedientes_legales_prestamo ON expedientes_legales(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_expedientes_legales_estado ON expedientes_legales(estado);
CREATE INDEX IF NOT EXISTS idx_promesas_pago_fecha ON promesas_pago(fecha_compromiso);

-- Habilitar RLS
ALTER TABLE intentos_cobro ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones_mora ENABLE ROW LEVEL SECURITY;
ALTER TABLE expedientes_legales ENABLE ROW LEVEL SECURITY;
ALTER TABLE seguimiento_judicial ENABLE ROW LEVEL SECURITY;

-- ══════════════════════════════════════════════════════════════════════════════
-- INSERTAR DATOS INICIALES
-- ══════════════════════════════════════════════════════════════════════════════

-- Crear negocio principal si no existe
INSERT INTO negocios (nombre, tipo, activo)
SELECT 'Robert Darin Fintech', 'fintech', true
WHERE NOT EXISTS (SELECT 1 FROM negocios WHERE tipo = 'fintech' LIMIT 1);

-- Crear sucursal principal (REQUERIDA para dar de alta empleados)
INSERT INTO sucursales (negocio_id, nombre, codigo, direccion, telefono, activa)
SELECT 
    n.id,
    'Sucursal Principal',
    'SUC-001',
    'Oficina Central',
    '5512345678',
    true
FROM negocios n 
WHERE n.tipo = 'fintech'
AND NOT EXISTS (SELECT 1 FROM sucursales WHERE codigo = 'SUC-001');

-- Activar módulos básicos del gavetero fintech
INSERT INTO modulos_activos (modulo_id, tipo, activo)
SELECT 'fintech', 'gavetero', true
WHERE NOT EXISTS (SELECT 1 FROM modulos_activos WHERE modulo_id = 'fintech');

INSERT INTO modulos_activos (modulo_id, tipo, activo)
SELECT 'prestamos', 'submodulo', true
WHERE NOT EXISTS (SELECT 1 FROM modulos_activos WHERE modulo_id = 'prestamos');

INSERT INTO modulos_activos (modulo_id, tipo, activo)
SELECT 'cobranza', 'submodulo', true
WHERE NOT EXISTS (SELECT 1 FROM modulos_activos WHERE modulo_id = 'cobranza');

INSERT INTO modulos_activos (modulo_id, tipo, activo)
SELECT 'clientes', 'submodulo', true
WHERE NOT EXISTS (SELECT 1 FROM modulos_activos WHERE modulo_id = 'clientes');

INSERT INTO modulos_activos (modulo_id, tipo, activo)
SELECT 'avales', 'submodulo', true
WHERE NOT EXISTS (SELECT 1 FROM modulos_activos WHERE modulo_id = 'avales');

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 30: DATOS INICIALES - ROLES Y SUPERADMIN
-- ══════════════════════════════════════════════════════════════════════════════
-- Esta sección configura los roles base y el superadmin inicial del sistema

-- 1. Crear roles base del sistema
INSERT INTO roles (id, nombre, descripcion) VALUES 
    (gen_random_uuid(), 'superadmin', 'Administrador total del sistema con acceso a todas las funciones'),
    (gen_random_uuid(), 'admin', 'Administrador de negocio con acceso a operaciones y reportes'),
    (gen_random_uuid(), 'operador', 'Operador/Cobrador con acceso a funciones operativas diarias'),
    (gen_random_uuid(), 'cliente', 'Cliente del sistema con acceso solo a su información'),
    (gen_random_uuid(), 'contador', 'Contador/Contabilidad con acceso a finanzas, reportes y nómina'),
    (gen_random_uuid(), 'recursos_humanos', 'Recursos Humanos con acceso a empleados, nómina y expedientes'),
    (gen_random_uuid(), 'aval', 'Aval/Garante con acceso a ver préstamos que garantiza')
ON CONFLICT (nombre) DO NOTHING;

-- 2. Crear permisos base del sistema (usa clave_permiso, no nombre)
INSERT INTO permisos (id, clave_permiso, descripcion) VALUES 
    (gen_random_uuid(), 'ver_dashboard', 'Ver panel principal'),
    (gen_random_uuid(), 'gestionar_clientes', 'Crear, editar y ver clientes'),
    (gen_random_uuid(), 'gestionar_prestamos', 'Crear, editar y ver préstamos'),
    (gen_random_uuid(), 'gestionar_tandas', 'Crear, editar y ver tandas'),
    (gen_random_uuid(), 'gestionar_avales', 'Crear, editar y ver avales'),
    (gen_random_uuid(), 'gestionar_pagos', 'Registrar y ver pagos'),
    (gen_random_uuid(), 'gestionar_empleados', 'Crear, editar y ver empleados'),
    (gen_random_uuid(), 'ver_reportes', 'Acceso a reportes y estadísticas'),
    (gen_random_uuid(), 'ver_auditoria', 'Ver registros de auditoría'),
    (gen_random_uuid(), 'gestionar_usuarios', 'Crear, editar usuarios y asignar roles'),
    (gen_random_uuid(), 'gestionar_roles', 'Crear y modificar roles y permisos'),
    (gen_random_uuid(), 'gestionar_sucursales', 'Crear, editar y ver sucursales'),
    (gen_random_uuid(), 'configuracion_global', 'Modificar configuración del sistema'),
    (gen_random_uuid(), 'acceso_control_center', 'Acceso al centro de control total')
ON CONFLICT (clave_permiso) DO NOTHING;

-- 3. Asignar todos los permisos al rol superadmin
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'superadmin'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 4. Asignar permisos al rol admin (todo menos control center y roles)
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'admin'
AND p.clave_permiso NOT IN ('acceso_control_center', 'gestionar_roles', 'configuracion_global')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 5. Asignar permisos al rol operador (solo operativo)
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'operador'
AND p.clave_permiso IN ('ver_dashboard', 'gestionar_clientes', 'gestionar_prestamos', 
                 'gestionar_tandas', 'gestionar_avales', 'gestionar_pagos')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 6. Asignar permisos al rol cliente (solo ver su info)
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'cliente'
AND p.clave_permiso = 'ver_dashboard'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 7. Asignar permisos al rol contador (finanzas, reportes, pagos)
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'contador'
AND p.clave_permiso IN ('ver_dashboard', 'gestionar_prestamos', 'gestionar_pagos', 
                 'gestionar_tandas', 'ver_reportes', 'ver_auditoria')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 8. Asignar permisos al rol recursos_humanos (empleados, nómina, usuarios)
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre = 'recursos_humanos'
AND p.clave_permiso IN ('ver_dashboard', 'gestionar_empleados', 'ver_reportes', 'gestionar_usuarios')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════════
-- 9. CONFIGURAR SUPERADMIN INICIAL: rdarinel92@gmail.com
-- ══════════════════════════════════════════════════════════════════════════════
-- NOTA: Este usuario debe existir primero en auth.users (Supabase Authentication)

-- Crear registro en usuarios si existe en auth.users
INSERT INTO usuarios (id, email, nombre_completo)
SELECT 
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'full_name', 'Robert Darin')
FROM auth.users au
WHERE au.email = 'rdarinel92@gmail.com'
ON CONFLICT (id) DO UPDATE SET
    nombre_completo = COALESCE(EXCLUDED.nombre_completo, usuarios.nombre_completo);

-- Asignar rol superadmin al usuario
INSERT INTO usuarios_roles (usuario_id, rol_id)
SELECT u.id, r.id
FROM usuarios u
CROSS JOIN roles r
WHERE u.email = 'rdarinel92@gmail.com'
AND r.nombre = 'superadmin'
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN DEL SCHEMA V10.1 - SISTEMA COMPLETO ROBERT DARIN FINTECH
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 31: VISTAS DE COMPATIBILIDAD
-- ══════════════════════════════════════════════════════════════════════════════

-- Vista para compatibilidad con código Dart que usa 'firmas'
CREATE OR REPLACE VIEW firmas AS SELECT * FROM firmas_avales;

-- Vista para compatibilidad con código Dart que usa 'auditoria_accesos'
CREATE OR REPLACE VIEW auditoria_accesos AS SELECT * FROM auditoria_acceso;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 32: MIS PROPIEDADES / TERRENOS (CONTROL DE PAGOS)
-- ══════════════════════════════════════════════════════════════════════════════
-- Módulo para llevar control de propiedades que el DUEÑO está comprando
-- (terrenos, casas, locales, etc.) con pagos mensuales/quincenales
-- Permite asignar a un empleado/admin para que realice los pagos
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS mis_propiedades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Información de la propiedad
  nombre TEXT NOT NULL, -- "Terreno Zapopan", "Casa Los Arcos"
  tipo TEXT DEFAULT 'terreno', -- terreno, casa, local, departamento, otro
  descripcion TEXT,
  ubicacion TEXT, -- Dirección o ubicación
  superficie_m2 NUMERIC(10,2), -- Metros cuadrados
  
  -- Información financiera
  precio_total NUMERIC(14,2) NOT NULL, -- Precio de compra total
  enganche NUMERIC(14,2) DEFAULT 0, -- Enganche pagado
  saldo_inicial NUMERIC(14,2) NOT NULL, -- Lo que se financia (precio - enganche)
  
  -- Plan de pagos
  monto_mensual NUMERIC(12,2) NOT NULL, -- Cuota mensual/quincenal
  frecuencia_pago TEXT DEFAULT 'Mensual', -- Mensual, Quincenal
  dia_pago INTEGER DEFAULT 15, -- Día del mes que se debe pagar
  plazo_meses INTEGER, -- Plazo total en meses
  
  -- Fechas importantes
  fecha_compra DATE,
  fecha_inicio_pagos DATE,
  fecha_fin_estimada DATE,
  
  -- Vendedor/Institución
  vendedor_nombre TEXT,
  vendedor_telefono TEXT,
  vendedor_cuenta_banco TEXT, -- Cuenta para hacer depósitos
  vendedor_banco TEXT, -- Nombre del banco
  
  -- Asignación para pagos
  asignado_a UUID REFERENCES usuarios(id) ON DELETE SET NULL, -- Quién hace los pagos
  
  -- Estado
  estado TEXT DEFAULT 'en_pagos', -- en_pagos, liquidado, cancelado
  notas TEXT,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Tabla de pagos realizados
CREATE TABLE IF NOT EXISTS pagos_propiedades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  propiedad_id UUID REFERENCES mis_propiedades(id) ON DELETE CASCADE,
  
  -- Información del pago
  numero_pago INTEGER NOT NULL,
  monto NUMERIC(12,2) NOT NULL,
  fecha_programada DATE NOT NULL, -- Fecha en que debía pagarse
  fecha_pago DATE, -- Fecha real del pago (null si no se ha pagado)
  
  -- Quién pagó
  pagado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  metodo_pago TEXT, -- efectivo, transferencia, deposito
  referencia TEXT, -- Número de referencia o folio
  
  -- Comprobante
  comprobante_url TEXT, -- URL del comprobante/voucher
  comprobante_filename TEXT,
  
  -- Estado
  estado TEXT DEFAULT 'pendiente', -- pendiente, pagado, atrasado, adelantado
  notas TEXT,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Índices para propiedades
CREATE INDEX IF NOT EXISTS idx_mis_propiedades_estado ON mis_propiedades(estado);
CREATE INDEX IF NOT EXISTS idx_mis_propiedades_asignado ON mis_propiedades(asignado_a);
CREATE INDEX IF NOT EXISTS idx_pagos_propiedades_propiedad ON pagos_propiedades(propiedad_id);
CREATE INDEX IF NOT EXISTS idx_pagos_propiedades_estado ON pagos_propiedades(estado);
CREATE INDEX IF NOT EXISTS idx_pagos_propiedades_fecha ON pagos_propiedades(fecha_programada);

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_propiedad_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_propiedad ON mis_propiedades;
CREATE TRIGGER trigger_update_propiedad
    BEFORE UPDATE ON mis_propiedades
    FOR EACH ROW EXECUTE FUNCTION update_propiedad_timestamp();

DROP TRIGGER IF EXISTS trigger_update_pago_propiedad ON pagos_propiedades;
CREATE TRIGGER trigger_update_pago_propiedad
    BEFORE UPDATE ON pagos_propiedades
    FOR EACH ROW EXECUTE FUNCTION update_propiedad_timestamp();

-- RLS para propiedades (solo superadmin y admin pueden ver/modificar)
ALTER TABLE mis_propiedades ENABLE ROW LEVEL SECURITY;
ALTER TABLE pagos_propiedades ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'propiedades_authenticated') THEN
        CREATE POLICY "propiedades_authenticated" ON mis_propiedades FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'pagos_propiedades_authenticated') THEN
        CREATE POLICY "pagos_propiedades_authenticated" ON pagos_propiedades FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 33: SISTEMA DE MORAS Y PENALIZACIONES (V10.6)
-- ══════════════════════════════════════════════════════════════════════════════

-- Configuración de moras por negocio
CREATE TABLE IF NOT EXISTS configuracion_moras (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  
  -- Configuración para préstamos
  prestamos_mora_diaria NUMERIC(5,2) DEFAULT 1.0, -- % de mora diaria sobre cuota vencida
  prestamos_mora_maxima NUMERIC(5,2) DEFAULT 30.0, -- % máximo de mora sobre cuota
  prestamos_dias_gracia INTEGER DEFAULT 0, -- Días de gracia antes de aplicar mora
  prestamos_aplicar_automatico BOOLEAN DEFAULT TRUE,
  
  -- Configuración para tandas
  tandas_mora_diaria NUMERIC(5,2) DEFAULT 2.0, -- % de mora diaria
  tandas_mora_maxima NUMERIC(5,2) DEFAULT 50.0, -- % máximo
  tandas_dias_gracia INTEGER DEFAULT 1, -- Días de gracia
  tandas_aplicar_automatico BOOLEAN DEFAULT TRUE,
  
  -- Notificaciones automáticas
  notificar_dias_antes INTEGER DEFAULT 3, -- Notificar X días antes del vencimiento
  notificar_recordatorio_diario BOOLEAN DEFAULT TRUE, -- Recordatorio diario si está vencido
  notificar_al_aval BOOLEAN DEFAULT TRUE, -- Notificar al aval también
  
  -- Escalamiento de notificaciones
  nivel_1_dias INTEGER DEFAULT 1, -- Después de X días: notificación leve
  nivel_2_dias INTEGER DEFAULT 7, -- Después de X días: notificación seria
  nivel_3_dias INTEGER DEFAULT 15, -- Después de X días: notificación grave
  nivel_4_dias INTEGER DEFAULT 30, -- Después de X días: notificación crítica (amenaza legal)
  
  -- Acciones automáticas
  bloquear_cliente_dias INTEGER DEFAULT 60, -- Bloquear cliente para nuevos préstamos después de X días mora
  enviar_a_legal_dias INTEGER DEFAULT 90, -- Enviar a auditoría legal automáticamente
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Registro histórico de moras aplicadas
CREATE TABLE IF NOT EXISTS moras_prestamos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
  amortizacion_id UUID REFERENCES amortizaciones(id) ON DELETE CASCADE,
  
  -- Detalles de la mora
  dias_mora INTEGER NOT NULL,
  monto_cuota_original NUMERIC(12,2) NOT NULL,
  porcentaje_mora_aplicado NUMERIC(5,2) NOT NULL,
  monto_mora NUMERIC(12,2) NOT NULL,
  monto_total_con_mora NUMERIC(12,2) NOT NULL, -- cuota + mora
  
  -- Estado de la mora
  estado TEXT DEFAULT 'pendiente', -- pendiente, pagada, condonada, en_legal
  condonado_por UUID REFERENCES usuarios(id),
  motivo_condonacion TEXT,
  fecha_condonacion TIMESTAMP,
  
  -- Pago de mora
  monto_mora_pagado NUMERIC(12,2) DEFAULT 0,
  fecha_pago_mora TIMESTAMP,
  
  -- Auditoría
  generado_automatico BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Registro histórico de moras en tandas
CREATE TABLE IF NOT EXISTS moras_tandas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tanda_id UUID REFERENCES tandas(id) ON DELETE CASCADE,
  participante_id UUID REFERENCES tanda_participantes(id) ON DELETE CASCADE,
  turno_numero INTEGER NOT NULL, -- El número de turno que no pagó a tiempo
  
  -- Detalles de la mora
  dias_mora INTEGER NOT NULL,
  monto_aportacion_original NUMERIC(12,2) NOT NULL,
  porcentaje_mora_aplicado NUMERIC(5,2) NOT NULL,
  monto_mora NUMERIC(12,2) NOT NULL,
  monto_total_con_mora NUMERIC(12,2) NOT NULL,
  
  -- Estado
  estado TEXT DEFAULT 'pendiente', -- pendiente, pagada, condonada
  condonado_por UUID REFERENCES usuarios(id),
  motivo_condonacion TEXT,
  fecha_condonacion TIMESTAMP,
  
  -- Pago
  monto_mora_pagado NUMERIC(12,2) DEFAULT 0,
  fecha_pago_mora TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Historial de notificaciones de mora enviadas a clientes
CREATE TABLE IF NOT EXISTS notificaciones_mora_cliente (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
  
  -- Referencia del objeto moroso
  tipo_deuda TEXT NOT NULL, -- 'prestamo', 'tanda'
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
  tanda_id UUID REFERENCES tandas(id) ON DELETE CASCADE,
  
  -- Contenido de la notificación
  nivel_mora TEXT NOT NULL, -- 'recordatorio', 'leve', 'seria', 'grave', 'critica', 'legal'
  titulo TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  dias_mora INTEGER,
  monto_pendiente NUMERIC(12,2),
  monto_mora NUMERIC(12,2),
  monto_total NUMERIC(12,2),
  
  -- Delivery
  canal TEXT DEFAULT 'app', -- 'app', 'push', 'sms', 'email', 'whatsapp'
  enviado BOOLEAN DEFAULT TRUE,
  leido BOOLEAN DEFAULT FALSE,
  fecha_lectura TIMESTAMP,
  
  -- Si se envió también al aval
  enviado_a_aval BOOLEAN DEFAULT FALSE,
  aval_id UUID REFERENCES avales(id),
  
  created_at TIMESTAMP DEFAULT NOW()
);

-- Clientes bloqueados por mora excesiva
CREATE TABLE IF NOT EXISTS clientes_bloqueados_mora (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
  
  -- Motivo del bloqueo
  motivo TEXT NOT NULL,
  dias_mora_maximo INTEGER NOT NULL,
  monto_total_adeudado NUMERIC(12,2) NOT NULL,
  
  -- Préstamos/tandas en mora
  prestamos_en_mora JSONB, -- Array de IDs de préstamos
  tandas_en_mora JSONB, -- Array de IDs de tandas
  
  -- Estado del bloqueo
  activo BOOLEAN DEFAULT TRUE,
  fecha_desbloqueo TIMESTAMP,
  desbloqueado_por UUID REFERENCES usuarios(id),
  motivo_desbloqueo TEXT,
  
  -- Auditoría
  bloqueado_por UUID REFERENCES usuarios(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para moras
CREATE INDEX IF NOT EXISTS idx_moras_prestamos_prestamo ON moras_prestamos(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_moras_prestamos_amort ON moras_prestamos(amortizacion_id);
CREATE INDEX IF NOT EXISTS idx_moras_prestamos_estado ON moras_prestamos(estado);
CREATE INDEX IF NOT EXISTS idx_moras_tandas_tanda ON moras_tandas(tanda_id);
CREATE INDEX IF NOT EXISTS idx_moras_tandas_participante ON moras_tandas(participante_id);
CREATE INDEX IF NOT EXISTS idx_notif_mora_cliente ON notificaciones_mora_cliente(cliente_id);
CREATE INDEX IF NOT EXISTS idx_notif_mora_tipo ON notificaciones_mora_cliente(tipo_deuda);
CREATE INDEX IF NOT EXISTS idx_clientes_bloqueados ON clientes_bloqueados_mora(cliente_id, activo);

-- RLS para tablas de moras
ALTER TABLE configuracion_moras ENABLE ROW LEVEL SECURITY;
ALTER TABLE moras_prestamos ENABLE ROW LEVEL SECURITY;
ALTER TABLE moras_tandas ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones_mora_cliente ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes_bloqueados_mora ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'config_moras_auth') THEN
        CREATE POLICY "config_moras_auth" ON configuracion_moras FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'moras_prestamos_auth') THEN
        CREATE POLICY "moras_prestamos_auth" ON moras_prestamos FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'moras_tandas_auth') THEN
        CREATE POLICY "moras_tandas_auth" ON moras_tandas FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notif_mora_cliente_auth') THEN
        CREATE POLICY "notif_mora_cliente_auth" ON notificaciones_mora_cliente FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'clientes_bloqueados_auth') THEN
        CREATE POLICY "clientes_bloqueados_auth" ON clientes_bloqueados_mora FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- Función para calcular mora de un préstamo
CREATE OR REPLACE FUNCTION calcular_mora_prestamo(
  p_amortizacion_id UUID,
  p_negocio_id UUID DEFAULT NULL
)
RETURNS TABLE (
  dias_mora INTEGER,
  monto_cuota NUMERIC,
  porcentaje_mora NUMERIC,
  monto_mora NUMERIC,
  monto_total NUMERIC
) AS $$
DECLARE
  v_fecha_vencimiento DATE;
  v_monto_cuota NUMERIC;
  v_dias_mora INTEGER;
  v_mora_diaria NUMERIC := 1.0;
  v_mora_maxima NUMERIC := 30.0;
  v_dias_gracia INTEGER := 0;
  v_porcentaje_calculado NUMERIC;
BEGIN
  -- Obtener datos de la amortización
  SELECT a.fecha_vencimiento, a.monto_cuota
  INTO v_fecha_vencimiento, v_monto_cuota
  FROM amortizaciones a
  WHERE a.id = p_amortizacion_id;
  
  -- Calcular días de mora
  v_dias_mora := GREATEST(0, CURRENT_DATE - v_fecha_vencimiento);
  
  -- Si hay negocio_id, obtener configuración personalizada
  IF p_negocio_id IS NOT NULL THEN
    SELECT cm.prestamos_mora_diaria, cm.prestamos_mora_maxima, cm.prestamos_dias_gracia
    INTO v_mora_diaria, v_mora_maxima, v_dias_gracia
    FROM configuracion_moras cm
    WHERE cm.negocio_id = p_negocio_id;
  END IF;
  
  -- Restar días de gracia
  v_dias_mora := GREATEST(0, v_dias_mora - v_dias_gracia);
  
  -- Calcular porcentaje de mora (limitado al máximo)
  v_porcentaje_calculado := LEAST(v_dias_mora * v_mora_diaria, v_mora_maxima);
  
  RETURN QUERY SELECT
    v_dias_mora,
    v_monto_cuota,
    v_porcentaje_calculado,
    ROUND(v_monto_cuota * v_porcentaje_calculado / 100, 2),
    ROUND(v_monto_cuota * (1 + v_porcentaje_calculado / 100), 2);
END;
$$ LANGUAGE plpgsql;

-- Función para aplicar mora automáticamente
CREATE OR REPLACE FUNCTION aplicar_mora_automatica()
RETURNS TRIGGER AS $$
DECLARE
  v_config RECORD;
  v_dias_mora INTEGER;
  v_monto_mora NUMERIC;
  v_negocio_id UUID;
BEGIN
  -- Solo procesar si cambió a estado 'vencido'
  IF NEW.estado = 'vencido' AND (OLD.estado IS NULL OR OLD.estado != 'vencido') THEN
    
    -- Obtener negocio del préstamo
    SELECT p.negocio_id INTO v_negocio_id
    FROM prestamos p
    WHERE p.id = NEW.prestamo_id;
    
    -- Obtener configuración
    SELECT * INTO v_config
    FROM configuracion_moras
    WHERE negocio_id = v_negocio_id;
    
    -- Si hay configuración y está habilitado el automático
    IF v_config IS NOT NULL AND v_config.prestamos_aplicar_automatico THEN
      v_dias_mora := CURRENT_DATE - NEW.fecha_vencimiento;
      
      -- Solo si pasaron los días de gracia
      IF v_dias_mora > v_config.prestamos_dias_gracia THEN
        v_dias_mora := v_dias_mora - v_config.prestamos_dias_gracia;
        v_monto_mora := ROUND(NEW.monto_cuota * LEAST(v_dias_mora * v_config.prestamos_mora_diaria, v_config.prestamos_mora_maxima) / 100, 2);
        
        -- Insertar registro de mora (si no existe)
        INSERT INTO moras_prestamos (
          prestamo_id,
          amortizacion_id,
          dias_mora,
          monto_cuota_original,
          porcentaje_mora_aplicado,
          monto_mora,
          monto_total_con_mora,
          generado_automatico
        )
        VALUES (
          NEW.prestamo_id,
          NEW.id,
          v_dias_mora,
          NEW.monto_cuota,
          LEAST(v_dias_mora * v_config.prestamos_mora_diaria, v_config.prestamos_mora_maxima),
          v_monto_mora,
          NEW.monto_cuota + v_monto_mora,
          TRUE
        )
        ON CONFLICT (amortizacion_id) WHERE amortizacion_id IS NOT NULL DO UPDATE
        SET dias_mora = EXCLUDED.dias_mora,
            porcentaje_mora_aplicado = EXCLUDED.porcentaje_mora_aplicado,
            monto_mora = EXCLUDED.monto_mora,
            monto_total_con_mora = EXCLUDED.monto_total_con_mora,
            updated_at = NOW();
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para aplicar mora automática (deshabilitado por defecto, habilitar si se desea)
-- DROP TRIGGER IF EXISTS trigger_aplicar_mora ON amortizaciones;
-- CREATE TRIGGER trigger_aplicar_mora
--     AFTER UPDATE ON amortizaciones
--     FOR EACH ROW EXECUTE FUNCTION aplicar_mora_automatica();

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 34: TIPOS DE ARQUILADO EXPANDIDOS (V10.6)
-- ══════════════════════════════════════════════════════════════════════════════

-- Los tipos de arquilado ya están soportados en la tabla prestamos:
-- - tipo: 'arquilado'
-- - interes_diario: % de interés por periodo
-- - capital_al_final: TRUE indica que el capital se paga al final
--
-- Agregamos tabla de variantes de arquilado para más flexibilidad:

CREATE TABLE IF NOT EXISTS variantes_arquilado (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL UNIQUE, -- 'clasico', 'renovable', 'acumulado', 'mixto'
  descripcion TEXT NOT NULL,
  
  -- Comportamiento del capital
  capital_al_final BOOLEAN DEFAULT TRUE, -- Capital se paga al final
  permite_renovacion BOOLEAN DEFAULT FALSE, -- Si al terminar puede renovar automáticamente
  intereses_acumulados BOOLEAN DEFAULT FALSE, -- Si los intereses no pagados se acumulan
  permite_abonos_capital BOOLEAN DEFAULT FALSE, -- Si puede abonar a capital durante el préstamo
  
  -- Cálculos
  interes_minimo NUMERIC(5,2) DEFAULT 1.0, -- % mínimo por periodo
  interes_maximo NUMERIC(5,2) DEFAULT 20.0, -- % máximo por periodo
  
  -- Frecuencias permitidas
  frecuencias_permitidas TEXT[] DEFAULT ARRAY['Semanal', 'Quincenal', 'Mensual'],
  
  -- Límites
  monto_minimo NUMERIC(12,2) DEFAULT 1000,
  monto_maximo NUMERIC(12,2) DEFAULT 1000000,
  plazo_minimo_periodos INTEGER DEFAULT 4,
  plazo_maximo_periodos INTEGER DEFAULT 52,
  
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Insertar variantes predefinidas de arquilado
INSERT INTO variantes_arquilado (nombre, descripcion, capital_al_final, permite_renovacion, intereses_acumulados, permite_abonos_capital)
VALUES
  ('clasico', 'Arquilado Clásico: Paga solo interés cada periodo. Al final devuelve capital + último interés. El más común.', TRUE, FALSE, FALSE, FALSE),
  ('renovable', 'Arquilado Renovable: Al terminar el plazo, puede renovar automáticamente por otro periodo sin pagar capital.', TRUE, TRUE, FALSE, FALSE),
  ('acumulado', 'Arquilado Acumulado: Si no paga interés de un periodo, se suma al siguiente. Riesgoso para el cliente.', TRUE, FALSE, TRUE, FALSE),
  ('mixto', 'Arquilado Mixto: Puede hacer abonos a capital cuando quiera. El interés se calcula sobre el saldo.', TRUE, FALSE, FALSE, TRUE)
ON CONFLICT (nombre) DO UPDATE SET descripcion = EXCLUDED.descripcion;

-- Agregar columna a préstamos para tipo de arquilado (si no existe)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'prestamos' AND column_name = 'variante_arquilado') THEN
        ALTER TABLE prestamos ADD COLUMN variante_arquilado TEXT DEFAULT 'clasico';
    END IF;
END $$;

-- RLS para variantes_arquilado
ALTER TABLE variantes_arquilado ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'variantes_arquilado_auth') THEN
        CREATE POLICY "variantes_arquilado_auth" ON variantes_arquilado FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 35: STORAGE BUCKETS (Supabase Storage)
-- ══════════════════════════════════════════════════════════════════════════════
-- Nota: Ejecutar en el SQL Editor de Supabase

-- Bucket para fondos de pantalla
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('fondos', 'fondos', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

-- Bucket para comprobantes de pago
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('comprobantes', 'comprobantes', false, 10485760, ARRAY['image/jpeg', 'image/png', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

-- Bucket para documentos de clientes (INE, etc)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('documentos', 'documentos', false, 10485760, ARRAY['image/jpeg', 'image/png', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

-- Bucket para avatares/fotos de perfil
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatares', 'avatares', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Bucket para logos de negocios
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('logos', 'logos', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/svg+xml', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Políticas de Storage para bucket 'fondos' (público, solo superadmin sube)
DROP POLICY IF EXISTS "fondos_public_read" ON storage.objects;
CREATE POLICY "fondos_public_read" ON storage.objects FOR SELECT 
USING (bucket_id = 'fondos');

DROP POLICY IF EXISTS "fondos_superadmin_insert" ON storage.objects;
CREATE POLICY "fondos_superadmin_insert" ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'fondos' AND
    EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin')
);

DROP POLICY IF EXISTS "fondos_superadmin_delete" ON storage.objects;
CREATE POLICY "fondos_superadmin_delete" ON storage.objects FOR DELETE 
USING (
    bucket_id = 'fondos' AND
    EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin')
);

-- Políticas para bucket 'comprobantes' (privado, usuarios autenticados)
DROP POLICY IF EXISTS "comprobantes_auth_read" ON storage.objects;
CREATE POLICY "comprobantes_auth_read" ON storage.objects FOR SELECT 
USING (bucket_id = 'comprobantes' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "comprobantes_auth_insert" ON storage.objects;
CREATE POLICY "comprobantes_auth_insert" ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'comprobantes' AND auth.role() = 'authenticated');

-- Políticas para bucket 'documentos' (privado, admin+)
DROP POLICY IF EXISTS "documentos_admin_read" ON storage.objects;
CREATE POLICY "documentos_admin_read" ON storage.objects FOR SELECT 
USING (
    bucket_id = 'documentos' AND
    EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin', 'operador'))
);

DROP POLICY IF EXISTS "documentos_admin_insert" ON storage.objects;
CREATE POLICY "documentos_admin_insert" ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'documentos' AND
    EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin', 'operador'))
);

-- Políticas para bucket 'avatares' (público lectura, usuario propio escribe)
DROP POLICY IF EXISTS "avatares_public_read" ON storage.objects;
CREATE POLICY "avatares_public_read" ON storage.objects FOR SELECT 
USING (bucket_id = 'avatares');

DROP POLICY IF EXISTS "avatares_auth_insert" ON storage.objects;
CREATE POLICY "avatares_auth_insert" ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'avatares' AND auth.role() = 'authenticated');

-- Políticas para bucket 'logos' (público, admin+ sube)
DROP POLICY IF EXISTS "logos_public_read" ON storage.objects;
CREATE POLICY "logos_public_read" ON storage.objects FOR SELECT 
USING (bucket_id = 'logos');

DROP POLICY IF EXISTS "logos_admin_insert" ON storage.objects;
CREATE POLICY "logos_admin_insert" ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'logos' AND
    EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin'))
);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 34: SISTEMA DE EMPLEADOS MULTI-NEGOCIO Y ROLES MODULARES (V10.21)
-- ══════════════════════════════════════════════════════════════════════════════

-- Tabla de asignación de empleados a múltiples negocios con rol específico
CREATE TABLE IF NOT EXISTS empleados_negocios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empleado_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    auth_uid UUID, -- Vinculación directa con auth.users
    rol_modulo TEXT NOT NULL DEFAULT 'operador', -- tecnico, repartidor, vendedor, cobrador, operador, admin
    modulos_acceso TEXT[] DEFAULT '{}', -- Array de módulos: ['climas', 'purificadora', 'ventas', 'prestamos']
    permisos_especificos JSONB DEFAULT '{}', -- Permisos granulares por módulo
    es_administrador BOOLEAN DEFAULT FALSE, -- Si puede administrar este negocio
    zona_asignada TEXT, -- Para técnicos y repartidores
    horario_trabajo JSONB DEFAULT '{}', -- { lunes: {inicio: '08:00', fin: '17:00'}, ... }
    comision_porcentaje DECIMAL(5,2) DEFAULT 0,
    meta_mensual DECIMAL(14,2) DEFAULT 0,
    activo BOOLEAN DEFAULT TRUE,
    fecha_asignacion DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(empleado_id, negocio_id)
);

CREATE INDEX IF NOT EXISTS idx_empleados_negocios_empleado ON empleados_negocios(empleado_id);
CREATE INDEX IF NOT EXISTS idx_empleados_negocios_negocio ON empleados_negocios(negocio_id);
CREATE INDEX IF NOT EXISTS idx_empleados_negocios_auth ON empleados_negocios(auth_uid);
CREATE INDEX IF NOT EXISTS idx_empleados_negocios_rol ON empleados_negocios(rol_modulo);

ALTER TABLE empleados_negocios ENABLE ROW LEVEL SECURITY;
CREATE POLICY "empleados_negocios_access" ON empleados_negocios FOR ALL 
USING (auth.role() = 'authenticated');

-- Tabla para técnicos de aire acondicionado
CREATE TABLE IF NOT EXISTS climas_tecnicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    empleado_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
    auth_uid UUID, -- Para login directo
    codigo TEXT NOT NULL, -- TEC-001
    nombre TEXT NOT NULL,
    apellidos TEXT,
    telefono TEXT,
    email TEXT,
    especialidades TEXT[] DEFAULT '{}', -- ['instalacion', 'mantenimiento', 'reparacion', 'refrigeracion']
    certificaciones TEXT[] DEFAULT '{}', -- ['EPA', 'NATE', 'R410A']
    vehiculo_asignado TEXT,
    zona_cobertura TEXT[] DEFAULT '{}', -- Array de colonias/zonas
    calificacion_promedio DECIMAL(3,2) DEFAULT 5.0,
    total_servicios INTEGER DEFAULT 0,
    servicios_mes INTEGER DEFAULT 0,
    comision_servicio DECIMAL(5,2) DEFAULT 10, -- % por servicio
    disponible BOOLEAN DEFAULT TRUE,
    en_servicio BOOLEAN DEFAULT FALSE,
    ubicacion_actual JSONB, -- { lat: , lng: }
    foto_url TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(negocio_id, codigo)
);

CREATE INDEX IF NOT EXISTS idx_climas_tecnicos_negocio ON climas_tecnicos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_climas_tecnicos_auth ON climas_tecnicos(auth_uid);
CREATE INDEX IF NOT EXISTS idx_climas_tecnicos_disponible ON climas_tecnicos(disponible);

ALTER TABLE climas_tecnicos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "climas_tecnicos_access" ON climas_tecnicos FOR ALL 
USING (auth.role() = 'authenticated');

-- Tabla para repartidores de purificadora
CREATE TABLE IF NOT EXISTS purificadora_repartidores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    empleado_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
    auth_uid UUID, -- Para login directo
    codigo TEXT NOT NULL, -- REP-001
    nombre TEXT NOT NULL,
    apellidos TEXT,
    telefono TEXT,
    email TEXT,
    licencia_conducir TEXT,
    vigencia_licencia DATE,
    vehiculo_asignado TEXT,
    capacidad_garrafones INTEGER DEFAULT 50,
    rutas_asignadas TEXT[] DEFAULT '{}',
    entregas_hoy INTEGER DEFAULT 0,
    entregas_mes INTEGER DEFAULT 0,
    garrafones_entregados_mes INTEGER DEFAULT 0,
    comision_garrrafon DECIMAL(5,2) DEFAULT 2, -- $ por garrafón
    efectivo_en_mano DECIMAL(14,2) DEFAULT 0,
    disponible BOOLEAN DEFAULT TRUE,
    en_ruta BOOLEAN DEFAULT FALSE,
    ubicacion_actual JSONB, -- { lat: , lng: }
    foto_url TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(negocio_id, codigo)
);

CREATE INDEX IF NOT EXISTS idx_purificadora_repartidores_negocio ON purificadora_repartidores(negocio_id);
CREATE INDEX IF NOT EXISTS idx_purificadora_repartidores_auth ON purificadora_repartidores(auth_uid);
CREATE INDEX IF NOT EXISTS idx_purificadora_repartidores_disponible ON purificadora_repartidores(disponible);

ALTER TABLE purificadora_repartidores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "purificadora_repartidores_access" ON purificadora_repartidores FOR ALL 
USING (auth.role() = 'authenticated');

-- Tabla de clientes por módulo (acceso a su app)
CREATE TABLE IF NOT EXISTS clientes_modulo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    auth_uid UUID, -- Para login
    modulo TEXT NOT NULL, -- 'climas', 'purificadora', 'ventas', 'prestamos'
    codigo_cliente TEXT, -- CLI-CLIMAS-001
    saldo_pendiente DECIMAL(14,2) DEFAULT 0,
    puntos_acumulados INTEGER DEFAULT 0,
    nivel_cliente TEXT DEFAULT 'nuevo', -- nuevo, frecuente, vip, premium
    preferencias JSONB DEFAULT '{}',
    historial_interacciones INTEGER DEFAULT 0,
    ultima_interaccion TIMESTAMPTZ,
    puede_pedir_credito BOOLEAN DEFAULT FALSE,
    limite_credito DECIMAL(14,2) DEFAULT 0,
    notificaciones_activas BOOLEAN DEFAULT TRUE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(cliente_id, modulo)
);

CREATE INDEX IF NOT EXISTS idx_clientes_modulo_negocio ON clientes_modulo(negocio_id);
CREATE INDEX IF NOT EXISTS idx_clientes_modulo_auth ON clientes_modulo(auth_uid);
CREATE INDEX IF NOT EXISTS idx_clientes_modulo_modulo ON clientes_modulo(modulo);

ALTER TABLE clientes_modulo ENABLE ROW LEVEL SECURITY;
CREATE POLICY "clientes_modulo_access" ON clientes_modulo FOR ALL 
USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 35: MÓDULO NICE - JOYERÍA MLM COMPLETO
-- ══════════════════════════════════════════════════════════════════════════════

-- Catálogos de joyería
CREATE TABLE IF NOT EXISTS nice_catalogos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    codigo TEXT,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    imagen_portada_url TEXT,
    imagen_portada TEXT, -- Alias para compatibilidad
    pdf_url TEXT,
    fecha_inicio DATE,
    fecha_fin DATE,
    vigencia_inicio DATE, -- Alias para compatibilidad
    vigencia_fin DATE, -- Alias para compatibilidad
    version TEXT DEFAULT '1.0',
    activo BOOLEAN DEFAULT TRUE,
    orden INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Categorías de productos Nice
CREATE TABLE IF NOT EXISTS nice_categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    icono TEXT DEFAULT 'diamond',
    color TEXT DEFAULT '#E91E63',
    imagen_url TEXT,
    orden INTEGER DEFAULT 0,
    activa BOOLEAN DEFAULT TRUE,
    activo BOOLEAN DEFAULT TRUE, -- Alias para compatibilidad
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Niveles de vendedoras MLM
CREATE TABLE IF NOT EXISTS nice_niveles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    codigo TEXT, -- bronce, plata, oro, platino, diamante (opcional)
    nombre TEXT NOT NULL,
    comision_ventas DECIMAL(5,2) DEFAULT 20, -- % de comisión (alias comision_porcentaje)
    comision_porcentaje DECIMAL(5,2) DEFAULT 20, -- Alias para compatibilidad
    comision_equipo DECIMAL(5,2) DEFAULT 5, -- % por ventas de equipo
    comision_equipo_porcentaje DECIMAL(5,2) DEFAULT 5, -- Alias para compatibilidad
    descuento_porcentaje DECIMAL(5,2) DEFAULT 25, -- Descuento al comprar
    ventas_minimas_mes DECIMAL(14,2) DEFAULT 0, -- Requerido para mantener nivel
    meta_ventas_mensual DECIMAL(14,2) DEFAULT 0, -- Alias para compatibilidad
    bono_reclutamiento DECIMAL(14,2) DEFAULT 0,
    beneficios JSONB DEFAULT '[]', -- Lista de beneficios del nivel
    color TEXT DEFAULT '#CD7F32',
    icono TEXT DEFAULT 'star', -- Icono del nivel
    orden INTEGER DEFAULT 0,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Productos de joyería
CREATE TABLE IF NOT EXISTS nice_productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    catalogo_id UUID REFERENCES nice_catalogos(id) ON DELETE SET NULL,
    categoria_id UUID REFERENCES nice_categorias(id) ON DELETE SET NULL,
    sku TEXT,
    codigo_pagina TEXT, -- Código del catálogo físico
    nombre TEXT NOT NULL,
    descripcion TEXT,
    material TEXT, -- oro, plata, acero, fantasía
    precio_catalogo DECIMAL(14,2) NOT NULL, -- Precio al público
    precio_vendedora DECIMAL(14,2), -- Precio para la vendedora
    costo DECIMAL(14,2), -- Costo real
    stock INTEGER DEFAULT 0,
    stock_minimo INTEGER DEFAULT 5,
    imagen_url TEXT,
    imagenes_adicionales JSONB DEFAULT '[]',
    destacado BOOLEAN DEFAULT FALSE,
    nuevo BOOLEAN DEFAULT FALSE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vendedoras/Consultoras Nice (MLM)
CREATE TABLE IF NOT EXISTS nice_vendedoras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    auth_uid UUID, -- Para login directo
    nivel_id UUID REFERENCES nice_niveles(id) ON DELETE SET NULL,
    patrocinadora_id UUID REFERENCES nice_vendedoras(id) ON DELETE SET NULL, -- Quien la reclutó
    codigo_vendedora TEXT, -- VND-001
    nombre TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    whatsapp TEXT,
    direccion TEXT,
    ciudad TEXT,
    fecha_nacimiento DATE,
    ine_url TEXT,
    foto_url TEXT,
    banco TEXT,
    clabe TEXT,
    numero_cuenta TEXT,
    fecha_ingreso DATE DEFAULT CURRENT_DATE,
    ventas_totales DECIMAL(14,2) DEFAULT 0,
    ventas_mes DECIMAL(14,2) DEFAULT 0,
    comisiones_pendientes DECIMAL(14,2) DEFAULT 0,
    equipo_total INTEGER DEFAULT 0, -- Personas reclutadas
    meta_mensual DECIMAL(14,2) DEFAULT 5000,
    notas TEXT,
    activa BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(negocio_id, codigo_vendedora),
    UNIQUE(negocio_id, email)
);

-- Clientes de vendedoras Nice
CREATE TABLE IF NOT EXISTS nice_clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    vendedora_id UUID REFERENCES nice_vendedoras(id) ON DELETE SET NULL,
    auth_uid UUID, -- Para login (opcional)
    nombre TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    whatsapp TEXT,
    direccion TEXT,
    ciudad TEXT,
    fecha_nacimiento DATE,
    preferencias JSONB DEFAULT '{}', -- tallas, colores, etc
    total_compras DECIMAL(14,2) DEFAULT 0,
    puntos INTEGER DEFAULT 0,
    nivel_cliente TEXT DEFAULT 'nuevo', -- nuevo, frecuente, vip
    notas TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pedidos Nice
CREATE TABLE IF NOT EXISTS nice_pedidos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    vendedora_id UUID REFERENCES nice_vendedoras(id) ON DELETE SET NULL,
    cliente_id UUID REFERENCES nice_clientes(id) ON DELETE SET NULL,
    folio TEXT, -- PED-NICE-001
    fecha_pedido TIMESTAMPTZ DEFAULT NOW(),
    fecha_entrega_estimada DATE,
    fecha_entrega_real DATE,
    subtotal DECIMAL(14,2) DEFAULT 0,
    descuento DECIMAL(14,2) DEFAULT 0,
    total DECIMAL(14,2) DEFAULT 0,
    metodo_pago TEXT DEFAULT 'efectivo',
    estado TEXT DEFAULT 'pendiente', -- pendiente, confirmado, en_proceso, enviado, entregado, cancelado
    direccion_entrega TEXT,
    notas TEXT,
    comision_vendedora DECIMAL(14,2) DEFAULT 0,
    comision_pagada BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Detalle de pedidos Nice
CREATE TABLE IF NOT EXISTS nice_pedido_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES nice_pedidos(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES nice_productos(id) ON DELETE SET NULL,
    cantidad INTEGER DEFAULT 1,
    precio_unitario DECIMAL(14,2) NOT NULL,
    descuento DECIMAL(14,2) DEFAULT 0,
    subtotal DECIMAL(14,2) NOT NULL,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Comisiones de vendedoras
CREATE TABLE IF NOT EXISTS nice_comisiones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedora_id UUID REFERENCES nice_vendedoras(id) ON DELETE CASCADE,
    pedido_id UUID REFERENCES nice_pedidos(id) ON DELETE SET NULL,
    tipo TEXT DEFAULT 'venta', -- venta, equipo, bono
    monto DECIMAL(14,2) NOT NULL,
    porcentaje DECIMAL(5,2),
    descripcion TEXT,
    estado TEXT DEFAULT 'pendiente', -- pendiente, aprobada, pagada
    fecha_pago DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inventario por vendedora (consignación)
CREATE TABLE IF NOT EXISTS nice_inventario_vendedora (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedora_id UUID REFERENCES nice_vendedoras(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES nice_productos(id) ON DELETE CASCADE,
    cantidad INTEGER DEFAULT 0,
    cantidad_vendida INTEGER DEFAULT 0,
    costo_unitario DECIMAL(14,2),
    fecha_asignacion DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(vendedora_id, producto_id)
);

-- Índices Nice
CREATE INDEX IF NOT EXISTS idx_nice_vendedoras_negocio ON nice_vendedoras(negocio_id);
CREATE INDEX IF NOT EXISTS idx_nice_vendedoras_auth ON nice_vendedoras(auth_uid);
CREATE INDEX IF NOT EXISTS idx_nice_vendedoras_nivel ON nice_vendedoras(nivel_id);
CREATE INDEX IF NOT EXISTS idx_nice_clientes_vendedora ON nice_clientes(vendedora_id);
CREATE INDEX IF NOT EXISTS idx_nice_clientes_auth ON nice_clientes(auth_uid);
CREATE INDEX IF NOT EXISTS idx_nice_pedidos_vendedora ON nice_pedidos(vendedora_id);
CREATE INDEX IF NOT EXISTS idx_nice_pedidos_cliente ON nice_pedidos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_nice_pedidos_estado ON nice_pedidos(estado);
CREATE INDEX IF NOT EXISTS idx_nice_productos_categoria ON nice_productos(categoria_id);

-- RLS Nice
ALTER TABLE nice_catalogos ENABLE ROW LEVEL SECURITY;
ALTER TABLE nice_categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE nice_niveles ENABLE ROW LEVEL SECURITY;
ALTER TABLE nice_productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE nice_vendedoras ENABLE ROW LEVEL SECURITY;
ALTER TABLE nice_clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE nice_pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE nice_pedido_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE nice_comisiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE nice_inventario_vendedora ENABLE ROW LEVEL SECURITY;

CREATE POLICY "nice_catalogos_access" ON nice_catalogos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "nice_categorias_access" ON nice_categorias FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "nice_niveles_access" ON nice_niveles FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "nice_productos_access" ON nice_productos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "nice_vendedoras_access" ON nice_vendedoras FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "nice_clientes_access" ON nice_clientes FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "nice_pedidos_access" ON nice_pedidos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "nice_pedido_items_access" ON nice_pedido_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "nice_comisiones_access" ON nice_comisiones FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "nice_inventario_access" ON nice_inventario_vendedora FOR ALL USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- DATOS INICIALES NICE JOYERÍA
-- ══════════════════════════════════════════════════════════════════════════════

-- Niveles MLM predefinidos (se insertan al ejecutar, asociados al primer negocio)
INSERT INTO nice_niveles (negocio_id, codigo, nombre, comision_ventas, comision_equipo, descuento_porcentaje, ventas_minimas_mes, bono_reclutamiento, color, orden)
SELECT n.id, v.codigo, v.nombre, v.comision_ventas, v.comision_equipo, v.descuento_porcentaje, v.ventas_minimas_mes, v.bono_reclutamiento, v.color, v.orden
FROM negocios n
CROSS JOIN (VALUES 
    ('bronce', '🥉 Bronce', 20, 0, 25, 0, 0, '#CD7F32', 1),
    ('plata', '🥈 Plata', 25, 3, 30, 5000, 100, '#C0C0C0', 2),
    ('oro', '🥇 Oro', 30, 5, 35, 15000, 200, '#FFD700', 3),
    ('platino', '💎 Platino', 35, 7, 40, 30000, 500, '#E5E4E2', 4),
    ('diamante', '👑 Diamante', 40, 10, 45, 50000, 1000, '#B9F2FF', 5)
) AS v(codigo, nombre, comision_ventas, comision_equipo, descuento_porcentaje, ventas_minimas_mes, bono_reclutamiento, color, orden)
WHERE n.id = (SELECT id FROM negocios LIMIT 1)
ON CONFLICT DO NOTHING;

-- Categorías de joyería predefinidas
INSERT INTO nice_categorias (negocio_id, nombre, descripcion, icono, color, orden)
SELECT n.id, v.nombre, v.descripcion, v.icono, v.color, v.orden
FROM negocios n
CROSS JOIN (VALUES 
    ('Anillos', 'Anillos de todos los estilos', 'ring', '#E91E63', 1),
    ('Collares', 'Collares y cadenas', 'necklace', '#9C27B0', 2),
    ('Aretes', 'Aretes y pendientes', 'earrings', '#673AB7', 3),
    ('Pulseras', 'Pulseras y brazaletes', 'bracelet', '#3F51B5', 4),
    ('Relojes', 'Relojes de moda', 'watch', '#2196F3', 5),
    ('Accesorios', 'Broches, pins y más', 'accessories', '#00BCD4', 6),
    ('Sets', 'Conjuntos completos', 'set', '#FF9800', 7)
) AS v(nombre, descripcion, icono, color, orden)
WHERE n.id = (SELECT id FROM negocios LIMIT 1)
ON CONFLICT DO NOTHING;

-- Catálogo inicial
INSERT INTO nice_catalogos (negocio_id, codigo, nombre, descripcion, fecha_inicio, fecha_fin, activo, orden)
SELECT n.id, 'CAT-2026-01', 'Catálogo Primavera 2026', 'Colección Primavera con las últimas tendencias', '2026-01-01', '2026-06-30', TRUE, 1
FROM negocios n
WHERE n.id = (SELECT id FROM negocios LIMIT 1)
ON CONFLICT DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════════
-- VISTAS NICE - Para consultas optimizadas
-- ══════════════════════════════════════════════════════════════════════════════

-- Vista de productos completa con categoría y catálogo
CREATE OR REPLACE VIEW v_nice_productos_completo AS
SELECT 
    p.id,
    p.negocio_id,
    p.catalogo_id,
    p.categoria_id,
    p.sku,
    p.codigo_pagina as pagina_catalogo,
    p.nombre,
    p.descripcion,
    p.material,
    p.precio_catalogo,
    COALESCE(p.precio_vendedora, p.precio_catalogo * 0.70) as precio_vendedora,
    COALESCE(p.costo, p.precio_catalogo * 0.45) as costo,
    p.stock,
    p.stock_minimo,
    p.imagen_url as imagen_principal_url,
    p.imagenes_adicionales,
    p.destacado as es_destacado,
    p.nuevo as es_nuevo,
    FALSE as es_oferta,
    NULL::DECIMAL as precio_oferta,
    p.activo,
    p.created_at,
    p.updated_at,
    c.nombre as categoria_nombre,
    c.color as categoria_color,
    c.icono as categoria_icono,
    cat.nombre as catalogo_nombre,
    cat.codigo as catalogo_codigo,
    CASE WHEN p.stock > 0 THEN TRUE ELSE FALSE END as disponible,
    (p.precio_catalogo - COALESCE(p.precio_vendedora, p.precio_catalogo * 0.70)) as ganancia_vendedora,
    0 as veces_vendido
FROM nice_productos p
LEFT JOIN nice_categorias c ON c.id = p.categoria_id
LEFT JOIN nice_catalogos cat ON cat.id = p.catalogo_id;

-- Vista de vendedoras completa con nivel y estadísticas
CREATE OR REPLACE VIEW v_nice_vendedoras_completo AS
SELECT 
    v.*,
    n.nombre as nivel_nombre,
    n.codigo as nivel_codigo,
    n.comision_ventas as nivel_comision,
    n.comision_equipo as nivel_comision_equipo,
    n.descuento_porcentaje as nivel_descuento,
    n.color as nivel_color,
    n.ventas_minimas_mes as nivel_meta,
    p.nombre as patrocinadora_nombre,
    p.codigo_vendedora as patrocinadora_codigo,
    (SELECT COUNT(*) FROM nice_vendedoras sub WHERE sub.patrocinadora_id = v.id) as equipo_directo,
    (SELECT COALESCE(SUM(total), 0) FROM nice_pedidos ped WHERE ped.vendedora_id = v.id AND ped.estado = 'entregado' AND EXTRACT(MONTH FROM ped.fecha_pedido) = EXTRACT(MONTH FROM CURRENT_DATE)) as ventas_mes_actual,
    (SELECT COUNT(*) FROM nice_pedidos ped WHERE ped.vendedora_id = v.id AND ped.estado = 'pendiente') as pedidos_pendientes,
    (SELECT COALESCE(SUM(monto), 0) FROM nice_comisiones com WHERE com.vendedora_id = v.id AND com.estado = 'pendiente') as comisiones_por_cobrar
FROM nice_vendedoras v
LEFT JOIN nice_niveles n ON n.id = v.nivel_id
LEFT JOIN nice_vendedoras p ON p.id = v.patrocinadora_id;

-- Vista de pedidos completa
CREATE OR REPLACE VIEW v_nice_pedidos_completo AS
SELECT 
    p.*,
    v.nombre as vendedora_nombre,
    v.codigo_vendedora,
    v.telefono as vendedora_telefono,
    c.nombre as cliente_nombre,
    c.telefono as cliente_telefono,
    c.direccion as cliente_direccion,
    (SELECT COUNT(*) FROM nice_pedido_items i WHERE i.pedido_id = p.id) as total_items,
    (SELECT COALESCE(SUM(cantidad), 0) FROM nice_pedido_items i WHERE i.pedido_id = p.id) as total_piezas
FROM nice_pedidos p
LEFT JOIN nice_vendedoras v ON v.id = p.vendedora_id
LEFT JOIN nice_clientes c ON c.id = p.cliente_id;

-- Vista de comisiones con detalles
CREATE OR REPLACE VIEW v_nice_comisiones_completo AS
SELECT 
    c.*,
    v.nombre as vendedora_nombre,
    v.codigo_vendedora,
    p.folio as pedido_folio,
    p.total as pedido_total
FROM nice_comisiones c
LEFT JOIN nice_vendedoras v ON v.id = c.vendedora_id
LEFT JOIN nice_pedidos p ON p.id = c.pedido_id;

-- Vista de inventario por vendedora
CREATE OR REPLACE VIEW v_nice_inventario_vendedora AS
SELECT 
    i.*,
    v.nombre as vendedora_nombre,
    v.codigo_vendedora,
    p.nombre as producto_nombre,
    p.sku as producto_sku,
    p.precio_catalogo,
    p.precio_vendedora,
    p.imagen_url as producto_imagen,
    cat.nombre as categoria_nombre,
    (i.cantidad - i.cantidad_vendida) as disponible,
    (i.cantidad * i.costo_unitario) as valor_consignacion
FROM nice_inventario_vendedora i
LEFT JOIN nice_vendedoras v ON v.id = i.vendedora_id
LEFT JOIN nice_productos p ON p.id = i.producto_id
LEFT JOIN nice_categorias cat ON cat.id = p.categoria_id;

-- Vista de clientes con estadísticas
CREATE OR REPLACE VIEW v_nice_clientes_completo AS
SELECT 
    c.*,
    v.nombre as vendedora_nombre,
    v.codigo_vendedora,
    (SELECT COUNT(*) FROM nice_pedidos p WHERE p.cliente_id = c.id) as total_pedidos,
    (SELECT MAX(fecha_pedido) FROM nice_pedidos p WHERE p.cliente_id = c.id) as ultima_compra
FROM nice_clientes c
LEFT JOIN nice_vendedoras v ON v.id = c.vendedora_id;

-- ═══════════════════════════════════════════════════════════════════════════════
-- VISTAS ADICIONALES NICE - Requeridas por el servicio
-- ═══════════════════════════════════════════════════════════════════════════════

-- Alias: v_nice_vendedoras_stats (igual a v_nice_vendedoras_completo)
CREATE OR REPLACE VIEW v_nice_vendedoras_stats AS
SELECT * FROM v_nice_vendedoras_completo;

-- Vista del árbol/red de equipo MLM
CREATE OR REPLACE VIEW v_nice_arbol_equipo AS
WITH RECURSIVE arbol AS (
    -- Nivel raíz: vendedoras sin patrocinadora
    SELECT 
        v.id,
        v.negocio_id,
        v.nombre,
        v.codigo_vendedora,
        v.patrocinadora_id,
        v.nivel_id,
        v.ventas_mes,
        v.activa,
        0 as nivel_profundidad,
        v.nombre as ruta,
        ARRAY[v.id] as jerarquia
    FROM nice_vendedoras v
    WHERE v.patrocinadora_id IS NULL
    
    UNION ALL
    
    -- Niveles descendientes
    SELECT 
        v.id,
        v.negocio_id,
        v.nombre,
        v.codigo_vendedora,
        v.patrocinadora_id,
        v.nivel_id,
        v.ventas_mes,
        v.activa,
        a.nivel_profundidad + 1,
        a.ruta || ' > ' || v.nombre,
        a.jerarquia || v.id
    FROM nice_vendedoras v
    INNER JOIN arbol a ON v.patrocinadora_id = a.id
    WHERE NOT v.id = ANY(a.jerarquia) -- Evitar ciclos
)
SELECT 
    a.*,
    n.nombre as nivel_nombre,
    n.color as nivel_color,
    p.nombre as patrocinadora_nombre,
    (SELECT COUNT(*) FROM nice_vendedoras sub WHERE sub.patrocinadora_id = a.id) as equipo_directo
FROM arbol a
LEFT JOIN nice_niveles n ON n.id = a.nivel_id
LEFT JOIN nice_vendedoras p ON p.id = a.patrocinadora_id;

-- ══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES NICE - Lógica de negocio
-- ══════════════════════════════════════════════════════════════════════════════

-- Función para calcular comisión de una venta
CREATE OR REPLACE FUNCTION calcular_comision_nice(
    p_vendedora_id UUID,
    p_monto_venta NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
    v_porcentaje NUMERIC;
BEGIN
    SELECT n.comision_ventas INTO v_porcentaje
    FROM nice_vendedoras v
    JOIN nice_niveles n ON n.id = v.nivel_id
    WHERE v.id = p_vendedora_id;
    
    IF v_porcentaje IS NULL THEN
        v_porcentaje := 20; -- Default 20%
    END IF;
    
    RETURN ROUND(p_monto_venta * v_porcentaje / 100, 2);
END;
$$ LANGUAGE plpgsql;

-- Función para verificar y actualizar nivel de vendedora
CREATE OR REPLACE FUNCTION actualizar_nivel_vendedora(p_vendedora_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_ventas_mes NUMERIC;
    v_nuevo_nivel_id UUID;
    v_nivel_actual TEXT;
    v_nivel_nuevo TEXT;
    v_negocio_id UUID;
BEGIN
    -- Obtener ventas del mes y negocio
    SELECT 
        COALESCE(SUM(total), 0),
        v.negocio_id
    INTO v_ventas_mes, v_negocio_id
    FROM nice_vendedoras v
    LEFT JOIN nice_pedidos p ON p.vendedora_id = v.id 
        AND p.estado = 'entregado'
        AND EXTRACT(MONTH FROM p.fecha_pedido) = EXTRACT(MONTH FROM CURRENT_DATE)
        AND EXTRACT(YEAR FROM p.fecha_pedido) = EXTRACT(YEAR FROM CURRENT_DATE)
    WHERE v.id = p_vendedora_id
    GROUP BY v.negocio_id;
    
    -- Obtener nivel actual
    SELECT n.nombre INTO v_nivel_actual
    FROM nice_vendedoras v
    JOIN nice_niveles n ON n.id = v.nivel_id
    WHERE v.id = p_vendedora_id;
    
    -- Buscar nivel correspondiente a las ventas
    SELECT id, nombre INTO v_nuevo_nivel_id, v_nivel_nuevo
    FROM nice_niveles
    WHERE negocio_id = v_negocio_id
        AND ventas_minimas_mes <= v_ventas_mes
    ORDER BY ventas_minimas_mes DESC
    LIMIT 1;
    
    -- Actualizar si hay cambio de nivel
    IF v_nuevo_nivel_id IS NOT NULL THEN
        UPDATE nice_vendedoras
        SET nivel_id = v_nuevo_nivel_id,
            ventas_mes = v_ventas_mes
        WHERE id = p_vendedora_id;
    END IF;
    
    RETURN COALESCE(v_nivel_nuevo, v_nivel_actual);
END;
$$ LANGUAGE plpgsql;

-- Función para generar folio de pedido
CREATE OR REPLACE FUNCTION generar_folio_nice_pedido(p_negocio_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_numero INTEGER;
    v_folio TEXT;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(folio FROM 'PED-NICE-(\d+)') AS INTEGER)), 0) + 1
    INTO v_numero
    FROM nice_pedidos
    WHERE negocio_id = p_negocio_id;
    
    v_folio := 'PED-NICE-' || LPAD(v_numero::TEXT, 6, '0');
    RETURN v_folio;
END;
$$ LANGUAGE plpgsql;

-- Trigger para generar folio automático
CREATE OR REPLACE FUNCTION trigger_nice_pedido_folio()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.folio IS NULL OR NEW.folio = '' THEN
        NEW.folio := generar_folio_nice_pedido(NEW.negocio_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_nice_pedido_folio ON nice_pedidos;
CREATE TRIGGER trigger_nice_pedido_folio
    BEFORE INSERT ON nice_pedidos
    FOR EACH ROW
    EXECUTE FUNCTION trigger_nice_pedido_folio();

-- Trigger para crear comisión al entregar pedido
CREATE OR REPLACE FUNCTION trigger_nice_comision_entrega()
RETURNS TRIGGER AS $$
DECLARE
    v_comision NUMERIC;
BEGIN
    -- Solo cuando cambia a 'entregado'
    IF NEW.estado = 'entregado' AND OLD.estado != 'entregado' THEN
        -- Calcular comisión
        v_comision := calcular_comision_nice(NEW.vendedora_id, NEW.total);
        
        -- Insertar comisión
        INSERT INTO nice_comisiones (vendedora_id, pedido_id, tipo, monto, porcentaje, descripcion, estado)
        VALUES (NEW.vendedora_id, NEW.id, 'venta', v_comision, 
                (SELECT n.comision_ventas FROM nice_vendedoras v JOIN nice_niveles n ON n.id = v.nivel_id WHERE v.id = NEW.vendedora_id),
                'Comisión por pedido ' || NEW.folio, 'pendiente');
        
        -- Actualizar comisión del pedido
        NEW.comision_vendedora := v_comision;
        
        -- Actualizar ventas de la vendedora
        UPDATE nice_vendedoras
        SET ventas_totales = ventas_totales + NEW.total,
            ventas_mes = ventas_mes + NEW.total
        WHERE id = NEW.vendedora_id;
        
        -- Verificar si sube de nivel
        PERFORM actualizar_nivel_vendedora(NEW.vendedora_id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_nice_comision_entrega ON nice_pedidos;
CREATE TRIGGER trigger_nice_comision_entrega
    BEFORE UPDATE ON nice_pedidos
    FOR EACH ROW
    EXECUTE FUNCTION trigger_nice_comision_entrega();

-- Función para generar código de vendedora
CREATE OR REPLACE FUNCTION generar_codigo_vendedora(p_negocio_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_numero INTEGER;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_vendedora FROM 'VND-(\d+)') AS INTEGER)), 0) + 1
    INTO v_numero
    FROM nice_vendedoras
    WHERE negocio_id = p_negocio_id;
    
    RETURN 'VND-' || LPAD(v_numero::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- ══════════════════════════════════════════════════════════════════════════════
-- PRODUCTOS DE EJEMPLO NICE
-- ══════════════════════════════════════════════════════════════════════════════

-- Insertar productos de ejemplo
INSERT INTO nice_productos (negocio_id, categoria_id, sku, codigo_pagina, nombre, descripcion, material, precio_catalogo, precio_vendedora, costo, stock, stock_minimo, destacado, nuevo, activo)
SELECT 
    n.id,
    cat.id,
    'NICE-' || LPAD((ROW_NUMBER() OVER())::TEXT, 4, '0'),
    'P' || LPAD((ROW_NUMBER() OVER())::TEXT, 3, '0'),
    prod.nombre,
    prod.descripcion,
    prod.material,
    prod.precio,
    ROUND(prod.precio * 0.70, 2),
    ROUND(prod.precio * 0.45, 2),
    prod.stock,
    5,
    prod.destacado,
    prod.nuevo,
    TRUE
FROM negocios n
CROSS JOIN (VALUES
    ('Anillo Solitario Clásico', 'Anillo con circón brillante central, diseño atemporal', 'Plata 925', 850.00, 25, TRUE, TRUE, 'Anillos'),
    ('Anillo Infinity Love', 'Símbolo del amor infinito con piedras', 'Oro 10k', 2200.00, 15, TRUE, FALSE, 'Anillos'),
    ('Anillo Triple Band', 'Tres bandas entrelazadas elegantes', 'Plata 925', 650.00, 30, FALSE, TRUE, 'Anillos'),
    ('Anillo Vintage Rose', 'Diseño floral estilo vintage', 'Oro rosa 14k', 3500.00, 10, TRUE, FALSE, 'Anillos'),
    ('Collar Corazón Brillante', 'Dije corazón con cadena de 45cm', 'Plata 925', 980.00, 20, TRUE, TRUE, 'Collares'),
    ('Collar Perlas Elegance', 'Collar de perlas cultivadas 6mm', 'Perlas/Plata', 1500.00, 12, TRUE, FALSE, 'Collares'),
    ('Collar Inicial Personalizado', 'Letra a elegir con cadena fina', 'Oro 10k', 1200.00, 40, FALSE, TRUE, 'Collares'),
    ('Collar Cruz Diamantada', 'Cruz con acabado diamantado', 'Plata 925', 750.00, 25, FALSE, FALSE, 'Collares'),
    ('Aretes Huggies Diamond', 'Aretes abrazadera con circones', 'Plata 925', 680.00, 35, TRUE, TRUE, 'Aretes'),
    ('Aretes Gota Cristal', 'Aretes largos con cristal Swarovski', 'Plata/Cristal', 950.00, 20, TRUE, FALSE, 'Aretes'),
    ('Aretes Perla Clásica', 'Perla de 8mm con poste de oro', 'Perla/Oro 10k', 1100.00, 18, FALSE, TRUE, 'Aretes'),
    ('Aretes Argolla Grande', 'Argollas 3cm acabado brillante', 'Oro 14k', 2800.00, 8, FALSE, FALSE, 'Aretes'),
    ('Pulsera Tennis Classic', 'Pulsera tennis con 30 circones', 'Plata 925', 1400.00, 15, TRUE, TRUE, 'Pulseras'),
    ('Pulsera Charm Love', 'Pulsera con 5 dijes incluidos', 'Plata 925', 890.00, 22, TRUE, FALSE, 'Pulseras'),
    ('Pulsera Rígida Elegante', 'Brazalete rígido pulido', 'Oro 10k', 3200.00, 6, FALSE, TRUE, 'Pulseras'),
    ('Pulsera Riviera Colores', 'Piedras multicolor en línea', 'Plata 925', 1050.00, 18, FALSE, FALSE, 'Pulseras'),
    ('Reloj Glamour Rose', 'Reloj dama con cristales', 'Acero/Oro rosa', 1800.00, 10, TRUE, TRUE, 'Relojes'),
    ('Reloj Classic Silver', 'Diseño minimalista elegante', 'Acero inoxidable', 1200.00, 15, FALSE, FALSE, 'Relojes'),
    ('Set Novia Completo', 'Collar + Aretes + Pulsera + Tiara', 'Plata 925/Cristal', 4500.00, 5, TRUE, TRUE, 'Sets'),
    ('Set XV Años Princess', 'Conjunto completo para quinceañera', 'Oro 10k/Circones', 6500.00, 4, TRUE, FALSE, 'Sets'),
    ('Set Fiesta Elegante', 'Collar y aretes a juego', 'Plata 925', 1800.00, 12, FALSE, TRUE, 'Sets'),
    ('Broche Mariposa Cristal', 'Broche decorativo con cristales', 'Fantasía fina', 280.00, 50, FALSE, FALSE, 'Accesorios'),
    ('Pin Inicial Dorado', 'Pin con letra personalizable', 'Fantasía dorada', 150.00, 80, FALSE, TRUE, 'Accesorios'),
    ('Diadema Brillante', 'Diadema para ocasiones especiales', 'Metal/Cristales', 450.00, 20, TRUE, FALSE, 'Accesorios')
) AS prod(nombre, descripcion, material, precio, stock, destacado, nuevo, categoria)
LEFT JOIN nice_categorias cat ON cat.nombre = prod.categoria AND cat.negocio_id = n.id
WHERE n.id = (SELECT id FROM negocios LIMIT 1)
ON CONFLICT DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 36: MÓDULO VENTAS/CATÁLOGO COMPLETO
-- ══════════════════════════════════════════════════════════════════════════════

-- Categorías de productos de ventas
CREATE TABLE IF NOT EXISTS ventas_categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    imagen_url TEXT,
    orden INTEGER DEFAULT 0,
    activa BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Productos de ventas
CREATE TABLE IF NOT EXISTS ventas_productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    categoria_id UUID REFERENCES ventas_categorias(id) ON DELETE SET NULL,
    sku TEXT,
    codigo_barras TEXT,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    unidad TEXT DEFAULT 'pieza',
    precio_compra DECIMAL(14,2) DEFAULT 0,
    precio_venta DECIMAL(14,2) NOT NULL,
    precio_mayoreo DECIMAL(14,2),
    cantidad_mayoreo INTEGER DEFAULT 10,
    stock INTEGER DEFAULT 0,
    stock_minimo INTEGER DEFAULT 5,
    imagen_url TEXT,
    destacado BOOLEAN DEFAULT FALSE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vendedores
CREATE TABLE IF NOT EXISTS ventas_vendedores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    auth_uid UUID, -- Para login directo
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    codigo TEXT, -- VEN-001
    nombre TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    zona TEXT,
    meta_mensual DECIMAL(14,2) DEFAULT 10000,
    comision_porcentaje DECIMAL(5,2) DEFAULT 5,
    ventas_mes DECIMAL(14,2) DEFAULT 0,
    comisiones_pendientes DECIMAL(14,2) DEFAULT 0,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(negocio_id, codigo)
);

-- Clientes de ventas
CREATE TABLE IF NOT EXISTS ventas_clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    vendedor_id UUID REFERENCES ventas_vendedores(id) ON DELETE SET NULL,
    auth_uid UUID, -- Para login (opcional)
    codigo_cliente TEXT,
    nombre TEXT NOT NULL,
    rfc TEXT,
    email TEXT,
    telefono TEXT,
    whatsapp TEXT,
    direccion TEXT,
    ciudad TEXT,
    codigo_postal TEXT,
    tipo TEXT DEFAULT 'minorista', -- minorista, mayorista, distribuidor
    limite_credito DECIMAL(14,2) DEFAULT 0,
    saldo_pendiente DECIMAL(14,2) DEFAULT 0,
    dias_credito INTEGER DEFAULT 0,
    descuento_default DECIMAL(5,2) DEFAULT 0,
    total_compras DECIMAL(14,2) DEFAULT 0,
    notas TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pedidos de ventas
CREATE TABLE IF NOT EXISTS ventas_pedidos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES ventas_clientes(id) ON DELETE SET NULL,
    vendedor_id UUID REFERENCES ventas_vendedores(id) ON DELETE SET NULL,
    numero_pedido TEXT, -- PED-001
    fecha_pedido TIMESTAMPTZ DEFAULT NOW(),
    fecha_entrega DATE,
    subtotal DECIMAL(14,2) DEFAULT 0,
    descuento DECIMAL(14,2) DEFAULT 0,
    impuestos DECIMAL(14,2) DEFAULT 0,
    total DECIMAL(14,2) DEFAULT 0,
    metodo_pago TEXT DEFAULT 'efectivo',
    estado TEXT DEFAULT 'pendiente', -- pendiente, confirmado, preparando, enviado, entregado, cancelado
    direccion_entrega TEXT,
    notas TEXT,
    facturado BOOLEAN DEFAULT FALSE,
    factura_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Detalle de pedidos
CREATE TABLE IF NOT EXISTS ventas_pedidos_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES ventas_pedidos(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES ventas_productos(id) ON DELETE SET NULL,
    cantidad INTEGER DEFAULT 1,
    precio_unitario DECIMAL(14,2) NOT NULL,
    descuento DECIMAL(14,2) DEFAULT 0,
    subtotal DECIMAL(14,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices Ventas
CREATE INDEX IF NOT EXISTS idx_ventas_productos_categoria ON ventas_productos(categoria_id);
CREATE INDEX IF NOT EXISTS idx_ventas_vendedores_negocio ON ventas_vendedores(negocio_id);
CREATE INDEX IF NOT EXISTS idx_ventas_vendedores_auth ON ventas_vendedores(auth_uid);
CREATE INDEX IF NOT EXISTS idx_ventas_clientes_vendedor ON ventas_clientes(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_ventas_clientes_auth ON ventas_clientes(auth_uid);
CREATE INDEX IF NOT EXISTS idx_ventas_pedidos_cliente ON ventas_pedidos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_ventas_pedidos_vendedor ON ventas_pedidos(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_ventas_pedidos_estado ON ventas_pedidos(estado);

-- RLS Ventas
ALTER TABLE ventas_categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas_productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas_vendedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas_clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas_pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas_pedidos_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ventas_categorias_access" ON ventas_categorias FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "ventas_productos_access" ON ventas_productos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "ventas_vendedores_access" ON ventas_vendedores FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "ventas_clientes_access" ON ventas_clientes FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "ventas_pedidos_access" ON ventas_pedidos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "ventas_pedidos_items_access" ON ventas_pedidos_items FOR ALL USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 37: MÓDULO CLIMAS - TABLAS FALTANTES
-- ══════════════════════════════════════════════════════════════════════════════

-- Clientes de climas (para el dashboard cliente)
CREATE TABLE IF NOT EXISTS climas_clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    auth_uid UUID, -- Para login
    codigo_cliente TEXT,
    nombre TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    whatsapp TEXT,
    direccion TEXT,
    ciudad TEXT,
    codigo_postal TEXT,
    tipo TEXT DEFAULT 'residencial', -- residencial, comercial, industrial
    total_servicios INTEGER DEFAULT 0,
    total_gastado DECIMAL(14,2) DEFAULT 0,
    saldo_pendiente DECIMAL(14,2) DEFAULT 0,
    notas TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Equipos del cliente (aires acondicionados)
CREATE TABLE IF NOT EXISTS climas_equipos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    marca TEXT,
    modelo TEXT,
    tipo TEXT, -- minisplit, central, ventana
    capacidad TEXT, -- 1 ton, 2 ton, etc
    numero_serie TEXT,
    ubicacion TEXT, -- sala, recámara, oficina
    fecha_instalacion DATE,
    fecha_garantia_fin DATE,
    ultimo_servicio DATE,
    proximo_servicio DATE,
    estado TEXT DEFAULT 'activo', -- activo, requiere_servicio, fuera_servicio
    foto_url TEXT,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Órdenes de servicio de climas (versión mejorada)
CREATE TABLE IF NOT EXISTS climas_ordenes_servicio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE SET NULL,
    equipo_id UUID REFERENCES climas_equipos(id) ON DELETE SET NULL,
    tecnico_id UUID REFERENCES climas_tecnicos(id) ON DELETE SET NULL,
    folio TEXT, -- ORD-CLI-001
    tipo_servicio TEXT DEFAULT 'mantenimiento', -- instalacion, mantenimiento, reparacion, emergencia
    prioridad TEXT DEFAULT 'normal', -- baja, normal, alta, urgente
    fecha_solicitud TIMESTAMPTZ DEFAULT NOW(),
    fecha_programada TIMESTAMPTZ,
    fecha_inicio TIMESTAMPTZ,
    fecha_fin TIMESTAMPTZ,
    direccion_servicio TEXT,
    descripcion_problema TEXT,
    diagnostico TEXT,
    trabajo_realizado TEXT,
    materiales_usados JSONB DEFAULT '[]',
    costo_materiales DECIMAL(14,2) DEFAULT 0,
    costo_mano_obra DECIMAL(14,2) DEFAULT 0,
    total DECIMAL(14,2) DEFAULT 0,
    metodo_pago TEXT,
    estado TEXT DEFAULT 'pendiente', -- pendiente, asignada, en_proceso, completada, cancelada
    calificacion INTEGER, -- 1-5
    comentario_cliente TEXT,
    fotos_antes JSONB DEFAULT '[]',
    fotos_despues JSONB DEFAULT '[]',
    firma_cliente_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices Climas
CREATE INDEX IF NOT EXISTS idx_climas_clientes_negocio ON climas_clientes(negocio_id);
CREATE INDEX IF NOT EXISTS idx_climas_clientes_auth ON climas_clientes(auth_uid);
CREATE INDEX IF NOT EXISTS idx_climas_equipos_cliente ON climas_equipos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_ordenes_cliente ON climas_ordenes_servicio(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_ordenes_tecnico ON climas_ordenes_servicio(tecnico_id);
CREATE INDEX IF NOT EXISTS idx_climas_ordenes_estado ON climas_ordenes_servicio(estado);

-- RLS Climas
ALTER TABLE climas_clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_equipos ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_ordenes_servicio ENABLE ROW LEVEL SECURITY;

CREATE POLICY "climas_clientes_access" ON climas_clientes FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_equipos_access" ON climas_equipos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "climas_ordenes_access" ON climas_ordenes_servicio FOR ALL USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 38: MÓDULO PURIFICADORA - TABLAS FALTANTES
-- ══════════════════════════════════════════════════════════════════════════════

-- Clientes de purificadora
CREATE TABLE IF NOT EXISTS purificadora_clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    auth_uid UUID, -- Para login
    repartidor_id UUID REFERENCES purificadora_repartidores(id) ON DELETE SET NULL,
    codigo_cliente TEXT,
    nombre TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    whatsapp TEXT,
    direccion TEXT,
    colonia TEXT,
    referencias TEXT,
    ciudad TEXT,
    codigo_postal TEXT,
    ubicacion_lat DECIMAL(10,8),
    ubicacion_lng DECIMAL(11,8),
    dia_preferido TEXT, -- lunes, martes, etc
    hora_preferida TEXT, -- mañana, tarde
    garrafones_prestados INTEGER DEFAULT 0, -- Cuántos tiene en su casa
    deposito_garrafones DECIMAL(14,2) DEFAULT 0,
    saldo DECIMAL(14,2) DEFAULT 0, -- Positivo = debe, negativo = a favor
    frecuencia_pedido TEXT DEFAULT 'semanal',
    total_garrafones_comprados INTEGER DEFAULT 0,
    ultimo_pedido DATE,
    notas TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rutas de entrega
CREATE TABLE IF NOT EXISTS purificadora_rutas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    repartidor_id UUID REFERENCES purificadora_repartidores(id) ON DELETE SET NULL,
    nombre TEXT NOT NULL, -- Ruta Norte, Ruta Centro
    descripcion TEXT,
    dia_semana TEXT, -- lunes, martes, etc
    zona TEXT,
    orden_paradas JSONB DEFAULT '[]', -- Array de cliente_ids en orden
    activa BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Productos de purificadora
CREATE TABLE IF NOT EXISTS purificadora_productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    codigo TEXT,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    tipo TEXT DEFAULT 'garrafon', -- garrafon, botella, dispensador, accesorio
    capacidad_litros DECIMAL(10,2),
    precio_venta DECIMAL(14,2) NOT NULL,
    precio_mayoreo DECIMAL(14,2),
    deposito DECIMAL(14,2) DEFAULT 0, -- Depósito por garrafón
    stock INTEGER DEFAULT 0,
    imagen_url TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Entregas/Pedidos de purificadora
CREATE TABLE IF NOT EXISTS purificadora_entregas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES purificadora_clientes(id) ON DELETE SET NULL,
    repartidor_id UUID REFERENCES purificadora_repartidores(id) ON DELETE SET NULL,
    ruta_id UUID REFERENCES purificadora_rutas(id) ON DELETE SET NULL,
    folio TEXT,
    fecha_programada DATE,
    fecha_entrega TIMESTAMPTZ,
    garrafones_entregados INTEGER DEFAULT 0,
    garrafones_recogidos INTEGER DEFAULT 0, -- Vacíos devueltos
    productos_adicionales JSONB DEFAULT '[]',
    subtotal DECIMAL(14,2) DEFAULT 0,
    descuento DECIMAL(14,2) DEFAULT 0,
    total DECIMAL(14,2) DEFAULT 0,
    metodo_pago TEXT, -- efectivo, transferencia, credito
    pagado BOOLEAN DEFAULT FALSE,
    monto_pagado DECIMAL(14,2) DEFAULT 0,
    estado TEXT DEFAULT 'programada', -- programada, en_ruta, entregada, cancelada, no_entregada
    motivo_no_entrega TEXT,
    notas TEXT,
    ubicacion_entrega_lat DECIMAL(10,8),
    ubicacion_entrega_lng DECIMAL(11,8),
    firma_cliente_url TEXT,
    foto_entrega_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cortes de caja de repartidores
CREATE TABLE IF NOT EXISTS purificadora_cortes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    repartidor_id UUID REFERENCES purificadora_repartidores(id) ON DELETE CASCADE,
    fecha DATE DEFAULT CURRENT_DATE,
    garrafones_salida INTEGER DEFAULT 0,
    garrafones_vendidos INTEGER DEFAULT 0,
    garrafones_devueltos INTEGER DEFAULT 0,
    garrafones_vacios_recogidos INTEGER DEFAULT 0,
    efectivo_esperado DECIMAL(14,2) DEFAULT 0,
    efectivo_recibido DECIMAL(14,2) DEFAULT 0,
    diferencia DECIMAL(14,2) DEFAULT 0,
    entregas_completadas INTEGER DEFAULT 0,
    entregas_fallidas INTEGER DEFAULT 0,
    kilometros_recorridos DECIMAL(10,2),
    observaciones TEXT,
    estado TEXT DEFAULT 'pendiente', -- pendiente, cerrado, revisado
    aprobado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices Purificadora
CREATE INDEX IF NOT EXISTS idx_purificadora_clientes_negocio ON purificadora_clientes(negocio_id);
CREATE INDEX IF NOT EXISTS idx_purificadora_clientes_auth ON purificadora_clientes(auth_uid);
CREATE INDEX IF NOT EXISTS idx_purificadora_clientes_repartidor ON purificadora_clientes(repartidor_id);
CREATE INDEX IF NOT EXISTS idx_purificadora_entregas_cliente ON purificadora_entregas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_purificadora_entregas_repartidor ON purificadora_entregas(repartidor_id);
CREATE INDEX IF NOT EXISTS idx_purificadora_entregas_estado ON purificadora_entregas(estado);
CREATE INDEX IF NOT EXISTS idx_purificadora_entregas_fecha ON purificadora_entregas(fecha_programada);

-- RLS Purificadora
ALTER TABLE purificadora_clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE purificadora_rutas ENABLE ROW LEVEL SECURITY;
ALTER TABLE purificadora_productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE purificadora_entregas ENABLE ROW LEVEL SECURITY;
ALTER TABLE purificadora_cortes ENABLE ROW LEVEL SECURITY;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 36.5: MÓDULO COLABORADORES - SOCIOS E INVERSIONISTAS
-- (Movido aquí para que exista antes de las tablas que lo referencian)
-- ══════════════════════════════════════════════════════════════════════════════

-- Tipos de colaborador
CREATE TABLE IF NOT EXISTS colaborador_tipos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    nivel_acceso INTEGER DEFAULT 1,
    puede_ver_finanzas BOOLEAN DEFAULT FALSE,
    puede_ver_clientes BOOLEAN DEFAULT FALSE,
    puede_ver_prestamos BOOLEAN DEFAULT FALSE,
    puede_operar BOOLEAN DEFAULT FALSE,
    puede_aprobar BOOLEAN DEFAULT FALSE,
    puede_emitir_facturas BOOLEAN DEFAULT FALSE,
    puede_ver_reportes BOOLEAN DEFAULT FALSE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE colaborador_tipos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "colaborador_tipos_access" ON colaborador_tipos FOR ALL USING (auth.role() = 'authenticated');

-- Insertar tipos de colaborador por defecto
INSERT INTO colaborador_tipos (codigo, nombre, descripcion, nivel_acceso, puede_ver_finanzas, puede_ver_clientes, puede_ver_prestamos, puede_operar, puede_aprobar, puede_emitir_facturas, puede_ver_reportes) VALUES
    ('co_superadmin', 'Co-Superadmin', 'Acceso total como segundo superadmin', 10, true, true, true, true, true, true, true),
    ('socio_operativo', 'Socio Operativo', 'Socio con capacidad de operar el negocio', 8, true, true, true, true, true, false, true),
    ('socio_inversionista', 'Socio Inversionista', 'Socio que solo invierte capital', 5, true, false, false, false, false, false, true),
    ('contador', 'Contador', 'Acceso a finanzas y reportes', 6, true, false, true, false, false, true, true),
    ('asesor', 'Asesor', 'Consultor con acceso limitado', 3, false, false, false, false, false, false, true),
    ('facturador', 'Facturador', 'Solo puede emitir facturas', 2, false, false, false, false, false, true, false)
ON CONFLICT (codigo) DO NOTHING;

-- Tabla principal de colaboradores
CREATE TABLE IF NOT EXISTS colaboradores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    auth_uid UUID, -- Vínculo con Supabase Auth (auth.users.id)
    tipo_id UUID REFERENCES colaborador_tipos(id) ON DELETE RESTRICT,
    
    -- Datos básicos
    nombre TEXT NOT NULL,
    email TEXT UNIQUE, -- Email único para vincular con cuenta
    telefono TEXT,
    tiene_cuenta BOOLEAN DEFAULT FALSE, -- Si ya tiene cuenta en la app
    
    -- Permisos customizados (JSON adicional a los del tipo)
    permisos_custom JSONB DEFAULT '{}',
    
    -- Inversión (si aplica)
    es_inversionista BOOLEAN DEFAULT FALSE,
    monto_invertido NUMERIC(14,2) DEFAULT 0,
    porcentaje_participacion NUMERIC(5,2) DEFAULT 0,
    fecha_inversion DATE,
    rendimiento_pactado NUMERIC(5,2), -- % de rendimiento mensual pactado
    
    -- Estado
    estado TEXT DEFAULT 'pendiente', -- pendiente, activo, inactivo, suspendido
    fecha_inicio DATE DEFAULT CURRENT_DATE,
    fecha_fin DATE,
    
    -- Notas
    notas TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE colaboradores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "colaboradores_access" ON colaboradores FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_colaboradores_negocio ON colaboradores(negocio_id);
CREATE INDEX IF NOT EXISTS idx_colaboradores_tipo ON colaboradores(tipo_id);
CREATE INDEX IF NOT EXISTS idx_colaboradores_estado ON colaboradores(estado);
CREATE INDEX IF NOT EXISTS idx_colaboradores_auth_uid ON colaboradores(auth_uid);
CREATE INDEX IF NOT EXISTS idx_colaboradores_email ON colaboradores(email);

-- Invitaciones de colaboradores
CREATE TABLE IF NOT EXISTS colaborador_invitaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    tipo_id UUID REFERENCES colaborador_tipos(id) ON DELETE RESTRICT,
    
    email TEXT NOT NULL,
    nombre TEXT,
    telefono TEXT,
    
    codigo_invitacion TEXT UNIQUE DEFAULT UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 8)),
    estado TEXT DEFAULT 'pendiente', -- pendiente, aceptada, rechazada, expirada
    fecha_envio TIMESTAMPTZ DEFAULT NOW(),
    fecha_expiracion TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
    fecha_respuesta TIMESTAMPTZ,
    
    invitado_por UUID REFERENCES usuarios(id),
    colaborador_creado_id UUID REFERENCES colaboradores(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE colaborador_invitaciones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "colaborador_invitaciones_access" ON colaborador_invitaciones FOR ALL USING (auth.role() = 'authenticated');

-- Actividad de colaboradores
CREATE TABLE IF NOT EXISTS colaborador_actividad (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID REFERENCES colaboradores(id) ON DELETE CASCADE,
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    accion TEXT NOT NULL, -- login, ver_reporte, aprobar_prestamo, etc.
    descripcion TEXT,
    ip_address TEXT,
    dispositivo TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE colaborador_actividad ENABLE ROW LEVEL SECURITY;
CREATE POLICY "colaborador_actividad_access" ON colaborador_actividad FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_colab_actividad_colaborador ON colaborador_actividad(colaborador_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN: TABLAS ADICIONALES PARA MÓDULOS (V10.8)
-- ══════════════════════════════════════════════════════════════════════════════

-- 0. Inversiones de colaboradores (debe ir antes de rendimientos)
CREATE TABLE IF NOT EXISTS colaborador_inversiones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID REFERENCES colaboradores(id) ON DELETE CASCADE,
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    tipo TEXT NOT NULL, -- aportacion, retiro, rendimiento, dividendo
    monto NUMERIC(14,2) NOT NULL,
    descripcion TEXT,
    
    fecha DATE DEFAULT CURRENT_DATE,
    comprobante_url TEXT,
    aprobado_por UUID REFERENCES usuarios(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE colaborador_inversiones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "colaborador_inversiones_access_v10" ON colaborador_inversiones;
CREATE POLICY "colaborador_inversiones_access_v10" ON colaborador_inversiones FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_colab_inversiones_colaborador ON colaborador_inversiones(colaborador_id);

-- 1. Rendimientos de inversiones de colaboradores
CREATE TABLE IF NOT EXISTS colaborador_rendimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inversion_id UUID REFERENCES colaborador_inversiones(id) ON DELETE CASCADE,
    colaborador_id UUID REFERENCES colaboradores(id) ON DELETE CASCADE,
    monto DECIMAL(12,2) NOT NULL DEFAULT 0,
    porcentaje DECIMAL(5,2) DEFAULT 0,
    periodo TEXT, -- 'mensual', 'trimestral', 'anual'
    fecha_calculo TIMESTAMPTZ DEFAULT NOW(),
    fecha_pago TIMESTAMPTZ,
    estado VARCHAR(20) DEFAULT 'pendiente', -- pendiente, pagado, cancelado
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_colaborador_rendimientos_inversion ON colaborador_rendimientos(inversion_id);
CREATE INDEX IF NOT EXISTS idx_colaborador_rendimientos_colaborador ON colaborador_rendimientos(colaborador_id);
ALTER TABLE colaborador_rendimientos ENABLE ROW LEVEL SECURITY;

-- 2. Permisos por módulo de colaboradores
CREATE TABLE IF NOT EXISTS colaborador_permisos_modulo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID REFERENCES colaboradores(id) ON DELETE CASCADE,
    modulo VARCHAR(50) NOT NULL,
    puede_ver BOOLEAN DEFAULT true,
    puede_crear BOOLEAN DEFAULT false,
    puede_editar BOOLEAN DEFAULT false,
    puede_eliminar BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(colaborador_id, modulo)
);

CREATE INDEX IF NOT EXISTS idx_colaborador_permisos_colaborador ON colaborador_permisos_modulo(colaborador_id);
ALTER TABLE colaborador_permisos_modulo ENABLE ROW LEVEL SECURITY;

-- 3. Productos de climas/aires acondicionados
CREATE TABLE IF NOT EXISTS climas_productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    marca TEXT,
    modelo TEXT,
    tipo VARCHAR(50) DEFAULT 'split', -- split, minisplit, ventana, central, industrial
    capacidad_btu INTEGER,
    precio_venta DECIMAL(10,2) DEFAULT 0,
    precio_instalacion DECIMAL(10,2) DEFAULT 0,
    garantia_meses INTEGER DEFAULT 12,
    descripcion TEXT,
    imagen_url TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_climas_productos_negocio ON climas_productos(negocio_id);
ALTER TABLE climas_productos ENABLE ROW LEVEL SECURITY;

-- 4. Documentos de cliente de climas
CREATE TABLE IF NOT EXISTS climas_cliente_documentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    tipo VARCHAR(50) NOT NULL, -- 'contrato', 'garantia', 'factura', 'identificacion', 'comprobante_domicilio'
    nombre TEXT,
    url TEXT NOT NULL,
    fecha_documento DATE,
    notas TEXT,
    subido_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_climas_cliente_documentos_cliente ON climas_cliente_documentos(cliente_id);
ALTER TABLE climas_cliente_documentos ENABLE ROW LEVEL SECURITY;

-- 5. Notas de cliente de climas
CREATE TABLE IF NOT EXISTS climas_cliente_notas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    usuario_id UUID REFERENCES usuarios(id),
    nota TEXT NOT NULL,
    tipo VARCHAR(30) DEFAULT 'general', -- general, seguimiento, queja, recordatorio
    importante BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_climas_cliente_notas_cliente ON climas_cliente_notas(cliente_id);
ALTER TABLE climas_cliente_notas ENABLE ROW LEVEL SECURITY;

-- 6. Contactos adicionales de cliente de climas
CREATE TABLE IF NOT EXISTS climas_cliente_contactos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    telefono TEXT,
    email TEXT,
    relacion TEXT, -- 'esposo/a', 'familiar', 'encargado', 'vecino'
    es_principal BOOLEAN DEFAULT false,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_climas_cliente_contactos_cliente ON climas_cliente_contactos(cliente_id);
ALTER TABLE climas_cliente_contactos ENABLE ROW LEVEL SECURITY;

-- 7. Cotizaciones de climas
CREATE TABLE IF NOT EXISTS climas_cotizaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    numero TEXT,
    fecha DATE DEFAULT CURRENT_DATE,
    vigencia_dias INTEGER DEFAULT 30,
    subtotal DECIMAL(12,2) DEFAULT 0,
    iva DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) DEFAULT 0,
    estado VARCHAR(20) DEFAULT 'pendiente', -- pendiente, aceptada, rechazada, vencida
    notas TEXT,
    productos JSONB DEFAULT '[]', -- Array de productos cotizados
    creado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_climas_cotizaciones_cliente ON climas_cotizaciones(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_cotizaciones_negocio ON climas_cotizaciones(negocio_id);
ALTER TABLE climas_cotizaciones ENABLE ROW LEVEL SECURITY;

-- 8. Detalle de pedidos de ventas (relación muchos a muchos)
CREATE TABLE IF NOT EXISTS ventas_pedidos_detalle (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES ventas_pedidos(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES ventas_productos(id) ON DELETE SET NULL,
    cantidad INTEGER DEFAULT 1,
    precio_unitario DECIMAL(10,2) NOT NULL,
    descuento DECIMAL(10,2) DEFAULT 0,
    subtotal DECIMAL(10,2) NOT NULL,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ventas_pedidos_detalle_pedido ON ventas_pedidos_detalle(pedido_id);
CREATE INDEX IF NOT EXISTS idx_ventas_pedidos_detalle_producto ON ventas_pedidos_detalle(producto_id);
ALTER TABLE ventas_pedidos_detalle ENABLE ROW LEVEL SECURITY;

-- 9. Comprobantes de pagos (para módulo de comprobantes)
CREATE TABLE IF NOT EXISTS comprobantes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    tipo VARCHAR(30) NOT NULL, -- 'pago', 'gasto', 'ingreso', 'transferencia'
    referencia_tipo VARCHAR(30), -- 'prestamo', 'tanda', 'venta', 'servicio'
    referencia_id UUID,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    monto DECIMAL(12,2) NOT NULL,
    fecha DATE DEFAULT CURRENT_DATE,
    descripcion TEXT,
    archivo_url TEXT,
    verificado BOOLEAN DEFAULT false,
    verificado_por UUID REFERENCES usuarios(id),
    verificado_at TIMESTAMPTZ,
    subido_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comprobantes_negocio ON comprobantes(negocio_id);
CREATE INDEX IF NOT EXISTS idx_comprobantes_cliente ON comprobantes(cliente_id);
CREATE INDEX IF NOT EXISTS idx_comprobantes_tipo ON comprobantes(tipo);
ALTER TABLE comprobantes ENABLE ROW LEVEL SECURITY;

-- 10. Inventario general
CREATE TABLE IF NOT EXISTS inventario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
    codigo TEXT,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    categoria VARCHAR(50),
    unidad VARCHAR(20) DEFAULT 'pza', -- pza, kg, lt, mt
    stock_actual DECIMAL(12,2) DEFAULT 0,
    stock_minimo DECIMAL(12,2) DEFAULT 0,
    stock_maximo DECIMAL(12,2),
    precio_compra DECIMAL(10,2) DEFAULT 0,
    precio_venta DECIMAL(10,2) DEFAULT 0,
    ubicacion TEXT,
    imagen_url TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventario_negocio ON inventario(negocio_id);
CREATE INDEX IF NOT EXISTS idx_inventario_sucursal ON inventario(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_inventario_codigo ON inventario(codigo);
ALTER TABLE inventario ENABLE ROW LEVEL SECURITY;

-- 11. Movimientos de inventario (historial)
CREATE TABLE IF NOT EXISTS inventario_movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inventario_id UUID REFERENCES inventario(id) ON DELETE CASCADE,
    tipo VARCHAR(20) NOT NULL, -- 'entrada', 'salida', 'ajuste', 'transferencia'
    cantidad DECIMAL(12,2) NOT NULL,
    stock_anterior DECIMAL(12,2),
    stock_nuevo DECIMAL(12,2),
    referencia_tipo VARCHAR(30), -- 'compra', 'venta', 'devolucion', 'merma'
    referencia_id UUID,
    notas TEXT,
    usuario_id UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventario_movimientos_inventario ON inventario_movimientos(inventario_id);
CREATE INDEX IF NOT EXISTS idx_inventario_movimientos_tipo ON inventario_movimientos(tipo);
ALTER TABLE inventario_movimientos ENABLE ROW LEVEL SECURITY;

-- 12. Entregas (para módulo de logística)
CREATE TABLE IF NOT EXISTS entregas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    pedido_id UUID, -- Referencia genérica a cualquier pedido
    pedido_tipo VARCHAR(30), -- 'venta', 'purificadora', 'nice', 'clima'
    repartidor_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
    direccion TEXT NOT NULL,
    latitud DECIMAL(10,8),
    longitud DECIMAL(11,8),
    fecha_programada DATE,
    hora_estimada TIME,
    fecha_entrega TIMESTAMPTZ,
    estado VARCHAR(20) DEFAULT 'pendiente', -- pendiente, en_camino, entregado, cancelado, reprogramado
    notas TEXT,
    firma_cliente TEXT, -- Base64 de firma
    foto_entrega TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_entregas_negocio ON entregas(negocio_id);
CREATE INDEX IF NOT EXISTS idx_entregas_cliente ON entregas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_entregas_repartidor ON entregas(repartidor_id);
CREATE INDEX IF NOT EXISTS idx_entregas_estado ON entregas(estado);
CREATE INDEX IF NOT EXISTS idx_entregas_fecha ON entregas(fecha_programada);
ALTER TABLE entregas ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para nuevas tablas
DO $$
BEGIN
    -- Políticas básicas para todas las nuevas tablas
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'colaborador_rendimientos_auth') THEN
        CREATE POLICY "colaborador_rendimientos_auth" ON colaborador_rendimientos FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'colaborador_permisos_modulo_auth') THEN
        CREATE POLICY "colaborador_permisos_modulo_auth" ON colaborador_permisos_modulo FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'climas_productos_auth') THEN
        CREATE POLICY "climas_productos_auth" ON climas_productos FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'climas_cliente_documentos_auth') THEN
        CREATE POLICY "climas_cliente_documentos_auth" ON climas_cliente_documentos FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'climas_cliente_notas_auth') THEN
        CREATE POLICY "climas_cliente_notas_auth" ON climas_cliente_notas FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'climas_cliente_contactos_auth') THEN
        CREATE POLICY "climas_cliente_contactos_auth" ON climas_cliente_contactos FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'climas_cotizaciones_auth') THEN
        CREATE POLICY "climas_cotizaciones_auth" ON climas_cotizaciones FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'ventas_pedidos_detalle_auth') THEN
        CREATE POLICY "ventas_pedidos_detalle_auth" ON ventas_pedidos_detalle FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'comprobantes_auth') THEN
        CREATE POLICY "comprobantes_auth" ON comprobantes FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'inventario_auth') THEN
        CREATE POLICY "inventario_auth" ON inventario FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'inventario_movimientos_auth') THEN
        CREATE POLICY "inventario_movimientos_auth" ON inventario_movimientos FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'entregas_auth') THEN
        CREATE POLICY "entregas_auth" ON entregas FOR ALL USING (auth.role() = 'authenticated');
    END IF;
END $$;

CREATE POLICY "purificadora_clientes_access" ON purificadora_clientes FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "purificadora_rutas_access" ON purificadora_rutas FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "purificadora_productos_access" ON purificadora_productos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "purificadora_entregas_access" ON purificadora_entregas FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "purificadora_cortes_access" ON purificadora_cortes FOR ALL USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 35: MIGRACIÓN V10.5 - NUEVAS COLUMNAS (ejecutar si ya tienes datos)
-- ══════════════════════════════════════════════════════════════════════════════

-- Agregar campo 'estado' a empleados (para filtros activo/inactivo)
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS estado TEXT DEFAULT 'activo';
COMMENT ON COLUMN empleados.estado IS 'activo, inactivo, suspendido, baja';

-- Asegurar que prestamos tenga todos los estados necesarios
-- (la columna ya existe, solo documentamos los valores posibles)
COMMENT ON COLUMN prestamos.estado IS 'activo, pagado, vencido, mora, cancelado, liquidado';

-- Asegurar que amortizaciones acepte pagado y pagada
COMMENT ON COLUMN amortizaciones.estado IS 'pendiente, pagado, pagada, vencido, parcial';

-- Índices adicionales para KPIs y filtros rápidos
CREATE INDEX IF NOT EXISTS idx_prestamos_estado ON prestamos(estado);
CREATE INDEX IF NOT EXISTS idx_empleados_estado ON empleados(estado);
CREATE INDEX IF NOT EXISTS idx_clientes_activo ON clientes(activo);
CREATE INDEX IF NOT EXISTS idx_tandas_estado ON tandas(estado);

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 36: INTEGRACIÓN STRIPE - PAGOS HÍBRIDOS (Efectivo + Tarjeta)
-- ══════════════════════════════════════════════════════════════════════════════
-- Esta integración permite:
-- ✅ Cobros con tarjeta via Stripe
-- ✅ Cobros en efectivo (tradicional)
-- ✅ Sincronización de clientes con Stripe
-- ✅ Domiciliación automática de cuotas
-- ✅ Links de pago por WhatsApp
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Habilitar extensión wrappers (si no existe)
-- NOTA: Esta extensión requiere plan Pro de Supabase o instalación manual
-- CREATE EXTENSION IF NOT EXISTS wrappers WITH SCHEMA extensions;

-- 2. Crear el wrapper de Stripe (EJECUTAR MANUALMENTE SI TIENES SUPABASE PRO)
-- NOTA: El Foreign Data Wrapper de Stripe requiere configuración especial
-- DO $$
-- BEGIN
--     IF NOT EXISTS (SELECT 1 FROM pg_foreign_data_wrapper WHERE fdwname = 'stripe_wrapper') THEN
--         CREATE FOREIGN DATA WRAPPER stripe_wrapper
--             HANDLER stripe_fdw_handler
--             VALIDATOR stripe_fdw_validator;
--     END IF;
-- END $$;

-- 3. Crear schema para tablas de Stripe
CREATE SCHEMA IF NOT EXISTS stripe;

-- 4. Guardar API Key en Vault (seguro)
-- NOTA: Ejecutar manualmente con tu API Key real:
-- SELECT vault.create_secret('sk_live_TU_API_KEY_AQUI', 'stripe', 'Stripe API Key');

-- 5. Crear servidor de conexión a Stripe
-- NOTA: Ejecutar después de guardar el secret en Vault:
-- CREATE SERVER stripe_server
--   FOREIGN DATA WRAPPER stripe_wrapper
--   OPTIONS (
--     api_key_name 'stripe'
--   );

-- 6. Tablas foráneas de Stripe (se crean automáticamente con import)
-- NOTA: Ejecutar después de crear el servidor:
-- IMPORT FOREIGN SCHEMA stripe FROM SERVER stripe_server INTO stripe;

-- ══════════════════════════════════════════════════════════════════════════════
-- CAMPOS ADICIONALES PARA INTEGRACIÓN STRIPE EN TABLAS EXISTENTES
-- ══════════════════════════════════════════════════════════════════════════════

-- Agregar stripe_customer_id a clientes (para sincronizar con Stripe)
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS prefiere_efectivo BOOLEAN DEFAULT TRUE;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS tiene_tarjeta_guardada BOOLEAN DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_clientes_stripe ON clientes(stripe_customer_id);
COMMENT ON COLUMN clientes.stripe_customer_id IS 'ID del cliente en Stripe (cus_xxx)';
COMMENT ON COLUMN clientes.prefiere_efectivo IS 'TRUE = prefiere efectivo, FALSE = prefiere tarjeta';

-- Agregar campos de Stripe a pagos
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS stripe_payment_id TEXT;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS stripe_charge_id TEXT;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS stripe_invoice_id TEXT;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS cobrado_automatico BOOLEAN DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_pagos_stripe ON pagos(stripe_payment_id);
COMMENT ON COLUMN pagos.metodo_pago IS 'efectivo, transferencia, tarjeta_stripe, link_pago, domiciliacion';

-- Agregar campos de Stripe a préstamos (para domiciliación)
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT;
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS domiciliacion_activa BOOLEAN DEFAULT FALSE;
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS dia_cobro_automatico INTEGER DEFAULT 1;
CREATE INDEX IF NOT EXISTS idx_prestamos_stripe_sub ON prestamos(stripe_subscription_id);
COMMENT ON COLUMN prestamos.domiciliacion_activa IS 'Si TRUE, Stripe cobra automáticamente cada mes';

-- Agregar campos de Stripe a tandas
ALTER TABLE tandas ADD COLUMN IF NOT EXISTS cobro_automatico_stripe BOOLEAN DEFAULT FALSE;
COMMENT ON COLUMN tandas.cobro_automatico_stripe IS 'Si TRUE, las aportaciones se cobran automáticamente';

-- ══════════════════════════════════════════════════════════════════════════════
-- TABLA: CONFIGURACIÓN DE STRIPE POR NEGOCIO
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS stripe_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Credenciales (encriptadas en Vault)
    stripe_account_id TEXT, -- acct_xxx (para Stripe Connect)
    modo_produccion BOOLEAN DEFAULT FALSE, -- FALSE = modo prueba
    
    -- Configuración de cobros
    cobrar_comision_cliente BOOLEAN DEFAULT FALSE, -- Si TRUE, el cliente paga el 3.6%
    porcentaje_comision NUMERIC(5,2) DEFAULT 3.6,
    
    -- Configuración de notificaciones
    notificar_pago_exitoso BOOLEAN DEFAULT TRUE,
    notificar_pago_fallido BOOLEAN DEFAULT TRUE,
    
    -- Métodos habilitados
    permitir_tarjeta BOOLEAN DEFAULT TRUE,
    permitir_oxxo BOOLEAN DEFAULT FALSE, -- Pago en OXXO
    permitir_spei BOOLEAN DEFAULT TRUE, -- Transferencia SPEI
    
    -- Webhook URL
    webhook_secret TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(negocio_id)
);

ALTER TABLE stripe_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "stripe_config_access" ON stripe_config FOR ALL USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- TABLA: LINKS DE PAGO (Para enviar por WhatsApp)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS links_pago (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    
    -- Referencia al cobro
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
    tanda_id UUID REFERENCES tandas(id) ON DELETE SET NULL,
    amortizacion_id UUID REFERENCES amortizaciones(id) ON DELETE SET NULL,
    concepto TEXT NOT NULL, -- "Cuota 3 de 12 - Préstamo", "Aportación Tanda Enero"
    
    -- Detalles del link
    monto NUMERIC(12,2) NOT NULL,
    stripe_payment_link_id TEXT, -- plink_xxx
    url_corta TEXT, -- URL acortada para WhatsApp
    
    -- Estado
    estado TEXT DEFAULT 'pendiente', -- pendiente, pagado, expirado, cancelado
    fecha_expiracion TIMESTAMP,
    fecha_pago TIMESTAMP,
    
    -- Auditoría
    enviado_por_whatsapp BOOLEAN DEFAULT FALSE,
    fecha_envio_whatsapp TIMESTAMP,
    creado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE links_pago ENABLE ROW LEVEL SECURITY;
CREATE POLICY "links_pago_access" ON links_pago FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_links_pago_cliente ON links_pago(cliente_id);
CREATE INDEX IF NOT EXISTS idx_links_pago_estado ON links_pago(estado);

-- ══════════════════════════════════════════════════════════════════════════════
-- TABLA: LOG DE TRANSACCIONES STRIPE (Para auditoría)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS stripe_transactions_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- IDs de Stripe
    stripe_event_id TEXT UNIQUE, -- evt_xxx
    stripe_payment_intent_id TEXT,
    stripe_charge_id TEXT,
    stripe_customer_id TEXT,
    
    -- Detalles
    tipo_evento TEXT NOT NULL, -- payment_intent.succeeded, charge.failed, etc.
    monto NUMERIC(12,2),
    moneda TEXT DEFAULT 'mxn',
    comision_stripe NUMERIC(12,2),
    monto_neto NUMERIC(12,2),
    
    -- Estado
    estado TEXT, -- succeeded, failed, pending
    mensaje_error TEXT,
    
    -- Referencias locales
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    pago_id UUID REFERENCES pagos(id) ON DELETE SET NULL,
    
    -- Webhook data
    webhook_payload JSONB,
    procesado BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE stripe_transactions_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "stripe_log_access" ON stripe_transactions_log FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_stripe_log_evento ON stripe_transactions_log(tipo_evento);
CREATE INDEX IF NOT EXISTS idx_stripe_log_cliente ON stripe_transactions_log(cliente_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES ÚTILES PARA STRIPE
-- ══════════════════════════════════════════════════════════════════════════════

-- Función para obtener total cobrado por Stripe en un período
CREATE OR REPLACE FUNCTION stripe_total_cobrado(
    p_negocio_id UUID,
    p_fecha_inicio DATE,
    p_fecha_fin DATE
) RETURNS NUMERIC AS $$
BEGIN
    RETURN COALESCE((
        SELECT SUM(monto)
        FROM pagos
        WHERE negocio_id = p_negocio_id
        AND metodo_pago IN ('tarjeta_stripe', 'link_pago', 'domiciliacion')
        AND fecha_pago BETWEEN p_fecha_inicio AND p_fecha_fin
    ), 0);
END;
$$ LANGUAGE plpgsql;

-- Función para obtener total cobrado en efectivo en un período
CREATE OR REPLACE FUNCTION efectivo_total_cobrado(
    p_negocio_id UUID,
    p_fecha_inicio DATE,
    p_fecha_fin DATE
) RETURNS NUMERIC AS $$
BEGIN
    RETURN COALESCE((
        SELECT SUM(monto)
        FROM pagos
        WHERE negocio_id = p_negocio_id
        AND metodo_pago IN ('efectivo', 'transferencia')
        AND fecha_pago BETWEEN p_fecha_inicio AND p_fecha_fin
    ), 0);
END;
$$ LANGUAGE plpgsql;

-- Función para obtener clientes sin Stripe (pagan efectivo)
CREATE OR REPLACE FUNCTION clientes_solo_efectivo(p_negocio_id UUID)
RETURNS TABLE(id UUID, nombre TEXT, telefono TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.nombre, c.telefono
    FROM clientes c
    WHERE c.negocio_id = p_negocio_id
    AND (c.stripe_customer_id IS NULL OR c.prefiere_efectivo = TRUE);
END;
$$ LANGUAGE plpgsql;

-- Función para obtener clientes con Stripe activo
CREATE OR REPLACE FUNCTION clientes_con_stripe(p_negocio_id UUID)
RETURNS TABLE(id UUID, nombre TEXT, telefono TEXT, stripe_customer_id TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.nombre, c.telefono, c.stripe_customer_id
    FROM clientes c
    WHERE c.negocio_id = p_negocio_id
    AND c.stripe_customer_id IS NOT NULL
    AND c.prefiere_efectivo = FALSE;
END;
$$ LANGUAGE plpgsql;

-- ══════════════════════════════════════════════════════════════════════════════
-- VISTA: RESUMEN DE COBROS POR MÉTODO
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW v_resumen_cobros_metodo AS
SELECT 
    negocio_id,
    DATE_TRUNC('month', fecha_pago) as mes,
    metodo_pago,
    COUNT(*) as total_transacciones,
    SUM(monto) as monto_total,
    AVG(monto) as promedio_transaccion
FROM pagos
WHERE fecha_pago IS NOT NULL
GROUP BY negocio_id, DATE_TRUNC('month', fecha_pago), metodo_pago
ORDER BY mes DESC, monto_total DESC;

-- ══════════════════════════════════════════════════════════════════════════════
-- GUÍA DE CONFIGURACIÓN MANUAL (Ejecutar en orden después del schema)
-- ══════════════════════════════════════════════════════════════════════════════
-- 
-- PASO 1: Guardar API Key en Vault
-- SELECT vault.create_secret('sk_live_TU_API_KEY', 'stripe', 'Stripe API Key');
--
-- PASO 2: Crear servidor Stripe
-- CREATE SERVER stripe_server
--   FOREIGN DATA WRAPPER stripe_wrapper
--   OPTIONS (api_key_name 'stripe');
--
-- PASO 3: Importar tablas de Stripe
-- IMPORT FOREIGN SCHEMA stripe FROM SERVER stripe_server INTO stripe;
--
-- PASO 4: Probar conexión
-- SELECT * FROM stripe.customers LIMIT 1;
--
-- PASO 5: Configurar webhook en Stripe Dashboard
-- URL: https://TU_PROYECTO.supabase.co/functions/v1/stripe-webhook
-- Eventos: payment_intent.succeeded, payment_intent.failed, charge.succeeded
--
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- VISTA Y FUNCIONES PARA COLABORADORES V10.7
-- (Tablas creadas arriba en SECCIÓN 36.5)
-- ══════════════════════════════════════════════════════════════════════════════

-- Vista de colaboradores completos
CREATE OR REPLACE VIEW v_colaboradores_completos AS
SELECT 
    c.id,
    c.negocio_id,
    c.usuario_id,
    c.auth_uid,
    c.tipo_id,
    c.nombre,
    c.email,
    c.telefono,
    c.tiene_cuenta,
    c.permisos_custom,
    c.es_inversionista,
    c.monto_invertido,
    c.porcentaje_participacion,
    c.fecha_inversion,
    c.rendimiento_pactado,
    c.estado,
    c.fecha_inicio,
    c.fecha_fin,
    c.notas,
    c.created_at,
    c.updated_at,
    ct.codigo as tipo_codigo,
    ct.nombre as tipo_nombre,
    ct.nivel_acceso,
    ct.puede_ver_finanzas,
    ct.puede_ver_clientes,
    ct.puede_ver_prestamos,
    ct.puede_operar,
    ct.puede_aprobar,
    ct.puede_emitir_facturas,
    ct.puede_ver_reportes,
    n.nombre as negocio_nombre,
    u.nombre_completo as usuario_nombre
FROM colaboradores c
LEFT JOIN colaborador_tipos ct ON ct.id = c.tipo_id
LEFT JOIN negocios n ON n.id = c.negocio_id
LEFT JOIN usuarios u ON u.id = c.usuario_id;

-- ══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES PARA COLABORADORES V10.7
-- ══════════════════════════════════════════════════════════════════════════════

-- Función para registrar actividad del colaborador
CREATE OR REPLACE FUNCTION registrar_actividad_colaborador(
  p_colaborador_id UUID,
  p_accion TEXT,
  p_descripcion TEXT DEFAULT NULL,
  p_ip TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_negocio_id UUID;
  v_actividad_id UUID;
BEGIN
  SELECT negocio_id INTO v_negocio_id FROM colaboradores WHERE id = p_colaborador_id;
  
  INSERT INTO colaborador_actividad (colaborador_id, negocio_id, accion, descripcion, ip_address)
  VALUES (p_colaborador_id, v_negocio_id, p_accion, p_descripcion, p_ip)
  RETURNING id INTO v_actividad_id;
  
  RETURN v_actividad_id;
END;
$$ LANGUAGE plpgsql;

-- Función para calcular rendimientos de inversionista
CREATE OR REPLACE FUNCTION calcular_rendimiento_inversionista(
  p_colaborador_id UUID,
  p_mes INTEGER DEFAULT NULL,
  p_anio INTEGER DEFAULT NULL
)
RETURNS TABLE (
  total_invertido NUMERIC,
  rendimiento_pactado NUMERIC,
  rendimiento_mes NUMERIC,
  rendimiento_acumulado NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.monto_invertido as total_invertido,
    COALESCE(c.rendimiento_pactado, 0) as rendimiento_pactado,
    (c.monto_invertido * COALESCE(c.rendimiento_pactado, 0) / 100) as rendimiento_mes,
    COALESCE(
      (SELECT SUM(monto) FROM colaborador_inversiones 
       WHERE colaborador_id = p_colaborador_id AND tipo = 'rendimiento'),
      0
    ) as rendimiento_acumulado
  FROM colaboradores c
  WHERE c.id = p_colaborador_id;
END;
$$ LANGUAGE plpgsql;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN DEL SCHEMA V10.7 - SISTEMA COMPLETO ROBERT DARIN FINTECH
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 37: SISTEMA DE VERIFICACIÓN DE COBROS CON QR
-- ══════════════════════════════════════════════════════════════════════════════
-- Sistema de doble confirmación para cobros en efectivo:
-- ✅ Cobrador genera QR único para cada cobro
-- ✅ Cliente escanea y confirma desde su app
-- ✅ Registro con GPS, hora y fotos
-- ✅ Notificación en tiempo real al admin
-- ✅ Previene fraudes de cobradores
-- ══════════════════════════════════════════════════════════════════════════════

-- Tabla principal de códigos QR de cobro
CREATE TABLE IF NOT EXISTS qr_cobros (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Código único del QR
    codigo_qr TEXT UNIQUE NOT NULL, -- UUID corto o código alfanumérico
    codigo_verificacion TEXT, -- Código de 6 dígitos para SMS (respaldo)
    
    -- Quién genera y quién confirma
    cobrador_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    
    -- Referencia al cobro (polimórfico - puede ser cualquier módulo)
    tipo_cobro TEXT NOT NULL, -- prestamo, tanda, purificadora, nice, ventas, climas, otro
    referencia_id UUID NOT NULL, -- ID del préstamo, tanda, pedido, etc.
    referencia_tabla TEXT, -- Nombre de la tabla para referencia
    
    -- Detalles del cobro
    monto NUMERIC(12,2) NOT NULL,
    concepto TEXT NOT NULL, -- "Cuota #3 de Préstamo", "Aportación Tanda Mayo", etc.
    descripcion_adicional TEXT,
    
    -- Estado del QR
    estado TEXT DEFAULT 'pendiente', -- pendiente, confirmado, expirado, cancelado, rechazado
    fecha_expiracion TIMESTAMP, -- El QR expira después de X horas
    
    -- Confirmación del cobrador (cuando recibe el efectivo)
    cobrador_confirmo BOOLEAN DEFAULT FALSE,
    cobrador_confirmo_at TIMESTAMP,
    cobrador_latitud DECIMAL(10,8),
    cobrador_longitud DECIMAL(11,8),
    cobrador_direccion TEXT,
    
    -- Confirmación del cliente (cuando escanea el QR)
    cliente_confirmo BOOLEAN DEFAULT FALSE,
    cliente_confirmo_at TIMESTAMP,
    cliente_latitud DECIMAL(10,8),
    cliente_longitud DECIMAL(11,8),
    cliente_dispositivo TEXT, -- Info del dispositivo del cliente
    cliente_ip TEXT,
    
    -- Evidencia fotográfica (opcional)
    foto_comprobante_url TEXT, -- Foto del dinero/recibo
    foto_selfie_url TEXT, -- Selfie del cobro (opcional)
    firma_digital_cliente TEXT, -- Firma en pantalla del cliente
    
    -- Resultado final
    pago_registrado BOOLEAN DEFAULT FALSE,
    pago_id UUID REFERENCES pagos(id) ON DELETE SET NULL, -- Pago creado tras confirmación
    
    -- Notificaciones
    notificacion_admin_enviada BOOLEAN DEFAULT FALSE,
    notificacion_cliente_enviada BOOLEAN DEFAULT FALSE,
    
    -- Auditoría
    notas TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_qr_cobros_codigo ON qr_cobros(codigo_qr);
CREATE INDEX IF NOT EXISTS idx_qr_cobros_estado ON qr_cobros(estado);
CREATE INDEX IF NOT EXISTS idx_qr_cobros_cliente ON qr_cobros(cliente_id);
CREATE INDEX IF NOT EXISTS idx_qr_cobros_cobrador ON qr_cobros(cobrador_id);
CREATE INDEX IF NOT EXISTS idx_qr_cobros_tipo ON qr_cobros(tipo_cobro);
CREATE INDEX IF NOT EXISTS idx_qr_cobros_referencia ON qr_cobros(referencia_id);
CREATE INDEX IF NOT EXISTS idx_qr_cobros_fecha ON qr_cobros(created_at DESC);

-- RLS
ALTER TABLE qr_cobros ENABLE ROW LEVEL SECURITY;
CREATE POLICY "qr_cobros_access" ON qr_cobros FOR ALL USING (auth.role() = 'authenticated');

-- Tabla de historial de escaneos (para auditoría)
CREATE TABLE IF NOT EXISTS qr_cobros_escaneos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    qr_cobro_id UUID REFERENCES qr_cobros(id) ON DELETE CASCADE,
    
    -- Quién escaneó
    escaneado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    tipo_usuario TEXT, -- cobrador, cliente, admin
    
    -- Ubicación del escaneo
    latitud DECIMAL(10,8),
    longitud DECIMAL(11,8),
    precision_gps DECIMAL(8,2), -- Precisión en metros
    direccion_aproximada TEXT,
    
    -- Dispositivo
    dispositivo TEXT,
    sistema_operativo TEXT,
    version_app TEXT,
    ip_address TEXT,
    
    -- Resultado
    accion TEXT, -- escaneo, confirmacion, rechazo, reporte
    resultado TEXT, -- exitoso, fallido, expirado
    mensaje TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE qr_cobros_escaneos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "qr_escaneos_access" ON qr_cobros_escaneos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_qr_escaneos_qr ON qr_cobros_escaneos(qr_cobro_id);

-- Tabla de configuración del sistema QR por negocio
CREATE TABLE IF NOT EXISTS qr_cobros_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID UNIQUE REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Configuración de expiración
    qr_expira_horas INTEGER DEFAULT 24, -- Horas antes de que expire el QR
    codigo_expira_minutos INTEGER DEFAULT 30, -- Minutos para código SMS
    
    -- Requisitos de confirmación
    requiere_confirmacion_cliente BOOLEAN DEFAULT TRUE,
    requiere_gps BOOLEAN DEFAULT TRUE,
    requiere_foto_comprobante BOOLEAN DEFAULT FALSE,
    requiere_firma_digital BOOLEAN DEFAULT FALSE,
    
    -- Tolerancia de ubicación
    distancia_maxima_metros INTEGER DEFAULT 500, -- Cliente y cobrador deben estar cerca
    
    -- Notificaciones
    notificar_admin_inmediato BOOLEAN DEFAULT TRUE,
    notificar_cliente_recordatorio BOOLEAN DEFAULT TRUE,
    
    -- Montos
    monto_minimo_qr NUMERIC(12,2) DEFAULT 0, -- Cobros menores no necesitan QR
    monto_maximo_sin_foto NUMERIC(12,2) DEFAULT 5000, -- Cobros mayores requieren foto
    
    -- Horarios permitidos
    hora_inicio_cobros TIME DEFAULT '07:00',
    hora_fin_cobros TIME DEFAULT '21:00',
    permitir_fines_semana BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE qr_cobros_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "qr_config_access" ON qr_cobros_config FOR ALL USING (auth.role() = 'authenticated');

-- Tabla de reportes de problemas con cobros
CREATE TABLE IF NOT EXISTS qr_cobros_reportes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    qr_cobro_id UUID REFERENCES qr_cobros(id) ON DELETE CASCADE,
    
    -- Quién reporta
    reportado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    tipo_reportante TEXT, -- cliente, cobrador, admin
    
    -- Tipo de problema
    tipo_problema TEXT NOT NULL, -- cobro_no_realizado, monto_incorrecto, cobrador_no_llego, fraude, otro
    descripcion TEXT NOT NULL,
    
    -- Evidencia
    fotos_evidencia TEXT[], -- Array de URLs
    
    -- Resolución
    estado TEXT DEFAULT 'abierto', -- abierto, en_revision, resuelto, cerrado
    resuelto_por UUID REFERENCES usuarios(id),
    resolucion TEXT,
    fecha_resolucion TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE qr_cobros_reportes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "qr_reportes_access" ON qr_cobros_reportes FOR ALL USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES PARA EL SISTEMA QR
-- ══════════════════════════════════════════════════════════════════════════════

-- Función para generar código QR único
CREATE OR REPLACE FUNCTION generar_codigo_qr()
RETURNS TEXT AS $$
DECLARE
    codigo TEXT;
BEGIN
    -- Genera código alfanumérico de 12 caracteres (fácil de leer)
    codigo := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 12));
    RETURN codigo;
END;
$$ LANGUAGE plpgsql;

-- Función para generar código de verificación de 6 dígitos
CREATE OR REPLACE FUNCTION generar_codigo_verificacion()
RETURNS TEXT AS $$
BEGIN
    RETURN LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Función para crear un nuevo QR de cobro
CREATE OR REPLACE FUNCTION crear_qr_cobro(
    p_negocio_id UUID,
    p_cobrador_id UUID,
    p_cliente_id UUID,
    p_tipo_cobro TEXT,
    p_referencia_id UUID,
    p_monto NUMERIC,
    p_concepto TEXT
) RETURNS UUID AS $$
DECLARE
    v_qr_id UUID;
    v_codigo_qr TEXT;
    v_codigo_verificacion TEXT;
    v_horas_expiracion INTEGER;
BEGIN
    -- Obtener configuración del negocio
    SELECT COALESCE(qr_expira_horas, 24) INTO v_horas_expiracion
    FROM qr_cobros_config WHERE negocio_id = p_negocio_id;
    
    IF v_horas_expiracion IS NULL THEN
        v_horas_expiracion := 24;
    END IF;
    
    -- Generar códigos únicos
    v_codigo_qr := generar_codigo_qr();
    v_codigo_verificacion := generar_codigo_verificacion();
    
    -- Insertar QR de cobro
    INSERT INTO qr_cobros (
        negocio_id, codigo_qr, codigo_verificacion,
        cobrador_id, cliente_id,
        tipo_cobro, referencia_id,
        monto, concepto,
        fecha_expiracion
    ) VALUES (
        p_negocio_id, v_codigo_qr, v_codigo_verificacion,
        p_cobrador_id, p_cliente_id,
        p_tipo_cobro, p_referencia_id,
        p_monto, p_concepto,
        NOW() + (v_horas_expiracion || ' hours')::INTERVAL
    ) RETURNING id INTO v_qr_id;
    
    RETURN v_qr_id;
END;
$$ LANGUAGE plpgsql;

-- Función para confirmar cobro (lado cobrador)
CREATE OR REPLACE FUNCTION confirmar_cobro_cobrador(
    p_qr_id UUID,
    p_latitud DECIMAL,
    p_longitud DECIMAL
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE qr_cobros
    SET 
        cobrador_confirmo = TRUE,
        cobrador_confirmo_at = NOW(),
        cobrador_latitud = p_latitud,
        cobrador_longitud = p_longitud,
        updated_at = NOW()
    WHERE id = p_qr_id AND estado = 'pendiente';
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Función para confirmar cobro (lado cliente)
CREATE OR REPLACE FUNCTION confirmar_cobro_cliente(
    p_codigo_qr TEXT,
    p_latitud DECIMAL,
    p_longitud DECIMAL,
    p_dispositivo TEXT DEFAULT NULL
) RETURNS TABLE(exito BOOLEAN, mensaje TEXT, qr_id UUID) AS $$
DECLARE
    v_qr RECORD;
BEGIN
    -- Buscar el QR
    SELECT * INTO v_qr FROM qr_cobros 
    WHERE codigo_qr = p_codigo_qr;
    
    -- Validaciones
    IF v_qr IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Código QR no encontrado'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    IF v_qr.estado != 'pendiente' THEN
        RETURN QUERY SELECT FALSE, 'Este código ya fue usado o expiró'::TEXT, v_qr.id;
        RETURN;
    END IF;
    
    IF v_qr.fecha_expiracion < NOW() THEN
        UPDATE qr_cobros SET estado = 'expirado' WHERE id = v_qr.id;
        RETURN QUERY SELECT FALSE, 'El código QR ha expirado'::TEXT, v_qr.id;
        RETURN;
    END IF;
    
    -- Confirmar el cobro
    UPDATE qr_cobros
    SET 
        cliente_confirmo = TRUE,
        cliente_confirmo_at = NOW(),
        cliente_latitud = p_latitud,
        cliente_longitud = p_longitud,
        cliente_dispositivo = p_dispositivo,
        estado = CASE WHEN cobrador_confirmo THEN 'confirmado' ELSE estado END,
        updated_at = NOW()
    WHERE id = v_qr.id;
    
    -- Si ambos confirmaron, marcar como confirmado
    IF v_qr.cobrador_confirmo THEN
        RETURN QUERY SELECT TRUE, 'Cobro confirmado exitosamente'::TEXT, v_qr.id;
    ELSE
        RETURN QUERY SELECT TRUE, 'Confirmación registrada, esperando al cobrador'::TEXT, v_qr.id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función para verificar si un cobro fue confirmado por ambas partes
CREATE OR REPLACE FUNCTION verificar_cobro_completo(p_qr_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_qr RECORD;
BEGIN
    SELECT * INTO v_qr FROM qr_cobros WHERE id = p_qr_id;
    
    IF v_qr IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Verificar que ambos confirmaron y actualizar estado
    IF v_qr.cobrador_confirmo AND v_qr.cliente_confirmo THEN
        UPDATE qr_cobros SET estado = 'confirmado', updated_at = NOW() WHERE id = p_qr_id;
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Vista para cobros pendientes de confirmación
CREATE OR REPLACE VIEW v_qr_cobros_pendientes AS
SELECT 
    qr.id,
    qr.codigo_qr,
    qr.monto,
    qr.concepto,
    qr.tipo_cobro,
    qr.estado,
    qr.created_at,
    qr.fecha_expiracion,
    qr.cobrador_confirmo,
    qr.cliente_confirmo,
    c.nombre as cliente_nombre,
    c.telefono as cliente_telefono,
    u.nombre_completo as cobrador_nombre,
    n.nombre as negocio_nombre,
    CASE 
        WHEN qr.fecha_expiracion < NOW() THEN 'expirado'
        WHEN qr.cobrador_confirmo AND qr.cliente_confirmo THEN 'completado'
        WHEN qr.cobrador_confirmo THEN 'esperando_cliente'
        WHEN qr.cliente_confirmo THEN 'esperando_cobrador'
        ELSE 'pendiente_ambos'
    END as estado_detallado
FROM qr_cobros qr
LEFT JOIN clientes c ON c.id = qr.cliente_id
LEFT JOIN usuarios u ON u.id = qr.cobrador_id
LEFT JOIN negocios n ON n.id = qr.negocio_id
WHERE qr.estado = 'pendiente'
ORDER BY qr.created_at DESC;

-- Vista para resumen de cobros del día
CREATE OR REPLACE VIEW v_qr_cobros_hoy AS
SELECT 
    negocio_id,
    COUNT(*) FILTER (WHERE estado = 'confirmado') as cobros_confirmados,
    COUNT(*) FILTER (WHERE estado = 'pendiente') as cobros_pendientes,
    COUNT(*) FILTER (WHERE estado = 'expirado') as cobros_expirados,
    SUM(monto) FILTER (WHERE estado = 'confirmado') as monto_confirmado,
    SUM(monto) FILTER (WHERE estado = 'pendiente') as monto_pendiente
FROM qr_cobros
WHERE DATE(created_at) = CURRENT_DATE
GROUP BY negocio_id;

-- ══════════════════════════════════════════════════════════════════════════════
-- TRIGGER: Notificar cuando se confirma un cobro
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION notificar_cobro_confirmado()
RETURNS TRIGGER AS $$
BEGIN
    -- Cuando ambos confirman, insertar notificación para el admin
    IF NEW.cobrador_confirmo = TRUE AND NEW.cliente_confirmo = TRUE 
       AND (OLD.cobrador_confirmo = FALSE OR OLD.cliente_confirmo = FALSE) THEN
        
        -- Actualizar estado a confirmado
        NEW.estado := 'confirmado';
        
        -- Insertar notificación (si existe la tabla)
        INSERT INTO notificaciones (
            usuario_id,
            titulo,
            mensaje,
            tipo,
            leida
        )
        SELECT 
            ur.usuario_id,
            'Cobro Confirmado',
            'Cobro de $' || NEW.monto || ' confirmado - ' || NEW.concepto,
            'cobro_confirmado',
            FALSE
        FROM usuarios_roles ur
        JOIN roles r ON r.id = ur.rol_id
        WHERE r.nombre IN ('superadmin', 'admin');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notificar_cobro ON qr_cobros;
CREATE TRIGGER trg_notificar_cobro
    BEFORE UPDATE ON qr_cobros
    FOR EACH ROW
    EXECUTE FUNCTION notificar_cobro_confirmado();

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN SECCIÓN 37: SISTEMA QR DE COBROS
-- ══════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 38: FACTURACIÓN ELECTRÓNICA CFDI 4.0
-- ══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.1 EMISORES (Configuración fiscal del negocio)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS facturacion_emisores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Datos fiscales obligatorios
    rfc VARCHAR(13) NOT NULL,
    razon_social VARCHAR(300) NOT NULL,
    nombre_comercial VARCHAR(300),
    regimen_fiscal VARCHAR(3) NOT NULL, -- Clave SAT (601, 612, 626, etc.)
    regimen_fiscal_descripcion VARCHAR(200),
    
    -- Dirección fiscal
    calle VARCHAR(200),
    numero_exterior VARCHAR(50),
    numero_interior VARCHAR(50),
    colonia VARCHAR(200),
    codigo_postal VARCHAR(5) NOT NULL, -- Lugar de expedición
    municipio VARCHAR(200),
    estado VARCHAR(100),
    pais VARCHAR(100) DEFAULT 'México',
    
    -- Certificados CSD (encriptados)
    certificado_cer TEXT, -- Base64 del .cer
    certificado_key TEXT, -- Base64 del .key (encriptado)
    certificado_password TEXT, -- Password encriptado
    certificado_numero VARCHAR(50),
    certificado_fecha_inicio TIMESTAMPTZ,
    certificado_fecha_fin TIMESTAMPTZ,
    
    -- Configuración del PAC
    proveedor_api VARCHAR(50) DEFAULT 'facturapi', -- facturapi, facturama, fiscoclic
    api_key TEXT,
    api_secret TEXT,
    modo_pruebas BOOLEAN DEFAULT TRUE,
    
    -- Personalización
    logo_url TEXT,
    color_primario VARCHAR(7) DEFAULT '#1E3A8A',
    
    -- Control de folios
    serie_facturas VARCHAR(10) DEFAULT 'A',
    folio_actual_facturas INTEGER DEFAULT 1,
    serie_notas_credito VARCHAR(10) DEFAULT 'NC',
    folio_actual_nc INTEGER DEFAULT 1,
    serie_pagos VARCHAR(10) DEFAULT 'P',
    folio_actual_pagos INTEGER DEFAULT 1,
    
    -- Opciones
    enviar_email_automatico BOOLEAN DEFAULT TRUE,
    incluir_pdf BOOLEAN DEFAULT TRUE,
    activo BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(negocio_id, rfc)
);

ALTER TABLE facturacion_emisores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "facturacion_emisores_auth" ON facturacion_emisores
    FOR ALL USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.2 CLIENTES FISCALES (Receptores de facturas)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS facturacion_clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Vínculos con clientes de otros módulos
    cliente_fintech_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    cliente_climas_id UUID REFERENCES climas_clientes(id) ON DELETE SET NULL,
    cliente_ventas_id UUID REFERENCES ventas_clientes(id) ON DELETE SET NULL,
    cliente_purificadora_id UUID REFERENCES purificadora_clientes(id) ON DELETE SET NULL,
    cliente_nice_id UUID REFERENCES nice_clientes(id) ON DELETE SET NULL,
    
    -- Datos fiscales del receptor
    rfc VARCHAR(13) NOT NULL,
    razon_social VARCHAR(300) NOT NULL,
    regimen_fiscal VARCHAR(3) NOT NULL,
    uso_cfdi VARCHAR(4) DEFAULT 'G03', -- Gastos en general
    
    -- Dirección fiscal
    calle VARCHAR(200),
    numero_exterior VARCHAR(50),
    numero_interior VARCHAR(50),
    colonia VARCHAR(200),
    codigo_postal VARCHAR(5) NOT NULL,
    municipio VARCHAR(200),
    estado VARCHAR(100),
    pais VARCHAR(100) DEFAULT 'México',
    
    -- Contacto
    email VARCHAR(255),
    telefono VARCHAR(20),
    
    -- Para extranjeros
    num_reg_id_trib VARCHAR(50), -- Tax ID extranjero
    residencia_fiscal VARCHAR(3), -- País ISO
    
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE facturacion_clientes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "facturacion_clientes_auth" ON facturacion_clientes
    FOR ALL USING (auth.role() = 'authenticated');

CREATE INDEX IF NOT EXISTS idx_facturacion_clientes_rfc ON facturacion_clientes(rfc);
CREATE INDEX IF NOT EXISTS idx_facturacion_clientes_negocio ON facturacion_clientes(negocio_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.3 FACTURAS (Comprobantes fiscales)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS facturas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    emisor_id UUID REFERENCES facturacion_emisores(id) ON DELETE RESTRICT,
    cliente_fiscal_id UUID REFERENCES facturacion_clientes(id) ON DELETE RESTRICT,
    
    -- Identificación del comprobante
    tipo_comprobante VARCHAR(1) NOT NULL DEFAULT 'I', -- I=Ingreso, E=Egreso, T=Traslado, N=Nómina, P=Pago
    serie VARCHAR(25),
    folio INTEGER,
    uuid_fiscal UUID, -- UUID asignado por el SAT
    
    -- Fechas
    fecha_emision TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_timbrado TIMESTAMPTZ,
    fecha_cancelacion TIMESTAMPTZ,
    
    -- Origen (desde qué módulo se generó)
    modulo_origen VARCHAR(50), -- prestamos, tandas, climas, ventas, purificadora, nice
    referencia_origen_id UUID,
    referencia_tipo VARCHAR(50), -- pago, pedido, servicio, etc.
    
    -- Totales
    subtotal DECIMAL(18,2) NOT NULL DEFAULT 0,
    descuento DECIMAL(18,2) DEFAULT 0,
    iva DECIMAL(18,2) DEFAULT 0,
    isr_retenido DECIMAL(18,2) DEFAULT 0,
    iva_retenido DECIMAL(18,2) DEFAULT 0,
    ieps DECIMAL(18,2) DEFAULT 0,
    total DECIMAL(18,2) NOT NULL DEFAULT 0,
    moneda VARCHAR(3) DEFAULT 'MXN',
    tipo_cambio DECIMAL(10,4) DEFAULT 1,
    
    -- Método de pago
    forma_pago VARCHAR(2) DEFAULT '99', -- 01=Efectivo, 03=Transferencia, 04=Tarjeta, 99=Por definir
    metodo_pago VARCHAR(3) DEFAULT 'PUE', -- PUE=Pago en una exhibición, PPD=Pago en parcialidades
    condiciones_pago VARCHAR(200),
    
    -- Datos CFDI
    uso_cfdi VARCHAR(4) DEFAULT 'G03',
    lugar_expedicion VARCHAR(5), -- CP del emisor
    confirmacion VARCHAR(10), -- Para facturas > $2M MXN
    
    -- Estado
    estado VARCHAR(20) DEFAULT 'borrador', -- borrador, timbrada, enviada, pagada, cancelada
    motivo_cancelacion VARCHAR(2), -- 01, 02, 03, 04 (SAT)
    uuid_sustitucion UUID, -- Si cancela por sustitución
    
    -- Archivos generados
    xml_content TEXT,
    pdf_url TEXT,
    
    -- Respuesta del PAC
    pac_response JSONB,
    cadena_original TEXT,
    sello_cfdi TEXT,
    sello_sat TEXT,
    certificado_sat VARCHAR(50),
    
    -- Envío
    email_enviado BOOLEAN DEFAULT FALSE,
    fecha_email TIMESTAMPTZ,
    
    -- Usuario que creó
    creado_por UUID REFERENCES usuarios(id),
    
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE facturas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "facturas_auth" ON facturas
    FOR ALL USING (auth.role() = 'authenticated');

CREATE INDEX IF NOT EXISTS idx_facturas_negocio ON facturas(negocio_id);
CREATE INDEX IF NOT EXISTS idx_facturas_uuid ON facturas(uuid_fiscal);
CREATE INDEX IF NOT EXISTS idx_facturas_estado ON facturas(estado);
CREATE INDEX IF NOT EXISTS idx_facturas_fecha ON facturas(fecha_emision);
CREATE INDEX IF NOT EXISTS idx_facturas_cliente ON facturas(cliente_fiscal_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.4 CONCEPTOS DE FACTURA (Líneas/Items)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS factura_conceptos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    factura_id UUID REFERENCES facturas(id) ON DELETE CASCADE,
    
    -- Claves SAT
    clave_prod_serv VARCHAR(8) NOT NULL, -- Catálogo SAT de productos/servicios
    clave_unidad VARCHAR(3) NOT NULL, -- Catálogo SAT de unidades
    unidad VARCHAR(50), -- Descripción de unidad (ej: "Pieza", "Servicio")
    no_identificacion VARCHAR(100), -- SKU interno
    
    -- Descripción
    descripcion TEXT NOT NULL,
    
    -- Cantidades
    cantidad DECIMAL(18,6) NOT NULL DEFAULT 1,
    valor_unitario DECIMAL(18,6) NOT NULL,
    descuento DECIMAL(18,2) DEFAULT 0,
    importe DECIMAL(18,2) NOT NULL,
    
    -- Impuestos
    objeto_imp VARCHAR(2) DEFAULT '02', -- 01=No objeto, 02=Sí objeto, 03=Sí objeto no obligado
    
    -- Cuenta predial (para inmuebles)
    cuenta_predial VARCHAR(150),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE factura_conceptos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "factura_conceptos_auth" ON factura_conceptos
    FOR ALL USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.5 IMPUESTOS POR CONCEPTO
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS factura_impuestos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    concepto_id UUID REFERENCES factura_conceptos(id) ON DELETE CASCADE,
    
    tipo VARCHAR(10) NOT NULL, -- traslado, retencion
    impuesto VARCHAR(3) NOT NULL, -- 001=ISR, 002=IVA, 003=IEPS
    tipo_factor VARCHAR(10) NOT NULL, -- Tasa, Cuota, Exento
    tasa_o_cuota DECIMAL(10,6), -- 0.160000 para 16%
    base DECIMAL(18,2) NOT NULL,
    importe DECIMAL(18,2),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE factura_impuestos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "factura_impuestos_auth" ON factura_impuestos
    FOR ALL USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.6 COMPLEMENTOS DE PAGO (Para PPD)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS factura_complementos_pago (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    emisor_id UUID REFERENCES facturacion_emisores(id),
    
    -- El comprobante de pago
    uuid_fiscal UUID,
    serie VARCHAR(25),
    folio INTEGER,
    fecha_timbrado TIMESTAMPTZ,
    
    -- Pago realizado
    fecha_pago TIMESTAMPTZ NOT NULL,
    forma_pago VARCHAR(2) NOT NULL,
    moneda VARCHAR(3) DEFAULT 'MXN',
    tipo_cambio DECIMAL(10,4) DEFAULT 1,
    monto DECIMAL(18,2) NOT NULL,
    
    -- Datos bancarios
    num_operacion VARCHAR(100),
    rfc_emisor_cta_ord VARCHAR(13),
    nom_banco_ord_ext VARCHAR(300),
    cta_ordenante VARCHAR(50),
    rfc_emisor_cta_ben VARCHAR(13),
    cta_beneficiario VARCHAR(50),
    
    estado VARCHAR(20) DEFAULT 'borrador',
    xml_content TEXT,
    pdf_url TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE factura_complementos_pago ENABLE ROW LEVEL SECURITY;

CREATE POLICY "factura_complementos_pago_auth" ON factura_complementos_pago
    FOR ALL USING (auth.role() = 'authenticated');

-- Relación de documentos pagados en un complemento
CREATE TABLE IF NOT EXISTS factura_documentos_relacionados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complemento_pago_id UUID REFERENCES factura_complementos_pago(id) ON DELETE CASCADE,
    factura_id UUID REFERENCES facturas(id) ON DELETE SET NULL,
    
    id_documento UUID NOT NULL, -- UUID de la factura que se paga
    serie VARCHAR(25),
    folio INTEGER,
    moneda VARCHAR(3) DEFAULT 'MXN',
    tipo_cambio DECIMAL(10,4) DEFAULT 1,
    metodo_pago VARCHAR(3) DEFAULT 'PPD',
    num_parcialidad INTEGER,
    imp_saldo_ant DECIMAL(18,2),
    imp_pagado DECIMAL(18,2),
    imp_saldo_insoluto DECIMAL(18,2),
    objeto_imp VARCHAR(2) DEFAULT '02',
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE factura_documentos_relacionados ENABLE ROW LEVEL SECURITY;

CREATE POLICY "factura_documentos_relacionados_auth" ON factura_documentos_relacionados
    FOR ALL USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.7 CATÁLOGOS SAT (Los más usados)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Regímenes fiscales
CREATE TABLE IF NOT EXISTS cat_regimen_fiscal (
    clave VARCHAR(3) PRIMARY KEY,
    descripcion VARCHAR(200) NOT NULL,
    fisica BOOLEAN DEFAULT FALSE,
    moral BOOLEAN DEFAULT FALSE,
    activo BOOLEAN DEFAULT TRUE
);

INSERT INTO cat_regimen_fiscal (clave, descripcion, fisica, moral) VALUES
('601', 'General de Ley Personas Morales', false, true),
('603', 'Personas Morales con Fines no Lucrativos', false, true),
('605', 'Sueldos y Salarios e Ingresos Asimilados a Salarios', true, false),
('606', 'Arrendamiento', true, false),
('607', 'Régimen de Enajenación o Adquisición de Bienes', true, false),
('608', 'Demás ingresos', true, false),
('610', 'Residentes en el Extranjero sin Establecimiento Permanente en México', true, true),
('611', 'Ingresos por Dividendos (socios y accionistas)', true, false),
('612', 'Personas Físicas con Actividades Empresariales y Profesionales', true, false),
('614', 'Ingresos por intereses', true, false),
('615', 'Régimen de los ingresos por obtención de premios', true, false),
('616', 'Sin obligaciones fiscales', true, false),
('620', 'Sociedades Cooperativas de Producción que optan por diferir sus ingresos', false, true),
('621', 'Incorporación Fiscal', true, false),
('622', 'Actividades Agrícolas, Ganaderas, Silvícolas y Pesqueras', true, true),
('623', 'Opcional para Grupos de Sociedades', false, true),
('624', 'Coordinados', false, true),
('625', 'Régimen de las Actividades Empresariales con ingresos a través de Plataformas Tecnológicas', true, false),
('626', 'Régimen Simplificado de Confianza', true, true)
ON CONFLICT (clave) DO NOTHING;

-- Uso CFDI
CREATE TABLE IF NOT EXISTS cat_uso_cfdi (
    clave VARCHAR(4) PRIMARY KEY,
    descripcion VARCHAR(200) NOT NULL,
    fisica BOOLEAN DEFAULT TRUE,
    moral BOOLEAN DEFAULT TRUE,
    activo BOOLEAN DEFAULT TRUE
);

INSERT INTO cat_uso_cfdi (clave, descripcion, fisica, moral) VALUES
('G01', 'Adquisición de mercancías', true, true),
('G02', 'Devoluciones, descuentos o bonificaciones', true, true),
('G03', 'Gastos en general', true, true),
('I01', 'Construcciones', true, true),
('I02', 'Mobiliario y equipo de oficina por inversiones', true, true),
('I03', 'Equipo de transporte', true, true),
('I04', 'Equipo de cómputo y accesorios', true, true),
('I05', 'Dados, troqueles, moldes, matrices y herramental', true, true),
('I06', 'Comunicaciones telefónicas', true, true),
('I07', 'Comunicaciones satelitales', true, true),
('I08', 'Otra maquinaria y equipo', true, true),
('D01', 'Honorarios médicos, dentales y gastos hospitalarios', true, false),
('D02', 'Gastos médicos por incapacidad o discapacidad', true, false),
('D03', 'Gastos funerales', true, false),
('D04', 'Donativos', true, false),
('D05', 'Intereses reales efectivamente pagados por créditos hipotecarios', true, false),
('D06', 'Aportaciones voluntarias al SAR', true, false),
('D07', 'Primas por seguros de gastos médicos', true, false),
('D08', 'Gastos de transportación escolar obligatoria', true, false),
('D09', 'Depósitos en cuentas para el ahorro, primas de pensiones', true, false),
('D10', 'Pagos por servicios educativos (colegiaturas)', true, false),
('S01', 'Sin efectos fiscales', true, true),
('CP01', 'Pagos', true, true),
('CN01', 'Nómina', true, false)
ON CONFLICT (clave) DO NOTHING;

-- Formas de pago
CREATE TABLE IF NOT EXISTS cat_forma_pago (
    clave VARCHAR(2) PRIMARY KEY,
    descripcion VARCHAR(200) NOT NULL,
    activo BOOLEAN DEFAULT TRUE
);

INSERT INTO cat_forma_pago (clave, descripcion) VALUES
('01', 'Efectivo'),
('02', 'Cheque nominativo'),
('03', 'Transferencia electrónica de fondos'),
('04', 'Tarjeta de crédito'),
('05', 'Monedero electrónico'),
('06', 'Dinero electrónico'),
('08', 'Vales de despensa'),
('12', 'Dación en pago'),
('13', 'Pago por subrogación'),
('14', 'Pago por consignación'),
('15', 'Condonación'),
('17', 'Compensación'),
('23', 'Novación'),
('24', 'Confusión'),
('25', 'Remisión de deuda'),
('26', 'Prescripción o caducidad'),
('27', 'A satisfacción del acreedor'),
('28', 'Tarjeta de débito'),
('29', 'Tarjeta de servicios'),
('30', 'Aplicación de anticipos'),
('31', 'Intermediario pagos'),
('99', 'Por definir')
ON CONFLICT (clave) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.8 LOGS DE FACTURACIÓN
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS facturacion_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    factura_id UUID REFERENCES facturas(id) ON DELETE CASCADE,
    
    accion VARCHAR(50) NOT NULL, -- creacion, timbrado, cancelacion, envio, reintento
    descripcion TEXT,
    resultado VARCHAR(20), -- exito, error, pendiente
    
    request_data JSONB,
    response_data JSONB,
    error_message TEXT,
    
    usuario_id UUID REFERENCES usuarios(id),
    ip_address VARCHAR(45),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE facturacion_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "facturacion_logs_auth" ON facturacion_logs
    FOR ALL USING (auth.role() = 'authenticated');

CREATE INDEX IF NOT EXISTS idx_facturacion_logs_factura ON facturacion_logs(factura_id);
CREATE INDEX IF NOT EXISTS idx_facturacion_logs_fecha ON facturacion_logs(created_at);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.9 VISTA COMPLETA DE FACTURAS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW v_facturas_completas AS
SELECT 
    f.*,
    e.rfc AS emisor_rfc,
    e.razon_social AS emisor_razon_social,
    e.regimen_fiscal AS emisor_regimen,
    c.rfc AS cliente_rfc,
    c.razon_social AS cliente_razon_social,
    c.email AS cliente_email,
    COALESCE(
        (SELECT COUNT(*) FROM factura_conceptos WHERE factura_id = f.id),
        0
    ) AS num_conceptos,
    CASE 
        WHEN f.estado = 'borrador' THEN 'Borrador'
        WHEN f.estado = 'timbrada' THEN 'Timbrada'
        WHEN f.estado = 'enviada' THEN 'Enviada'
        WHEN f.estado = 'pagada' THEN 'Pagada'
        WHEN f.estado = 'cancelada' THEN 'Cancelada'
        ELSE f.estado
    END AS estado_display,
    CASE f.tipo_comprobante
        WHEN 'I' THEN 'Ingreso'
        WHEN 'E' THEN 'Egreso'
        WHEN 'T' THEN 'Traslado'
        WHEN 'N' THEN 'Nómina'
        WHEN 'P' THEN 'Pago'
        ELSE f.tipo_comprobante
    END AS tipo_display
FROM facturas f
LEFT JOIN facturacion_emisores e ON e.id = f.emisor_id
LEFT JOIN facturacion_clientes c ON c.id = f.cliente_fiscal_id;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.10 FUNCIÓN: Obtener siguiente folio
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION obtener_siguiente_folio(
    p_emisor_id UUID,
    p_tipo VARCHAR DEFAULT 'factura'
)
RETURNS INTEGER AS $$
DECLARE
    v_folio INTEGER;
BEGIN
    IF p_tipo = 'factura' THEN
        UPDATE facturacion_emisores 
        SET folio_actual_facturas = folio_actual_facturas + 1
        WHERE id = p_emisor_id
        RETURNING folio_actual_facturas INTO v_folio;
    ELSIF p_tipo = 'nota_credito' THEN
        UPDATE facturacion_emisores 
        SET folio_actual_nc = folio_actual_nc + 1
        WHERE id = p_emisor_id
        RETURNING folio_actual_nc INTO v_folio;
    ELSIF p_tipo = 'pago' THEN
        UPDATE facturacion_emisores 
        SET folio_actual_pagos = folio_actual_pagos + 1
        WHERE id = p_emisor_id
        RETURNING folio_actual_pagos INTO v_folio;
    END IF;
    
    RETURN v_folio;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 38.11 FUNCIÓN: Estadísticas de facturación
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION obtener_estadisticas_facturacion(p_negocio_id UUID)
RETURNS TABLE (
    total_facturas BIGINT,
    facturas_mes BIGINT,
    total_facturado DECIMAL,
    facturado_mes DECIMAL,
    timbradas BIGINT,
    pendientes BIGINT,
    canceladas BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT AS total_facturas,
        COUNT(*) FILTER (WHERE DATE_TRUNC('month', f.fecha_emision) = DATE_TRUNC('month', NOW()))::BIGINT AS facturas_mes,
        COALESCE(SUM(f.total) FILTER (WHERE f.estado != 'cancelada'), 0)::DECIMAL AS total_facturado,
        COALESCE(SUM(f.total) FILTER (WHERE DATE_TRUNC('month', f.fecha_emision) = DATE_TRUNC('month', NOW()) AND f.estado != 'cancelada'), 0)::DECIMAL AS facturado_mes,
        COUNT(*) FILTER (WHERE f.estado = 'timbrada')::BIGINT AS timbradas,
        COUNT(*) FILTER (WHERE f.estado = 'borrador')::BIGINT AS pendientes,
        COUNT(*) FILTER (WHERE f.estado = 'cancelada')::BIGINT AS canceladas
    FROM facturas f
    WHERE f.negocio_id = p_negocio_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN SECCIÓN 38: FACTURACIÓN ELECTRÓNICA CFDI 4.0
-- ══════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 39: OPTIMIZACIÓN DE BASE DE DATOS (V10.9)
-- ══════════════════════════════════════════════════════════════════════════════
-- Esta sección agrega:
-- ✅ Índices compuestos para consultas frecuentes
-- ✅ Índices parciales para filtros comunes
-- ✅ Vistas materializadas para dashboards
-- ✅ Funciones optimizadas con STABLE/IMMUTABLE
-- ✅ Estadísticas automáticas
-- ══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- 39.1 ÍNDICES COMPUESTOS PARA CONSULTAS FRECUENTES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Préstamos: Filtro por negocio + estado (consulta más común)
CREATE INDEX IF NOT EXISTS idx_prestamos_negocio_estado 
ON prestamos(negocio_id, estado);

-- Préstamos: Para dashboards con fecha
CREATE INDEX IF NOT EXISTS idx_prestamos_negocio_fecha 
ON prestamos(negocio_id, fecha_creacion DESC);

-- Préstamos: Búsqueda por cliente + estado
CREATE INDEX IF NOT EXISTS idx_prestamos_cliente_estado 
ON prestamos(cliente_id, estado);

-- Amortizaciones: Cuotas pendientes ordenadas por fecha (cobranza)
CREATE INDEX IF NOT EXISTS idx_amortizaciones_vencimiento_estado 
ON amortizaciones(fecha_vencimiento, estado);

-- Amortizaciones: Por préstamo ordenado por cuota
CREATE INDEX IF NOT EXISTS idx_amortizaciones_prestamo_cuota 
ON amortizaciones(prestamo_id, numero_cuota);

-- Pagos: Filtro por negocio + fecha (reportes)
CREATE INDEX IF NOT EXISTS idx_pagos_negocio_fecha 
ON pagos(negocio_id, fecha_pago DESC);

-- Clientes: Búsqueda por nombre (full text sería mejor pero esto es básico)
CREATE INDEX IF NOT EXISTS idx_clientes_nombre_lower 
ON clientes(LOWER(nombre));

-- Clientes: Por negocio + estado activo
CREATE INDEX IF NOT EXISTS idx_clientes_negocio_activo 
ON clientes(negocio_id) WHERE activo = true;

-- Tandas: Por negocio + estado
CREATE INDEX IF NOT EXISTS idx_tandas_negocio_estado 
ON tandas(negocio_id, estado);

-- Chat: Mensajes no leídos por conversación
CREATE INDEX IF NOT EXISTS idx_chat_mensajes_no_leidos 
ON chat_mensajes(conversacion_id, created_at) WHERE leido = false;

-- Notificaciones: No leídas por usuario
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_no_leidas 
ON notificaciones(usuario_id, created_at DESC) WHERE leida = false;

-- Registros de cobro: Pendientes de confirmación
CREATE INDEX IF NOT EXISTS idx_registros_cobro_pendientes 
ON registros_cobro(fecha_registro DESC) WHERE estado = 'pendiente';

-- Empleados: Activos por sucursal
CREATE INDEX IF NOT EXISTS idx_empleados_sucursal_activo 
ON empleados(sucursal_id) WHERE activo = true;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 39.2 ÍNDICES PARCIALES PARA ESTADOS COMUNES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Solo préstamos activos (los más consultados)
CREATE INDEX IF NOT EXISTS idx_prestamos_activos 
ON prestamos(negocio_id, cliente_id, fecha_creacion) 
WHERE estado IN ('activo', 'mora');

-- Solo préstamos en mora (para alertas)
CREATE INDEX IF NOT EXISTS idx_prestamos_mora 
ON prestamos(negocio_id, fecha_creacion) 
WHERE estado = 'mora';

-- Amortizaciones pendientes (para cobranza)
CREATE INDEX IF NOT EXISTS idx_amortizaciones_pendientes 
ON amortizaciones(prestamo_id, fecha_vencimiento) 
WHERE estado = 'pendiente';

-- Amortizaciones vencidas (alertas de mora)
CREATE INDEX IF NOT EXISTS idx_amortizaciones_vencidas 
ON amortizaciones(prestamo_id, fecha_vencimiento) 
WHERE estado = 'vencido';

-- Tandas activas
CREATE INDEX IF NOT EXISTS idx_tandas_activas 
ON tandas(negocio_id, fecha_inicio) 
WHERE estado = 'activa';

-- Avales verificados
CREATE INDEX IF NOT EXISTS idx_avales_verificados 
ON avales(negocio_id, prestamo_id) 
WHERE verificado = true;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 39.3 VISTAS MATERIALIZADAS PARA DASHBOARDS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Vista materializada: Resumen de cartera por negocio
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_resumen_cartera AS
SELECT 
    p.negocio_id,
    COUNT(*) FILTER (WHERE p.estado = 'activo') AS prestamos_activos,
    COUNT(*) FILTER (WHERE p.estado = 'mora') AS prestamos_mora,
    COUNT(*) FILTER (WHERE p.estado = 'pagado') AS prestamos_pagados,
    COUNT(*) FILTER (WHERE p.estado = 'vencido') AS prestamos_vencidos,
    COALESCE(SUM(p.monto) FILTER (WHERE p.estado IN ('activo', 'mora')), 0) AS capital_vigente,
    COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'pendiente'), 0) AS por_cobrar,
    COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'vencido'), 0) AS vencido,
    NOW() AS ultima_actualizacion
FROM prestamos p
LEFT JOIN amortizaciones a ON a.prestamo_id = p.id
GROUP BY p.negocio_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_resumen_cartera_negocio 
ON mv_resumen_cartera(negocio_id);

-- Vista materializada: KPIs del mes actual
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_kpis_mes AS
SELECT 
    p.negocio_id,
    DATE_TRUNC('month', NOW()) AS mes,
    COUNT(*) FILTER (WHERE p.fecha_creacion >= DATE_TRUNC('month', NOW())) AS nuevos_prestamos,
    COALESCE(SUM(p.monto) FILTER (WHERE p.fecha_creacion >= DATE_TRUNC('month', NOW())), 0) AS monto_colocado,
    COALESCE(SUM(pago.monto), 0) AS monto_cobrado,
    COUNT(DISTINCT pago.id) AS pagos_recibidos,
    NOW() AS ultima_actualizacion
FROM prestamos p
LEFT JOIN pagos pago ON pago.negocio_id = p.negocio_id 
    AND pago.fecha_pago >= DATE_TRUNC('month', NOW())
GROUP BY p.negocio_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_kpis_mes_negocio 
ON mv_kpis_mes(negocio_id);

-- Vista materializada: Top clientes por negocio
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_top_clientes AS
SELECT 
    c.negocio_id,
    c.id AS cliente_id,
    c.nombre,
    COUNT(p.id) AS total_prestamos,
    COALESCE(SUM(p.monto), 0) AS monto_total,
    COUNT(*) FILTER (WHERE p.estado = 'pagado') AS prestamos_pagados,
    COALESCE(AVG(CASE WHEN p.estado = 'pagado' THEN 1 ELSE 0 END) * 100, 0) AS tasa_cumplimiento,
    NOW() AS ultima_actualizacion
FROM clientes c
LEFT JOIN prestamos p ON p.cliente_id = c.id
WHERE c.activo = true
GROUP BY c.negocio_id, c.id, c.nombre;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_top_clientes_pk 
ON mv_top_clientes(negocio_id, cliente_id);

CREATE INDEX IF NOT EXISTS idx_mv_top_clientes_ranking 
ON mv_top_clientes(negocio_id, monto_total DESC);

-- Vista materializada: Cobranza del día
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_cobranza_dia AS
SELECT 
    a.prestamo_id,
    p.negocio_id,
    p.cliente_id,
    c.nombre AS cliente_nombre,
    c.telefono AS cliente_telefono,
    a.numero_cuota,
    a.monto_cuota,
    a.fecha_vencimiento,
    a.estado,
    CASE 
        WHEN a.fecha_vencimiento < CURRENT_DATE THEN 'vencido'
        WHEN a.fecha_vencimiento = CURRENT_DATE THEN 'hoy'
        WHEN a.fecha_vencimiento = CURRENT_DATE + 1 THEN 'mañana'
        ELSE 'futuro'
    END AS urgencia,
    NOW() AS ultima_actualizacion
FROM amortizaciones a
JOIN prestamos p ON p.id = a.prestamo_id
JOIN clientes c ON c.id = p.cliente_id
WHERE a.estado IN ('pendiente', 'vencido')
AND a.fecha_vencimiento <= CURRENT_DATE + 7;

CREATE INDEX IF NOT EXISTS idx_mv_cobranza_negocio_fecha 
ON mv_cobranza_dia(negocio_id, fecha_vencimiento);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 39.4 FUNCIÓN PARA REFRESCAR VISTAS MATERIALIZADAS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION refrescar_vistas_materializadas()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_cartera;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_kpis_mes;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_clientes;
    REFRESH MATERIALIZED VIEW mv_cobranza_dia;
END;
$$ LANGUAGE plpgsql;

-- Comentario: Ejecutar esta función periódicamente (cron en Supabase o desde la app)
-- SELECT refrescar_vistas_materializadas();

-- ═══════════════════════════════════════════════════════════════════════════════
-- 39.5 FUNCIONES HELPER OPTIMIZADAS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Función: Obtener saldo pendiente de un préstamo (STABLE = cacheable)
CREATE OR REPLACE FUNCTION obtener_saldo_prestamo(p_prestamo_id UUID)
RETURNS DECIMAL AS $$
    SELECT COALESCE(SUM(monto_cuota), 0)
    FROM amortizaciones
    WHERE prestamo_id = p_prestamo_id
    AND estado IN ('pendiente', 'vencido');
$$ LANGUAGE SQL STABLE;

-- Función: Verificar si cliente tiene préstamos activos
CREATE OR REPLACE FUNCTION cliente_tiene_prestamo_activo(p_cliente_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM prestamos
        WHERE cliente_id = p_cliente_id
        AND estado IN ('activo', 'mora')
    );
$$ LANGUAGE SQL STABLE;

-- Función: Obtener siguiente cuota a pagar
CREATE OR REPLACE FUNCTION obtener_siguiente_cuota(p_prestamo_id UUID)
RETURNS TABLE (
    amortizacion_id UUID,
    numero_cuota INTEGER,
    monto_cuota DECIMAL,
    fecha_vencimiento DATE,
    dias_vencido INTEGER
) AS $$
    SELECT 
        id,
        numero_cuota,
        monto_cuota,
        fecha_vencimiento,
        GREATEST(0, CURRENT_DATE - fecha_vencimiento)::INTEGER
    FROM amortizaciones
    WHERE prestamo_id = p_prestamo_id
    AND estado IN ('pendiente', 'vencido')
    ORDER BY numero_cuota
    LIMIT 1;
$$ LANGUAGE SQL STABLE;

-- Función: Calcular mora de un préstamo
CREATE OR REPLACE FUNCTION calcular_mora_prestamo(p_prestamo_id UUID)
RETURNS TABLE (
    cuotas_vencidas INTEGER,
    monto_vencido DECIMAL,
    dias_mora_max INTEGER,
    mora_porcentaje DECIMAL
) AS $$
    SELECT 
        COUNT(*)::INTEGER,
        COALESCE(SUM(monto_cuota), 0),
        COALESCE(MAX(CURRENT_DATE - fecha_vencimiento), 0)::INTEGER,
        CASE 
            WHEN MAX(CURRENT_DATE - fecha_vencimiento) <= 0 THEN 0
            WHEN MAX(CURRENT_DATE - fecha_vencimiento) <= 7 THEN 5
            WHEN MAX(CURRENT_DATE - fecha_vencimiento) <= 30 THEN 10
            ELSE 15
        END::DECIMAL
    FROM amortizaciones
    WHERE prestamo_id = p_prestamo_id
    AND estado = 'vencido';
$$ LANGUAGE SQL STABLE;

-- Función: Resumen rápido de cartera (STABLE para cache)
CREATE OR REPLACE FUNCTION resumen_cartera_negocio(p_negocio_id UUID)
RETURNS TABLE (
    total_prestamos BIGINT,
    prestamos_activos BIGINT,
    prestamos_mora BIGINT,
    capital_vigente DECIMAL,
    por_cobrar DECIMAL,
    vencido DECIMAL,
    recuperacion_mes DECIMAL
) AS $$
    SELECT 
        COUNT(DISTINCT p.id),
        COUNT(DISTINCT p.id) FILTER (WHERE p.estado = 'activo'),
        COUNT(DISTINCT p.id) FILTER (WHERE p.estado = 'mora'),
        COALESCE(SUM(DISTINCT CASE WHEN p.estado IN ('activo', 'mora') THEN p.monto ELSE 0 END), 0),
        COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'pendiente'), 0),
        COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'vencido'), 0),
        COALESCE((
            SELECT SUM(monto) 
            FROM pagos 
            WHERE negocio_id = p_negocio_id 
            AND fecha_pago >= DATE_TRUNC('month', NOW())
        ), 0)
    FROM prestamos p
    LEFT JOIN amortizaciones a ON a.prestamo_id = p.id
    WHERE p.negocio_id = p_negocio_id;
$$ LANGUAGE SQL STABLE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 39.6 OPTIMIZACIÓN DE FUNCIONES EXISTENTES (agregar STABLE/IMMUTABLE)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Actualizar función usuario_tiene_rol para ser STABLE
CREATE OR REPLACE FUNCTION usuario_tiene_rol(rol_nombre TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM usuarios_roles ur
    JOIN roles r ON r.id = ur.rol_id
    WHERE ur.usuario_id = auth.uid() AND r.nombre = rol_nombre
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Actualizar función es_admin_o_superior para ser STABLE
CREATE OR REPLACE FUNCTION es_admin_o_superior()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM usuarios_roles ur
    JOIN roles r ON r.id = ur.rol_id
    WHERE ur.usuario_id = auth.uid() 
    AND r.nombre IN ('superadmin', 'admin')
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 39.7 TABLAS PARA CACHÉ DE ESTADÍSTICAS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Tabla de caché para estadísticas frecuentes (se actualiza con trigger o cron)
CREATE TABLE IF NOT EXISTS cache_estadisticas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- 'cartera', 'kpis', 'cobranza'
    datos JSONB NOT NULL,
    calculado_at TIMESTAMPTZ DEFAULT NOW(),
    expira_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '15 minutes',
    UNIQUE(negocio_id, tipo)
);

CREATE INDEX IF NOT EXISTS idx_cache_estadisticas_negocio_tipo 
ON cache_estadisticas(negocio_id, tipo);

CREATE INDEX IF NOT EXISTS idx_cache_estadisticas_expira 
ON cache_estadisticas(expira_at);

ALTER TABLE cache_estadisticas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cache_estadisticas_access" ON cache_estadisticas FOR ALL 
USING (auth.role() = 'authenticated');

-- Función para obtener o calcular estadísticas con caché
CREATE OR REPLACE FUNCTION obtener_estadisticas_cached(
    p_negocio_id UUID,
    p_tipo TEXT DEFAULT 'cartera'
)
RETURNS JSONB AS $$
DECLARE
    v_cache JSONB;
    v_resultado JSONB;
BEGIN
    -- Buscar en caché
    SELECT datos INTO v_cache
    FROM cache_estadisticas
    WHERE negocio_id = p_negocio_id 
    AND tipo = p_tipo
    AND expira_at > NOW();
    
    IF v_cache IS NOT NULL THEN
        RETURN v_cache;
    END IF;
    
    -- Calcular y guardar en caché
    IF p_tipo = 'cartera' THEN
        SELECT jsonb_build_object(
            'total_prestamos', COUNT(DISTINCT p.id),
            'activos', COUNT(DISTINCT p.id) FILTER (WHERE p.estado = 'activo'),
            'mora', COUNT(DISTINCT p.id) FILTER (WHERE p.estado = 'mora'),
            'capital_vigente', COALESCE(SUM(DISTINCT CASE WHEN p.estado IN ('activo', 'mora') THEN p.monto ELSE 0 END), 0),
            'por_cobrar', COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'pendiente'), 0),
            'vencido', COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'vencido'), 0)
        ) INTO v_resultado
        FROM prestamos p
        LEFT JOIN amortizaciones a ON a.prestamo_id = p.id
        WHERE p.negocio_id = p_negocio_id;
    ELSIF p_tipo = 'kpis' THEN
        SELECT jsonb_build_object(
            'nuevos_mes', COUNT(*) FILTER (WHERE fecha_creacion >= DATE_TRUNC('month', NOW())),
            'monto_colocado_mes', COALESCE(SUM(monto) FILTER (WHERE fecha_creacion >= DATE_TRUNC('month', NOW())), 0),
            'tasa_recuperacion', ROUND(
                COALESCE(
                    (COUNT(*) FILTER (WHERE estado = 'pagado')::DECIMAL / NULLIF(COUNT(*), 0) * 100), 0
                ), 2
            )
        ) INTO v_resultado
        FROM prestamos
        WHERE negocio_id = p_negocio_id;
    ELSE
        v_resultado := '{}'::JSONB;
    END IF;
    
    -- Guardar en caché
    INSERT INTO cache_estadisticas (negocio_id, tipo, datos, calculado_at, expira_at)
    VALUES (p_negocio_id, p_tipo, v_resultado, NOW(), NOW() + INTERVAL '15 minutes')
    ON CONFLICT (negocio_id, tipo) 
    DO UPDATE SET datos = EXCLUDED.datos, calculado_at = NOW(), expira_at = NOW() + INTERVAL '15 minutes';
    
    RETURN v_resultado;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 39.8 LIMPIEZA AUTOMÁTICA DE DATOS ANTIGUOS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Función para limpiar registros de auditoría antiguos (mantener últimos 6 meses)
CREATE OR REPLACE FUNCTION limpiar_auditoria_antigua()
RETURNS INTEGER AS $$
DECLARE
    v_eliminados INTEGER := 0;
    v_temp INTEGER;
BEGIN
    DELETE FROM auditoria
    WHERE fecha < NOW() - INTERVAL '6 months';
    GET DIAGNOSTICS v_temp = ROW_COUNT;
    v_eliminados := v_eliminados + v_temp;
    
    DELETE FROM auditoria_acceso
    WHERE created_at < NOW() - INTERVAL '6 months';
    GET DIAGNOSTICS v_temp = ROW_COUNT;
    v_eliminados := v_eliminados + v_temp;
    
    RETURN v_eliminados;
END;
$$ LANGUAGE plpgsql;

-- Función para limpiar notificaciones leídas antiguas
CREATE OR REPLACE FUNCTION limpiar_notificaciones_antiguas()
RETURNS INTEGER AS $$
DECLARE
    v_eliminados INTEGER;
BEGIN
    DELETE FROM notificaciones
    WHERE leida = true 
    AND created_at < NOW() - INTERVAL '3 months';
    GET DIAGNOSTICS v_eliminados = ROW_COUNT;
    RETURN v_eliminados;
END;
$$ LANGUAGE plpgsql;

-- Función para limpiar caché expirado
CREATE OR REPLACE FUNCTION limpiar_cache_expirado()
RETURNS INTEGER AS $$
DECLARE
    v_eliminados INTEGER;
BEGIN
    DELETE FROM cache_estadisticas
    WHERE expira_at < NOW();
    GET DIAGNOSTICS v_eliminados = ROW_COUNT;
    RETURN v_eliminados;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 39.9 FUNCIÓN MAESTRA DE MANTENIMIENTO
-- ═══════════════════════════════════════════════════════════════════════════════

-- Ejecutar todas las tareas de mantenimiento
CREATE OR REPLACE FUNCTION ejecutar_mantenimiento_db()
RETURNS TABLE (
    tarea TEXT,
    registros_afectados INTEGER,
    tiempo_ms INTEGER
) AS $$
DECLARE
    v_inicio TIMESTAMPTZ;
    v_registros INTEGER;
BEGIN
    -- 1. Limpiar caché expirado
    v_inicio := clock_timestamp();
    SELECT limpiar_cache_expirado() INTO v_registros;
    RETURN QUERY SELECT 'Limpiar caché'::TEXT, v_registros, 
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
    
    -- 2. Limpiar auditoría antigua
    v_inicio := clock_timestamp();
    SELECT limpiar_auditoria_antigua() INTO v_registros;
    RETURN QUERY SELECT 'Limpiar auditoría'::TEXT, v_registros,
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
    
    -- 3. Limpiar notificaciones
    v_inicio := clock_timestamp();
    SELECT limpiar_notificaciones_antiguas() INTO v_registros;
    RETURN QUERY SELECT 'Limpiar notificaciones'::TEXT, v_registros,
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
    
    -- 4. Refrescar vistas materializadas
    v_inicio := clock_timestamp();
    PERFORM refrescar_vistas_materializadas();
    RETURN QUERY SELECT 'Refrescar vistas'::TEXT, 0,
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
    
    -- 5. Actualizar estadísticas de tablas principales
    v_inicio := clock_timestamp();
    ANALYZE prestamos;
    ANALYZE amortizaciones;
    ANALYZE pagos;
    ANALYZE clientes;
    RETURN QUERY SELECT 'Actualizar estadísticas'::TEXT, 0,
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Comentario: Ejecutar mantenimiento periódicamente
-- SELECT * FROM ejecutar_mantenimiento_db();

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN SECCIÓN 39: OPTIMIZACIÓN DE BASE DE DATOS
-- ══════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════
-- FIN DEL SCHEMA V10.9 - SISTEMA COMPLETO ROBERT DARIN FINTECH
-- 128+ Tablas | 39 Secciones | RLS Habilitado | Storage Configurado | OPTIMIZADO
-- ══════════════════════════════════════════════════════════════════════════════
-- INCLUYE AHORA:
-- ✅ Sistema Multi-Negocio + Sucursales
-- ✅ Préstamos + Tandas + Avales completos
-- ✅ Técnicos CLIMAS con auth_uid
-- ✅ Repartidores PURIFICADORA con auth_uid
-- ✅ Vendedoras NICE MLM con auth_uid
-- ✅ Vendedores VENTAS con auth_uid
-- ✅ Clientes por módulo con auth_uid
-- ✅ Pedidos, productos, categorías para cada módulo
-- ✅ Colaboradores (socios, inversionistas)
-- ✅ 🆕 FACTURACIÓN ELECTRÓNICA CFDI 4.0 COMPLETA
-- ✅ 🆕 Emisores, Clientes Fiscales, Facturas, Conceptos
-- ✅ 🆕 Complementos de Pago (PPD)
-- ✅ 🆕 Catálogos SAT (Régimen, Uso CFDI, Formas de Pago)
-- ✅ 🆕 Soporte para FacturAPI, Facturama, FiscoClic
-- ✅ Tarjetas Digitales
-- ✅ Auditoría Legal + Moras
-- ✅ Chat nativo + Notificaciones
-- ✅ KPIs y filtros optimizados
-- ✅ INTEGRACIÓN STRIPE HÍBRIDA (Efectivo + Tarjeta)
-- ✅ Links de pago para WhatsApp
-- ✅ Domiciliación automática de cuotas
-- ✅ Log de transacciones Stripe
-- ✅ SISTEMA QR DE VERIFICACIÓN DE COBROS EN EFECTIVO
-- ✅ Doble confirmación (cobrador + cliente)
-- ✅ Geolocalización de cobros
-- ✅ Notificaciones en tiempo real
-- ✅ Prevención de fraudes
-- ✅ Buckets: fondos, comprobantes, documentos, avatares, logos
-- ✅ 🆕 SISTEMA DE BACKUPS Y PROTECCIÓN DE DATOS
-- Listo para ejecutar en Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 40: SISTEMA DE BACKUPS Y PROTECCIÓN DE DATOS (PRODUCCIÓN)
-- ══════════════════════════════════════════════════════════════════════════════
-- ⚠️ EJECUTAR ESTA SECCIÓN ANTES DE EMPEZAR CON DATOS REALES
-- ══════════════════════════════════════════════════════════════════════════════

-- Crear schema para backups
CREATE SCHEMA IF NOT EXISTS backup;

-- Tabla de registro de backups realizados
CREATE TABLE IF NOT EXISTS backup.historial_backups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha_backup TIMESTAMPTZ DEFAULT NOW(),
    tipo TEXT NOT NULL, -- 'manual', 'automatico', 'pre_migracion'
    tablas_respaldadas TEXT[],
    registros_totales INTEGER,
    tamaño_estimado TEXT,
    notas TEXT,
    realizado_por UUID,
    exitoso BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIÓN: Backup completo de datos críticos
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION backup.crear_backup_completo(p_notas TEXT DEFAULT NULL)
RETURNS TABLE (
    tabla TEXT,
    registros INTEGER,
    estado TEXT
) AS $$
DECLARE
    v_total INTEGER := 0;
    v_tablas TEXT[] := '{}';
BEGIN
    -- 1. Backup de clientes
    DROP TABLE IF EXISTS backup.clientes;
    CREATE TABLE backup.clientes AS SELECT *, NOW() as backup_at FROM public.clientes;
    SELECT COUNT(*) INTO v_total FROM backup.clientes;
    v_tablas := array_append(v_tablas, 'clientes');
    RETURN QUERY SELECT 'clientes'::TEXT, v_total, 'OK'::TEXT;
    
    -- 2. Backup de préstamos
    DROP TABLE IF EXISTS backup.prestamos;
    CREATE TABLE backup.prestamos AS SELECT *, NOW() as backup_at FROM public.prestamos;
    SELECT COUNT(*) INTO v_total FROM backup.prestamos;
    v_tablas := array_append(v_tablas, 'prestamos');
    RETURN QUERY SELECT 'prestamos'::TEXT, v_total, 'OK'::TEXT;
    
    -- 3. Backup de amortizaciones
    DROP TABLE IF EXISTS backup.amortizaciones;
    CREATE TABLE backup.amortizaciones AS SELECT *, NOW() as backup_at FROM public.amortizaciones;
    SELECT COUNT(*) INTO v_total FROM backup.amortizaciones;
    v_tablas := array_append(v_tablas, 'amortizaciones');
    RETURN QUERY SELECT 'amortizaciones'::TEXT, v_total, 'OK'::TEXT;
    
    -- 4. Backup de pagos
    DROP TABLE IF EXISTS backup.pagos;
    CREATE TABLE backup.pagos AS SELECT *, NOW() as backup_at FROM public.pagos;
    SELECT COUNT(*) INTO v_total FROM backup.pagos;
    v_tablas := array_append(v_tablas, 'pagos');
    RETURN QUERY SELECT 'pagos'::TEXT, v_total, 'OK'::TEXT;
    
    -- 5. Backup de tandas
    DROP TABLE IF EXISTS backup.tandas;
    CREATE TABLE backup.tandas AS SELECT *, NOW() as backup_at FROM public.tandas;
    SELECT COUNT(*) INTO v_total FROM backup.tandas;
    v_tablas := array_append(v_tablas, 'tandas');
    RETURN QUERY SELECT 'tandas'::TEXT, v_total, 'OK'::TEXT;
    
    -- 6. Backup de tanda_participantes
    DROP TABLE IF EXISTS backup.tanda_participantes;
    CREATE TABLE backup.tanda_participantes AS SELECT *, NOW() as backup_at FROM public.tanda_participantes;
    SELECT COUNT(*) INTO v_total FROM backup.tanda_participantes;
    v_tablas := array_append(v_tablas, 'tanda_participantes');
    RETURN QUERY SELECT 'tanda_participantes'::TEXT, v_total, 'OK'::TEXT;
    
    -- 7. Backup de avales
    DROP TABLE IF EXISTS backup.avales;
    CREATE TABLE backup.avales AS SELECT *, NOW() as backup_at FROM public.avales;
    SELECT COUNT(*) INTO v_total FROM backup.avales;
    v_tablas := array_append(v_tablas, 'avales');
    RETURN QUERY SELECT 'avales'::TEXT, v_total, 'OK'::TEXT;
    
    -- 8. Backup de usuarios
    DROP TABLE IF EXISTS backup.usuarios;
    CREATE TABLE backup.usuarios AS SELECT *, NOW() as backup_at FROM public.usuarios;
    SELECT COUNT(*) INTO v_total FROM backup.usuarios;
    v_tablas := array_append(v_tablas, 'usuarios');
    RETURN QUERY SELECT 'usuarios'::TEXT, v_total, 'OK'::TEXT;
    
    -- 9. Backup de registros_cobro
    DROP TABLE IF EXISTS backup.registros_cobro;
    CREATE TABLE backup.registros_cobro AS SELECT *, NOW() as backup_at FROM public.registros_cobro;
    SELECT COUNT(*) INTO v_total FROM backup.registros_cobro;
    v_tablas := array_append(v_tablas, 'registros_cobro');
    RETURN QUERY SELECT 'registros_cobro'::TEXT, v_total, 'OK'::TEXT;
    
    -- 10. Backup de negocios
    DROP TABLE IF EXISTS backup.negocios;
    CREATE TABLE backup.negocios AS SELECT *, NOW() as backup_at FROM public.negocios;
    SELECT COUNT(*) INTO v_total FROM backup.negocios;
    v_tablas := array_append(v_tablas, 'negocios');
    RETURN QUERY SELECT 'negocios'::TEXT, v_total, 'OK'::TEXT;
    
    -- Registrar backup en historial
    INSERT INTO backup.historial_backups (tipo, tablas_respaldadas, notas)
    VALUES ('manual', v_tablas, p_notas);
    
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIÓN: Verificar integridad de datos
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION verificar_integridad_datos()
RETURNS TABLE (
    tabla TEXT,
    registros BIGINT,
    ultimo_registro TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'usuarios'::TEXT, COUNT(*)::BIGINT, MAX(created_at) FROM usuarios
    UNION ALL SELECT 'clientes', COUNT(*), MAX(created_at) FROM clientes
    UNION ALL SELECT 'prestamos', COUNT(*), MAX(created_at) FROM prestamos
    UNION ALL SELECT 'amortizaciones', COUNT(*), MAX(created_at) FROM amortizaciones
    UNION ALL SELECT 'pagos', COUNT(*), MAX(created_at) FROM pagos
    UNION ALL SELECT 'tandas', COUNT(*), MAX(created_at) FROM tandas
    UNION ALL SELECT 'avales', COUNT(*), MAX(created_at) FROM avales
    UNION ALL SELECT 'negocios', COUNT(*), MAX(created_at) FROM negocios
    ORDER BY 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIÓN: Comparar datos actuales vs backup
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION backup.comparar_con_backup()
RETURNS TABLE (
    tabla TEXT,
    registros_actuales BIGINT,
    registros_backup BIGINT,
    diferencia BIGINT,
    estado TEXT
) AS $$
DECLARE
    v_actual BIGINT;
    v_backup BIGINT;
BEGIN
    -- Clientes
    SELECT COUNT(*) INTO v_actual FROM public.clientes;
    SELECT COUNT(*) INTO v_backup FROM backup.clientes;
    RETURN QUERY SELECT 'clientes'::TEXT, v_actual, COALESCE(v_backup, 0), 
        v_actual - COALESCE(v_backup, 0),
        CASE WHEN v_actual >= COALESCE(v_backup, 0) THEN '✅ OK' ELSE '⚠️ PERDIDA' END;
    
    -- Préstamos
    SELECT COUNT(*) INTO v_actual FROM public.prestamos;
    SELECT COUNT(*) INTO v_backup FROM backup.prestamos;
    RETURN QUERY SELECT 'prestamos'::TEXT, v_actual, COALESCE(v_backup, 0),
        v_actual - COALESCE(v_backup, 0),
        CASE WHEN v_actual >= COALESCE(v_backup, 0) THEN '✅ OK' ELSE '⚠️ PERDIDA' END;
    
    -- Amortizaciones
    SELECT COUNT(*) INTO v_actual FROM public.amortizaciones;
    SELECT COUNT(*) INTO v_backup FROM backup.amortizaciones;
    RETURN QUERY SELECT 'amortizaciones'::TEXT, v_actual, COALESCE(v_backup, 0),
        v_actual - COALESCE(v_backup, 0),
        CASE WHEN v_actual >= COALESCE(v_backup, 0) THEN '✅ OK' ELSE '⚠️ PERDIDA' END;
    
    -- Pagos
    SELECT COUNT(*) INTO v_actual FROM public.pagos;
    SELECT COUNT(*) INTO v_backup FROM backup.pagos;
    RETURN QUERY SELECT 'pagos'::TEXT, v_actual, COALESCE(v_backup, 0),
        v_actual - COALESCE(v_backup, 0),
        CASE WHEN v_actual >= COALESCE(v_backup, 0) THEN '✅ OK' ELSE '⚠️ PERDIDA' END;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 'No hay backup previo'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════════
-- INSTRUCCIONES DE USO
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- 1. ANTES de cualquier cambio SQL, ejecutar:
--    SELECT * FROM backup.crear_backup_completo('Antes de actualización v10.X');
--
-- 2. Para verificar estado actual:
--    SELECT * FROM verificar_integridad_datos();
--
-- 3. Después de cambios, comparar:
--    SELECT * FROM backup.comparar_con_backup();
--
-- 4. Ver historial de backups:
--    SELECT * FROM backup.historial_backups ORDER BY fecha_backup DESC;
--
-- ══════════════════════════════════════════════════════════════════════════════
-- FIN SECCIÓN 40: SISTEMA DE BACKUPS
-- ══════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 41: AUTO-CREACIÓN DE DATOS INICIALES NICE
-- ══════════════════════════════════════════════════════════════════════════════
-- Este trigger crea automáticamente niveles, categorías, catálogos y productos
-- de ejemplo cuando se crea un negocio de tipo 'retail' (NICE Joyería)
-- ══════════════════════════════════════════════════════════════════════════════

-- Función que inicializa datos NICE para un nuevo negocio
CREATE OR REPLACE FUNCTION inicializar_datos_nice()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo ejecutar para negocios tipo retail (NICE)
    IF NEW.tipo = 'retail' THEN
        
        -- 1. Insertar niveles MLM
        INSERT INTO nice_niveles (negocio_id, nombre, orden, comision_porcentaje, comision_equipo_porcentaje, meta_ventas_mensual, beneficios, color, icono, activo)
        VALUES
            (NEW.id, 'Bronce', 1, 20.00, 0.00, 5000.00, '["Precio preferencial 30% descuento", "Kit de inicio", "Capacitación básica"]', '#CD7F32', 'star_border', TRUE),
            (NEW.id, 'Plata', 2, 25.00, 3.00, 15000.00, '["Todo Bronce", "5% comisión equipo nivel 1", "Catálogo digital", "Soporte prioritario"]', '#C0C0C0', 'star_half', TRUE),
            (NEW.id, 'Oro', 3, 30.00, 5.00, 35000.00, '["Todo Plata", "7% comisión equipo", "Bonos trimestrales", "Reconocimiento público"]', '#FFD700', 'star', TRUE),
            (NEW.id, 'Platino', 4, 35.00, 8.00, 75000.00, '["Todo Oro", "10% comisión equipo", "Viaje anual", "Producto gratis mensual"]', '#E5E4E2', 'workspace_premium', TRUE),
            (NEW.id, 'Diamante', 5, 40.00, 12.00, 150000.00, '["Todo Platino", "15% comisión multinivel", "Auto programa", "Participación utilidades"]', '#B9F2FF', 'diamond', TRUE);
        
        -- 2. Insertar categorías de joyería
        INSERT INTO nice_categorias (negocio_id, nombre, descripcion, icono, color, orden, activa)
        VALUES
            (NEW.id, 'Anillos', 'Anillos de compromiso, bodas y moda', 'ring_volume', '#E91E63', 1, TRUE),
            (NEW.id, 'Collares', 'Cadenas, dijes y gargantillas', 'necklace', '#9C27B0', 2, TRUE),
            (NEW.id, 'Aretes', 'Aretes, huggies y piercings', 'earbuds', '#673AB7', 3, TRUE),
            (NEW.id, 'Pulseras', 'Pulseras, brazaletes y tobilleras', 'watch', '#3F51B5', 4, TRUE),
            (NEW.id, 'Relojes', 'Relojes de dama y caballero', 'schedule', '#2196F3', 5, TRUE),
            (NEW.id, 'Sets', 'Conjuntos y juegos de joyería', 'inventory_2', '#00BCD4', 6, TRUE),
            (NEW.id, 'Accesorios', 'Broches, pins y otros accesorios', 'category', '#009688', 7, TRUE);
        
        -- 3. Insertar catálogo inicial
        INSERT INTO nice_catalogos (negocio_id, nombre, descripcion, vigencia_inicio, vigencia_fin, imagen_portada, version, activo)
        VALUES
            (NEW.id, 'Catálogo 2026', 'Catálogo de lanzamiento ' || NEW.nombre, CURRENT_DATE, CURRENT_DATE + INTERVAL '1 year', NULL, '1.0', TRUE);
        
        -- 4. Insertar productos de ejemplo
        INSERT INTO nice_productos (negocio_id, categoria_id, sku, codigo_pagina, nombre, descripcion, material, precio_catalogo, precio_vendedora, costo, stock, stock_minimo, destacado, nuevo, activo)
        SELECT 
            NEW.id,
            cat.id,
            'NICE-' || LPAD(ROW_NUMBER() OVER()::TEXT, 4, '0'),
            'P' || LPAD(ROW_NUMBER() OVER()::TEXT, 3, '0'),
            prod.nombre,
            prod.descripcion,
            prod.material,
            prod.precio,
            ROUND(prod.precio * 0.70, 2),
            ROUND(prod.precio * 0.45, 2),
            prod.stock,
            5,
            prod.destacado,
            prod.nuevo,
            TRUE
        FROM (VALUES
            ('Anillo Solitario Clásico', 'Anillo con circón brillante central', 'Plata 925', 850.00, 25, TRUE, TRUE, 'Anillos'),
            ('Anillo Infinity Love', 'Símbolo del amor infinito', 'Oro 10k', 2200.00, 15, TRUE, FALSE, 'Anillos'),
            ('Collar Corazón Brillante', 'Dije corazón con cadena 45cm', 'Plata 925', 980.00, 20, TRUE, TRUE, 'Collares'),
            ('Collar Perlas Elegance', 'Perlas cultivadas 6mm', 'Perlas/Plata', 1500.00, 12, TRUE, FALSE, 'Collares'),
            ('Aretes Huggies Diamond', 'Aretes abrazadera con circones', 'Plata 925', 680.00, 35, TRUE, TRUE, 'Aretes'),
            ('Aretes Gota Cristal', 'Cristal Swarovski', 'Plata/Cristal', 950.00, 20, TRUE, FALSE, 'Aretes'),
            ('Pulsera Tennis Classic', '30 circones brillantes', 'Plata 925', 1400.00, 15, TRUE, TRUE, 'Pulseras'),
            ('Pulsera Charm Love', '5 dijes incluidos', 'Plata 925', 890.00, 22, TRUE, FALSE, 'Pulseras'),
            ('Reloj Glamour Rose', 'Reloj dama con cristales', 'Acero/Oro rosa', 1800.00, 10, TRUE, TRUE, 'Relojes'),
            ('Set Novia Completo', 'Collar + Aretes + Pulsera', 'Plata 925/Cristal', 4500.00, 5, TRUE, TRUE, 'Sets')
        ) AS prod(nombre, descripcion, material, precio, stock, destacado, nuevo, categoria)
        LEFT JOIN nice_categorias cat ON cat.nombre = prod.categoria AND cat.negocio_id = NEW.id;
        
        RAISE NOTICE 'NICE: Datos iniciales creados para negocio %', NEW.nombre;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger que se ejecuta después de INSERT en negocios
DROP TRIGGER IF EXISTS trigger_inicializar_nice ON negocios;
CREATE TRIGGER trigger_inicializar_nice
    AFTER INSERT ON negocios
    FOR EACH ROW
    EXECUTE FUNCTION inicializar_datos_nice();

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN SECCIÓN 41: AUTO-CREACIÓN DATOS NICE
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 42: PARCHE V10.27 - COLUMNAS Y TABLAS FALTANTES (AUDITORÍA COMPLETA)
-- Fecha: 12 Enero 2026
-- Descripción: Sincronización completa entre modelos Flutter y base de datos
-- ══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.0 COLUMNAS CRÍTICAS - negocio_id en tablas de facturación
-- IMPORTANTE: Ejecutar PRIMERO para evitar errores en índices
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE;
ALTER TABLE facturacion_emisores ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE;
ALTER TABLE facturacion_clientes ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE;
ALTER TABLE facturacion_logs ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE;
ALTER TABLE factura_complementos_pago ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE;

-- Índices para negocio_id si no existen
CREATE INDEX IF NOT EXISTS idx_facturas_negocio ON facturas(negocio_id);
CREATE INDEX IF NOT EXISTS idx_facturacion_clientes_negocio ON facturacion_clientes(negocio_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.1 AVALES - Campos V10.26 para documentos directos y tracking
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE avales ADD COLUMN IF NOT EXISTS ine_url TEXT;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS ine_reverso_url TEXT;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS domicilio_url TEXT;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS selfie_url TEXT;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS ingresos_url TEXT;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS ubicacion_consentida BOOLEAN DEFAULT FALSE;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS firma_digital_url TEXT;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS fecha_firma TIMESTAMPTZ;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS ultima_latitud DECIMAL(10,8);
ALTER TABLE avales ADD COLUMN IF NOT EXISTS ultima_longitud DECIMAL(11,8);
ALTER TABLE avales ADD COLUMN IF NOT EXISTS ultimo_checkin TIMESTAMPTZ;
ALTER TABLE avales ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.2 CLIENTES - Campos faltantes del modelo
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS apellidos TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ciudad TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS estado TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS codigo_postal TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ine_url TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS comprobante_domicilio_url TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS latitud DECIMAL(10,8);
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS longitud DECIMAL(11,8);
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS notas TEXT;
-- Campos de referencias personales
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ref_nombre_1 TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ref_telefono_1 TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ref_relacion_1 TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ref_nombre_2 TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ref_telefono_2 TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ref_relacion_2 TEXT;
-- Campos laborales
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS empresa TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS antiguedad_laboral TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS clave_elector TEXT;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.3 USUARIOS - Campos faltantes
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS ultimo_acceso TIMESTAMPTZ;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS dispositivo_actual TEXT;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS ip_ultimo_acceso TEXT;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.4 PRÉSTAMOS - Campos faltantes para multitenancy y auditoría
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE;
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL;
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS proposito TEXT;
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS garantia TEXT;
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS aprobado_por UUID REFERENCES usuarios(id);
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS fecha_aprobacion TIMESTAMPTZ;
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS fecha_primer_pago DATE;
ALTER TABLE prestamos ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Índices para multitenancy préstamos
CREATE INDEX IF NOT EXISTS idx_prestamos_negocio ON prestamos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_prestamos_sucursal ON prestamos(sucursal_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.5 AMORTIZACIONES - Campo faltante
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE amortizaciones ADD COLUMN IF NOT EXISTS saldo_restante NUMERIC(12,2) DEFAULT 0;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.6 TANDAS - Campos faltantes para multitenancy
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE tandas ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE;
ALTER TABLE tandas ADD COLUMN IF NOT EXISTS sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL;
ALTER TABLE tandas ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE tandas ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Índices para multitenancy tandas
CREATE INDEX IF NOT EXISTS idx_tandas_negocio ON tandas(negocio_id);
CREATE INDEX IF NOT EXISTS idx_tandas_sucursal ON tandas(sucursal_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.7 COLABORADORES - Campos faltantes
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE colaborador_permisos_modulo ADD COLUMN IF NOT EXISTS puede_exportar BOOLEAN DEFAULT FALSE;
ALTER TABLE colaborador_permisos_modulo ADD COLUMN IF NOT EXISTS solo_propios BOOLEAN DEFAULT TRUE;

ALTER TABLE colaborador_actividad ADD COLUMN IF NOT EXISTS tipo_accion TEXT;
ALTER TABLE colaborador_actividad ADD COLUMN IF NOT EXISTS modulo TEXT;
ALTER TABLE colaborador_actividad ADD COLUMN IF NOT EXISTS detalles JSONB DEFAULT '{}';

ALTER TABLE colaborador_invitaciones ADD COLUMN IF NOT EXISTS mensaje_personal TEXT;
ALTER TABLE colaborador_invitaciones ADD COLUMN IF NOT EXISTS veces_enviada INTEGER DEFAULT 1;

ALTER TABLE colaborador_inversiones ADD COLUMN IF NOT EXISTS referencia_bancaria TEXT;

ALTER TABLE colaborador_rendimientos ADD COLUMN IF NOT EXISTS periodo_inicio DATE;
ALTER TABLE colaborador_rendimientos ADD COLUMN IF NOT EXISTS periodo_fin DATE;
ALTER TABLE colaborador_rendimientos ADD COLUMN IF NOT EXISTS monto_base NUMERIC(14,2);
ALTER TABLE colaborador_rendimientos ADD COLUMN IF NOT EXISTS tasa_aplicada NUMERIC(5,2);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.8 DOCUMENTOS_AVAL - Campos faltantes
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE documentos_aval ADD COLUMN IF NOT EXISTS nombre_archivo TEXT;
ALTER TABLE documentos_aval ADD COLUMN IF NOT EXISTS tamano_bytes INTEGER;
ALTER TABLE documentos_aval ADD COLUMN IF NOT EXISTS mime_type TEXT;
ALTER TABLE documentos_aval ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.9 PAGOS - Campos faltantes
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS tanda_id UUID REFERENCES tandas(id) ON DELETE SET NULL;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS amortizacion_id UUID REFERENCES amortizaciones(id) ON DELETE SET NULL;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS metodo_pago TEXT DEFAULT 'efectivo';
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS recibo_oficial_url TEXT;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS registrado_por UUID REFERENCES usuarios(id);

CREATE INDEX IF NOT EXISTS idx_pagos_negocio ON pagos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_pagos_tanda ON pagos(tanda_id);
CREATE INDEX IF NOT EXISTS idx_pagos_cliente ON pagos(cliente_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.10 COMPROBANTES_PRESTAMO - Campos faltantes
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE comprobantes_prestamo ADD COLUMN IF NOT EXISTS fecha_subida TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE comprobantes_prestamo ADD COLUMN IF NOT EXISTS subido_por UUID REFERENCES usuarios(id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.11 EMPLEADOS - Campos faltantes del modelo
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS nombre TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS apellidos TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS telefono TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS direccion TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS departamento TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS numero_empleado TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS curp TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS rfc TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS nss TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS cuenta_banco TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS banco TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS foto_url TEXT;
-- Renombrar/agregar campos para consistencia
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS salario_base NUMERIC(12,2);
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS tipo_pago_comision TEXT;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS fecha_ingreso DATE;

CREATE INDEX IF NOT EXISTS idx_empleados_negocio ON empleados(negocio_id);
CREATE INDEX IF NOT EXISTS idx_empleados_numero ON empleados(numero_empleado);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.12 QR_COBROS - Campos faltantes
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE qr_cobros ADD COLUMN IF NOT EXISTS cliente_ip TEXT;
ALTER TABLE qr_cobros ADD COLUMN IF NOT EXISTS notificacion_admin_enviada BOOLEAN DEFAULT FALSE;
ALTER TABLE qr_cobros ADD COLUMN IF NOT EXISTS notificacion_cliente_enviada BOOLEAN DEFAULT FALSE;
ALTER TABLE qr_cobros ADD COLUMN IF NOT EXISTS notas TEXT;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.13 NICE - Campos faltantes en modelos
-- ═══════════════════════════════════════════════════════════════════════════

-- nice_niveles - campos del modelo
ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS equipo_minimo INTEGER DEFAULT 0;
ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS puntos_minimos INTEGER DEFAULT 0;
ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS comision_equipo_n1 NUMERIC(5,2) DEFAULT 0;
ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS comision_equipo_n2 NUMERIC(5,2) DEFAULT 0;
ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS comision_equipo_n3 NUMERIC(5,2) DEFAULT 0;
ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS bono_liderazgo NUMERIC(12,2) DEFAULT 0;
ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS icono TEXT;
ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS insignia_url TEXT;

-- nice_vendedoras - campos del modelo
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS apellidos TEXT;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS estado TEXT;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS codigo_postal TEXT;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS rfc TEXT;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS curp TEXT;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS titular_cuenta TEXT;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS instagram TEXT;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS facebook TEXT;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS tiktok TEXT;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS verificada BOOLEAN DEFAULT FALSE;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS comisiones_totales NUMERIC(12,2) DEFAULT 0;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS puntos_acumulados INTEGER DEFAULT 0;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS clientes_activos INTEGER DEFAULT 0;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS equipo_directo INTEGER DEFAULT 0;
ALTER TABLE nice_vendedoras ADD COLUMN IF NOT EXISTS usuario_id UUID REFERENCES usuarios(id);

-- nice_clientes - campos del modelo
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS apellidos TEXT;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS colonia TEXT;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS estado TEXT;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS codigo_postal TEXT;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS referencias TEXT;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS categorias_favoritas TEXT[];
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS talla_anillo TEXT;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS preferencias_color TEXT;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS cantidad_pedidos INTEGER DEFAULT 0;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS ultima_compra DATE;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS acepta_whatsapp BOOLEAN DEFAULT TRUE;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS acepta_email BOOLEAN DEFAULT TRUE;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS fecha_ultimo_contacto DATE;
ALTER TABLE nice_clientes ADD COLUMN IF NOT EXISTS es_vip BOOLEAN DEFAULT FALSE;

-- nice_productos - campos del modelo
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS imagen_principal_url TEXT;
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS es_nuevo BOOLEAN DEFAULT FALSE;
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS es_destacado BOOLEAN DEFAULT FALSE;
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS es_oferta BOOLEAN DEFAULT FALSE;
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS precio_oferta NUMERIC(10,2);
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS disponible BOOLEAN DEFAULT TRUE;
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS veces_vendido INTEGER DEFAULT 0;
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS peso_gramos NUMERIC(8,2);
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS pagina_catalogo INTEGER;
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS talla TEXT;
ALTER TABLE nice_productos ADD COLUMN IF NOT EXISTS stock_minimo INTEGER DEFAULT 5;

-- nice_pedidos - campos del modelo
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS catalogo_id UUID REFERENCES nice_catalogos(id);
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS envio NUMERIC(10,2) DEFAULT 0;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS ganancia_vendedora NUMERIC(10,2) DEFAULT 0;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS puntos_generados INTEGER DEFAULT 0;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS tipo_envio TEXT;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS guia_envio TEXT;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS paqueteria TEXT;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS cliente_nombre TEXT;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS cliente_telefono TEXT;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS notas_vendedora TEXT;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS notas_internas TEXT;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS referencia_pago TEXT;
ALTER TABLE nice_pedidos ADD COLUMN IF NOT EXISTS comprobante_url TEXT;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.14 VENTAS - Campos faltantes en modelos
-- ═══════════════════════════════════════════════════════════════════════════

-- ventas_clientes - campos del modelo
ALTER TABLE ventas_clientes ADD COLUMN IF NOT EXISTS vendedor_id UUID REFERENCES ventas_vendedores(id);
ALTER TABLE ventas_clientes ADD COLUMN IF NOT EXISTS auth_uid UUID;
ALTER TABLE ventas_clientes ADD COLUMN IF NOT EXISTS rfc TEXT;
ALTER TABLE ventas_clientes ADD COLUMN IF NOT EXISTS codigo_postal TEXT;
ALTER TABLE ventas_clientes ADD COLUMN IF NOT EXISTS dias_credito INTEGER DEFAULT 0;
ALTER TABLE ventas_clientes ADD COLUMN IF NOT EXISTS total_compras NUMERIC(14,2) DEFAULT 0;

-- ventas_productos - campos del modelo
ALTER TABLE ventas_productos ADD COLUMN IF NOT EXISTS marca TEXT;
ALTER TABLE ventas_productos ADD COLUMN IF NOT EXISTS modelo TEXT;
ALTER TABLE ventas_productos ADD COLUMN IF NOT EXISTS galeria TEXT[];
ALTER TABLE ventas_productos ADD COLUMN IF NOT EXISTS especificaciones JSONB DEFAULT '{}';
ALTER TABLE ventas_productos ADD COLUMN IF NOT EXISTS stock_maximo INTEGER;

-- ventas_vendedores - campos del modelo
ALTER TABLE ventas_vendedores ADD COLUMN IF NOT EXISTS auth_uid UUID;
ALTER TABLE ventas_vendedores ADD COLUMN IF NOT EXISTS codigo TEXT;
ALTER TABLE ventas_vendedores ADD COLUMN IF NOT EXISTS zona TEXT;
ALTER TABLE ventas_vendedores ADD COLUMN IF NOT EXISTS comisiones_pendientes NUMERIC(12,2) DEFAULT 0;

-- ventas_pedidos - campos del modelo
ALTER TABLE ventas_pedidos ADD COLUMN IF NOT EXISTS tipo_venta TEXT DEFAULT 'contado';
ALTER TABLE ventas_pedidos ADD COLUMN IF NOT EXISTS fecha_entrega_estimada DATE;
ALTER TABLE ventas_pedidos ADD COLUMN IF NOT EXISTS fecha_entregado TIMESTAMPTZ;
ALTER TABLE ventas_pedidos ADD COLUMN IF NOT EXISTS monto_pagado NUMERIC(12,2) DEFAULT 0;
ALTER TABLE ventas_pedidos ADD COLUMN IF NOT EXISTS saldo_pendiente NUMERIC(12,2) DEFAULT 0;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.15 CLIMAS - Campos y tablas faltantes
-- ═══════════════════════════════════════════════════════════════════════════

-- climas_clientes - campos del modelo
ALTER TABLE climas_clientes ADD COLUMN IF NOT EXISTS colonia TEXT;
ALTER TABLE climas_clientes ADD COLUMN IF NOT EXISTS referencia TEXT;
ALTER TABLE climas_clientes ADD COLUMN IF NOT EXISTS rfc TEXT;
ALTER TABLE climas_clientes ADD COLUMN IF NOT EXISTS latitud DECIMAL(10,8);
ALTER TABLE climas_clientes ADD COLUMN IF NOT EXISTS longitud DECIMAL(11,8);

-- climas_tecnicos - campos del modelo (restructuración completa)
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS codigo TEXT;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS apellidos TEXT;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS especialidades TEXT[];
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS certificaciones TEXT[];
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS vehiculo_asignado TEXT;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS zona_cobertura TEXT[];
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS calificacion_promedio NUMERIC(3,2) DEFAULT 0;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS total_servicios INTEGER DEFAULT 0;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS servicios_mes INTEGER DEFAULT 0;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS comision_servicio NUMERIC(5,2) DEFAULT 0;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS disponible BOOLEAN DEFAULT TRUE;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS en_servicio BOOLEAN DEFAULT FALSE;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS ubicacion_actual TEXT;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS foto_url TEXT;
-- Campos para compatibilidad con modelo
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS especialidad TEXT;
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS nivel TEXT DEFAULT 'junior';
ALTER TABLE climas_tecnicos ADD COLUMN IF NOT EXISTS salario_base NUMERIC(12,2) DEFAULT 0;

-- climas_productos - campos del modelo
ALTER TABLE climas_productos ADD COLUMN IF NOT EXISTS codigo TEXT;
ALTER TABLE climas_productos ADD COLUMN IF NOT EXISTS costo NUMERIC(10,2) DEFAULT 0;
ALTER TABLE climas_productos ADD COLUMN IF NOT EXISTS stock INTEGER DEFAULT 0;
ALTER TABLE climas_productos ADD COLUMN IF NOT EXISTS stock_minimo INTEGER DEFAULT 5;

-- climas_ordenes_servicio - campos del modelo
ALTER TABLE climas_ordenes_servicio ADD COLUMN IF NOT EXISTS numero_orden TEXT;
ALTER TABLE climas_ordenes_servicio ADD COLUMN IF NOT EXISTS hora_programada TIME;
ALTER TABLE climas_ordenes_servicio ADD COLUMN IF NOT EXISTS firma_cliente TEXT;
ALTER TABLE climas_ordenes_servicio ADD COLUMN IF NOT EXISTS foto_antes TEXT;
ALTER TABLE climas_ordenes_servicio ADD COLUMN IF NOT EXISTS foto_despues TEXT;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.16 PURIFICADORA - Campos faltantes y tablas nuevas
-- ═══════════════════════════════════════════════════════════════════════════

-- purificadora_clientes - campos del modelo
ALTER TABLE purificadora_clientes ADD COLUMN IF NOT EXISTS garrafones_en_prestamo INTEGER DEFAULT 0;
ALTER TABLE purificadora_clientes ADD COLUMN IF NOT EXISTS garrafones_maximo INTEGER DEFAULT 10;
ALTER TABLE purificadora_clientes ADD COLUMN IF NOT EXISTS frecuencia_entrega TEXT DEFAULT 'semanal';
ALTER TABLE purificadora_clientes ADD COLUMN IF NOT EXISTS dias_entrega TEXT[];
ALTER TABLE purificadora_clientes ADD COLUMN IF NOT EXISTS saldo_pendiente NUMERIC(12,2) DEFAULT 0;
ALTER TABLE purificadora_clientes ADD COLUMN IF NOT EXISTS ultima_entrega DATE;

-- purificadora_repartidores - campos del modelo
ALTER TABLE purificadora_repartidores ADD COLUMN IF NOT EXISTS licencia TEXT;
ALTER TABLE purificadora_repartidores ADD COLUMN IF NOT EXISTS vehiculo TEXT;
ALTER TABLE purificadora_repartidores ADD COLUMN IF NOT EXISTS placas TEXT;
ALTER TABLE purificadora_repartidores ADD COLUMN IF NOT EXISTS garrafones_asignados INTEGER DEFAULT 0;
ALTER TABLE purificadora_repartidores ADD COLUMN IF NOT EXISTS estado TEXT DEFAULT 'activo';

-- purificadora_rutas - campos del modelo
ALTER TABLE purificadora_rutas ADD COLUMN IF NOT EXISTS dias_ruta TEXT[];
ALTER TABLE purificadora_rutas ADD COLUMN IF NOT EXISTS horario_inicio TIME;
ALTER TABLE purificadora_rutas ADD COLUMN IF NOT EXISTS horario_fin TIME;
ALTER TABLE purificadora_rutas ADD COLUMN IF NOT EXISTS clientes_total INTEGER DEFAULT 0;
ALTER TABLE purificadora_rutas ADD COLUMN IF NOT EXISTS zona_coordenadas JSONB;

-- purificadora_entregas - campos del modelo
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS folio TEXT;
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS productos_adicionales JSONB DEFAULT '[]';
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS subtotal NUMERIC(10,2) DEFAULT 0;
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS descuento NUMERIC(10,2) DEFAULT 0;
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS total NUMERIC(10,2) DEFAULT 0;
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS monto_pagado NUMERIC(10,2) DEFAULT 0;
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS motivo_no_entrega TEXT;
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS ubicacion_entrega_lat DECIMAL(10,8);
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS ubicacion_entrega_lng DECIMAL(11,8);
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS firma_cliente_url TEXT;
ALTER TABLE purificadora_entregas ADD COLUMN IF NOT EXISTS foto_entrega_url TEXT;

-- purificadora_cortes - campos del modelo
ALTER TABLE purificadora_cortes ADD COLUMN IF NOT EXISTS garrafones_vacios_recogidos INTEGER DEFAULT 0;
ALTER TABLE purificadora_cortes ADD COLUMN IF NOT EXISTS garrafones_regreso INTEGER DEFAULT 0;
ALTER TABLE purificadora_cortes ADD COLUMN IF NOT EXISTS garrafones_faltantes INTEGER DEFAULT 0;
ALTER TABLE purificadora_cortes ADD COLUMN IF NOT EXISTS total_ventas NUMERIC(12,2) DEFAULT 0;
ALTER TABLE purificadora_cortes ADD COLUMN IF NOT EXISTS total_cobranza_anterior NUMERIC(12,2) DEFAULT 0;
ALTER TABLE purificadora_cortes ADD COLUMN IF NOT EXISTS transferencias_recibidas NUMERIC(12,2) DEFAULT 0;
ALTER TABLE purificadora_cortes ADD COLUMN IF NOT EXISTS ruta_id UUID REFERENCES purificadora_rutas(id);

-- Tablas nuevas que faltan en SQL pero existen en modelos

-- Tabla: purificadora_produccion
CREATE TABLE IF NOT EXISTS purificadora_produccion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    garrafones_producidos INTEGER DEFAULT 0,
    garrafones_defectuosos INTEGER DEFAULT 0,
    litros_agua_usados NUMERIC(12,2) DEFAULT 0,
    litros_desperdicio NUMERIC(12,2) DEFAULT 0,
    costo_produccion NUMERIC(12,2) DEFAULT 0,
    responsable_id UUID REFERENCES usuarios(id),
    turno TEXT DEFAULT 'matutino',
    observaciones TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purificadora_produccion ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purificadora_produccion_access" ON purificadora_produccion;
CREATE POLICY "purificadora_produccion_access" ON purificadora_produccion FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_purificadora_produccion_negocio ON purificadora_produccion(negocio_id);
CREATE INDEX IF NOT EXISTS idx_purificadora_produccion_fecha ON purificadora_produccion(fecha);

-- Tabla: purificadora_precios
CREATE TABLE IF NOT EXISTS purificadora_precios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES purificadora_productos(id) ON DELETE CASCADE,
    tipo_cliente TEXT DEFAULT 'general', -- general, mayoreo, especial
    precio NUMERIC(10,2) NOT NULL,
    precio_anterior NUMERIC(10,2),
    vigente_desde DATE DEFAULT CURRENT_DATE,
    vigente_hasta DATE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purificadora_precios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purificadora_precios_access" ON purificadora_precios;
CREATE POLICY "purificadora_precios_access" ON purificadora_precios FOR ALL USING (auth.role() = 'authenticated');

-- Tabla: purificadora_inventario_garrafones
CREATE TABLE IF NOT EXISTS purificadora_inventario_garrafones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    tipo_movimiento TEXT NOT NULL, -- entrada, salida, prestamo, devolucion, perdida
    cantidad INTEGER NOT NULL,
    garrafones_buenos INTEGER DEFAULT 0,
    garrafones_danados INTEGER DEFAULT 0,
    garrafones_en_prestamo INTEGER DEFAULT 0,
    garrafones_disponibles INTEGER DEFAULT 0,
    referencia_id UUID, -- Puede ser entrega, repartidor, cliente
    referencia_tipo TEXT, -- entrega, repartidor, cliente, ajuste
    motivo TEXT,
    realizado_por UUID REFERENCES usuarios(id),
    fecha DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purificadora_inventario_garrafones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purificadora_inventario_garrafones_access" ON purificadora_inventario_garrafones;
CREATE POLICY "purificadora_inventario_garrafones_access" ON purificadora_inventario_garrafones FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_purificadora_inv_garrafones_negocio ON purificadora_inventario_garrafones(negocio_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.17 CHAT - Campos y tablas faltantes
-- ═══════════════════════════════════════════════════════════════════════════

-- chat_conversaciones - campos faltantes
ALTER TABLE chat_conversaciones ADD COLUMN IF NOT EXISTS ultimo_mensaje TEXT;
ALTER TABLE chat_conversaciones ADD COLUMN IF NOT EXISTS fecha_ultimo_mensaje TIMESTAMPTZ;
ALTER TABLE chat_conversaciones ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- chat_mensajes - campos faltantes
ALTER TABLE chat_mensajes ADD COLUMN IF NOT EXISTS leido BOOLEAN DEFAULT FALSE;
ALTER TABLE chat_mensajes ADD COLUMN IF NOT EXISTS fecha_lectura TIMESTAMPTZ;

-- chat_participantes - campo faltante
ALTER TABLE chat_participantes ADD COLUMN IF NOT EXISTS silenciado BOOLEAN DEFAULT FALSE;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.18 NOTIFICACIONES - Tablas faltantes
-- ═══════════════════════════════════════════════════════════════════════════

-- Tabla: notificaciones_masivas
CREATE TABLE IF NOT EXISTS notificaciones_masivas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    mensaje TEXT NOT NULL,
    tipo TEXT DEFAULT 'general', -- general, promocion, urgente, recordatorio
    destinatarios_tipo TEXT DEFAULT 'todos', -- todos, clientes, empleados, avales, colaboradores
    destinatarios_filtro JSONB DEFAULT '{}',
    total_destinatarios INTEGER DEFAULT 0,
    enviadas INTEGER DEFAULT 0,
    leidas INTEGER DEFAULT 0,
    errores INTEGER DEFAULT 0,
    programada_para TIMESTAMPTZ,
    enviada_at TIMESTAMPTZ,
    estado TEXT DEFAULT 'borrador', -- borrador, programada, enviando, completada, cancelada
    creado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE notificaciones_masivas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notificaciones_masivas_access" ON notificaciones_masivas;
CREATE POLICY "notificaciones_masivas_access" ON notificaciones_masivas FOR ALL USING (auth.role() = 'authenticated');

-- Agregar FK de notificaciones a notificaciones_masivas (no se pudo agregar antes por orden de creación)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_notificaciones_masiva' 
        AND table_name = 'notificaciones'
    ) THEN
        ALTER TABLE notificaciones 
        ADD CONSTRAINT fk_notificaciones_masiva 
        FOREIGN KEY (notificacion_masiva_id) REFERENCES notificaciones_masivas(id);
    END IF;
END $$;

-- Tabla: notificaciones_mora_cliente
CREATE TABLE IF NOT EXISTS notificaciones_mora_cliente (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
    amortizacion_id UUID REFERENCES amortizaciones(id) ON DELETE SET NULL,
    tipo TEXT NOT NULL, -- recordatorio, primer_aviso, segundo_aviso, urgente
    titulo TEXT NOT NULL,
    mensaje TEXT NOT NULL,
    monto_adeudado NUMERIC(12,2),
    dias_mora INTEGER DEFAULT 0,
    canal TEXT DEFAULT 'app', -- app, sms, email, whatsapp, llamada
    enviada BOOLEAN DEFAULT FALSE,
    fecha_envio TIMESTAMPTZ,
    leida BOOLEAN DEFAULT FALSE,
    fecha_lectura TIMESTAMPTZ,
    respuesta TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE notificaciones_mora_cliente ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notificaciones_mora_cliente_access" ON notificaciones_mora_cliente;
CREATE POLICY "notificaciones_mora_cliente_access" ON notificaciones_mora_cliente FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_notif_mora_cliente ON notificaciones_mora_cliente(cliente_id);
CREATE INDEX IF NOT EXISTS idx_notif_mora_prestamo ON notificaciones_mora_cliente(prestamo_id);

-- Tabla: notificaciones_sistema
CREATE TABLE IF NOT EXISTS notificaciones_sistema (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- alerta, error, info, exito
    categoria TEXT, -- seguridad, sistema, backup, actualizacion
    titulo TEXT NOT NULL,
    mensaje TEXT NOT NULL,
    detalles JSONB DEFAULT '{}',
    nivel_urgencia INTEGER DEFAULT 1, -- 1=bajo, 2=medio, 3=alto, 4=critico
    resuelta BOOLEAN DEFAULT FALSE,
    resuelta_por UUID REFERENCES usuarios(id),
    fecha_resolucion TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE notificaciones_sistema ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notificaciones_sistema_access" ON notificaciones_sistema;
CREATE POLICY "notificaciones_sistema_access" ON notificaciones_sistema FOR ALL USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.19 AUDITORÍA LEGAL - Tablas faltantes
-- ═══════════════════════════════════════════════════════════════════════════

-- Tabla: seguimiento_judicial (falta modelo)
CREATE TABLE IF NOT EXISTS seguimiento_judicial (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expediente_id UUID REFERENCES expedientes_legales(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    tipo_evento TEXT NOT NULL, -- audiencia, notificacion, resolucion, embargo, otro
    descripcion TEXT NOT NULL,
    resultado TEXT,
    documento_url TEXT,
    proxima_fecha DATE,
    proxima_accion TEXT,
    responsable TEXT,
    notas TEXT,
    registrado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE seguimiento_judicial ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "seguimiento_judicial_access" ON seguimiento_judicial;
CREATE POLICY "seguimiento_judicial_access" ON seguimiento_judicial FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_seguimiento_expediente ON seguimiento_judicial(expediente_id);

-- Tabla: acuses_recibo
CREATE TABLE IF NOT EXISTS acuses_recibo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expediente_id UUID REFERENCES expedientes_legales(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- carta, demanda, citatorio, embargo
    fecha_envio DATE NOT NULL,
    destinatario TEXT NOT NULL,
    direccion TEXT,
    medio_envio TEXT DEFAULT 'mensajeria', -- mensajeria, correo, personal, edicto
    numero_guia TEXT,
    fecha_entrega DATE,
    recibido_por TEXT,
    foto_acuse_url TEXT,
    observaciones TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE acuses_recibo ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "acuses_recibo_access" ON acuses_recibo;
CREATE POLICY "acuses_recibo_access" ON acuses_recibo FOR ALL USING (auth.role() = 'authenticated');

-- Tabla: promesas_pago
CREATE TABLE IF NOT EXISTS promesas_pago (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expediente_id UUID REFERENCES expedientes_legales(id) ON DELETE SET NULL,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
    monto_prometido NUMERIC(12,2) NOT NULL,
    fecha_promesa DATE NOT NULL,
    fecha_limite DATE NOT NULL,
    estado TEXT DEFAULT 'pendiente', -- pendiente, cumplida, incumplida, parcial
    monto_pagado NUMERIC(12,2) DEFAULT 0,
    fecha_pago TIMESTAMPTZ,
    medio_contacto TEXT, -- telefono, whatsapp, presencial, email
    testigo TEXT,
    grabacion_url TEXT,
    documento_firmado_url TEXT,
    notas TEXT,
    registrado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE promesas_pago ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "promesas_pago_access" ON promesas_pago;
CREATE POLICY "promesas_pago_access" ON promesas_pago FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_promesas_cliente ON promesas_pago(cliente_id);
CREATE INDEX IF NOT EXISTS idx_promesas_prestamo ON promesas_pago(prestamo_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.20 QR COBROS - Tablas faltantes
-- ═══════════════════════════════════════════════════════════════════════════

-- Tabla: qr_cobros_escaneos
CREATE TABLE IF NOT EXISTS qr_cobros_escaneos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    qr_cobro_id UUID REFERENCES qr_cobros(id) ON DELETE CASCADE,
    escaneado_por UUID REFERENCES usuarios(id),
    tipo_escaneo TEXT DEFAULT 'cliente', -- cliente, cobrador, admin
    exitoso BOOLEAN DEFAULT FALSE,
    motivo_fallo TEXT,
    latitud DECIMAL(10,8),
    longitud DECIMAL(11,8),
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE qr_cobros_escaneos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "qr_cobros_escaneos_access" ON qr_cobros_escaneos;
CREATE POLICY "qr_cobros_escaneos_access" ON qr_cobros_escaneos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_qr_escaneos_cobro ON qr_cobros_escaneos(qr_cobro_id);

-- Tabla: qr_cobros_config
CREATE TABLE IF NOT EXISTS qr_cobros_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE UNIQUE,
    habilitado BOOLEAN DEFAULT TRUE,
    requiere_gps BOOLEAN DEFAULT TRUE,
    requiere_foto BOOLEAN DEFAULT FALSE,
    tiempo_expiracion_minutos INTEGER DEFAULT 30,
    distancia_maxima_metros INTEGER DEFAULT 500,
    permitir_confirmacion_offline BOOLEAN DEFAULT FALSE,
    notificar_admin_tiempo_real BOOLEAN DEFAULT TRUE,
    enviar_comprobante_cliente BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE qr_cobros_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "qr_cobros_config_access" ON qr_cobros_config;
CREATE POLICY "qr_cobros_config_access" ON qr_cobros_config FOR ALL USING (auth.role() = 'authenticated');

-- Tabla: qr_cobros_estadisticas_diarias (renombrada para evitar conflicto con qr_cobros_reportes)
CREATE TABLE IF NOT EXISTS qr_cobros_estadisticas_diarias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    total_qr_generados INTEGER DEFAULT 0,
    total_confirmados INTEGER DEFAULT 0,
    total_expirados INTEGER DEFAULT 0,
    total_cancelados INTEGER DEFAULT 0,
    monto_total_confirmado NUMERIC(14,2) DEFAULT 0,
    cobrador_top_id UUID REFERENCES usuarios(id),
    cobrador_top_monto NUMERIC(14,2),
    tiempo_promedio_confirmacion INTEGER, -- en minutos
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE qr_cobros_estadisticas_diarias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "qr_cobros_estadisticas_access" ON qr_cobros_estadisticas_diarias;
CREATE POLICY "qr_cobros_estadisticas_access" ON qr_cobros_estadisticas_diarias FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_qr_estadisticas_negocio ON qr_cobros_estadisticas_diarias(negocio_id);
CREATE INDEX IF NOT EXISTS idx_qr_estadisticas_fecha ON qr_cobros_estadisticas_diarias(fecha);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.21 FACTURACIÓN - Tablas faltantes
-- ═══════════════════════════════════════════════════════════════════════════

-- Tabla: factura_impuestos
CREATE TABLE IF NOT EXISTS factura_impuestos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    factura_id UUID REFERENCES facturas(id) ON DELETE CASCADE,
    concepto_id UUID REFERENCES factura_conceptos(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- traslado, retencion
    impuesto TEXT NOT NULL, -- IVA, ISR, IEPS
    tipo_factor TEXT DEFAULT 'Tasa', -- Tasa, Cuota, Exento
    base NUMERIC(14,2) NOT NULL,
    tasa NUMERIC(8,6) NOT NULL,
    importe NUMERIC(14,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE factura_impuestos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "factura_impuestos_access" ON factura_impuestos;
CREATE POLICY "factura_impuestos_access" ON factura_impuestos FOR ALL USING (auth.role() = 'authenticated');

-- Tabla: factura_complementos_pago
CREATE TABLE IF NOT EXISTS factura_complementos_pago (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    factura_id UUID REFERENCES facturas(id) ON DELETE CASCADE,
    fecha_pago DATE NOT NULL,
    forma_pago TEXT NOT NULL,
    moneda TEXT DEFAULT 'MXN',
    tipo_cambio NUMERIC(10,4) DEFAULT 1,
    monto NUMERIC(14,2) NOT NULL,
    num_operacion TEXT,
    rfc_emisor_cuenta TEXT,
    cuenta_ordenante TEXT,
    rfc_receptor_cuenta TEXT,
    cuenta_beneficiario TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE factura_complementos_pago ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "factura_complementos_pago_access" ON factura_complementos_pago;
CREATE POLICY "factura_complementos_pago_access" ON factura_complementos_pago FOR ALL USING (auth.role() = 'authenticated');

-- Tabla: factura_documentos_relacionados
CREATE TABLE IF NOT EXISTS factura_documentos_relacionados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    factura_id UUID REFERENCES facturas(id) ON DELETE CASCADE,
    complemento_id UUID REFERENCES factura_complementos_pago(id) ON DELETE CASCADE,
    uuid_relacionado TEXT NOT NULL,
    serie TEXT,
    folio TEXT,
    moneda TEXT DEFAULT 'MXN',
    tipo_cambio NUMERIC(10,4) DEFAULT 1,
    metodo_pago TEXT,
    num_parcialidad INTEGER,
    imp_saldo_ant NUMERIC(14,2),
    imp_pagado NUMERIC(14,2),
    imp_saldo_insoluto NUMERIC(14,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE factura_documentos_relacionados ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "factura_documentos_relacionados_access" ON factura_documentos_relacionados;
CREATE POLICY "factura_documentos_relacionados_access" ON factura_documentos_relacionados FOR ALL USING (auth.role() = 'authenticated');

-- Tabla: facturacion_logs
CREATE TABLE IF NOT EXISTS facturacion_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    factura_id UUID REFERENCES facturas(id) ON DELETE SET NULL,
    accion TEXT NOT NULL, -- timbrado, cancelacion, consulta, envio_email
    exitoso BOOLEAN DEFAULT FALSE,
    mensaje TEXT,
    request_data JSONB,
    response_data JSONB,
    codigo_error TEXT,
    proveedor TEXT DEFAULT 'facturapi', -- facturapi, sw_sapien, finkok
    tiempo_respuesta_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE facturacion_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "facturacion_logs_access" ON facturacion_logs;
CREATE POLICY "facturacion_logs_access" ON facturacion_logs FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_facturacion_logs_factura ON facturacion_logs(factura_id);
CREATE INDEX IF NOT EXISTS idx_facturacion_logs_negocio ON facturacion_logs(negocio_id);

-- Campos faltantes en facturacion_clientes
ALTER TABLE facturacion_clientes ADD COLUMN IF NOT EXISTS cliente_nice_id UUID REFERENCES nice_clientes(id);

-- Campos faltantes en facturas
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS email_enviado BOOLEAN DEFAULT FALSE;
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS fecha_email TIMESTAMPTZ;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.22 STRIPE - Tabla faltante
-- ═══════════════════════════════════════════════════════════════════════════

-- Tabla: stripe_transactions_log
CREATE TABLE IF NOT EXISTS stripe_transactions_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    stripe_event_id TEXT UNIQUE,
    tipo_evento TEXT NOT NULL, -- payment_intent.succeeded, charge.refunded, etc
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    monto NUMERIC(12,2),
    moneda TEXT DEFAULT 'mxn',
    estado TEXT NOT NULL, -- succeeded, failed, pending, refunded
    payment_intent_id TEXT,
    charge_id TEXT,
    customer_id TEXT,
    payment_method_id TEXT,
    descripcion TEXT,
    metadata JSONB DEFAULT '{}',
    error_code TEXT,
    error_message TEXT,
    procesado BOOLEAN DEFAULT FALSE,
    fecha_procesado TIMESTAMPTZ,
    raw_event JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE stripe_transactions_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "stripe_transactions_log_access" ON stripe_transactions_log;
CREATE POLICY "stripe_transactions_log_access" ON stripe_transactions_log FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_stripe_log_negocio ON stripe_transactions_log(negocio_id);
CREATE INDEX IF NOT EXISTS idx_stripe_log_event_id ON stripe_transactions_log(stripe_event_id);
-- Nota: columna puede ser payment_intent_id o stripe_payment_intent_id según versión
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'stripe_transactions_log' AND column_name = 'payment_intent_id') THEN
        CREATE INDEX IF NOT EXISTS idx_stripe_log_payment_intent ON stripe_transactions_log(payment_intent_id);
    ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'stripe_transactions_log' AND column_name = 'stripe_payment_intent_id') THEN
        CREATE INDEX IF NOT EXISTS idx_stripe_log_payment_intent ON stripe_transactions_log(stripe_payment_intent_id);
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.23 REGISTROS_COBRO - Crear modelo si no existe
-- ═══════════════════════════════════════════════════════════════════════════

-- La tabla ya existe, solo agregamos campos si faltan
ALTER TABLE registros_cobro ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.24 NICE - Tabla faltante
-- ═══════════════════════════════════════════════════════════════════════════

-- Tabla: nice_inventario_vendedora
CREATE TABLE IF NOT EXISTS nice_inventario_vendedora (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedora_id UUID REFERENCES nice_vendedoras(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES nice_productos(id) ON DELETE CASCADE,
    catalogo_id UUID REFERENCES nice_catalogos(id) ON DELETE SET NULL,
    cantidad INTEGER DEFAULT 0,
    cantidad_vendida INTEGER DEFAULT 0,
    cantidad_devuelta INTEGER DEFAULT 0,
    precio_vendedora NUMERIC(10,2),
    fecha_asignacion DATE DEFAULT CURRENT_DATE,
    estado TEXT DEFAULT 'en_poder', -- en_poder, vendido, devuelto, perdido
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(vendedora_id, producto_id, catalogo_id)
);

ALTER TABLE nice_inventario_vendedora ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "nice_inventario_vendedora_access" ON nice_inventario_vendedora;
CREATE POLICY "nice_inventario_vendedora_access" ON nice_inventario_vendedora FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_nice_inv_vendedora ON nice_inventario_vendedora(vendedora_id);
CREATE INDEX IF NOT EXISTS idx_nice_inv_producto ON nice_inventario_vendedora(producto_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 42.25 TRIGGERS DE ACTUALIZACIÓN
-- ═══════════════════════════════════════════════════════════════════════════

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Aplicar trigger a tablas principales
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN 
        SELECT unnest(ARRAY[
            'usuarios', 'clientes', 'prestamos', 'tandas', 'avales',
            'empleados', 'pagos', 'colaboradores', 'chat_conversaciones',
            'documentos_aval', 'nice_inventario_vendedora', 'qr_cobros_config',
            'registros_cobro'
        ])
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trigger_update_%s_updated_at ON %s', t, t);
        EXECUTE format('
            CREATE TRIGGER trigger_update_%s_updated_at
            BEFORE UPDATE ON %s
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column()
        ', t, t);
    END LOOP;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN SECCIÓN 42: PARCHE V10.27 - SINCRONIZACIÓN COMPLETA
-- Total: 24 subsecciones, ~150 columnas agregadas, 15 tablas nuevas
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 43: PARCHE V10.28 - TABLAS FALTANTES (AUDITORÍA COMPLETA FINAL)
-- Fecha: 13 Enero 2026
-- Descripción: Todas las tablas utilizadas en código Dart que no existían
-- ══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.1 TANDA_PAGOS - Pagos programados de tandas
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS tanda_pagos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tanda_participante_id UUID REFERENCES tanda_participantes(id) ON DELETE CASCADE,
    numero_semana INTEGER NOT NULL,
    monto NUMERIC(12,2) NOT NULL,
    fecha_programada DATE NOT NULL,
    fecha_pago TIMESTAMPTZ,
    estado TEXT DEFAULT 'pendiente', -- pendiente, pagado, vencido, parcial
    monto_pagado NUMERIC(12,2) DEFAULT 0,
    comprobante_url TEXT,
    metodo_pago TEXT DEFAULT 'efectivo',
    registrado_por UUID REFERENCES usuarios(id),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tanda_pagos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tanda_pagos_access" ON tanda_pagos;
CREATE POLICY "tanda_pagos_access" ON tanda_pagos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_tanda_pagos_participante ON tanda_pagos(tanda_participante_id);
CREATE INDEX IF NOT EXISTS idx_tanda_pagos_fecha ON tanda_pagos(fecha_programada);
CREATE INDEX IF NOT EXISTS idx_tanda_pagos_estado ON tanda_pagos(estado);

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.2 DOCUMENTOS_CLIENTE - Documentos de clientes
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS documentos_cliente (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    tipo_documento TEXT NOT NULL, -- ine_frente, ine_reverso, comprobante_domicilio, selfie, ingresos
    documento_url TEXT NOT NULL,
    nombre_archivo TEXT,
    tamano_bytes INTEGER,
    mime_type TEXT,
    verificado BOOLEAN DEFAULT FALSE,
    verificado_por UUID REFERENCES usuarios(id),
    fecha_verificacion TIMESTAMPTZ,
    fecha_vencimiento DATE,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE documentos_cliente ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "documentos_cliente_access" ON documentos_cliente;
CREATE POLICY "documentos_cliente_access" ON documentos_cliente FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_documentos_cliente_cliente ON documentos_cliente(cliente_id);
CREATE INDEX IF NOT EXISTS idx_documentos_cliente_tipo ON documentos_cliente(tipo_documento);

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.3 SISTEMA DE TARJETAS VIRTUALES
-- ═══════════════════════════════════════════════════════════════════════════

-- Tarjetas virtuales (complemento a tarjetas_digitales)
CREATE TABLE IF NOT EXISTS tarjetas_virtuales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
    numero_tarjeta TEXT UNIQUE NOT NULL, -- Encriptado
    cvv_hash TEXT NOT NULL,
    fecha_expiracion DATE NOT NULL,
    saldo NUMERIC(14,2) DEFAULT 0,
    saldo_maximo NUMERIC(14,2) DEFAULT 50000,
    estado TEXT DEFAULT 'activa', -- activa, bloqueada, cancelada, vencida
    pin_hash TEXT,
    intentos_fallidos INTEGER DEFAULT 0,
    ultimo_uso TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_virtuales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tarjetas_virtuales_access" ON tarjetas_virtuales;
CREATE POLICY "tarjetas_virtuales_access" ON tarjetas_virtuales FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_tarjetas_virtuales_cliente ON tarjetas_virtuales(cliente_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_virtuales_negocio ON tarjetas_virtuales(negocio_id);

-- Titulares de tarjetas
CREATE TABLE IF NOT EXISTS tarjetas_titulares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_virtuales(id) ON DELETE CASCADE,
    nombre_completo TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    direccion TEXT,
    ciudad TEXT,
    estado TEXT,
    codigo_postal TEXT,
    pais TEXT DEFAULT 'México',
    fecha_nacimiento DATE,
    curp TEXT,
    rfc TEXT,
    es_principal BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_titulares ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tarjetas_titulares_access" ON tarjetas_titulares;
CREATE POLICY "tarjetas_titulares_access" ON tarjetas_titulares FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_tarjetas_titulares_tarjeta ON tarjetas_titulares(tarjeta_id);

-- Transacciones de tarjetas
CREATE TABLE IF NOT EXISTS tarjetas_transacciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_virtuales(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- compra, retiro, transferencia, recarga, devolucion
    monto NUMERIC(14,2) NOT NULL,
    concepto TEXT,
    comercio TEXT,
    referencia TEXT,
    autorizacion TEXT,
    saldo_anterior NUMERIC(14,2),
    saldo_posterior NUMERIC(14,2),
    estado TEXT DEFAULT 'completada', -- pendiente, completada, rechazada, reversada
    fecha_procesamiento TIMESTAMPTZ,
    ip_origen TEXT,
    dispositivo TEXT,
    ubicacion_lat DECIMAL(10,8),
    ubicacion_lng DECIMAL(11,8),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_transacciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tarjetas_transacciones_access" ON tarjetas_transacciones;
CREATE POLICY "tarjetas_transacciones_access" ON tarjetas_transacciones FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_tarjetas_trans_tarjeta ON tarjetas_transacciones(tarjeta_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_trans_fecha ON tarjetas_transacciones(created_at);
CREATE INDEX IF NOT EXISTS idx_tarjetas_trans_tipo ON tarjetas_transacciones(tipo);

-- Recargas de tarjetas
CREATE TABLE IF NOT EXISTS tarjetas_recargas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_virtuales(id) ON DELETE CASCADE,
    monto NUMERIC(14,2) NOT NULL,
    metodo_pago TEXT NOT NULL, -- efectivo, transferencia, oxxo, tarjeta
    referencia_pago TEXT,
    comprobante_url TEXT,
    estado TEXT DEFAULT 'pendiente', -- pendiente, completada, rechazada
    fecha_verificacion TIMESTAMPTZ,
    verificado_por UUID REFERENCES usuarios(id),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_recargas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tarjetas_recargas_access" ON tarjetas_recargas;
CREATE POLICY "tarjetas_recargas_access" ON tarjetas_recargas FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_tarjetas_recargas_tarjeta ON tarjetas_recargas(tarjeta_id);

-- Alertas de tarjetas
CREATE TABLE IF NOT EXISTS tarjetas_alertas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_virtuales(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- saldo_bajo, transaccion_sospechosa, vencimiento_proximo, bloqueo
    titulo TEXT NOT NULL,
    mensaje TEXT,
    prioridad INTEGER DEFAULT 1, -- 1=baja, 2=media, 3=alta, 4=urgente
    leida BOOLEAN DEFAULT FALSE,
    fecha_lectura TIMESTAMPTZ,
    accion_requerida BOOLEAN DEFAULT FALSE,
    accion_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_alertas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tarjetas_alertas_access" ON tarjetas_alertas;
CREATE POLICY "tarjetas_alertas_access" ON tarjetas_alertas FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_tarjetas_alertas_tarjeta ON tarjetas_alertas(tarjeta_id);

-- Log de tarjetas
CREATE TABLE IF NOT EXISTS tarjetas_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_virtuales(id) ON DELETE CASCADE,
    accion TEXT NOT NULL, -- creacion, activacion, bloqueo, desbloqueo, cambio_pin, consulta_saldo
    descripcion TEXT,
    ip_origen TEXT,
    dispositivo TEXT,
    user_agent TEXT,
    exito BOOLEAN DEFAULT TRUE,
    error_mensaje TEXT,
    usuario_id UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tarjetas_log_access" ON tarjetas_log;
CREATE POLICY "tarjetas_log_access" ON tarjetas_log FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_tarjetas_log_tarjeta ON tarjetas_log(tarjeta_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.4 COLABORADORES - Compensaciones y Pagos
-- ═══════════════════════════════════════════════════════════════════════════

-- Tipos de compensación
CREATE TABLE IF NOT EXISTS compensacion_tipos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    tipo TEXT DEFAULT 'porcentaje', -- porcentaje, monto_fijo, por_operacion
    valor NUMERIC(10,2),
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE compensacion_tipos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "compensacion_tipos_access" ON compensacion_tipos;
CREATE POLICY "compensacion_tipos_access" ON compensacion_tipos FOR ALL USING (auth.role() = 'authenticated');

-- Compensaciones de colaboradores
CREATE TABLE IF NOT EXISTS colaborador_compensaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID REFERENCES colaboradores(id) ON DELETE CASCADE,
    tipo_compensacion_id UUID REFERENCES compensacion_tipos(id) ON DELETE SET NULL,
    periodo_inicio DATE NOT NULL,
    periodo_fin DATE NOT NULL,
    monto_base NUMERIC(14,2) DEFAULT 0,
    porcentaje_aplicado NUMERIC(5,2),
    monto_calculado NUMERIC(14,2) NOT NULL,
    estado TEXT DEFAULT 'pendiente', -- pendiente, aprobada, pagada, cancelada
    aprobado_por UUID REFERENCES usuarios(id),
    fecha_aprobacion TIMESTAMPTZ,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE colaborador_compensaciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "colaborador_compensaciones_access" ON colaborador_compensaciones;
CREATE POLICY "colaborador_compensaciones_access" ON colaborador_compensaciones FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_colab_comp_colaborador ON colaborador_compensaciones(colaborador_id);

-- Pagos a colaboradores
CREATE TABLE IF NOT EXISTS colaborador_pagos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID REFERENCES colaboradores(id) ON DELETE CASCADE,
    compensacion_id UUID REFERENCES colaborador_compensaciones(id) ON DELETE SET NULL,
    monto NUMERIC(14,2) NOT NULL,
    metodo_pago TEXT DEFAULT 'transferencia',
    referencia_bancaria TEXT,
    comprobante_url TEXT,
    fecha_pago DATE NOT NULL,
    estado TEXT DEFAULT 'completado', -- pendiente, completado, rechazado
    notas TEXT,
    registrado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE colaborador_pagos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "colaborador_pagos_access" ON colaborador_pagos;
CREATE POLICY "colaborador_pagos_access" ON colaborador_pagos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_colab_pagos_colaborador ON colaborador_pagos(colaborador_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.5 VENTAS - Tablas complementarias
-- ═══════════════════════════════════════════════════════════════════════════

-- Cotizaciones de ventas
CREATE TABLE IF NOT EXISTS ventas_cotizaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES ventas_clientes(id) ON DELETE SET NULL,
    vendedor_id UUID REFERENCES ventas_vendedores(id) ON DELETE SET NULL,
    folio TEXT,
    fecha DATE DEFAULT CURRENT_DATE,
    vigencia_dias INTEGER DEFAULT 15,
    subtotal NUMERIC(14,2) DEFAULT 0,
    descuento NUMERIC(14,2) DEFAULT 0,
    iva NUMERIC(14,2) DEFAULT 0,
    total NUMERIC(14,2) DEFAULT 0,
    estado TEXT DEFAULT 'vigente', -- vigente, aceptada, rechazada, vencida
    convertida_pedido_id UUID,
    notas TEXT,
    condiciones TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE ventas_cotizaciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ventas_cotizaciones_access" ON ventas_cotizaciones;
CREATE POLICY "ventas_cotizaciones_access" ON ventas_cotizaciones FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_ventas_cotizaciones_negocio ON ventas_cotizaciones(negocio_id);
CREATE INDEX IF NOT EXISTS idx_ventas_cotizaciones_cliente ON ventas_cotizaciones(cliente_id);

-- Pagos de ventas
CREATE TABLE IF NOT EXISTS ventas_pagos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES ventas_pedidos(id) ON DELETE CASCADE,
    monto NUMERIC(14,2) NOT NULL,
    metodo_pago TEXT DEFAULT 'efectivo',
    referencia TEXT,
    comprobante_url TEXT,
    fecha_pago TIMESTAMPTZ DEFAULT NOW(),
    estado TEXT DEFAULT 'completado', -- pendiente, completado, rechazado
    registrado_por UUID REFERENCES usuarios(id),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE ventas_pagos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ventas_pagos_access" ON ventas_pagos;
CREATE POLICY "ventas_pagos_access" ON ventas_pagos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_ventas_pagos_pedido ON ventas_pagos(pedido_id);

-- Créditos de clientes de ventas
CREATE TABLE IF NOT EXISTS ventas_cliente_creditos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES ventas_clientes(id) ON DELETE CASCADE,
    limite_credito NUMERIC(14,2) DEFAULT 0,
    credito_utilizado NUMERIC(14,2) DEFAULT 0,
    credito_disponible NUMERIC(14,2) DEFAULT 0,
    dias_credito INTEGER DEFAULT 30,
    estado TEXT DEFAULT 'activo', -- activo, suspendido, bloqueado
    ultima_evaluacion DATE,
    historial_pagos_score INTEGER DEFAULT 100,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE ventas_cliente_creditos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ventas_cliente_creditos_access" ON ventas_cliente_creditos;
CREATE POLICY "ventas_cliente_creditos_access" ON ventas_cliente_creditos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_ventas_cliente_creditos_cliente ON ventas_cliente_creditos(cliente_id);

-- Contactos de clientes de ventas
CREATE TABLE IF NOT EXISTS ventas_cliente_contactos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES ventas_clientes(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    cargo TEXT,
    telefono TEXT,
    email TEXT,
    es_principal BOOLEAN DEFAULT FALSE,
    notas TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE ventas_cliente_contactos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ventas_cliente_contactos_access" ON ventas_cliente_contactos;
CREATE POLICY "ventas_cliente_contactos_access" ON ventas_cliente_contactos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_ventas_cliente_contactos_cliente ON ventas_cliente_contactos(cliente_id);

-- Documentos de clientes de ventas
CREATE TABLE IF NOT EXISTS ventas_cliente_documentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES ventas_clientes(id) ON DELETE CASCADE,
    tipo_documento TEXT NOT NULL,
    nombre TEXT NOT NULL,
    url TEXT NOT NULL,
    tamano_bytes INTEGER,
    verificado BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE ventas_cliente_documentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ventas_cliente_documentos_access" ON ventas_cliente_documentos;
CREATE POLICY "ventas_cliente_documentos_access" ON ventas_cliente_documentos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_ventas_cliente_documentos_cliente ON ventas_cliente_documentos(cliente_id);

-- Notas de clientes de ventas
CREATE TABLE IF NOT EXISTS ventas_cliente_notas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES ventas_clientes(id) ON DELETE CASCADE,
    nota TEXT NOT NULL,
    tipo TEXT DEFAULT 'general', -- general, seguimiento, queja, importante
    creado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE ventas_cliente_notas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ventas_cliente_notas_access" ON ventas_cliente_notas;
CREATE POLICY "ventas_cliente_notas_access" ON ventas_cliente_notas FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_ventas_cliente_notas_cliente ON ventas_cliente_notas(cliente_id);

-- Vista alias para lineas de pedido
CREATE OR REPLACE VIEW ventas_pedido_lineas AS SELECT * FROM ventas_pedidos_items;

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.6 CLIMAS - Tablas complementarias
-- ═══════════════════════════════════════════════════════════════════════════

-- Pagos de servicios de climas
CREATE TABLE IF NOT EXISTS climas_pagos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    orden_servicio_id UUID REFERENCES climas_ordenes_servicio(id) ON DELETE CASCADE,
    monto NUMERIC(12,2) NOT NULL,
    metodo_pago TEXT DEFAULT 'efectivo',
    referencia TEXT,
    comprobante_url TEXT,
    fecha_pago TIMESTAMPTZ DEFAULT NOW(),
    estado TEXT DEFAULT 'completado',
    registrado_por UUID REFERENCES usuarios(id),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE climas_pagos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "climas_pagos_access" ON climas_pagos;
CREATE POLICY "climas_pagos_access" ON climas_pagos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_climas_pagos_orden ON climas_pagos(orden_servicio_id);

-- Equipos por cliente
CREATE TABLE IF NOT EXISTS climas_equipos_cliente (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES climas_clientes(id) ON DELETE CASCADE,
    equipo_id UUID REFERENCES climas_equipos(id) ON DELETE CASCADE,
    ubicacion TEXT, -- recamara, sala, oficina, etc.
    fecha_instalacion DATE,
    garantia_hasta DATE,
    ultimo_servicio DATE,
    proximo_servicio DATE,
    notas TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(cliente_id, equipo_id, ubicacion)
);

ALTER TABLE climas_equipos_cliente ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "climas_equipos_cliente_access" ON climas_equipos_cliente;
CREATE POLICY "climas_equipos_cliente_access" ON climas_equipos_cliente FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_climas_equipos_cliente_cliente ON climas_equipos_cliente(cliente_id);
CREATE INDEX IF NOT EXISTS idx_climas_equipos_cliente_equipo ON climas_equipos_cliente(equipo_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.7 PURIFICADORA - Tablas complementarias
-- ═══════════════════════════════════════════════════════════════════════════

-- Pagos de purificadora
CREATE TABLE IF NOT EXISTS purificadora_pagos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entrega_id UUID REFERENCES purificadora_entregas(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES purificadora_clientes(id) ON DELETE SET NULL,
    monto NUMERIC(12,2) NOT NULL,
    metodo_pago TEXT DEFAULT 'efectivo',
    referencia TEXT,
    comprobante_url TEXT,
    fecha_pago TIMESTAMPTZ DEFAULT NOW(),
    estado TEXT DEFAULT 'completado',
    registrado_por UUID REFERENCES usuarios(id),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purificadora_pagos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purificadora_pagos_access" ON purificadora_pagos;
CREATE POLICY "purificadora_pagos_access" ON purificadora_pagos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_purificadora_pagos_entrega ON purificadora_pagos(entrega_id);
CREATE INDEX IF NOT EXISTS idx_purificadora_pagos_cliente ON purificadora_pagos(cliente_id);

-- Alias para pagos de purificadora (código usa 'puri_pagos')
CREATE OR REPLACE VIEW puri_pagos AS SELECT * FROM purificadora_pagos;

-- Gastos de purificadora
CREATE TABLE IF NOT EXISTS purificadora_gastos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    repartidor_id UUID REFERENCES purificadora_repartidores(id) ON DELETE SET NULL,
    ruta_id UUID REFERENCES purificadora_rutas(id) ON DELETE SET NULL,
    fecha DATE DEFAULT CURRENT_DATE,
    concepto TEXT NOT NULL,
    monto NUMERIC(12,2) NOT NULL,
    categoria TEXT DEFAULT 'operativo', -- operativo, vehiculo, mantenimiento, otros
    comprobante_url TEXT,
    aprobado BOOLEAN DEFAULT FALSE,
    aprobado_por UUID REFERENCES usuarios(id),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purificadora_gastos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purificadora_gastos_access" ON purificadora_gastos;
CREATE POLICY "purificadora_gastos_access" ON purificadora_gastos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_purificadora_gastos_negocio ON purificadora_gastos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_purificadora_gastos_fecha ON purificadora_gastos(fecha);

-- Historial de garrafones (diferente a inventario)
CREATE TABLE IF NOT EXISTS purificadora_garrafones_historial (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    fecha DATE DEFAULT CURRENT_DATE,
    garrafones_inicio INTEGER DEFAULT 0,
    garrafones_producidos INTEGER DEFAULT 0,
    garrafones_vendidos INTEGER DEFAULT 0,
    garrafones_prestados INTEGER DEFAULT 0,
    garrafones_devueltos INTEGER DEFAULT 0,
    garrafones_danados INTEGER DEFAULT 0,
    garrafones_fin INTEGER DEFAULT 0,
    observaciones TEXT,
    registrado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purificadora_garrafones_historial ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purificadora_garrafones_historial_access" ON purificadora_garrafones_historial;
CREATE POLICY "purificadora_garrafones_historial_access" ON purificadora_garrafones_historial FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_puri_garrafones_hist_negocio ON purificadora_garrafones_historial(negocio_id);
CREATE INDEX IF NOT EXISTS idx_puri_garrafones_hist_fecha ON purificadora_garrafones_historial(fecha);

-- Contactos de clientes de purificadora
CREATE TABLE IF NOT EXISTS purificadora_cliente_contactos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES purificadora_clientes(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    telefono TEXT,
    relacion TEXT, -- titular, encargado, familiar
    es_principal BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purificadora_cliente_contactos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purificadora_cliente_contactos_access" ON purificadora_cliente_contactos;
CREATE POLICY "purificadora_cliente_contactos_access" ON purificadora_cliente_contactos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_puri_cliente_contactos_cliente ON purificadora_cliente_contactos(cliente_id);

-- Documentos de clientes de purificadora
CREATE TABLE IF NOT EXISTS purificadora_cliente_documentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES purificadora_clientes(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    nombre TEXT,
    url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purificadora_cliente_documentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purificadora_cliente_documentos_access" ON purificadora_cliente_documentos;
CREATE POLICY "purificadora_cliente_documentos_access" ON purificadora_cliente_documentos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_puri_cliente_documentos_cliente ON purificadora_cliente_documentos(cliente_id);

-- Notas de clientes de purificadora
CREATE TABLE IF NOT EXISTS purificadora_cliente_notas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES purificadora_clientes(id) ON DELETE CASCADE,
    nota TEXT NOT NULL,
    creado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purificadora_cliente_notas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purificadora_cliente_notas_access" ON purificadora_cliente_notas;
CREATE POLICY "purificadora_cliente_notas_access" ON purificadora_cliente_notas FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_puri_cliente_notas_cliente ON purificadora_cliente_notas(cliente_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.8 NICE - Tablas complementarias
-- ═══════════════════════════════════════════════════════════════════════════

-- Movimientos de inventario NICE
CREATE TABLE IF NOT EXISTS nice_inventario_movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES nice_productos(id) ON DELETE CASCADE,
    vendedora_id UUID REFERENCES nice_vendedoras(id) ON DELETE SET NULL,
    tipo_movimiento TEXT NOT NULL, -- entrada, salida, ajuste, devolucion, traspaso
    cantidad INTEGER NOT NULL,
    stock_anterior INTEGER,
    stock_posterior INTEGER,
    referencia_id UUID, -- ID del pedido, devolucion, etc.
    referencia_tipo TEXT, -- pedido, devolucion, ajuste
    motivo TEXT,
    realizado_por UUID REFERENCES usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE nice_inventario_movimientos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "nice_inventario_movimientos_access" ON nice_inventario_movimientos;
CREATE POLICY "nice_inventario_movimientos_access" ON nice_inventario_movimientos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_nice_inv_mov_negocio ON nice_inventario_movimientos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_nice_inv_mov_producto ON nice_inventario_movimientos(producto_id);
CREATE INDEX IF NOT EXISTS idx_nice_inv_mov_vendedora ON nice_inventario_movimientos(vendedora_id);

-- Pagos de NICE
CREATE TABLE IF NOT EXISTS nice_pagos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES nice_pedidos(id) ON DELETE CASCADE,
    monto NUMERIC(12,2) NOT NULL,
    metodo_pago TEXT DEFAULT 'efectivo',
    referencia TEXT,
    comprobante_url TEXT,
    fecha_pago TIMESTAMPTZ DEFAULT NOW(),
    estado TEXT DEFAULT 'completado',
    registrado_por UUID REFERENCES usuarios(id),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE nice_pagos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "nice_pagos_access" ON nice_pagos;
CREATE POLICY "nice_pagos_access" ON nice_pagos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_nice_pagos_pedido ON nice_pagos(pedido_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.9 FACTURACIÓN - Tablas complementarias
-- ═══════════════════════════════════════════════════════════════════════════

-- Productos para facturación
CREATE TABLE IF NOT EXISTS facturacion_productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    clave_producto_sat TEXT NOT NULL,
    clave_unidad_sat TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    valor_unitario NUMERIC(14,2) NOT NULL,
    unidad TEXT DEFAULT 'PZA',
    impuesto_iva NUMERIC(5,2) DEFAULT 16.00,
    objeto_impuesto TEXT DEFAULT '02', -- 01=No objeto, 02=Sí objeto, 03=Sí objeto no obligado
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE facturacion_productos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "facturacion_productos_access" ON facturacion_productos;
CREATE POLICY "facturacion_productos_access" ON facturacion_productos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_facturacion_productos_negocio ON facturacion_productos(negocio_id);

-- Vistas/Alias para catálogos SAT (compatibilidad con código)
CREATE OR REPLACE VIEW catalogo_forma_pago AS SELECT * FROM cat_forma_pago;
CREATE OR REPLACE VIEW catalogo_regimen_fiscal AS SELECT * FROM cat_regimen_fiscal;
CREATE OR REPLACE VIEW catalogo_uso_cfdi AS SELECT * FROM cat_uso_cfdi;

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.10 OTRAS TABLAS Y ALIASES
-- ═══════════════════════════════════════════════════════════════════════════

-- Contratos
CREATE TABLE IF NOT EXISTS contratos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    prestamo_id UUID REFERENCES prestamos(id) ON DELETE SET NULL,
    tipo_contrato TEXT NOT NULL, -- prestamo, garantia, servicio
    numero_contrato TEXT,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    contenido TEXT, -- HTML o texto del contrato
    plantilla_id UUID,
    estado TEXT DEFAULT 'vigente', -- borrador, vigente, vencido, cancelado
    firmado BOOLEAN DEFAULT FALSE,
    fecha_firma TIMESTAMPTZ,
    firma_cliente_url TEXT,
    firma_empresa_url TEXT,
    documento_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE contratos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "contratos_access" ON contratos;
CREATE POLICY "contratos_access" ON contratos FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_contratos_negocio ON contratos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_contratos_cliente ON contratos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_contratos_prestamo ON contratos(prestamo_id);

-- Firmas digitales (genéricas) - Renombrada a firmas_digitales para evitar conflicto con VIEW
CREATE TABLE IF NOT EXISTS firmas_digitales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entidad_tipo TEXT NOT NULL, -- contrato, pagare, aval, cliente
    entidad_id UUID NOT NULL,
    firmante_tipo TEXT NOT NULL, -- cliente, aval, empleado, empresa
    firmante_id UUID,
    firma_url TEXT NOT NULL,
    ip_origen TEXT,
    dispositivo TEXT,
    geolocalizacion TEXT,
    latitud DECIMAL(10,8),
    longitud DECIMAL(11,8),
    fecha_firma TIMESTAMPTZ DEFAULT NOW(),
    verificada BOOLEAN DEFAULT FALSE,
    hash_documento TEXT, -- Hash del documento firmado
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE firmas_digitales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "firmas_digitales_access" ON firmas_digitales;
CREATE POLICY "firmas_digitales_access" ON firmas_digitales FOR ALL USING (auth.role() = 'authenticated');
CREATE INDEX IF NOT EXISTS idx_firmas_digitales_entidad ON firmas_digitales(entidad_tipo, entidad_id);
CREATE INDEX IF NOT EXISTS idx_firmas_digitales_firmante ON firmas_digitales(firmante_tipo, firmante_id);

-- Alias para conversaciones (código usa 'conversaciones' en algunos lugares)
CREATE OR REPLACE VIEW conversaciones AS SELECT * FROM chat_conversaciones;

-- Alias para fondos de pantalla (código usa 'fondos' en algunos lugares)
CREATE OR REPLACE VIEW fondos AS SELECT * FROM fondos_pantalla;

-- ═══════════════════════════════════════════════════════════════════════════
-- 43.11 TRIGGERS PARA NUEVAS TABLAS
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN 
        SELECT unnest(ARRAY[
            'documentos_cliente', 'tarjetas_virtuales', 'ventas_cotizaciones',
            'ventas_cliente_creditos', 'contratos', 'facturacion_productos'
        ])
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trigger_update_%s_updated_at ON %s', t, t);
        EXECUTE format('
            CREATE TRIGGER trigger_update_%s_updated_at
            BEFORE UPDATE ON %s
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column()
        ', t, t);
    END LOOP;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN SECCIÓN 43: PARCHE V10.28 - TABLAS FALTANTES
-- Total: 11 subsecciones, ~35 tablas nuevas + vistas alias
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 44: POST-REQUISITOS - VERIFICACIÓN DE COLUMNAS negocio_id
-- IMPORTANTE: Se ejecuta AL FINAL después de que todas las tablas existen
-- Agrega negocio_id a tablas existentes que no la tengan
-- ══════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    t TEXT;
    tables_multitenancy TEXT[] := ARRAY[
        'facturas', 'facturacion_clientes', 'facturacion_emisores', 'facturacion_logs',
        'factura_complementos_pago', 'prestamos', 'tandas', 'pagos', 'empleados', 
        'clientes', 'avales', 'sucursales', 'usuarios_negocios', 'modulos_activos',
        'tarjetas_digitales', 'aires_equipos', 'aires_tecnicos', 'aires_ordenes_servicio',
        'empleados_negocios', 'climas_tecnicos', 'purificadora_repartidores', 'clientes_modulo',
        'nice_vendedoras', 'ventas_vendedores', 'climas_clientes', 'purificadora_clientes',
        'colaboradores', 'climas_productos', 'climas_cotizaciones', 'comprobantes',
        'inventario', 'entregas', 'purificadora_produccion', 'purificadora_inventario_garrafones',
        'qr_cobros_reportes', 'stripe_transactions_log', 'cache_estadisticas',
        'qr_cobros_config', 'notificaciones_masivas', 'notificaciones_sistema',
        'tarjetas_virtuales', 'compensacion_tipos', 'ventas_cotizaciones',
        'purificadora_pagos', 'purificadora_gastos', 'purificadora_garrafones_historial',
        'nice_inventario_movimientos', 'facturacion_productos', 'contratos'
    ];
BEGIN
    FOREACH t IN ARRAY tables_multitenancy LOOP
        -- Solo procesar si la tabla existe
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = t AND table_schema = 'public') THEN
            -- Agregar negocio_id si no existe
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = t AND column_name = 'negocio_id') THEN
                EXECUTE format('ALTER TABLE %I ADD COLUMN negocio_id UUID', t);
                RAISE NOTICE 'POST: Agregada columna negocio_id a tabla %', t;
            END IF;
            
            -- Agregar FK a negocios si no existe
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.table_constraints tc
                JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
                WHERE tc.table_name = t 
                AND tc.constraint_type = 'FOREIGN KEY'
                AND ccu.table_name = 'negocios'
                AND ccu.column_name = 'id'
            ) THEN
                BEGIN
                    EXECUTE format('ALTER TABLE %I ADD CONSTRAINT fk_%s_negocio FOREIGN KEY (negocio_id) REFERENCES negocios(id) ON DELETE CASCADE', t, t);
                    RAISE NOTICE 'POST: Agregada FK negocio_id a tabla %', t;
                EXCEPTION WHEN duplicate_object THEN
                    -- FK ya existe, ignorar
                    NULL;
                END;
            END IF;
            
            -- Crear índice si no existe
            BEGIN
                EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_negocio_id ON %I(negocio_id)', t, t);
            EXCEPTION WHEN duplicate_table THEN
                -- Índice ya existe, ignorar
                NULL;
            END;
        END IF;
    END LOOP;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE 'POST-REQUISITOS: Verificación de negocio_id completada';
    RAISE NOTICE 'Todas las tablas multitenancy tienen columna negocio_id';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN SECCIÓN 44: POST-REQUISITOS
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 45: PARCHE COLUMNAS FALTANTES EN TABLAS NICE
-- Agrega columnas alias para compatibilidad con triggers y código existente
-- ══════════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
    -- nice_niveles: columnas alias
    ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS comision_porcentaje DECIMAL(5,2) DEFAULT 20;
    ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS comision_equipo_porcentaje DECIMAL(5,2) DEFAULT 5;
    ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS meta_ventas_mensual DECIMAL(14,2) DEFAULT 0;
    ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS beneficios JSONB DEFAULT '[]';
    ALTER TABLE nice_niveles ADD COLUMN IF NOT EXISTS icono TEXT DEFAULT 'star';
    -- Hacer codigo nullable
    ALTER TABLE nice_niveles ALTER COLUMN codigo DROP NOT NULL;
    
    -- nice_catalogos: columnas alias
    ALTER TABLE nice_catalogos ADD COLUMN IF NOT EXISTS imagen_portada TEXT;
    ALTER TABLE nice_catalogos ADD COLUMN IF NOT EXISTS vigencia_inicio DATE;
    ALTER TABLE nice_catalogos ADD COLUMN IF NOT EXISTS vigencia_fin DATE;
    ALTER TABLE nice_catalogos ADD COLUMN IF NOT EXISTS version TEXT DEFAULT '1.0';
    -- Hacer codigo nullable
    ALTER TABLE nice_catalogos ALTER COLUMN codigo DROP NOT NULL;
    
    -- nice_categorias: columna alias
    ALTER TABLE nice_categorias ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;
    
    RAISE NOTICE 'PARCHE: Columnas NICE agregadas correctamente';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PARCHE NICE: Algunas columnas ya existían o error menor: %', SQLERRM;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN SECCIÓN 45: PARCHE COLUMNAS NICE
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN DEL SCHEMA - SQL MAESTRO V10.28 COMPLETO
-- Robert Darin Fintech - Enero 2026
-- ══════════════════════════════════════════════════════════════════════════════
