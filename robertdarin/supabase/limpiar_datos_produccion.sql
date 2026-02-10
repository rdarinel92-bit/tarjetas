-- LIMPIAR DATOS FICTICIOS - DEJAR SOLO ESTRUCTURA
-- Ejecutar en orden para respetar foreign keys

-- 1. TABLAS DE TRANSACCIONES Y REGISTROS
TRUNCATE TABLE activity_log CASCADE;
TRUNCATE TABLE auditoria CASCADE;
TRUNCATE TABLE cache_estadisticas CASCADE;

-- 2. MÓDULO FINANCIERO
TRUNCATE TABLE pagos CASCADE;
TRUNCATE TABLE comprobantes_prestamo CASCADE;
TRUNCATE TABLE comprobantes CASCADE;
TRUNCATE TABLE moras_prestamos CASCADE;
TRUNCATE TABLE amortizaciones CASCADE;
TRUNCATE TABLE prestamos_avales CASCADE;
TRUNCATE TABLE prestamos CASCADE;

-- 3. TANDAS
TRUNCATE TABLE tanda_pagos CASCADE;
TRUNCATE TABLE moras_tandas CASCADE;
TRUNCATE TABLE tanda_participantes CASCADE;
TRUNCATE TABLE tandas_avales CASCADE;
TRUNCATE TABLE tandas CASCADE;

-- 4. CLIENTES Y AVALES
TRUNCATE TABLE documentos_cliente CASCADE;
TRUNCATE TABLE documentos_aval CASCADE;
TRUNCATE TABLE referencias_aval CASCADE;
TRUNCATE TABLE validaciones_aval CASCADE;
TRUNCATE TABLE verificaciones_identidad CASCADE;
TRUNCATE TABLE firmas_avales CASCADE;
TRUNCATE TABLE aval_checkins CASCADE;
TRUNCATE TABLE avales CASCADE;
TRUNCATE TABLE expediente_clientes CASCADE;
TRUNCATE TABLE clientes CASCADE;

-- 5. QR Y COBROS
TRUNCATE TABLE qr_cobros_escaneos CASCADE;
TRUNCATE TABLE qr_cobros_reportes CASCADE;
TRUNCATE TABLE qr_cobros_estadisticas_diarias CASCADE;
TRUNCATE TABLE qr_cobros CASCADE;
TRUNCATE TABLE registros_cobro CASCADE;
TRUNCATE TABLE intentos_cobro CASCADE;
TRUNCATE TABLE promesas_pago CASCADE;

-- 6. FACTURACIÓN
TRUNCATE TABLE factura_impuestos CASCADE;
TRUNCATE TABLE factura_conceptos CASCADE;
TRUNCATE TABLE factura_documentos_relacionados CASCADE;
TRUNCATE TABLE factura_complementos_pago CASCADE;
TRUNCATE TABLE facturacion_logs CASCADE;
TRUNCATE TABLE facturas CASCADE;
TRUNCATE TABLE facturacion_clientes CASCADE;

-- 7. NICE JOYERÍA
TRUNCATE TABLE nice_comisiones CASCADE;
TRUNCATE TABLE nice_pagos CASCADE;
TRUNCATE TABLE nice_pedido_items CASCADE;
TRUNCATE TABLE nice_pedidos CASCADE;
TRUNCATE TABLE nice_inventario_movimientos CASCADE;
TRUNCATE TABLE nice_inventario_vendedora CASCADE;
TRUNCATE TABLE nice_clientes CASCADE;
TRUNCATE TABLE nice_vendedoras CASCADE;
TRUNCATE TABLE nice_productos CASCADE;

-- 8. CLIMAS
TRUNCATE TABLE climas_solicitud_historial CASCADE;
TRUNCATE TABLE climas_solicitudes_qr CASCADE;
TRUNCATE TABLE climas_solicitudes_cliente CASCADE;
TRUNCATE TABLE climas_registro_tiempo CASCADE;
TRUNCATE TABLE climas_solicitudes_refacciones CASCADE;
TRUNCATE TABLE climas_recordatorios_mantenimiento CASCADE;
TRUNCATE TABLE climas_ordenes CASCADE;
TRUNCATE TABLE climas_equipos_cliente CASCADE;
TRUNCATE TABLE climas_clientes CASCADE;
TRUNCATE TABLE climas_tecnico_zonas CASCADE;
TRUNCATE TABLE climas_tecnicos CASCADE;

-- 9. PURIFICADORA
TRUNCATE TABLE purificadora_pagos CASCADE;
TRUNCATE TABLE purificadora_entregas CASCADE;
TRUNCATE TABLE purificadora_cortes CASCADE;
TRUNCATE TABLE purificadora_gastos CASCADE;
TRUNCATE TABLE purificadora_cliente_notas CASCADE;
TRUNCATE TABLE purificadora_cliente_documentos CASCADE;
TRUNCATE TABLE purificadora_cliente_contactos CASCADE;
TRUNCATE TABLE purificadora_clientes CASCADE;
TRUNCATE TABLE purificadora_rutas CASCADE;
TRUNCATE TABLE purificadora_repartidores CASCADE;

-- 10. VENTAS
TRUNCATE TABLE ventas_pagos CASCADE;
TRUNCATE TABLE ventas_pedidos_items CASCADE;
TRUNCATE TABLE ventas_pedidos_detalle CASCADE;
TRUNCATE TABLE ventas_pedidos CASCADE;
TRUNCATE TABLE ventas_cotizaciones CASCADE;
TRUNCATE TABLE ventas_cliente_notas CASCADE;
TRUNCATE TABLE ventas_cliente_documentos CASCADE;
TRUNCATE TABLE ventas_cliente_creditos CASCADE;
TRUNCATE TABLE ventas_cliente_contactos CASCADE;
TRUNCATE TABLE ventas_clientes CASCADE;
TRUNCATE TABLE ventas_vendedores CASCADE;

-- 11. COLABORADORES
TRUNCATE TABLE colaborador_pagos CASCADE;
TRUNCATE TABLE colaborador_compensaciones CASCADE;
TRUNCATE TABLE colaborador_rendimientos CASCADE;
TRUNCATE TABLE colaborador_inversiones CASCADE;
TRUNCATE TABLE colaborador_actividad CASCADE;
TRUNCATE TABLE colaborador_invitaciones CASCADE;
TRUNCATE TABLE colaborador_permisos_modulo CASCADE;
TRUNCATE TABLE colaboradores CASCADE;

-- 12. TARJETAS
TRUNCATE TABLE tarjetas_transacciones CASCADE;
TRUNCATE TABLE tarjetas_recargas CASCADE;
TRUNCATE TABLE tarjetas_log CASCADE;
TRUNCATE TABLE tarjetas_alertas CASCADE;
TRUNCATE TABLE tarjetas_titulares CASCADE;
TRUNCATE TABLE tarjetas_digitales CASCADE;
TRUNCATE TABLE tarjetas_virtuales CASCADE;
TRUNCATE TABLE transacciones_tarjeta CASCADE;

-- 13. NOTIFICACIONES
TRUNCATE TABLE notificaciones CASCADE;
TRUNCATE TABLE notificaciones_masivas CASCADE;
TRUNCATE TABLE notificaciones_mora CASCADE;
TRUNCATE TABLE notificaciones_mora_aval CASCADE;
TRUNCATE TABLE notificaciones_mora_cliente CASCADE;
TRUNCATE TABLE notificaciones_documento_aval CASCADE;
TRUNCATE TABLE notificaciones_sistema CASCADE;

-- 14. CHAT
TRUNCATE TABLE mensajes CASCADE;
TRUNCATE TABLE mensajes_aval_cobrador CASCADE;
TRUNCATE TABLE chat_participantes CASCADE;
TRUNCATE TABLE chat_mensajes CASCADE;
TRUNCATE TABLE chat_conversaciones CASCADE;
TRUNCATE TABLE chats CASCADE;

-- 15. OTROS
TRUNCATE TABLE contratos CASCADE;
TRUNCATE TABLE firmas_digitales CASCADE;
TRUNCATE TABLE links_pago CASCADE;
TRUNCATE TABLE recordatorios CASCADE;
TRUNCATE TABLE inventario_movimientos CASCADE;
TRUNCATE TABLE inventario CASCADE;
TRUNCATE TABLE entregas CASCADE;
TRUNCATE TABLE envios_capital CASCADE;
TRUNCATE TABLE movimientos_capital CASCADE;
TRUNCATE TABLE stripe_transactions_log CASCADE;
TRUNCATE TABLE comisiones_empleados CASCADE;
TRUNCATE TABLE pagos_comisiones CASCADE;
TRUNCATE TABLE expedientes_legales CASCADE;
TRUNCATE TABLE seguimiento_judicial CASCADE;
TRUNCATE TABLE acuses_recibo CASCADE;
TRUNCATE TABLE mis_propiedades CASCADE;
TRUNCATE TABLE pagos_propiedades CASCADE;
TRUNCATE TABLE promociones CASCADE;
TRUNCATE TABLE log_fraude CASCADE;

-- 16. EMPLEADOS (mantener estructura pero limpiar)
TRUNCATE TABLE empleados_negocios CASCADE;
TRUNCATE TABLE empleados CASCADE;

-- 17. USUARIOS (limpiar asignaciones, mantener estructura)
TRUNCATE TABLE usuarios_sucursales CASCADE;
TRUNCATE TABLE usuarios_negocios CASCADE;
TRUNCATE TABLE usuarios_roles CASCADE;
TRUNCATE TABLE preferencias_usuario CASCADE;
TRUNCATE TABLE usuarios CASCADE;

-- NO LIMPIAR (configuración base):
-- roles, permisos, roles_permisos (sistema de permisos)
-- sucursales (configuración)
-- negocios (tu negocio principal)
-- metodos_pago (configuración)
-- nice_niveles, nice_categorias, nice_catalogos (configuración)
-- climas_zonas, climas_catalogo_servicios_publico (configuración)
-- configuracion_moras, configuracion_apis, qr_cobros_config (configuración)

SELECT 'LIMPIEZA COMPLETADA - Base de datos lista para producción' as resultado;
