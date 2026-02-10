-- ══════════════════════════════════════════════════════════════════════════════
-- SCRIPT DE AUDITORÍA - VERIFICAR TABLAS EN SUPABASE
-- Robert Darin Fintech V10.30
-- 
-- INSTRUCCIONES:
-- 1. Ve a Supabase Dashboard → SQL Editor
-- 2. Copia y pega este script
-- 3. Ejecuta y revisa el resultado
-- ══════════════════════════════════════════════════════════════════════════════

-- Lista todas las tablas esperadas según database_schema.sql
WITH tablas_esperadas AS (
    SELECT unnest(ARRAY[
        -- SECCIÓN 1: IDENTIDAD
        'roles', 'permisos', 'roles_permisos', 'usuarios', 'usuarios_roles',
        
        -- SECCIÓN 2: ESTRUCTURA EMPRESARIAL
        'negocios', 'usuarios_negocios', 'sucursales', 'empleados', 
        'alertas_sistema', 'recordatorios',
        
        -- SECCIÓN 3: CLIENTES
        'clientes', 'expediente_clientes',
        
        -- SECCIÓN 4: PRÉSTAMOS
        'prestamos', 'amortizaciones', 'comisiones_empleados', 'pagos_comisiones',
        
        -- SECCIÓN 5: TANDAS
        'tandas', 'tanda_participantes',
        
        -- SECCIÓN 6: AVALES
        'avales', 'prestamos_avales', 'tandas_avales',
        
        -- SECCIÓN 7: PAGOS
        'pagos', 'comprobantes_prestamo',
        
        -- SECCIÓN 8: CHAT
        'chat_conversaciones', 'chat_mensajes', 'chat_participantes',
        'chats', 'mensajes',
        
        -- SECCIÓN 9: CALENDARIO
        'calendario',
        
        -- SECCIÓN 10: AUDITORÍA
        'auditoria', 'auditoria_acceso', 'auditoria_legal',
        
        -- SECCIÓN 11: NOTIFICACIONES
        'notificaciones_masivas', 'notificaciones',
        
        -- SECCIÓN 12: PROMOCIONES
        'promociones',
        
        -- SECCIÓN 13-16: CONFIGURACIÓN
        'configuracion_global', 'temas_app', 'preferencias_usuario',
        'fondos_pantalla', 'configuracion',
        
        -- SECCIÓN 17: MÉTODOS DE PAGO
        'metodos_pago', 'registros_cobro',
        
        -- SECCIÓN 18-21: AVALES AVANZADO
        'aval_checkins', 'chat_aval_cobrador', 'mensajes_aval_cobrador',
        'firmas_avales', 'notificaciones_mora_aval',
        
        -- SECCIÓN 22-24: MULTI-TENANT
        'usuarios_sucursales', 'modulos_activos', 'configuracion_apis',
        
        -- SECCIÓN 25: TARJETAS
        'tarjetas_digitales', 'transacciones_tarjeta',
        
        -- SECCIÓN 26: DOCUMENTOS AVAL
        'documentos_aval', 'referencias_aval', 'validaciones_aval',
        'verificaciones_identidad', 'log_fraude', 'notificaciones_documento_aval',
        
        -- SECCIÓN 27: AIRES ACONDICIONADOS
        'aires_equipos', 'aires_tecnicos', 'aires_ordenes_servicio', 'aires_garantias',
        
        -- SECCIÓN 28: NOTIFICACIONES SISTEMA
        'notificaciones_sistema',
        
        -- SECCIÓN 29: AUDITORÍA LEGAL
        'intentos_cobro', 'notificaciones_mora', 'expedientes_legales',
        'seguimiento_judicial', 'acuses_recibo', 'promesas_pago',
        
        -- SECCIÓN 32: PROPIEDADES
        'mis_propiedades', 'pagos_propiedades',
        
        -- SECCIÓN 33: MORAS
        'configuracion_moras', 'moras_prestamos', 'moras_tandas',
        'notificaciones_mora_cliente', 'clientes_bloqueados_mora',
        
        -- SECCIÓN 34: ARQUILADO
        'variantes_arquilado',
        
        -- SECCIÓN 34: EMPLEADOS MULTI-NEGOCIO
        'empleados_negocios', 'climas_tecnicos', 'purificadora_repartidores',
        'clientes_modulo',
        
        -- SECCIÓN 35: NICE JOYERÍA
        'nice_catalogos', 'nice_categorias', 'nice_niveles', 'nice_productos',
        'nice_vendedoras', 'nice_clientes', 'nice_pedidos', 'nice_pedido_items',
        'nice_comisiones', 'nice_inventario_vendedora',
        
        -- VENTAS GENERAL
        'ventas_categorias', 'ventas_productos', 'ventas_vendedores',
        'ventas_clientes', 'ventas_pedidos', 'ventas_pedidos_items',
        'ventas_pedidos_detalle',
        
        -- CLIMAS
        'climas_clientes', 'climas_equipos', 'climas_ordenes_servicio',
        'climas_productos', 'climas_cliente_documentos', 'climas_cliente_notas',
        'climas_cliente_contactos', 'climas_cotizaciones',
        
        -- PURIFICADORA
        'purificadora_clientes', 'purificadora_rutas', 'purificadora_productos',
        'purificadora_entregas', 'purificadora_cortes', 'purificadora_produccion',
        'purificadora_precios', 'purificadora_inventario_garrafones',
        
        -- COLABORADORES
        'colaborador_tipos', 'colaboradores', 'colaborador_invitaciones',
        'colaborador_actividad', 'colaborador_inversiones', 'colaborador_rendimientos',
        'colaborador_permisos_modulo',
        
        -- INVENTARIO GENERAL
        'comprobantes', 'inventario', 'inventario_movimientos', 'entregas',
        
        -- STRIPE
        'stripe_config', 'links_pago', 'stripe_transactions_log',
        
        -- QR COBROS
        'qr_cobros', 'qr_cobros_escaneos', 'qr_cobros_config', 'qr_cobros_reportes',
        
        -- FACTURACIÓN
        'facturacion_emisores', 'facturacion_clientes', 'facturas',
        'factura_conceptos', 'factura_impuestos', 'factura_complementos_pago',
        'factura_documentos_relacionados', 'cat_regimen_fiscal',
        'cat_uso_cfdi', 'cat_forma_pago', 'facturacion_logs',
        
        -- CACHE Y OTROS
        'cache_estadisticas', 'activity_log'
    ]) AS tabla_esperada
),
tablas_existentes AS (
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
),
analisis AS (
    SELECT 
        te.tabla_esperada,
        CASE WHEN tex.table_name IS NOT NULL THEN '✅ EXISTE' ELSE '❌ FALTA' END AS estado
    FROM tablas_esperadas te
    LEFT JOIN tablas_existentes tex ON tex.table_name = te.tabla_esperada
)
SELECT * FROM analisis ORDER BY estado DESC, tabla_esperada;

-- ══════════════════════════════════════════════════════════════════════════════
-- RESUMEN
-- ══════════════════════════════════════════════════════════════════════════════

SELECT 
    '📊 RESUMEN DE AUDITORÍA' AS seccion,
    '' AS detalle
UNION ALL
SELECT 
    'Tablas que EXISTEN:',
    COUNT(*)::TEXT
FROM tablas_existentes
UNION ALL
SELECT 
    'Tablas ESPERADAS:',
    (SELECT COUNT(*) FROM tablas_esperadas)::TEXT
UNION ALL
SELECT 
    'Tablas FALTANTES:',
    (SELECT COUNT(*) FROM tablas_esperadas te 
     LEFT JOIN tablas_existentes tex ON tex.table_name = te.tabla_esperada
     WHERE tex.table_name IS NULL)::TEXT;

-- ══════════════════════════════════════════════════════════════════════════════
-- VERIFICAR RLS HABILITADO
-- ══════════════════════════════════════════════════════════════════════════════

SELECT 
    '🔐 TABLAS SIN RLS HABILITADO' AS seccion,
    string_agg(tablename, ', ') AS tablas
FROM pg_tables t
LEFT JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public'
AND NOT c.relrowsecurity
GROUP BY 1;

-- ══════════════════════════════════════════════════════════════════════════════
-- VERIFICAR ÍNDICES
-- ══════════════════════════════════════════════════════════════════════════════

SELECT 
    '📈 CANTIDAD DE ÍNDICES POR TABLA (TOP 10)' AS seccion,
    '' AS detalle
UNION ALL
SELECT 
    tablename,
    COUNT(indexname)::TEXT AS cantidad_indices
FROM pg_indexes
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY COUNT(indexname) DESC
LIMIT 10;
