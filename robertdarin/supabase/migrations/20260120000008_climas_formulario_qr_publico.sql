-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: SISTEMA DE SOLICITUDES QR PARA MÓDULO CLIMAS
-- Fecha: 20 Enero 2026
-- Descripción: Formulario público accesible via QR, chat en tiempo real,
--              sistema de aprobación de clientes
-- ══════════════════════════════════════════════════════════════════════════════

-- Habilitar extensión para generar tokens
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TABLA PRINCIPAL: Solicitudes desde QR (LEADS sin autenticación)
-- El cliente escanea QR → Llena formulario → Se guarda aquí
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE IF NOT EXISTS climas_solicitudes_qr (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Datos del solicitante
    nombre_completo TEXT NOT NULL,
    telefono TEXT NOT NULL,
    email TEXT,
    
    -- Ubicación del servicio
    direccion TEXT NOT NULL,
    colonia TEXT,
    ciudad TEXT,
    codigo_postal TEXT,
    referencia_ubicacion TEXT, -- "Casa azul esquina con farmacia"
    latitud DECIMAL(10, 8),
    longitud DECIMAL(11, 8),
    
    -- Tipo de servicio solicitado
    tipo_servicio TEXT NOT NULL DEFAULT 'cotizacion', -- cotizacion, instalacion, mantenimiento, reparacion, emergencia
    
    -- Detalles del equipo actual (si aplica)
    tiene_equipo_actual BOOLEAN DEFAULT FALSE,
    marca_equipo_actual TEXT,
    modelo_equipo_actual TEXT,
    capacidad_btu_actual INTEGER,
    antiguedad_equipo TEXT, -- menos_1_año, 1_3_años, 3_5_años, mas_5_años
    problema_reportado TEXT,
    
    -- Detalles para instalación nueva
    tipo_espacio TEXT, -- recamara, sala, oficina, local_comercial, bodega
    metros_cuadrados DECIMAL(8, 2),
    cantidad_equipos_deseados INTEGER DEFAULT 1,
    presupuesto_estimado TEXT, -- bajo, medio, alto, sin_limite
    
    -- Preferencias de contacto
    horario_contacto_preferido TEXT, -- mañana, tarde, cualquier_hora
    medio_contacto_preferido TEXT DEFAULT 'telefono', -- telefono, whatsapp, email
    disponibilidad_visita TEXT, -- lo_antes_posible, esta_semana, proxima_semana, solo_fines_semana
    
    -- Fotos adjuntas
    fotos JSONB DEFAULT '[]'::jsonb, -- Array de URLs de fotos subidas
    
    -- Notas adicionales del cliente
    notas_cliente TEXT,
    
    -- Estado del flujo
    estado TEXT DEFAULT 'nueva', -- nueva, revisando, contactado, agendado, aprobado, rechazado, convertido
    
    -- Seguimiento interno
    revisado_por UUID REFERENCES usuarios(id),
    fecha_revision TIMESTAMPTZ,
    notas_internas TEXT, -- Notas del admin/técnico
    motivo_rechazo TEXT,
    
    -- Conversión a cliente
    cliente_creado_id UUID REFERENCES climas_clientes(id),
    orden_creada_id UUID REFERENCES climas_ordenes_servicio(id),
    fecha_conversion TIMESTAMPTZ,
    
    -- Token único para seguimiento del cliente (usando UUID como alternativa a gen_random_bytes)
    token_seguimiento TEXT DEFAULT replace(gen_random_uuid()::text, '-', ''),
    
    -- Metadatos
    ip_origen TEXT,
    user_agent TEXT,
    fuente TEXT DEFAULT 'qr_tarjeta', -- qr_tarjeta, web, referido
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TABLA: Chat público (sin autenticación del cliente)
-- Permite comunicación antes de crear cuenta
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE IF NOT EXISTS climas_chat_solicitud (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    solicitud_id UUID NOT NULL REFERENCES climas_solicitudes_qr(id) ON DELETE CASCADE,
    
    -- Quién envía el mensaje
    es_cliente BOOLEAN NOT NULL, -- TRUE = cliente, FALSE = negocio
    remitente_id UUID REFERENCES usuarios(id), -- NULL si es cliente (no autenticado)
    remitente_nombre TEXT NOT NULL, -- Nombre mostrado
    
    -- Contenido
    mensaje TEXT NOT NULL,
    tipo_mensaje TEXT DEFAULT 'texto', -- texto, imagen, ubicacion, archivo
    adjunto_url TEXT,
    adjunto_nombre TEXT,
    
    -- Estado lectura
    leido BOOLEAN DEFAULT FALSE,
    fecha_leido TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TABLA: Catálogo de servicios públicos (para mostrar en formulario)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE IF NOT EXISTS climas_catalogo_servicios_publico (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    codigo TEXT,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    icono TEXT, -- nombre del icono Material
    
    -- Precios de referencia (mostrar en formulario)
    precio_desde DECIMAL(12, 2),
    precio_hasta DECIMAL(12, 2),
    mostrar_precio BOOLEAN DEFAULT TRUE,
    
    -- Tiempo estimado
    tiempo_estimado TEXT, -- "30 min", "1-2 horas", etc.
    
    -- Categoría
    categoria TEXT DEFAULT 'general', -- instalacion, mantenimiento, reparacion, emergencia
    
    -- Promociones
    en_promocion BOOLEAN DEFAULT FALSE,
    precio_promocion DECIMAL(12, 2),
    texto_promocion TEXT,
    
    orden INTEGER DEFAULT 0,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TABLA: Configuración del formulario QR por negocio
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE IF NOT EXISTS climas_config_formulario_qr (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID UNIQUE REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Personalización visual
    logo_url TEXT,
    color_primario TEXT DEFAULT '#00D9FF',
    color_secundario TEXT DEFAULT '#8B5CF6',
    mensaje_bienvenida TEXT DEFAULT '¡Bienvenido! Complete el formulario para recibir atención personalizada.',
    
    -- Campos opcionales/requeridos
    campo_email_requerido BOOLEAN DEFAULT FALSE,
    campo_direccion_requerido BOOLEAN DEFAULT TRUE,
    campo_fotos_habilitado BOOLEAN DEFAULT TRUE,
    max_fotos INTEGER DEFAULT 5,
    
    -- Servicios disponibles
    servicios_habilitados JSONB DEFAULT '["cotizacion", "instalacion", "mantenimiento", "reparacion"]'::jsonb,
    
    -- Notificaciones
    notificar_email TEXT, -- Email donde enviar notificaciones de nuevas solicitudes
    notificar_whatsapp TEXT, -- WhatsApp para notificaciones
    notificar_push BOOLEAN DEFAULT TRUE,
    
    -- Texto legal
    aviso_privacidad_url TEXT,
    terminos_condiciones_url TEXT,
    
    -- Estado
    formulario_activo BOOLEAN DEFAULT TRUE,
    mensaje_formulario_inactivo TEXT DEFAULT 'Lo sentimos, no estamos recibiendo solicitudes en este momento.',
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TABLA: Historial de seguimiento de solicitudes
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE IF NOT EXISTS climas_solicitud_historial (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    solicitud_id UUID NOT NULL REFERENCES climas_solicitudes_qr(id) ON DELETE CASCADE,
    
    estado_anterior TEXT,
    estado_nuevo TEXT NOT NULL,
    comentario TEXT,
    
    usuario_id UUID REFERENCES usuarios(id),
    usuario_nombre TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- ÍNDICES PARA RENDIMIENTO
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_climas_sol_qr_negocio ON climas_solicitudes_qr(negocio_id);
CREATE INDEX IF NOT EXISTS idx_climas_sol_qr_estado ON climas_solicitudes_qr(estado);
CREATE INDEX IF NOT EXISTS idx_climas_sol_qr_created ON climas_solicitudes_qr(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_climas_sol_qr_token ON climas_solicitudes_qr(token_seguimiento);
CREATE INDEX IF NOT EXISTS idx_climas_sol_qr_telefono ON climas_solicitudes_qr(telefono);

CREATE INDEX IF NOT EXISTS idx_climas_chat_sol_solicitud ON climas_chat_solicitud(solicitud_id);
CREATE INDEX IF NOT EXISTS idx_climas_chat_sol_created ON climas_chat_solicitud(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_climas_catalogo_negocio ON climas_catalogo_servicios_publico(negocio_id);
CREATE INDEX IF NOT EXISTS idx_climas_catalogo_activo ON climas_catalogo_servicios_publico(activo);

-- ═══════════════════════════════════════════════════════════════════════════════
-- RLS (Row Level Security)
-- ═══════════════════════════════════════════════════════════════════════════════
ALTER TABLE climas_solicitudes_qr ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_chat_solicitud ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_catalogo_servicios_publico ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_config_formulario_qr ENABLE ROW LEVEL SECURITY;
ALTER TABLE climas_solicitud_historial ENABLE ROW LEVEL SECURITY;

-- Políticas para solicitudes QR (acceso público para INSERT, autenticado para SELECT/UPDATE)
CREATE POLICY "climas_sol_qr_insert_public" ON climas_solicitudes_qr
    FOR INSERT WITH CHECK (true); -- Cualquiera puede crear solicitud

CREATE POLICY "climas_sol_qr_select_auth" ON climas_solicitudes_qr
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "climas_sol_qr_update_auth" ON climas_solicitudes_qr
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Políticas para chat (acceso mixto)
CREATE POLICY "climas_chat_insert_public" ON climas_chat_solicitud
    FOR INSERT WITH CHECK (true); -- Cliente puede enviar mensaje

CREATE POLICY "climas_chat_select_auth" ON climas_chat_solicitud
    FOR SELECT USING (auth.role() = 'authenticated');

-- Catálogo público (lectura pública)
CREATE POLICY "climas_catalogo_select_public" ON climas_catalogo_servicios_publico
    FOR SELECT USING (activo = true);

CREATE POLICY "climas_catalogo_manage_auth" ON climas_catalogo_servicios_publico
    FOR ALL USING (auth.role() = 'authenticated');

-- Config formulario
CREATE POLICY "climas_config_form_auth" ON climas_config_formulario_qr
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "climas_config_form_select_public" ON climas_config_formulario_qr
    FOR SELECT USING (true); -- Para cargar config en formulario público

-- Historial solo autenticados
CREATE POLICY "climas_historial_auth" ON climas_solicitud_historial
    FOR ALL USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIÓN: Crear cliente desde solicitud aprobada
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION climas_aprobar_solicitud_qr(
    p_solicitud_id UUID,
    p_crear_cliente BOOLEAN DEFAULT TRUE,
    p_crear_orden BOOLEAN DEFAULT FALSE,
    p_notas TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_solicitud RECORD;
    v_cliente_id UUID;
    v_orden_id UUID;
BEGIN
    -- Obtener solicitud
    SELECT * INTO v_solicitud 
    FROM climas_solicitudes_qr 
    WHERE id = p_solicitud_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;
    
    -- Crear cliente si se solicita
    IF p_crear_cliente THEN
        INSERT INTO climas_clientes (
            negocio_id, nombre, telefono, email, direccion, 
            colonia, ciudad, codigo_postal, referencia,
            latitud, longitud, tipo_cliente, notas, activo
        ) VALUES (
            v_solicitud.negocio_id,
            v_solicitud.nombre_completo,
            v_solicitud.telefono,
            v_solicitud.email,
            v_solicitud.direccion,
            v_solicitud.colonia,
            v_solicitud.ciudad,
            v_solicitud.codigo_postal,
            v_solicitud.referencia_ubicacion,
            v_solicitud.latitud,
            v_solicitud.longitud,
            CASE WHEN v_solicitud.tipo_espacio IN ('local_comercial', 'bodega') THEN 'comercial' ELSE 'residencial' END,
            COALESCE(v_solicitud.notas_cliente, '') || E'\n\nOrigen: Formulario QR',
            TRUE
        )
        RETURNING id INTO v_cliente_id;
    END IF;
    
    -- Actualizar solicitud
    UPDATE climas_solicitudes_qr SET
        estado = 'aprobado',
        cliente_creado_id = v_cliente_id,
        fecha_conversion = NOW(),
        notas_internas = COALESCE(notas_internas, '') || E'\n' || COALESCE(p_notas, ''),
        revisado_por = auth.uid(),
        fecha_revision = NOW(),
        updated_at = NOW()
    WHERE id = p_solicitud_id;
    
    -- Registrar en historial
    INSERT INTO climas_solicitud_historial (solicitud_id, estado_anterior, estado_nuevo, comentario, usuario_id)
    VALUES (p_solicitud_id, v_solicitud.estado, 'aprobado', p_notas, auth.uid());
    
    RETURN jsonb_build_object(
        'success', true,
        'cliente_id', v_cliente_id,
        'orden_id', v_orden_id,
        'message', 'Solicitud aprobada correctamente'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIÓN: Obtener solicitud por token (para seguimiento público)
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION climas_obtener_solicitud_por_token(p_token TEXT)
RETURNS JSONB AS $$
DECLARE
    v_solicitud RECORD;
    v_mensajes JSONB;
BEGIN
    SELECT * INTO v_solicitud 
    FROM climas_solicitudes_qr 
    WHERE token_seguimiento = p_token;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;
    
    -- Obtener mensajes del chat
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'es_cliente', es_cliente,
            'remitente_nombre', remitente_nombre,
            'mensaje', mensaje,
            'tipo_mensaje', tipo_mensaje,
            'adjunto_url', adjunto_url,
            'created_at', created_at
        ) ORDER BY created_at ASC
    ), '[]'::jsonb) INTO v_mensajes
    FROM climas_chat_solicitud
    WHERE solicitud_id = v_solicitud.id;
    
    RETURN jsonb_build_object(
        'success', true,
        'solicitud', jsonb_build_object(
            'id', v_solicitud.id,
            'nombre', v_solicitud.nombre_completo,
            'estado', v_solicitud.estado,
            'tipo_servicio', v_solicitud.tipo_servicio,
            'created_at', v_solicitud.created_at,
            'respuesta', v_solicitud.notas_internas
        ),
        'mensajes', v_mensajes
    );
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER: Actualizar updated_at automáticamente
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION update_climas_solicitud_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_climas_sol_qr_updated ON climas_solicitudes_qr;
CREATE TRIGGER trigger_climas_sol_qr_updated
    BEFORE UPDATE ON climas_solicitudes_qr
    FOR EACH ROW
    EXECUTE FUNCTION update_climas_solicitud_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════════
-- DATOS INICIALES: Catálogo de servicios de ejemplo
-- ═══════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    v_negocio_id UUID;
BEGIN
    -- Obtener primer negocio (para demo)
    SELECT id INTO v_negocio_id FROM negocios LIMIT 1;
    
    IF v_negocio_id IS NOT NULL THEN
        -- Insertar servicios de ejemplo si no existen
        INSERT INTO climas_catalogo_servicios_publico (negocio_id, codigo, nombre, descripcion, icono, precio_desde, precio_hasta, tiempo_estimado, categoria, orden) 
        VALUES 
            (v_negocio_id, 'INST-MS', 'Instalación Minisplit', 'Instalación profesional de aire acondicionado tipo minisplit', 'ac_unit', 1500, 3500, '2-4 horas', 'instalacion', 1),
            (v_negocio_id, 'MANT-PREV', 'Mantenimiento Preventivo', 'Limpieza completa, recarga de gas si necesario, revisión general', 'build', 350, 650, '1-2 horas', 'mantenimiento', 2),
            (v_negocio_id, 'REP-GEN', 'Reparación General', 'Diagnóstico y reparación de fallas comunes', 'handyman', 500, 2000, '1-3 horas', 'reparacion', 3),
            (v_negocio_id, 'CARGA-GAS', 'Recarga de Gas Refrigerante', 'Recarga de gas R22, R410A o R32', 'propane_tank', 800, 1800, '30-60 min', 'reparacion', 4),
            (v_negocio_id, 'EMERG-24H', 'Servicio de Emergencia 24h', 'Atención urgente fuera de horario', 'emergency', 1500, 3000, '1-2 horas', 'emergencia', 5)
        ON CONFLICT DO NOTHING;
        
        -- Crear configuración por defecto
        INSERT INTO climas_config_formulario_qr (negocio_id, mensaje_bienvenida)
        VALUES (v_negocio_id, '¡Bienvenido! Solicita tu servicio de aire acondicionado de forma fácil y rápida.')
        ON CONFLICT (negocio_id) DO NOTHING;
        
        RAISE NOTICE 'Datos iniciales de climas creados para negocio %', v_negocio_id;
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- FIN MIGRACIÓN: CLIMAS FORMULARIO QR PÚBLICO
-- ═══════════════════════════════════════════════════════════════════════════════
