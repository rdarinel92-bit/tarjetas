-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Sistema de Tarjetas de Servicio QR Multi-Negocio v10.52
-- Fecha: 2026-01-21
-- 
-- Sistema profesional para generar tarjetas de presentación/servicio con QR
-- Soporta múltiples negocios y módulos sin mezclar datos
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 1: TABLA PRINCIPAL - TARJETAS DE SERVICIO
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tarjetas_servicio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    
    -- Identificación
    codigo VARCHAR(20) UNIQUE NOT NULL DEFAULT UPPER(SUBSTRING(MD5(RANDOM()::TEXT), 1, 8)),
    nombre_tarjeta VARCHAR(100) NOT NULL,  -- Ej: "Servicios de Aire Acondicionado"
    
    -- Módulo/Tipo de servicio
    modulo VARCHAR(50) NOT NULL CHECK (modulo IN (
        'climas', 'prestamos', 'tandas', 'cobranza', 'servicios', 'general'
    )),
    
    -- Información del negocio (se muestra en tarjeta)
    nombre_negocio VARCHAR(150),
    slogan TEXT,
    telefono_principal VARCHAR(20),
    telefono_secundario VARCHAR(20),
    whatsapp VARCHAR(20),
    email VARCHAR(100),
    direccion TEXT,
    ciudad VARCHAR(100),
    
    -- Branding
    logo_url TEXT,
    color_primario VARCHAR(7) DEFAULT '#00D9FF',
    color_secundario VARCHAR(7) DEFAULT '#8B5CF6',
    color_fondo VARCHAR(7) DEFAULT '#0D0D14',
    
    -- QR Configuration
    qr_deep_link TEXT,  -- robertdarin://modulo/ruta?negocio=XXX
    qr_web_fallback TEXT,  -- URL web si no tiene app
    qr_color VARCHAR(7) DEFAULT '#FFFFFF',
    qr_con_logo BOOLEAN DEFAULT true,
    
    -- Servicios ofrecidos (para mostrar en tarjeta)
    servicios JSONB DEFAULT '[]'::JSONB,  -- ["Instalación", "Mantenimiento", "Reparación"]
    
    -- Horario
    horario_atencion TEXT,  -- Ej: "Lun-Vie 9am-6pm"
    
    -- Redes sociales
    facebook TEXT,
    instagram TEXT,
    tiktok TEXT,
    
    -- Template de diseño
    template VARCHAR(30) DEFAULT 'profesional' CHECK (template IN (
        'profesional', 'moderno', 'minimalista', 'clasico', 'premium', 'corporativo'
    )),
    
    -- Estado
    activa BOOLEAN DEFAULT true,
    
    -- Estadísticas
    escaneos_total INTEGER DEFAULT 0,
    ultimo_escaneo TIMESTAMPTZ,
    
    -- Metadata
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para búsqueda eficiente
CREATE INDEX IF NOT EXISTS idx_tarjetas_servicio_negocio ON tarjetas_servicio(negocio_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_servicio_modulo ON tarjetas_servicio(modulo);
CREATE INDEX IF NOT EXISTS idx_tarjetas_servicio_codigo ON tarjetas_servicio(codigo);
CREATE INDEX IF NOT EXISTS idx_tarjetas_servicio_activa ON tarjetas_servicio(activa);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 2: REGISTRO DE ESCANEOS QR
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tarjetas_servicio_escaneos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_servicio(id) ON DELETE CASCADE,
    
    -- Info del escaneo
    ip_address INET,
    user_agent TEXT,
    plataforma VARCHAR(20),  -- android, ios, web
    ciudad_detectada VARCHAR(100),
    pais_detectado VARCHAR(50),
    
    -- Acción tomada
    accion VARCHAR(30) DEFAULT 'ver' CHECK (accion IN (
        'ver', 'llamar', 'whatsapp', 'email', 'mapa', 'formulario', 'otro'
    )),
    
    -- Si convirtió a solicitud
    genero_solicitud BOOLEAN DEFAULT false,
    solicitud_id UUID,  -- ID de la solicitud generada (si aplica)
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_escaneos_tarjeta ON tarjetas_servicio_escaneos(tarjeta_id);
CREATE INDEX IF NOT EXISTS idx_escaneos_fecha ON tarjetas_servicio_escaneos(created_at);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 3: TEMPLATES DE TARJETAS (DISEÑOS PRE-DEFINIDOS)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tarjetas_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    preview_url TEXT,  -- Imagen de preview del template
    
    -- Configuración del template
    config JSONB DEFAULT '{}'::JSONB,  -- Posiciones, fuentes, etc.
    
    -- Para qué módulos aplica
    modulos_compatibles TEXT[] DEFAULT ARRAY['general'],
    
    -- Premium o gratuito
    es_premium BOOLEAN DEFAULT false,
    
    activo BOOLEAN DEFAULT true,
    orden INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insertar templates iniciales
INSERT INTO tarjetas_templates (nombre, descripcion, modulos_compatibles, config, orden) VALUES
    ('profesional', 'Diseño profesional con gradientes', ARRAY['climas', 'prestamos', 'tandas', 'servicios', 'general'], 
     '{"gradient": true, "rounded": 16, "shadow": true}'::JSONB, 1),
    ('moderno', 'Estilo moderno y limpio', ARRAY['climas', 'prestamos', 'tandas', 'servicios', 'general'], 
     '{"gradient": false, "rounded": 20, "shadow": false, "border": true}'::JSONB, 2),
    ('minimalista', 'Diseño minimalista elegante', ARRAY['climas', 'servicios', 'general'], 
     '{"gradient": false, "rounded": 8, "minimal": true}'::JSONB, 3),
    ('clasico', 'Estilo clásico tradicional', ARRAY['prestamos', 'tandas', 'general'], 
     '{"gradient": false, "rounded": 4, "classic": true}'::JSONB, 4),
    ('premium', 'Diseño premium con efectos', ARRAY['climas', 'prestamos', 'tandas', 'servicios', 'general'], 
     '{"gradient": true, "rounded": 24, "glassmorphism": true}'::JSONB, 5),
    ('corporativo', 'Estilo corporativo formal', ARRAY['prestamos', 'tandas', 'general'], 
     '{"gradient": false, "rounded": 12, "formal": true}'::JSONB, 6)
ON CONFLICT (nombre) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 4: CONFIGURACIÓN DE LANDING PAGES POR MÓDULO
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tarjetas_landing_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    modulo VARCHAR(50) NOT NULL,
    
    -- Configuración de la landing page
    titulo TEXT,
    subtitulo TEXT,
    descripcion TEXT,
    imagen_hero_url TEXT,
    
    -- CTA (Call to Action)
    cta_texto VARCHAR(50) DEFAULT 'Solicitar Servicio',
    cta_color VARCHAR(7) DEFAULT '#00D9FF',
    
    -- Campos del formulario (qué campos mostrar)
    campos_formulario JSONB DEFAULT '[
        {"campo": "nombre", "requerido": true},
        {"campo": "telefono", "requerido": true},
        {"campo": "email", "requerido": false},
        {"campo": "direccion", "requerido": false},
        {"campo": "mensaje", "requerido": false}
    ]'::JSONB,
    
    -- Ruta de destino en la app
    ruta_app TEXT,  -- /climas/formulario-publico, /prestamos/solicitar, etc.
    
    activa BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(negocio_id, modulo)
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 5: HISTORIAL DE TARJETAS GENERADAS (EXPORTACIONES)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tarjetas_servicio_exportaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarjeta_id UUID REFERENCES tarjetas_servicio(id) ON DELETE CASCADE,
    
    -- Tipo de exportación
    formato VARCHAR(10) NOT NULL CHECK (formato IN ('png', 'pdf', 'svg', 'print')),
    resolucion VARCHAR(20),  -- '300dpi', '150dpi', 'web'
    
    -- Cantidad si es impresión
    cantidad INTEGER DEFAULT 1,
    
    -- Notas
    notas TEXT,
    
    exportado_por UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 6: RLS POLICIES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Habilitar RLS
ALTER TABLE tarjetas_servicio ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarjetas_servicio_escaneos ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarjetas_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarjetas_landing_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarjetas_servicio_exportaciones ENABLE ROW LEVEL SECURITY;

-- Políticas para tarjetas_servicio
DROP POLICY IF EXISTS "tarjetas_servicio_select" ON tarjetas_servicio;
CREATE POLICY "tarjetas_servicio_select" ON tarjetas_servicio
    FOR SELECT USING (
        -- Superadmin ve todo
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin'
        )
        OR
        -- Usuarios del mismo negocio
        negocio_id IN (
            SELECT negocio_id FROM usuarios_negocios WHERE usuario_id = auth.uid()
        )
        OR
        -- Tarjetas activas son públicas (para escaneos)
        activa = true
    );

DROP POLICY IF EXISTS "tarjetas_servicio_insert" ON tarjetas_servicio;
CREATE POLICY "tarjetas_servicio_insert" ON tarjetas_servicio
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre IN ('superadmin', 'admin')
        )
    );

DROP POLICY IF EXISTS "tarjetas_servicio_update" ON tarjetas_servicio;
CREATE POLICY "tarjetas_servicio_update" ON tarjetas_servicio
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre IN ('superadmin', 'admin')
        )
        OR created_by = auth.uid()
    );

DROP POLICY IF EXISTS "tarjetas_servicio_delete" ON tarjetas_servicio;
CREATE POLICY "tarjetas_servicio_delete" ON tarjetas_servicio
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre = 'superadmin'
        )
    );

-- Políticas para escaneos (público puede insertar, solo admin puede leer)
DROP POLICY IF EXISTS "escaneos_insert_public" ON tarjetas_servicio_escaneos;
CREATE POLICY "escaneos_insert_public" ON tarjetas_servicio_escaneos
    FOR INSERT WITH CHECK (true);  -- Cualquiera puede registrar escaneo

DROP POLICY IF EXISTS "escaneos_select" ON tarjetas_servicio_escaneos;
CREATE POLICY "escaneos_select" ON tarjetas_servicio_escaneos
    FOR SELECT USING (
        tarjeta_id IN (
            SELECT id FROM tarjetas_servicio 
            WHERE created_by = auth.uid()
            OR negocio_id IN (SELECT negocio_id FROM usuarios_negocios WHERE usuario_id = auth.uid())
        )
        OR
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre = 'superadmin'
        )
    );

-- Templates son públicos para lectura
DROP POLICY IF EXISTS "templates_select_public" ON tarjetas_templates;
CREATE POLICY "templates_select_public" ON tarjetas_templates
    FOR SELECT USING (activo = true);

-- Landing config
DROP POLICY IF EXISTS "landing_config_select" ON tarjetas_landing_config;
CREATE POLICY "landing_config_select" ON tarjetas_landing_config
    FOR SELECT USING (
        activa = true
        OR negocio_id IN (SELECT negocio_id FROM usuarios_negocios WHERE usuario_id = auth.uid())
        OR EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre = 'superadmin'
        )
    );

DROP POLICY IF EXISTS "landing_config_manage" ON tarjetas_landing_config;
CREATE POLICY "landing_config_manage" ON tarjetas_landing_config
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre IN ('superadmin', 'admin')
        )
    );

-- Exportaciones
DROP POLICY IF EXISTS "exportaciones_all" ON tarjetas_servicio_exportaciones;
CREATE POLICY "exportaciones_all" ON tarjetas_servicio_exportaciones
    FOR ALL USING (
        exportado_por = auth.uid()
        OR EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre = 'superadmin'
        )
    );

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 7: TRIGGERS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_tarjeta_servicio_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_tarjetas_servicio_updated ON tarjetas_servicio;
CREATE TRIGGER tr_tarjetas_servicio_updated
    BEFORE UPDATE ON tarjetas_servicio
    FOR EACH ROW EXECUTE FUNCTION update_tarjeta_servicio_timestamp();

-- Trigger para incrementar contador de escaneos
CREATE OR REPLACE FUNCTION increment_tarjeta_escaneos()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE tarjetas_servicio 
    SET escaneos_total = escaneos_total + 1,
        ultimo_escaneo = NOW()
    WHERE id = NEW.tarjeta_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_increment_escaneos ON tarjetas_servicio_escaneos;
CREATE TRIGGER tr_increment_escaneos
    AFTER INSERT ON tarjetas_servicio_escaneos
    FOR EACH ROW EXECUTE FUNCTION increment_tarjeta_escaneos();

-- Trigger para generar deep_link automáticamente
CREATE OR REPLACE FUNCTION generate_tarjeta_deep_link()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.qr_deep_link IS NULL OR NEW.qr_deep_link = '' THEN
        NEW.qr_deep_link = 'robertdarin://' || NEW.modulo || '/formulario?negocio=' || 
            COALESCE(NEW.negocio_id::TEXT, 'demo') || '&tarjeta=' || NEW.codigo;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_generate_deep_link ON tarjetas_servicio;
CREATE TRIGGER tr_generate_deep_link
    BEFORE INSERT ON tarjetas_servicio
    FOR EACH ROW EXECUTE FUNCTION generate_tarjeta_deep_link();

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 8: FUNCIONES ÚTILES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Función para obtener estadísticas de una tarjeta
CREATE OR REPLACE FUNCTION get_tarjeta_stats(p_tarjeta_id UUID)
RETURNS TABLE (
    total_escaneos INTEGER,
    escaneos_hoy INTEGER,
    escaneos_semana INTEGER,
    escaneos_mes INTEGER,
    conversiones INTEGER,
    tasa_conversion NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_escaneos,
        COUNT(*) FILTER (WHERE e.created_at >= CURRENT_DATE)::INTEGER as escaneos_hoy,
        COUNT(*) FILTER (WHERE e.created_at >= CURRENT_DATE - INTERVAL '7 days')::INTEGER as escaneos_semana,
        COUNT(*) FILTER (WHERE e.created_at >= CURRENT_DATE - INTERVAL '30 days')::INTEGER as escaneos_mes,
        COUNT(*) FILTER (WHERE e.genero_solicitud = true)::INTEGER as conversiones,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(*) FILTER (WHERE e.genero_solicitud = true)::NUMERIC / COUNT(*)) * 100, 2)
            ELSE 0 
        END as tasa_conversion
    FROM tarjetas_servicio_escaneos e
    WHERE e.tarjeta_id = p_tarjeta_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para obtener todas las tarjetas de un negocio con stats
CREATE OR REPLACE FUNCTION get_tarjetas_negocio(p_negocio_id UUID)
RETURNS TABLE (
    tarjeta JSONB,
    estadisticas JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        to_jsonb(t.*) as tarjeta,
        (SELECT to_jsonb(s.*) FROM get_tarjeta_stats(t.id) s) as estadisticas
    FROM tarjetas_servicio t
    WHERE t.negocio_id = p_negocio_id AND t.activa = true
    ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════════
-- FIN DE MIGRACIÓN
-- ═══════════════════════════════════════════════════════════════════════════════

COMMENT ON TABLE tarjetas_servicio IS 'Tarjetas de presentación/servicio con QR para diferentes módulos de negocio';
COMMENT ON TABLE tarjetas_servicio_escaneos IS 'Registro de todos los escaneos QR de las tarjetas';
COMMENT ON TABLE tarjetas_templates IS 'Templates de diseño predefinidos para las tarjetas';
COMMENT ON TABLE tarjetas_landing_config IS 'Configuración de landing pages por módulo y negocio';
