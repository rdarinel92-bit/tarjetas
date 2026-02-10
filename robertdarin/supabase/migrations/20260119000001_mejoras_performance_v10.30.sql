-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN V10.30 — MEJORAS DE PERFORMANCE Y FUNCIONALIDADES
-- Robert Darin Fintech
-- Fecha: 19 de Enero 2026
-- 
-- CAMBIOS:
-- 1. Índices adicionales para consultas frecuentes
-- 2. Funciones RPC para estadísticas optimizadas
-- 3. Cache de estadísticas para dashboard
-- 4. Vistas materializadas para reportes
-- 5. Mejoras de integridad referencial
-- 6. Publicación Realtime para tablas críticas
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 1: ÍNDICES ADICIONALES PARA PERFORMANCE
-- ══════════════════════════════════════════════════════════════════════════════

-- Índices compuestos para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_prestamos_cliente_estado ON prestamos(cliente_id, estado);
CREATE INDEX IF NOT EXISTS idx_prestamos_negocio_estado ON prestamos(negocio_id, estado);
CREATE INDEX IF NOT EXISTS idx_prestamos_fecha_estado ON prestamos(fecha_creacion, estado);
CREATE INDEX IF NOT EXISTS idx_amortizaciones_vencimiento_estado ON amortizaciones(fecha_vencimiento, estado);
CREATE INDEX IF NOT EXISTS idx_amortizaciones_prestamo_estado ON amortizaciones(prestamo_id, estado);
CREATE INDEX IF NOT EXISTS idx_pagos_cliente_fecha ON pagos(cliente_id, fecha_pago);
CREATE INDEX IF NOT EXISTS idx_pagos_negocio_fecha ON pagos(negocio_id, fecha_pago);
CREATE INDEX IF NOT EXISTS idx_clientes_negocio_activo ON clientes(negocio_id, activo);
CREATE INDEX IF NOT EXISTS idx_tandas_negocio_estado ON tandas(negocio_id, estado);
CREATE INDEX IF NOT EXISTS idx_empleados_sucursal_activo ON empleados(sucursal_id, activo);
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_leida ON notificaciones(usuario_id, leida);
CREATE INDEX IF NOT EXISTS idx_chat_mensajes_conv_fecha ON chat_mensajes(conversacion_id, created_at DESC);

-- Extensión para búsquedas de texto (debe ir ANTES del índice)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Índices para búsquedas de texto (ILIKE)
CREATE INDEX IF NOT EXISTS idx_clientes_nombre_trgm ON clientes USING gin(nombre gin_trgm_ops);

-- Índices parciales para estados activos (más eficientes)
CREATE INDEX IF NOT EXISTS idx_prestamos_activos ON prestamos(cliente_id) WHERE estado = 'activo';
CREATE INDEX IF NOT EXISTS idx_prestamos_en_mora ON prestamos(cliente_id) WHERE estado = 'mora';
CREATE INDEX IF NOT EXISTS idx_amortizaciones_pendientes ON amortizaciones(prestamo_id) WHERE estado = 'pendiente';
CREATE INDEX IF NOT EXISTS idx_amortizaciones_vencidas ON amortizaciones(prestamo_id) WHERE estado = 'vencido';
CREATE INDEX IF NOT EXISTS idx_tandas_activas ON tandas(negocio_id) WHERE estado = 'activa';
CREATE INDEX IF NOT EXISTS idx_notificaciones_no_leidas ON notificaciones(usuario_id) WHERE leida = false;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 2: TABLA DE CACHE PARA ESTADÍSTICAS DEL DASHBOARD
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS cache_estadisticas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
    sucursal_id UUID REFERENCES sucursales(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL, -- 'dashboard_global', 'dashboard_sucursal', 'kpi_mensual'
    fecha_calculo TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    periodo TEXT, -- '2026-01', 'semana_3', etc
    datos JSONB NOT NULL DEFAULT '{}',
    expira_en TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 hour'),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(negocio_id, sucursal_id, tipo, periodo)
);

-- Agregar columna expira_en si no existe
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'cache_estadisticas' AND column_name = 'expira_en') THEN
        ALTER TABLE cache_estadisticas ADD COLUMN expira_en TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 hour');
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_cache_estadisticas_negocio ON cache_estadisticas(negocio_id);
CREATE INDEX IF NOT EXISTS idx_cache_estadisticas_tipo ON cache_estadisticas(tipo);
-- El índice para expira_en se crea solo si la columna existe
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'cache_estadisticas' AND column_name = 'expira_en') THEN
        CREATE INDEX IF NOT EXISTS idx_cache_estadisticas_expira ON cache_estadisticas(expira_en);
    END IF;
END $$;

ALTER TABLE cache_estadisticas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cache_estadisticas_auth" ON cache_estadisticas FOR ALL 
USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 3: FUNCIONES RPC OPTIMIZADAS PARA DASHBOARD
-- ══════════════════════════════════════════════════════════════════════════════

-- Función: Obtener estadísticas principales del dashboard
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_negocio_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
    v_resultado JSONB;
    v_cache JSONB;
    v_fecha_inicio DATE;
    v_fecha_fin DATE;
BEGIN
    -- Definir periodo del mes actual
    v_fecha_inicio := date_trunc('month', CURRENT_DATE)::DATE;
    v_fecha_fin := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    
    -- Verificar cache
    SELECT datos INTO v_cache
    FROM cache_estadisticas
    WHERE tipo = 'dashboard_global'
      AND (negocio_id = p_negocio_id OR (p_negocio_id IS NULL AND negocio_id IS NULL))
      AND expira_en > NOW()
    LIMIT 1;
    
    IF v_cache IS NOT NULL THEN
        RETURN v_cache;
    END IF;
    
    -- Calcular estadísticas
    SELECT jsonb_build_object(
        -- Cartera
        'cartera_total', COALESCE((
            SELECT SUM(p.monto)
            FROM prestamos p
            WHERE p.estado IN ('activo', 'mora')
            AND (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ), 0),
        
        'cartera_vencida', COALESCE((
            SELECT SUM(a.monto_cuota)
            FROM amortizaciones a
            JOIN prestamos p ON p.id = a.prestamo_id
            WHERE a.estado = 'vencido'
            AND (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ), 0),
        
        -- Colocación del mes
        'colocado_mes', COALESCE((
            SELECT SUM(monto)
            FROM prestamos
            WHERE fecha_creacion >= v_fecha_inicio
            AND fecha_creacion <= v_fecha_fin
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ), 0),
        
        -- Recuperado del mes
        'recuperado_mes', COALESCE((
            SELECT SUM(monto)
            FROM pagos
            WHERE fecha_pago >= v_fecha_inicio
            AND fecha_pago <= v_fecha_fin
            AND prestamo_id IS NOT NULL
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ), 0),
        
        -- Clientes
        'total_clientes', (
            SELECT COUNT(*)
            FROM clientes
            WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        'clientes_activos', (
            SELECT COUNT(*)
            FROM clientes
            WHERE activo = true
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Préstamos
        'prestamos_activos', (
            SELECT COUNT(*)
            FROM prestamos
            WHERE estado = 'activo'
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        'prestamos_en_mora', (
            SELECT COUNT(*)
            FROM prestamos
            WHERE estado = 'mora'
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Pagos del mes
        'pagos_mes', (
            SELECT COUNT(*)
            FROM pagos
            WHERE fecha_pago >= v_fecha_inicio
            AND fecha_pago <= v_fecha_fin
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Tandas activas
        'tandas_activas', (
            SELECT COUNT(*)
            FROM tandas
            WHERE estado = 'activa'
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Empleados y sucursales
        'total_empleados', (
            SELECT COUNT(*)
            FROM empleados
            WHERE activo = true
        ),
        'total_sucursales', (
            SELECT COUNT(*)
            FROM sucursales
            WHERE activa = true
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Metadatos
        'fecha_calculo', NOW(),
        'periodo', to_char(CURRENT_DATE, 'YYYY-MM')
    ) INTO v_resultado;
    
    -- Guardar en cache (expira en 1 hora)
    INSERT INTO cache_estadisticas (negocio_id, tipo, periodo, datos, expira_en)
    VALUES (p_negocio_id, 'dashboard_global', to_char(CURRENT_DATE, 'YYYY-MM'), v_resultado, NOW() + INTERVAL '1 hour')
    ON CONFLICT (negocio_id, sucursal_id, tipo, periodo) 
    DO UPDATE SET datos = EXCLUDED.datos, expira_en = EXCLUDED.expira_en, fecha_calculo = NOW();
    
    RETURN v_resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función: Obtener cuotas próximas a vencer (próximos 7 días)
CREATE OR REPLACE FUNCTION get_cuotas_proximas(
    p_negocio_id UUID DEFAULT NULL,
    p_dias INTEGER DEFAULT 7
)
RETURNS TABLE (
    amortizacion_id UUID,
    prestamo_id UUID,
    cliente_id UUID,
    cliente_nombre TEXT,
    numero_cuota INTEGER,
    monto_cuota NUMERIC,
    fecha_vencimiento DATE,
    dias_para_vencer INTEGER,
    estado TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id as amortizacion_id,
        a.prestamo_id,
        p.cliente_id,
        c.nombre as cliente_nombre,
        a.numero_cuota,
        a.monto_cuota,
        a.fecha_vencimiento,
        (a.fecha_vencimiento - CURRENT_DATE)::INTEGER as dias_para_vencer,
        a.estado
    FROM amortizaciones a
    JOIN prestamos p ON p.id = a.prestamo_id
    JOIN clientes c ON c.id = p.cliente_id
    WHERE a.estado = 'pendiente'
    AND a.fecha_vencimiento BETWEEN CURRENT_DATE AND (CURRENT_DATE + p_dias)
    AND (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
    ORDER BY a.fecha_vencimiento ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función: Obtener cuotas vencidas (en mora)
CREATE OR REPLACE FUNCTION get_cuotas_vencidas(
    p_negocio_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    amortizacion_id UUID,
    prestamo_id UUID,
    cliente_id UUID,
    cliente_nombre TEXT,
    cliente_telefono TEXT,
    numero_cuota INTEGER,
    monto_cuota NUMERIC,
    fecha_vencimiento DATE,
    dias_mora INTEGER,
    monto_mora NUMERIC,
    aval_nombre TEXT,
    aval_telefono TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id as amortizacion_id,
        a.prestamo_id,
        p.cliente_id,
        c.nombre as cliente_nombre,
        c.telefono as cliente_telefono,
        a.numero_cuota,
        a.monto_cuota,
        a.fecha_vencimiento,
        (CURRENT_DATE - a.fecha_vencimiento)::INTEGER as dias_mora,
        COALESCE(m.monto_mora, 0) as monto_mora,
        av.nombre as aval_nombre,
        av.telefono as aval_telefono
    FROM amortizaciones a
    JOIN prestamos p ON p.id = a.prestamo_id
    JOIN clientes c ON c.id = p.cliente_id
    LEFT JOIN moras_prestamos m ON m.amortizacion_id = a.id
    LEFT JOIN prestamos_avales pa ON pa.prestamo_id = p.id AND pa.orden = 1
    LEFT JOIN avales av ON av.id = pa.aval_id
    WHERE a.estado IN ('vencido', 'pendiente')
    AND a.fecha_vencimiento < CURRENT_DATE
    AND (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
    ORDER BY a.fecha_vencimiento ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función: Resumen de cartera por estado
CREATE OR REPLACE FUNCTION get_resumen_cartera(p_negocio_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'por_estado', (
                SELECT jsonb_agg(jsonb_build_object(
                    'estado', estado,
                    'cantidad', cantidad,
                    'monto_total', monto_total
                ))
                FROM (
                    SELECT 
                        estado,
                        COUNT(*) as cantidad,
                        SUM(monto) as monto_total
                    FROM prestamos
                    WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
                    GROUP BY estado
                ) sub
            ),
            'por_sucursal', (
                SELECT jsonb_agg(jsonb_build_object(
                    'sucursal_id', sucursal_id,
                    'sucursal_nombre', sucursal_nombre,
                    'cantidad', cantidad,
                    'monto_activo', monto_activo
                ))
                FROM (
                    SELECT 
                        p.sucursal_id,
                        s.nombre as sucursal_nombre,
                        COUNT(*) as cantidad,
                        SUM(CASE WHEN p.estado = 'activo' THEN p.monto ELSE 0 END) as monto_activo
                    FROM prestamos p
                    LEFT JOIN sucursales s ON s.id = p.sucursal_id
                    WHERE (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
                    GROUP BY p.sucursal_id, s.nombre
                ) sub
            ),
            'resumen_general', jsonb_build_object(
                'total_prestamos', (SELECT COUNT(*) FROM prestamos WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)),
                'total_colocado', (SELECT COALESCE(SUM(monto), 0) FROM prestamos WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)),
                'total_recuperado', (SELECT COALESCE(SUM(monto), 0) FROM pagos WHERE prestamo_id IS NOT NULL AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)),
                'porcentaje_mora', (
                    SELECT ROUND(
                        (COUNT(*) FILTER (WHERE estado = 'mora')::NUMERIC / 
                         NULLIF(COUNT(*) FILTER (WHERE estado IN ('activo', 'mora')), 0)::NUMERIC) * 100
                    , 2)
                    FROM prestamos 
                    WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
                )
            ),
            'fecha_calculo', NOW()
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función: Historial de pagos de un cliente
CREATE OR REPLACE FUNCTION get_historial_pagos_cliente(
    p_cliente_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    pago_id UUID,
    prestamo_id UUID,
    tanda_id UUID,
    monto NUMERIC,
    metodo_pago TEXT,
    fecha_pago TIMESTAMPTZ,
    numero_cuota INTEGER,
    tipo TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pg.id as pago_id,
        pg.prestamo_id,
        pg.tanda_id,
        pg.monto,
        pg.metodo_pago,
        pg.fecha_pago,
        a.numero_cuota,
        CASE 
            WHEN pg.prestamo_id IS NOT NULL THEN 'prestamo'
            WHEN pg.tanda_id IS NOT NULL THEN 'tanda'
            ELSE 'otro'
        END as tipo
    FROM pagos pg
    LEFT JOIN amortizaciones a ON a.id = pg.amortizacion_id
    WHERE pg.cliente_id = p_cliente_id
    ORDER BY pg.fecha_pago DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función: Estado de cuenta de un préstamo
CREATE OR REPLACE FUNCTION get_estado_cuenta_prestamo(p_prestamo_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_prestamo RECORD;
    v_resultado JSONB;
BEGIN
    -- Obtener datos del préstamo
    SELECT * INTO v_prestamo FROM prestamos WHERE id = p_prestamo_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Préstamo no encontrado');
    END IF;
    
    SELECT jsonb_build_object(
        'prestamo', jsonb_build_object(
            'id', v_prestamo.id,
            'monto', v_prestamo.monto,
            'interes', v_prestamo.interes,
            'plazo_meses', v_prestamo.plazo_meses,
            'frecuencia', v_prestamo.frecuencia_pago,
            'estado', v_prestamo.estado,
            'fecha_creacion', v_prestamo.fecha_creacion
        ),
        'cliente', (
            SELECT jsonb_build_object(
                'id', c.id,
                'nombre', c.nombre,
                'telefono', c.telefono,
                'email', c.email
            )
            FROM clientes c WHERE c.id = v_prestamo.cliente_id
        ),
        'amortizaciones', (
            SELECT jsonb_agg(jsonb_build_object(
                'numero_cuota', a.numero_cuota,
                'monto_cuota', a.monto_cuota,
                'monto_capital', a.monto_capital,
                'monto_interes', a.monto_interes,
                'saldo_restante', a.saldo_restante,
                'fecha_vencimiento', a.fecha_vencimiento,
                'fecha_pago', a.fecha_pago,
                'estado', a.estado
            ) ORDER BY a.numero_cuota)
            FROM amortizaciones a WHERE a.prestamo_id = p_prestamo_id
        ),
        'pagos', (
            SELECT jsonb_agg(jsonb_build_object(
                'id', pg.id,
                'monto', pg.monto,
                'fecha_pago', pg.fecha_pago,
                'metodo_pago', pg.metodo_pago,
                'numero_cuota', a.numero_cuota
            ) ORDER BY pg.fecha_pago DESC)
            FROM pagos pg
            LEFT JOIN amortizaciones a ON a.id = pg.amortizacion_id
            WHERE pg.prestamo_id = p_prestamo_id
        ),
        'resumen', jsonb_build_object(
            'total_a_pagar', (SELECT SUM(monto_cuota) FROM amortizaciones WHERE prestamo_id = p_prestamo_id),
            'total_pagado', (SELECT COALESCE(SUM(monto), 0) FROM pagos WHERE prestamo_id = p_prestamo_id),
            'saldo_pendiente', (
                SELECT SUM(monto_cuota) 
                FROM amortizaciones 
                WHERE prestamo_id = p_prestamo_id AND estado IN ('pendiente', 'vencido')
            ),
            'cuotas_pagadas', (SELECT COUNT(*) FROM amortizaciones WHERE prestamo_id = p_prestamo_id AND estado IN ('pagado', 'pagada')),
            'cuotas_pendientes', (SELECT COUNT(*) FROM amortizaciones WHERE prestamo_id = p_prestamo_id AND estado = 'pendiente'),
            'cuotas_vencidas', (SELECT COUNT(*) FROM amortizaciones WHERE prestamo_id = p_prestamo_id AND estado = 'vencido'),
            'dias_mora_total', (
                SELECT COALESCE(SUM(CURRENT_DATE - fecha_vencimiento), 0)
                FROM amortizaciones 
                WHERE prestamo_id = p_prestamo_id AND estado = 'vencido'
            )
        ),
        'avales', (
            SELECT jsonb_agg(jsonb_build_object(
                'nombre', av.nombre,
                'telefono', av.telefono,
                'relacion', av.relacion,
                'orden', pa.orden
            ) ORDER BY pa.orden)
            FROM prestamos_avales pa
            JOIN avales av ON av.id = pa.aval_id
            WHERE pa.prestamo_id = p_prestamo_id
        ),
        'fecha_consulta', NOW()
    ) INTO v_resultado;
    
    RETURN v_resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 4: FUNCIONES PARA NICE JOYERÍA MLM
-- ══════════════════════════════════════════════════════════════════════════════

-- Función: Dashboard de vendedora Nice
CREATE OR REPLACE FUNCTION get_nice_dashboard_vendedora(p_vendedora_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_fecha_inicio DATE;
    v_fecha_fin DATE;
BEGIN
    v_fecha_inicio := date_trunc('month', CURRENT_DATE)::DATE;
    v_fecha_fin := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    
    RETURN (
        SELECT jsonb_build_object(
            'vendedora', (
                SELECT jsonb_build_object(
                    'id', v.id,
                    'nombre', v.nombre,
                    'codigo', v.codigo_vendedora,
                    'nivel', n.nombre,
                    'nivel_color', n.color,
                    'comision_porcentaje', n.comision_ventas,
                    'meta_mensual', v.meta_mensual,
                    'foto_url', v.foto_url
                )
                FROM nice_vendedoras v
                LEFT JOIN nice_niveles n ON n.id = v.nivel_id
                WHERE v.id = p_vendedora_id
            ),
            'ventas_mes', (
                SELECT COALESCE(SUM(total), 0)
                FROM nice_pedidos
                WHERE vendedora_id = p_vendedora_id
                AND estado = 'entregado'
                AND fecha_pedido >= v_fecha_inicio
                AND fecha_pedido <= v_fecha_fin
            ),
            'comisiones_pendientes', (
                SELECT COALESCE(SUM(monto), 0)
                FROM nice_comisiones
                WHERE vendedora_id = p_vendedora_id
                AND estado = 'pendiente'
            ),
            'pedidos_pendientes', (
                SELECT COUNT(*)
                FROM nice_pedidos
                WHERE vendedora_id = p_vendedora_id
                AND estado = 'pendiente'
            ),
            'clientes_total', (
                SELECT COUNT(*)
                FROM nice_clientes
                WHERE vendedora_id = p_vendedora_id
                AND activo = true
            ),
            'equipo_directo', (
                SELECT COUNT(*)
                FROM nice_vendedoras
                WHERE patrocinadora_id = p_vendedora_id
                AND activa = true
            ),
            'progreso_meta', (
                SELECT jsonb_build_object(
                    'ventas', COALESCE(SUM(total), 0),
                    'meta', v.meta_mensual,
                    'porcentaje', ROUND(COALESCE(SUM(total), 0) / NULLIF(v.meta_mensual, 0) * 100, 1)
                )
                FROM nice_vendedoras v
                LEFT JOIN nice_pedidos p ON p.vendedora_id = v.id
                    AND p.estado = 'entregado'
                    AND p.fecha_pedido >= v_fecha_inicio
                WHERE v.id = p_vendedora_id
                GROUP BY v.meta_mensual
            ),
            'ultimos_pedidos', (
                SELECT jsonb_agg(jsonb_build_object(
                    'id', p.id,
                    'folio', p.folio,
                    'cliente', c.nombre,
                    'total', p.total,
                    'estado', p.estado,
                    'fecha', p.fecha_pedido
                ) ORDER BY p.fecha_pedido DESC)
                FROM (
                    SELECT * FROM nice_pedidos 
                    WHERE vendedora_id = p_vendedora_id
                    ORDER BY fecha_pedido DESC
                    LIMIT 5
                ) p
                LEFT JOIN nice_clientes c ON c.id = p.cliente_id
            ),
            'fecha_consulta', NOW()
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función: Ranking de vendedoras del mes
CREATE OR REPLACE FUNCTION get_nice_ranking_mes(
    p_negocio_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    posicion INTEGER,
    vendedora_id UUID,
    nombre TEXT,
    codigo TEXT,
    nivel TEXT,
    nivel_color TEXT,
    ventas_mes NUMERIC,
    pedidos_mes INTEGER,
    foto_url TEXT
) AS $$
DECLARE
    v_fecha_inicio DATE;
    v_fecha_fin DATE;
BEGIN
    v_fecha_inicio := date_trunc('month', CURRENT_DATE)::DATE;
    v_fecha_fin := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(p.total), 0) DESC)::INTEGER as posicion,
        v.id as vendedora_id,
        v.nombre,
        v.codigo_vendedora as codigo,
        n.nombre as nivel,
        n.color as nivel_color,
        COALESCE(SUM(p.total), 0) as ventas_mes,
        COUNT(p.id)::INTEGER as pedidos_mes,
        v.foto_url
    FROM nice_vendedoras v
    LEFT JOIN nice_niveles n ON n.id = v.nivel_id
    LEFT JOIN nice_pedidos p ON p.vendedora_id = v.id
        AND p.estado = 'entregado'
        AND p.fecha_pedido >= v_fecha_inicio
        AND p.fecha_pedido <= v_fecha_fin
    WHERE v.negocio_id = p_negocio_id
    AND v.activa = true
    GROUP BY v.id, v.nombre, v.codigo_vendedora, n.nombre, n.color, v.foto_url
    ORDER BY ventas_mes DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 5: VISTAS MATERIALIZADAS PARA REPORTES
-- ══════════════════════════════════════════════════════════════════════════════

-- Vista materializada: Resumen mensual de préstamos
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_resumen_mensual_prestamos AS
SELECT 
    date_trunc('month', p.fecha_creacion)::DATE as mes,
    p.negocio_id,
    COUNT(*) as total_prestamos,
    SUM(p.monto) as monto_colocado,
    AVG(p.monto) as monto_promedio,
    AVG(p.interes) as interes_promedio,
    COUNT(*) FILTER (WHERE p.estado = 'pagado') as prestamos_liquidados,
    COUNT(*) FILTER (WHERE p.estado = 'mora') as prestamos_en_mora
FROM prestamos p
GROUP BY date_trunc('month', p.fecha_creacion), p.negocio_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_resumen_mensual ON mv_resumen_mensual_prestamos(mes, negocio_id);

-- Vista materializada: Resumen mensual de pagos
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_resumen_mensual_pagos AS
SELECT 
    date_trunc('month', pg.fecha_pago)::DATE as mes,
    pg.negocio_id,
    COUNT(*) as total_pagos,
    SUM(pg.monto) as monto_recuperado,
    AVG(pg.monto) as pago_promedio,
    COUNT(DISTINCT pg.cliente_id) as clientes_que_pagaron
FROM pagos pg
WHERE pg.fecha_pago IS NOT NULL
GROUP BY date_trunc('month', pg.fecha_pago), pg.negocio_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_resumen_pagos ON mv_resumen_mensual_pagos(mes, negocio_id);

-- Función para refrescar vistas materializadas
CREATE OR REPLACE FUNCTION refresh_vistas_materializadas()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_mensual_prestamos;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_mensual_pagos;
END;
$$ LANGUAGE plpgsql;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 6: TRIGGERS ADICIONALES
-- ══════════════════════════════════════════════════════════════════════════════

-- Trigger: Limpiar cache cuando cambian datos importantes
CREATE OR REPLACE FUNCTION invalidar_cache_estadisticas()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM cache_estadisticas 
    WHERE (negocio_id = NEW.negocio_id OR negocio_id IS NULL)
    AND tipo = 'dashboard_global';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger a tablas que afectan estadísticas
DO $$
BEGIN
    -- Préstamos
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_invalidar_cache_prestamos') THEN
        CREATE TRIGGER trigger_invalidar_cache_prestamos
        AFTER INSERT OR UPDATE OR DELETE ON prestamos
        FOR EACH ROW EXECUTE FUNCTION invalidar_cache_estadisticas();
    END IF;
    
    -- Pagos
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_invalidar_cache_pagos') THEN
        CREATE TRIGGER trigger_invalidar_cache_pagos
        AFTER INSERT OR UPDATE OR DELETE ON pagos
        FOR EACH ROW EXECUTE FUNCTION invalidar_cache_estadisticas();
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 7: TABLAS DE AUDITORÍA MEJORADAS
-- ══════════════════════════════════════════════════════════════════════════════

-- Tabla de logs de actividad del sistema (más ligera que auditoría)
CREATE TABLE IF NOT EXISTS activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    accion TEXT NOT NULL, -- 'login', 'crear_prestamo', 'registrar_pago', etc.
    entidad TEXT, -- 'prestamos', 'clientes', 'pagos'
    entidad_id UUID,
    metadata JSONB DEFAULT '{}',
    ip_address INET,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_log_usuario ON activity_log(usuario_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_accion ON activity_log(accion);
CREATE INDEX IF NOT EXISTS idx_activity_log_fecha ON activity_log(created_at);
CREATE INDEX IF NOT EXISTS idx_activity_log_entidad ON activity_log(entidad, entidad_id);

-- Particionar por mes para mejor performance (opcional, descomentar si hay mucho volumen)
-- CREATE INDEX IF NOT EXISTS idx_activity_log_fecha_mes ON activity_log(date_trunc('month', created_at));

ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "activity_log_admin" ON activity_log FOR ALL 
USING (es_admin_o_superior());

-- Función helper para registrar actividad
CREATE OR REPLACE FUNCTION log_activity(
    p_accion TEXT,
    p_entidad TEXT DEFAULT NULL,
    p_entidad_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO activity_log (usuario_id, accion, entidad, entidad_id, metadata)
    VALUES (auth.uid(), p_accion, p_entidad, p_entidad_id, p_metadata)
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 8: PUBLICACIÓN REALTIME PARA TABLAS CRÍTICAS
-- ══════════════════════════════════════════════════════════════════════════════

-- Habilitar Realtime para tablas importantes
-- Ejecutar esto en Supabase Dashboard > Database > Replication
-- O descomentar las siguientes líneas:

-- ALTER PUBLICATION supabase_realtime ADD TABLE notificaciones;
-- ALTER PUBLICATION supabase_realtime ADD TABLE chat_mensajes;
-- ALTER PUBLICATION supabase_realtime ADD TABLE registros_cobro;
-- ALTER PUBLICATION supabase_realtime ADD TABLE mensajes_aval_cobrador;
-- ALTER PUBLICATION supabase_realtime ADD TABLE pagos;
-- ALTER PUBLICATION supabase_realtime ADD TABLE amortizaciones;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 9: LIMPIEZA Y MANTENIMIENTO AUTOMÁTICO
-- ══════════════════════════════════════════════════════════════════════════════

-- Función para limpiar datos antiguos
CREATE OR REPLACE FUNCTION limpiar_datos_antiguos()
RETURNS VOID AS $$
BEGIN
    -- Limpiar cache expirado
    DELETE FROM cache_estadisticas WHERE expira_en < NOW();
    
    -- Limpiar activity_log mayor a 90 días
    DELETE FROM activity_log WHERE created_at < NOW() - INTERVAL '90 days';
    
    -- Limpiar notificaciones leídas mayores a 30 días
    DELETE FROM notificaciones 
    WHERE leida = true 
    AND created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN DE LA MIGRACIÓN V10.30
-- ══════════════════════════════════════════════════════════════════════════════

-- Nota: Para ejecutar esta migración en Supabase Cloud:
-- 1. supabase db push (si usas CLI)
-- 2. O copiar y pegar en SQL Editor del Dashboard

DO $$ BEGIN RAISE NOTICE 'Migración V10.30 completada exitosamente'; END $$;
