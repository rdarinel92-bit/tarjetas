-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Configurador de Formularios QR Dinámicos V10.52
-- Fecha: 2026-01-21
-- 
-- Sistema para que el admin pueda configurar qué campos aparecen
-- cuando un cliente escanea el QR de cualquier módulo
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 1: CONFIGURACIÓN DE FORMULARIOS QR POR MÓDULO
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS formularios_qr_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    tarjeta_servicio_id UUID REFERENCES tarjetas_servicio(id) ON DELETE CASCADE,
    
    -- Identificación del formulario
    modulo VARCHAR(50) NOT NULL CHECK (modulo IN (
        'climas', 'prestamos', 'tandas', 'cobranza', 'servicios', 'general'
    )),
    nombre_formulario VARCHAR(100) NOT NULL DEFAULT 'Formulario de Contacto',
    
    -- Configuración visual
    titulo_header TEXT DEFAULT '¡Contáctanos!',
    subtitulo_header TEXT DEFAULT 'Completa el formulario y te contactaremos pronto',
    color_header VARCHAR(7) DEFAULT '#00D9FF',
    imagen_header_url TEXT,
    logo_url TEXT,
    
    -- Mensaje de éxito
    mensaje_exito TEXT DEFAULT '¡Gracias! Tu solicitud ha sido enviada. Te contactaremos pronto.',
    
    -- Configuración de campos (JSON dinámico)
    campos JSONB DEFAULT '[
        {"id": "nombre", "tipo": "text", "label": "Nombre completo", "placeholder": "Tu nombre", "requerido": true, "orden": 1, "activo": true},
        {"id": "telefono", "tipo": "tel", "label": "Teléfono / WhatsApp", "placeholder": "10 dígitos", "requerido": true, "orden": 2, "activo": true},
        {"id": "email", "tipo": "email", "label": "Correo electrónico", "placeholder": "tu@email.com", "requerido": false, "orden": 3, "activo": true},
        {"id": "direccion", "tipo": "textarea", "label": "Dirección", "placeholder": "Calle, número, colonia...", "requerido": false, "orden": 4, "activo": true},
        {"id": "mensaje", "tipo": "textarea", "label": "¿En qué podemos ayudarte?", "placeholder": "Describe tu solicitud...", "requerido": false, "orden": 5, "activo": true}
    ]'::JSONB,
    
    -- Campos específicos por módulo (opcionales)
    campos_modulo JSONB DEFAULT '[]'::JSONB,
    
    -- Opciones adicionales
    mostrar_horario BOOLEAN DEFAULT true,
    mostrar_telefono_negocio BOOLEAN DEFAULT true,
    mostrar_direccion_negocio BOOLEAN DEFAULT true,
    mostrar_redes_sociales BOOLEAN DEFAULT true,
    permitir_fotos BOOLEAN DEFAULT true,
    max_fotos INTEGER DEFAULT 3,
    
    -- Notificaciones
    notificar_whatsapp BOOLEAN DEFAULT true,
    notificar_email BOOLEAN DEFAULT true,
    emails_notificacion TEXT[], -- Lista de emails para notificar
    
    -- Estado
    activo BOOLEAN DEFAULT true,
    
    -- Metadata
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Un formulario por módulo por negocio (o por tarjeta específica)
    UNIQUE(negocio_id, modulo) -- Si no tiene tarjeta específica, usa el default del módulo
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_formularios_qr_negocio ON formularios_qr_config(negocio_id);
CREATE INDEX IF NOT EXISTS idx_formularios_qr_modulo ON formularios_qr_config(modulo);
CREATE INDEX IF NOT EXISTS idx_formularios_qr_tarjeta ON formularios_qr_config(tarjeta_servicio_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 2: CAMPOS PREDEFINIDOS POR MÓDULO (CATÁLOGO)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS campos_formulario_catalogo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identificación
    codigo VARCHAR(50) NOT NULL UNIQUE,  -- Ej: 'climas_tipo_equipo'
    modulo VARCHAR(50) NOT NULL,
    
    -- Configuración del campo
    tipo VARCHAR(30) NOT NULL CHECK (tipo IN (
        'text', 'email', 'tel', 'number', 'textarea', 
        'select', 'radio', 'checkbox', 'date', 'time',
        'file', 'photo', 'location', 'signature'
    )),
    label VARCHAR(100) NOT NULL,
    placeholder TEXT,
    hint TEXT,  -- Texto de ayuda
    
    -- Opciones para select/radio/checkbox
    opciones JSONB DEFAULT '[]'::JSONB,  -- [{"valor": "1", "texto": "Opción 1"}]
    
    -- Validación
    requerido_default BOOLEAN DEFAULT false,
    min_length INTEGER,
    max_length INTEGER,
    patron_regex TEXT,  -- Para validación custom
    
    -- Orden sugerido
    orden_sugerido INTEGER DEFAULT 99,
    
    -- Estado
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insertar campos predefinidos para cada módulo
INSERT INTO campos_formulario_catalogo (codigo, modulo, tipo, label, placeholder, hint, opciones, requerido_default, orden_sugerido) VALUES
    -- CAMPOS UNIVERSALES
    ('nombre', 'general', 'text', 'Nombre completo', 'Tu nombre', NULL, '[]', true, 1),
    ('telefono', 'general', 'tel', 'Teléfono / WhatsApp', '10 dígitos', 'Para contactarte', '[]', true, 2),
    ('email', 'general', 'email', 'Correo electrónico', 'tu@email.com', NULL, '[]', false, 3),
    ('direccion', 'general', 'textarea', 'Dirección', 'Calle, número, colonia, ciudad...', NULL, '[]', false, 4),
    ('mensaje', 'general', 'textarea', '¿En qué podemos ayudarte?', 'Describe tu solicitud...', NULL, '[]', false, 10),
    
    -- CAMPOS ESPECÍFICOS CLIMAS
    ('climas_tipo_servicio', 'climas', 'select', 'Tipo de servicio', 'Selecciona...', NULL, 
     '[{"valor": "instalacion", "texto": "Instalación nueva"}, {"valor": "mantenimiento", "texto": "Mantenimiento"}, {"valor": "reparacion", "texto": "Reparación"}, {"valor": "limpieza", "texto": "Limpieza"}, {"valor": "cotizacion", "texto": "Cotización"}]', true, 5),
    ('climas_tipo_equipo', 'climas', 'select', 'Tipo de equipo', 'Selecciona...', NULL,
     '[{"valor": "minisplit", "texto": "Minisplit"}, {"valor": "central", "texto": "Aire central"}, {"valor": "ventana", "texto": "Ventana"}, {"valor": "portatil", "texto": "Portátil"}, {"valor": "otro", "texto": "Otro"}]', false, 6),
    ('climas_marca', 'climas', 'text', 'Marca del equipo', 'Ej: LG, Samsung, Mirage...', NULL, '[]', false, 7),
    ('climas_toneladas', 'climas', 'select', 'Capacidad (toneladas)', 'Selecciona...', NULL,
     '[{"valor": "1", "texto": "1 tonelada"}, {"valor": "1.5", "texto": "1.5 toneladas"}, {"valor": "2", "texto": "2 toneladas"}, {"valor": "3", "texto": "3 toneladas"}, {"valor": "otro", "texto": "No sé"}]', false, 8),
    ('climas_urgente', 'climas', 'checkbox', '¿Es urgente?', NULL, 'Marcar si necesitas atención inmediata', '[]', false, 9),
    
    -- CAMPOS ESPECÍFICOS PRÉSTAMOS
    ('prestamos_monto', 'prestamos', 'number', 'Monto solicitado', '$0.00', 'Cantidad aproximada que necesitas', '[]', true, 5),
    ('prestamos_plazo', 'prestamos', 'select', 'Plazo deseado', 'Selecciona...', NULL,
     '[{"valor": "1", "texto": "1 mes"}, {"valor": "2", "texto": "2 meses"}, {"valor": "3", "texto": "3 meses"}, {"valor": "6", "texto": "6 meses"}, {"valor": "12", "texto": "12 meses"}]', true, 6),
    ('prestamos_frecuencia', 'prestamos', 'select', 'Frecuencia de pago', 'Selecciona...', NULL,
     '[{"valor": "semanal", "texto": "Semanal"}, {"valor": "quincenal", "texto": "Quincenal"}, {"valor": "mensual", "texto": "Mensual"}]', true, 7),
    ('prestamos_ocupacion', 'prestamos', 'text', 'Ocupación / Trabajo', 'Ej: Empleado, Comerciante...', NULL, '[]', false, 8),
    ('prestamos_tiene_aval', 'prestamos', 'radio', '¿Tienes aval?', NULL, NULL,
     '[{"valor": "si", "texto": "Sí"}, {"valor": "no", "texto": "No"}, {"valor": "puedo_conseguir", "texto": "Puedo conseguir"}]', false, 9),
    
    -- CAMPOS ESPECÍFICOS TANDAS
    ('tandas_monto_semana', 'tandas', 'select', 'Monto por semana', 'Selecciona...', 'Cuánto puedes aportar semanalmente',
     '[{"valor": "100", "texto": "$100"}, {"valor": "200", "texto": "$200"}, {"valor": "500", "texto": "$500"}, {"valor": "1000", "texto": "$1,000"}, {"valor": "otro", "texto": "Otro monto"}]', true, 5),
    ('tandas_numero_preferido', 'tandas', 'select', 'Número preferido', 'Selecciona...', 'Qué número de tanda prefieres',
     '[{"valor": "primero", "texto": "Primeros números (1-3)"}, {"valor": "medio", "texto": "Números intermedios (4-7)"}, {"valor": "ultimo", "texto": "Últimos números (8-10)"}, {"valor": "cualquiera", "texto": "Cualquiera"}]', false, 6),
    ('tandas_experiencia', 'tandas', 'radio', '¿Has participado en tandas antes?', NULL, NULL,
     '[{"valor": "si", "texto": "Sí"}, {"valor": "no", "texto": "No, es mi primera vez"}]', false, 7),
    
    -- CAMPOS ESPECÍFICOS SERVICIOS GENERALES
    ('servicios_tipo', 'servicios', 'select', 'Tipo de servicio', 'Selecciona...', NULL,
     '[{"valor": "domicilio", "texto": "A domicilio"}, {"valor": "taller", "texto": "En taller/local"}, {"valor": "remoto", "texto": "Servicio remoto"}]', false, 5),
    ('servicios_fecha_preferida', 'servicios', 'date', 'Fecha preferida', NULL, 'Selecciona una fecha tentativa', '[]', false, 6),
    ('servicios_horario', 'servicios', 'select', 'Horario preferido', 'Selecciona...', NULL,
     '[{"valor": "manana", "texto": "Mañana (8am-12pm)"}, {"valor": "tarde", "texto": "Tarde (12pm-6pm)"}, {"valor": "cualquiera", "texto": "Cualquier horario"}]', false, 7)
ON CONFLICT (codigo) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 3: HISTORIAL DE ENVÍOS DE FORMULARIOS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS formularios_qr_envios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    formulario_config_id UUID REFERENCES formularios_qr_config(id) ON DELETE SET NULL,
    tarjeta_servicio_id UUID REFERENCES tarjetas_servicio(id) ON DELETE SET NULL,
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Datos del envío
    modulo VARCHAR(50) NOT NULL,
    datos JSONB NOT NULL,  -- Todos los campos del formulario
    fotos TEXT[],  -- URLs de las fotos subidas
    
    -- Datos del cliente (extraídos para búsqueda rápida)
    nombre TEXT,
    telefono TEXT,
    email TEXT,
    
    -- Seguimiento
    estado VARCHAR(30) DEFAULT 'nuevo' CHECK (estado IN (
        'nuevo', 'visto', 'contactado', 'en_proceso', 'completado', 'cancelado', 'spam'
    )),
    asignado_a UUID REFERENCES auth.users(id),
    notas_internas TEXT,
    
    -- Tracking
    ip_address INET,
    user_agent TEXT,
    origen VARCHAR(30) DEFAULT 'qr',  -- qr, web, directo
    
    -- Timestamps
    contactado_at TIMESTAMPTZ,
    completado_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para búsqueda
CREATE INDEX IF NOT EXISTS idx_envios_negocio ON formularios_qr_envios(negocio_id);
CREATE INDEX IF NOT EXISTS idx_envios_modulo ON formularios_qr_envios(modulo);
CREATE INDEX IF NOT EXISTS idx_envios_estado ON formularios_qr_envios(estado);
CREATE INDEX IF NOT EXISTS idx_envios_fecha ON formularios_qr_envios(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_envios_telefono ON formularios_qr_envios(telefono);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 4: RLS POLICIES
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE formularios_qr_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE campos_formulario_catalogo ENABLE ROW LEVEL SECURITY;
ALTER TABLE formularios_qr_envios ENABLE ROW LEVEL SECURITY;

-- Políticas para config
DROP POLICY IF EXISTS "formularios_config_select" ON formularios_qr_config;
CREATE POLICY "formularios_config_select" ON formularios_qr_config
    FOR SELECT USING (
        activo = true
        OR negocio_id IN (SELECT negocio_id FROM usuarios_negocios WHERE usuario_id = auth.uid())
        OR EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin'
        )
    );

DROP POLICY IF EXISTS "formularios_config_manage" ON formularios_qr_config;
CREATE POLICY "formularios_config_manage" ON formularios_qr_config
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin')
        )
    );

-- Catálogo es público para lectura
DROP POLICY IF EXISTS "campos_catalogo_select" ON campos_formulario_catalogo;
CREATE POLICY "campos_catalogo_select" ON campos_formulario_catalogo
    FOR SELECT USING (activo = true);

-- Envíos: público puede insertar, admin puede ver/gestionar
DROP POLICY IF EXISTS "envios_insert_public" ON formularios_qr_envios;
CREATE POLICY "envios_insert_public" ON formularios_qr_envios
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "envios_select" ON formularios_qr_envios;
CREATE POLICY "envios_select" ON formularios_qr_envios
    FOR SELECT USING (
        negocio_id IN (SELECT negocio_id FROM usuarios_negocios WHERE usuario_id = auth.uid())
        OR EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin'
        )
    );

DROP POLICY IF EXISTS "envios_update" ON formularios_qr_envios;
CREATE POLICY "envios_update" ON formularios_qr_envios
    FOR UPDATE USING (
        negocio_id IN (SELECT negocio_id FROM usuarios_negocios WHERE usuario_id = auth.uid())
        OR asignado_a = auth.uid()
        OR EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin'
        )
    );

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 5: TRIGGERS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_formulario_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_formularios_config_updated ON formularios_qr_config;
CREATE TRIGGER tr_formularios_config_updated
    BEFORE UPDATE ON formularios_qr_config
    FOR EACH ROW EXECUTE FUNCTION update_formulario_config_timestamp();

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 6: FUNCIONES ÚTILES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Función para obtener la configuración del formulario de una tarjeta
CREATE OR REPLACE FUNCTION get_formulario_config(
    p_tarjeta_id UUID DEFAULT NULL,
    p_negocio_id UUID DEFAULT NULL,
    p_modulo VARCHAR DEFAULT 'general'
)
RETURNS JSONB AS $$
DECLARE
    v_config JSONB;
BEGIN
    -- Primero buscar config específica de la tarjeta
    IF p_tarjeta_id IS NOT NULL THEN
        SELECT to_jsonb(f.*) INTO v_config
        FROM formularios_qr_config f
        WHERE f.tarjeta_servicio_id = p_tarjeta_id AND f.activo = true
        LIMIT 1;
        
        IF v_config IS NOT NULL THEN
            RETURN v_config;
        END IF;
    END IF;
    
    -- Si no, buscar config del módulo para el negocio
    IF p_negocio_id IS NOT NULL THEN
        SELECT to_jsonb(f.*) INTO v_config
        FROM formularios_qr_config f
        WHERE f.negocio_id = p_negocio_id 
          AND f.modulo = p_modulo 
          AND f.tarjeta_servicio_id IS NULL
          AND f.activo = true
        LIMIT 1;
        
        IF v_config IS NOT NULL THEN
            RETURN v_config;
        END IF;
    END IF;
    
    -- Retornar configuración por defecto
    RETURN jsonb_build_object(
        'nombre_formulario', 'Formulario de Contacto',
        'titulo_header', '¡Contáctanos!',
        'subtitulo_header', 'Completa el formulario',
        'color_header', '#00D9FF',
        'mensaje_exito', '¡Gracias! Te contactaremos pronto.',
        'campos', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', c.codigo,
                    'tipo', c.tipo,
                    'label', c.label,
                    'placeholder', c.placeholder,
                    'requerido', c.requerido_default,
                    'orden', c.orden_sugerido,
                    'activo', true,
                    'opciones', c.opciones
                ) ORDER BY c.orden_sugerido
            )
            FROM campos_formulario_catalogo c
            WHERE (c.modulo = 'general' OR c.modulo = p_modulo)
              AND c.activo = true
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para estadísticas de envíos
CREATE OR REPLACE FUNCTION get_estadisticas_formularios(p_negocio_id UUID)
RETURNS TABLE (
    total_envios INTEGER,
    nuevos INTEGER,
    contactados INTEGER,
    completados INTEGER,
    tasa_conversion NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_envios,
        COUNT(*) FILTER (WHERE e.estado = 'nuevo')::INTEGER as nuevos,
        COUNT(*) FILTER (WHERE e.estado IN ('contactado', 'en_proceso'))::INTEGER as contactados,
        COUNT(*) FILTER (WHERE e.estado = 'completado')::INTEGER as completados,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(*) FILTER (WHERE e.estado = 'completado')::NUMERIC / COUNT(*)) * 100, 2)
            ELSE 0 
        END as tasa_conversion
    FROM formularios_qr_envios e
    WHERE e.negocio_id = p_negocio_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════════
-- FIN DE MIGRACIÓN
-- ═══════════════════════════════════════════════════════════════════════════════

COMMENT ON TABLE formularios_qr_config IS 'Configuración de formularios QR por negocio y módulo';
COMMENT ON TABLE campos_formulario_catalogo IS 'Catálogo de campos predefinidos para formularios';
COMMENT ON TABLE formularios_qr_envios IS 'Historial de envíos de formularios QR';
