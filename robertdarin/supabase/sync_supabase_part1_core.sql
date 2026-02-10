-- ══════════════════════════════════════════════════════════════════════════════
-- SINCRONIZACIÓN COMPLETA SUPABASE CLOUD
-- Robert Darin Fintech V10.30
-- Fecha: 19 Enero 2026
--
-- INSTRUCCIONES:
-- 1. Ve a Supabase Dashboard → SQL Editor
-- 2. Copia SOLO la sección que necesitas ejecutar
-- 3. Ejecuta y verifica el resultado
--
-- Este script está dividido en partes para evitar timeouts
-- ══════════════════════════════════════════════════════════════════════════════

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 1: EXTENSIONES Y FUNCIONES BASE (Ejecutar primero)
-- ██████████████████████████████████████████████████████████████████████████████

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION actualizar_updated_at() 
RETURNS TRIGGER AS $$
BEGIN 
  NEW.updated_at = NOW(); 
  RETURN NEW; 
END; 
$$ LANGUAGE plpgsql;

-- Función helper: verificar si usuario tiene rol
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

-- Función helper: verificar si es admin o superior
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

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 2: TABLAS CORE (Identidad, Negocios, Usuarios)
-- ██████████████████████████████████████████████████████████████████████████████

-- ROLES
CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT UNIQUE NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- PERMISOS
CREATE TABLE IF NOT EXISTS permisos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clave_permiso TEXT UNIQUE NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ROLES_PERMISOS
CREATE TABLE IF NOT EXISTS roles_permisos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rol_id UUID REFERENCES roles(id) ON DELETE CASCADE,
  permiso_id UUID REFERENCES permisos(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(rol_id, permiso_id)
);

-- USUARIOS
CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY, 
  email TEXT UNIQUE NOT NULL,
  nombre_completo TEXT,
  telefono TEXT,
  foto_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- USUARIOS_ROLES
CREATE TABLE IF NOT EXISTS usuarios_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  rol_id UUID REFERENCES roles(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(usuario_id, rol_id)
);

-- NEGOCIOS
CREATE TABLE IF NOT EXISTS negocios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    tipo TEXT DEFAULT 'fintech',
    propietario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
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

-- USUARIOS_NEGOCIOS
CREATE TABLE IF NOT EXISTS usuarios_negocios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    rol_negocio TEXT DEFAULT 'admin',
    permisos JSONB DEFAULT '{}',
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(usuario_id, negocio_id)
);

-- SUCURSALES
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

-- EMPLEADOS
CREATE TABLE IF NOT EXISTS empleados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  puesto TEXT,
  salario NUMERIC(12,2),
  comision_porcentaje NUMERIC(5,2) DEFAULT 0,
  comision_tipo TEXT DEFAULT 'ninguna',
  fecha_contratacion DATE DEFAULT CURRENT_DATE,
  activo BOOLEAN DEFAULT TRUE,
  estado TEXT DEFAULT 'activo',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 3: TABLAS DE CLIENTES Y PRÉSTAMOS
-- ██████████████████████████████████████████████████████████████████████████████

-- CLIENTES
CREATE TABLE IF NOT EXISTS clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
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

-- PRESTAMOS
CREATE TABLE IF NOT EXISTS prestamos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
  aval_id UUID,
  monto NUMERIC(12,2) NOT NULL,
  interes NUMERIC(5,2) DEFAULT 0,
  plazo_meses INTEGER NOT NULL,
  frecuencia_pago TEXT DEFAULT 'Mensual',
  tipo_prestamo TEXT DEFAULT 'normal',
  interes_diario NUMERIC(8,4) DEFAULT 0,
  capital_al_final BOOLEAN DEFAULT FALSE,
  variante_arquilado TEXT DEFAULT 'clasico',
  estado TEXT DEFAULT 'activo',
  proposito TEXT,
  garantia TEXT,
  aprobado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  fecha_aprobacion TIMESTAMP,
  fecha_primer_pago DATE,
  fecha_creacion TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- AMORTIZACIONES
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
  estado TEXT DEFAULT 'pendiente',
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(prestamo_id, numero_cuota)
);

-- PAGOS
CREATE TABLE IF NOT EXISTS pagos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  prestamo_id UUID REFERENCES prestamos(id) ON DELETE CASCADE,
  tanda_id UUID,
  amortizacion_id UUID REFERENCES amortizaciones(id) ON DELETE SET NULL,
  cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
  monto NUMERIC(12,2) NOT NULL,
  metodo_pago TEXT DEFAULT 'efectivo',
  fecha_pago TIMESTAMP DEFAULT NOW(),
  nota TEXT,
  comprobante_url TEXT,
  recibo_oficial_url TEXT,
  latitud DOUBLE PRECISION,
  longitud DOUBLE PRECISION,
  registrado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 4: TABLAS DE TANDAS Y AVALES
-- ██████████████████████████████████████████████████████████████████████████████

-- TANDAS
CREATE TABLE IF NOT EXISTS tandas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  sucursal_id UUID REFERENCES sucursales(id) ON DELETE SET NULL,
  nombre TEXT NOT NULL,
  monto_por_persona NUMERIC(12,2) NOT NULL,
  numero_participantes INTEGER NOT NULL,
  turno INTEGER DEFAULT 1,
  frecuencia TEXT DEFAULT 'Semanal',
  estado TEXT DEFAULT 'activa',
  fecha_inicio TIMESTAMP DEFAULT NOW(),
  fecha_fin TIMESTAMP,
  organizador_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- TANDA_PARTICIPANTES
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

-- AVALES
CREATE TABLE IF NOT EXISTS avales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  prestamo_id UUID,
  tanda_id UUID,
  cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  nombre TEXT NOT NULL,
  email TEXT,
  telefono TEXT,
  direccion TEXT,
  identificacion TEXT,
  relacion TEXT,
  verificado BOOLEAN DEFAULT FALSE,
  ubicacion_consentida BOOLEAN DEFAULT FALSE,
  fecha_consentimiento_ubicacion TIMESTAMP,
  ultima_latitud DECIMAL(10, 8),
  ultima_longitud DECIMAL(11, 8),
  ultimo_checkin TIMESTAMP,
  firma_digital_url TEXT,
  fecha_firma TIMESTAMP,
  ine_url TEXT,
  ine_reverso_url TEXT,
  domicilio_url TEXT,
  selfie_url TEXT,
  ingresos_url TEXT,
  fcm_token TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- PRESTAMOS_AVALES
CREATE TABLE IF NOT EXISTS prestamos_avales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestamo_id UUID NOT NULL REFERENCES prestamos(id) ON DELETE CASCADE,
    aval_id UUID NOT NULL REFERENCES avales(id) ON DELETE CASCADE,
    orden INT DEFAULT 1,
    tipo VARCHAR(50) DEFAULT 'garante',
    porcentaje_responsabilidad DECIMAL(5,2) DEFAULT 100.00,
    firma_digital TEXT,
    firmado_at TIMESTAMPTZ,
    estado VARCHAR(20) DEFAULT 'pendiente',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(prestamo_id, aval_id)
);

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 5: TABLAS DE NOTIFICACIONES Y CHAT
-- ██████████████████████████████████████████████████████████████████████████████

-- NOTIFICACIONES
CREATE TABLE IF NOT EXISTS notificaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  tipo TEXT DEFAULT 'info',
  prioridad TEXT DEFAULT 'normal',
  icono TEXT,
  leida BOOLEAN DEFAULT FALSE,
  fecha_lectura TIMESTAMP,
  enlace TEXT,
  ruta_destino VARCHAR(100),
  notificacion_masiva_id UUID,
  referencia_id UUID,
  referencia_tipo TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- CHAT_CONVERSACIONES
CREATE TABLE IF NOT EXISTS chat_conversaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_conversacion TEXT NOT NULL,
  tipo TEXT,
  titulo TEXT,
  cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
  aval_id UUID,
  prestamo_id UUID,
  tanda_id UUID,
  referencia_id UUID,
  referencia_tipo TEXT,
  creado_por_usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  estado TEXT DEFAULT 'activo',
  ultimo_mensaje TEXT,
  fecha_ultimo_mensaje TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- CHAT_MENSAJES
CREATE TABLE IF NOT EXISTS chat_mensajes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversacion_id UUID REFERENCES chat_conversaciones(id) ON DELETE CASCADE,
  remitente_usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  tipo_mensaje TEXT DEFAULT 'texto',
  contenido_texto TEXT,
  archivo_url TEXT,
  latitud DOUBLE PRECISION,
  longitud DOUBLE PRECISION,
  hash_contenido TEXT,
  es_sistema BOOLEAN DEFAULT FALSE,
  leido BOOLEAN DEFAULT FALSE,
  fecha_lectura TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- CALENDARIO
CREATE TABLE IF NOT EXISTS calendario (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo TEXT NOT NULL,
  descripcion TEXT,
  fecha TIMESTAMP NOT NULL,
  fecha_fin TIMESTAMP,
  tipo TEXT,
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
  prestamo_id UUID,
  completado BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 6: TABLAS DE CONFIGURACIÓN
-- ██████████████████████████████████████████████████████████████████████████████

-- CONFIGURACION_GLOBAL
CREATE TABLE IF NOT EXISTS configuracion_global (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_app VARCHAR(100) DEFAULT 'Uniko',
    version VARCHAR(20) DEFAULT '1.0.0',
    modo_mantenimiento BOOLEAN DEFAULT false,
    max_avales_prestamo INT DEFAULT 3,
    max_avales_tanda INT DEFAULT 2,
    monto_min_prestamo DECIMAL(15,2) DEFAULT 1000,
    monto_max_prestamo DECIMAL(15,2) DEFAULT 500000,
    interes_default DECIMAL(5,2) DEFAULT 10.00,
    email_soporte VARCHAR(100) DEFAULT 'soporte@robertdarin.com',
    telefono_soporte VARCHAR(20) DEFAULT '+52 555 123 4567',
    whatsapp VARCHAR(20) DEFAULT '+52 555 123 4567',
    color_acento VARCHAR(10) DEFAULT '#00BCD4',
    color_botones VARCHAR(10) DEFAULT '#4CAF50',
    color_alertas VARCHAR(10) DEFAULT '#FF5722',
    fondos_inteligentes BOOLEAN DEFAULT false,
    fondos_por_rol BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insertar configuración inicial
INSERT INTO configuracion_global (id) 
SELECT gen_random_uuid() 
WHERE NOT EXISTS (SELECT 1 FROM configuracion_global);

-- TEMAS_APP
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

-- PREFERENCIAS_USUARIO
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

-- CONFIGURACION
CREATE TABLE IF NOT EXISTS configuracion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clave TEXT UNIQUE NOT NULL,
  valor TEXT,
  descripcion TEXT,
  tipo TEXT DEFAULT 'string',
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 7: ROLES Y DATOS INICIALES
-- ██████████████████████████████████████████████████████████████████████████████

-- Insertar roles base
INSERT INTO roles (nombre, descripcion) VALUES
('superadmin', 'Control total del sistema'),
('admin', 'Gerente de sucursal'),
('operador', 'Cajero/Operador'),
('cliente', 'Usuario cliente'),
('aval', 'Aval/Garante'),
('contador', 'Contador/Contabilidad'),
('recursos_humanos', 'Recursos Humanos')
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
('auditoria.ver', 'Ver auditoría'),
('ver_dashboard', 'Ver panel principal'),
('gestionar_clientes', 'Gestionar clientes'),
('gestionar_prestamos', 'Gestionar préstamos'),
('gestionar_tandas', 'Gestionar tandas'),
('gestionar_avales', 'Gestionar avales'),
('gestionar_pagos', 'Gestionar pagos'),
('gestionar_empleados', 'Gestionar empleados'),
('gestionar_usuarios', 'Gestionar usuarios'),
('gestionar_roles', 'Gestionar roles'),
('gestionar_sucursales', 'Gestionar sucursales'),
('configuracion_global', 'Configuración global'),
('acceso_control_center', 'Centro de control')
ON CONFLICT (clave_permiso) DO NOTHING;

-- Temas iniciales
INSERT INTO temas_app (nombre, descripcion, color_primario, color_secundario, color_acento, activo) VALUES
    ('Neón Oscuro', 'Tema oscuro con acentos neón', '#1E1E2C', '#2D2D44', '#00BCD4', true),
    ('Verde Dinero', 'Tema inspirado en finanzas', '#0D2818', '#1E3D2F', '#4CAF50', false),
    ('Dorado Premium', 'Tema elegante dorado', '#1A1A2E', '#16213E', '#FFD700', false),
    ('Azul Corporativo', 'Tema profesional azul', '#0A1929', '#132F4C', '#0288D1', false)
ON CONFLICT DO NOTHING;

-- Configuración inicial legacy
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

-- Negocio inicial
INSERT INTO negocios (nombre, tipo, activo)
SELECT 'Robert Darin Fintech', 'fintech', true
WHERE NOT EXISTS (SELECT 1 FROM negocios WHERE tipo = 'fintech' LIMIT 1);

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 8: HABILITAR RLS EN TODAS LAS TABLAS
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

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 9: POLÍTICAS RLS BÁSICAS
-- ██████████████████████████████████████████████████████████████████████████████

-- Política universal para autenticados
DO $$ 
BEGIN 
    -- USUARIOS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'usuarios_select_all') THEN
        CREATE POLICY "usuarios_select_all" ON usuarios FOR SELECT USING (true);
    END IF;
    
    -- CLIENTES
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'clientes_authenticated') THEN
        CREATE POLICY "clientes_authenticated" ON clientes FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- PRÉSTAMOS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'prestamos_authenticated') THEN
        CREATE POLICY "prestamos_authenticated" ON prestamos FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- AMORTIZACIONES
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'amortizaciones_authenticated') THEN
        CREATE POLICY "amortizaciones_authenticated" ON amortizaciones FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- PAGOS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'pagos_authenticated') THEN
        CREATE POLICY "pagos_authenticated" ON pagos FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- TANDAS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'tandas_authenticated') THEN
        CREATE POLICY "tandas_authenticated" ON tandas FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- AVALES
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'avales_authenticated') THEN
        CREATE POLICY "avales_authenticated" ON avales FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- NOTIFICACIONES
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notificaciones_propias') THEN
        CREATE POLICY "notificaciones_propias" ON notificaciones FOR SELECT USING (usuario_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notificaciones_update') THEN
        CREATE POLICY "notificaciones_update" ON notificaciones FOR UPDATE USING (usuario_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notificaciones_insert') THEN
        CREATE POLICY "notificaciones_insert" ON notificaciones FOR INSERT WITH CHECK (true);
    END IF;

    -- NEGOCIOS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'negocios_select') THEN
        CREATE POLICY "negocios_select" ON negocios FOR SELECT USING (auth.role() = 'authenticated');
    END IF;

    -- SUCURSALES
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'sucursales_authenticated') THEN
        CREATE POLICY "sucursales_authenticated" ON sucursales FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- EMPLEADOS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'empleados_authenticated') THEN
        CREATE POLICY "empleados_authenticated" ON empleados FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- ROLES
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'roles_select_all') THEN
        CREATE POLICY "roles_select_all" ON roles FOR SELECT USING (true);
    END IF;

    -- PERMISOS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'permisos_select_all') THEN
        CREATE POLICY "permisos_select_all" ON permisos FOR SELECT USING (true);
    END IF;

    -- CONFIG GLOBAL
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'configuracion_global_select') THEN
        CREATE POLICY "configuracion_global_select" ON configuracion_global FOR SELECT USING (true);
    END IF;

    -- TEMAS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'temas_app_select') THEN
        CREATE POLICY "temas_app_select" ON temas_app FOR SELECT USING (true);
    END IF;

    -- CONFIGURACION
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'configuracion_select_all') THEN
        CREATE POLICY "configuracion_select_all" ON configuracion FOR SELECT USING (auth.role() = 'authenticated');
    END IF;
    
    -- CALENDARIO
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'calendario_access') THEN
        CREATE POLICY "calendario_access" ON calendario FOR ALL USING (usuario_id = auth.uid() OR es_admin_o_superior());
    END IF;

    -- CHAT
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_conversaciones_auth') THEN
        CREATE POLICY "chat_conversaciones_auth" ON chat_conversaciones FOR ALL USING (auth.role() = 'authenticated');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_mensajes_auth') THEN
        CREATE POLICY "chat_mensajes_auth" ON chat_mensajes FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- PREFERENCIAS USUARIO
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'preferencias_usuario_own') THEN
        CREATE POLICY "preferencias_usuario_own" ON preferencias_usuario FOR ALL USING (auth.uid() = usuario_id);
    END IF;
END $$;

-- ██████████████████████████████████████████████████████████████████████████████
-- PARTE 10: ÍNDICES DE RENDIMIENTO
-- ██████████████████████████████████████████████████████████████████████████████

-- Clientes
CREATE INDEX IF NOT EXISTS idx_clientes_nombre ON clientes(nombre);
CREATE INDEX IF NOT EXISTS idx_clientes_negocio ON clientes(negocio_id);
CREATE INDEX IF NOT EXISTS idx_clientes_sucursal ON clientes(sucursal_id);

-- Préstamos
CREATE INDEX IF NOT EXISTS idx_prestamos_cliente ON prestamos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_prestamos_estado ON prestamos(estado);
CREATE INDEX IF NOT EXISTS idx_prestamos_negocio ON prestamos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_prestamos_fecha ON prestamos(fecha_creacion);

-- Amortizaciones
CREATE INDEX IF NOT EXISTS idx_amortizaciones_prestamo ON amortizaciones(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_amortizaciones_estado ON amortizaciones(estado);
CREATE INDEX IF NOT EXISTS idx_amortizaciones_vencimiento ON amortizaciones(fecha_vencimiento);

-- Pagos
CREATE INDEX IF NOT EXISTS idx_pagos_prestamo ON pagos(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_pagos_cliente ON pagos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos(fecha_pago);
CREATE INDEX IF NOT EXISTS idx_pagos_negocio ON pagos(negocio_id);

-- Tandas
CREATE INDEX IF NOT EXISTS idx_tandas_estado ON tandas(estado);
CREATE INDEX IF NOT EXISTS idx_tandas_negocio ON tandas(negocio_id);
CREATE INDEX IF NOT EXISTS idx_tanda_participantes_tanda ON tanda_participantes(tanda_id);

-- Avales
CREATE INDEX IF NOT EXISTS idx_avales_negocio ON avales(negocio_id);
CREATE INDEX IF NOT EXISTS idx_avales_cliente ON avales(cliente_id);

-- Notificaciones
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario ON notificaciones(usuario_id);
CREATE INDEX IF NOT EXISTS idx_notificaciones_leida ON notificaciones(leida);

-- Chat
CREATE INDEX IF NOT EXISTS idx_chat_mensajes_conversacion ON chat_mensajes(conversacion_id);
CREATE INDEX IF NOT EXISTS idx_chat_mensajes_fecha ON chat_mensajes(created_at);

-- Sucursales
CREATE INDEX IF NOT EXISTS idx_sucursales_negocio ON sucursales(negocio_id);

-- Empleados
CREATE INDEX IF NOT EXISTS idx_empleados_sucursal ON empleados(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_empleados_usuario ON empleados(usuario_id);

-- Usuarios Negocios
CREATE INDEX IF NOT EXISTS idx_usuarios_negocios_usuario ON usuarios_negocios(usuario_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_negocios_negocio ON usuarios_negocios(negocio_id);

-- ██████████████████████████████████████████████████████████████████████████████
-- VERIFICACIÓN FINAL
-- ██████████████████████████████████████████████████████████████████████████████

SELECT 'SINCRONIZACIÓN COMPLETA' AS status, COUNT(*) AS tablas_creadas
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
