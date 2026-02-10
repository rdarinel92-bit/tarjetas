class AppRoutes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const dashboardSuperadmin = '/dashboardSuperadmin';
  static const dashboardAdmin = '/dashboardAdmin';
  static const dashboardOperador = '/dashboardOperador';
  static const dashboardCliente = '/dashboardCliente';
  static const dashboardAval = '/dashboardAval'; // NUEVO: Panel de Aval
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // DASHBOARD COLABORADORES V10.16
  // ═══════════════════════════════════════════════════════════════════════════════
  static const dashboardColaborador = '/dashboardColaborador';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // DASHBOARD VENDEDORA NICE V10.20
  // ═══════════════════════════════════════════════════════════════════════════════
  static const dashboardVendedoraNice = '/dashboardVendedoraNice';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // DASHBOARDS TÉCNICOS, REPARTIDORES Y CLIENTES V10.21
  // ═══════════════════════════════════════════════════════════════════════════════
  static const dashboardTecnicoClimas = '/dashboardTecnicoClimas';
  static const dashboardRepartidorPurificadora = '/dashboardRepartidorPurificadora';
  static const dashboardClienteClimas = '/dashboardClienteClimas';
  static const dashboardClientePurificadora = '/dashboardClientePurificadora';
  static const dashboardClienteVentas = '/dashboardClienteVentas'; // V10.22 Cliente Ventas
  static const dashboardClienteNice = '/dashboardClienteNice'; // V10.22 Cliente Nice MLM
  static const dashboardVendedorVentas = '/dashboardVendedorVentas';
  
  static const empleados = '/empleados';
  static const clientes = '/clientes';
  static const prestamos = '/prestamos';
  static const tandas = '/tandas';
  static const chat = '/chat';
  static const chatDetalle = '/chatDetalle';
  static const pagos = '/pagos';
  static const calendario = '/calendario';
  static const roles = '/roles';
  static const dashboardKpi = '/dashboardKpi';
  
  static const usuarios = '/usuarios';
  static const sucursales = '/sucursales';
  static const inventario = '/inventario';
  static const facturacion = '/facturacion';
  static const entregas = '/entregas';
  static const reportes = '/reportes';
  static const adminPanel = '/adminPanel';
  static const auditoria = '/auditoria';
  static const historial = '/historial';
  static const aportaciones = '/aportaciones';
  static const comprobantes = '/comprobantes';

  static const formularioCliente = '/formularioCliente';
  static const formularioPrestamo = '/formularioPrestamo';
  static const formularioTanda = '/formularioTanda';
  static const formularioEmpleado = '/formularioEmpleado';

  static const formularioPrestamoExistente = '/formularioPrestamoExistente';
  static const formularioTandaExistente = '/formularioTandaExistente';

  // Detalles
  static const detalleTanda = '/detalleTanda';
  static const detallePrestamo = '/detallePrestamo';
  
  // Editar
  static const editarTanda = '/editarTanda';
  static const editarPrestamo = '/editarPrestamo';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // DETALLES COMPLETOS V10.18
  // ═══════════════════════════════════════════════════════════════════════════════
  static const detalleEmpleado = '/detalle-empleado';
  static const detalleClienteCompleto = '/detalle-cliente-completo';
  static const usuariosGestion = '/usuarios-gestion';

  // Avales
  static const avales = '/avales';

  // Nueva ruta de Ajustes
  static const settings = '/settings';

  // Centro de Control Total (Superadmin)
  static const controlCenter = '/controlCenter';

  // Notificaciones
  static const notificaciones = '/notificaciones';

  // Sistema de Cobros V9.0
  static const registrarCobro = '/registrarCobro';
  static const cobrosPendientes = '/cobrosPendientes';
  static const configurarMetodosPago = '/configurarMetodosPago';
  static const rutaCobro = '/rutaCobro';
  
  // Cotizador de Préstamos V10.27
  static const cotizadorPrestamo = '/cotizador';

  // Centro de Finanzas
  static const finanzasDashboard = '/finanzas';
  static const finanzasTarjetasQr = '/finanzas/tarjetas-qr';
  static const finanzasFacturas = '/finanzas/facturas';
  
  // Sistema Legal V10.1
  static const auditoriaLegal = '/auditoriaLegal';
  
  // Información Legal y Copyright V10.51
  static const informacionLegal = '/informacion-legal';
  static const terminosCondiciones = '/terminos-condiciones';
  static const politicaPrivacidad = '/politica-privacidad';
  
  // Verificación Documentos Avales V10.26
  static const verificarDocumentosAval = '/verificarDocumentosAval';
  
  // Propiedades Personales V10.5
  static const misPropiedades = '/misPropiedades';
  static const pagosPropiedadesEmpleado = '/pagosPropiedadesEmpleado';
  
  // Sistema de Moras V10.6
  static const moras = '/moras';
  
  // Centro Control Multi-Empresa V10.11
  static const centroMultiEmpresa = '/centroMultiEmpresa';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO FACTURACIÓN CFDI 4.0 V10.13
  // ═══════════════════════════════════════════════════════════════════════════════
  static const facturacionDashboard = '/facturacion/dashboard';
  static const facturacionConfig = '/facturacion/config';
  static const facturacionNueva = '/facturacion/nueva';
  static const facturacionClientes = '/facturacion/clientes';
  static const facturacionProductos = '/facturacion/productos';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO COLABORADORES V10.16 - Completo con todas las pantallas
  // ═══════════════════════════════════════════════════════════════════════════════
  static const colaboradores = '/colaboradores';
  static const registroColaborador = '/registro-colaborador'; // V10.7 Registro con código
  static const colaboradoresInversionistas = '/colaboradores/inversionistas';
  static const colaboradoresPermisos = '/colaboradores/permisos';
  static const colaboradorInversiones = '/colaboradores/inversiones';
  static const colaboradorActividad = '/colaboradores/actividad';
  static const estadoCuentaInversionista = '/colaboradores/estado-cuenta';
  static const misFacturasColaborador = '/colaboradores/mis-facturas';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // COMPENSACIONES Y CHAT V10.17
  // ═══════════════════════════════════════════════════════════════════════════════
  static const compensacionesConfig = '/compensaciones';
  static const pagosColaboradores = '/pagos-colaboradores';
  static const chatColaboradores = '/chat-colaboradores';
  static const rendimientosInversionista = '/rendimientos-inversionista';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO TARJETAS VIRTUALES V10.14
  // ═══════════════════════════════════════════════════════════════════════════════
  static const tarjetasDashboard = '/tarjetas';
  static const tarjetasConfig = '/tarjetas/config';
  static const tarjetasNueva = '/tarjetas/nueva';
  static const tarjetasTitulares = '/tarjetas/titulares';
  static const tarjetasTitularNuevo = '/tarjetas/titular/nuevo';
  static const tarjetasDetalle = '/tarjetas/detalle';
  static const misTarjetas = '/mis-tarjetas'; // V10.22 - Tarjetas del cliente
  static const solicitudesTarjetas = '/tarjetas/solicitudes'; // V10.52 - Solicitudes QR
  static const tarjetasChat = '/tarjetas/chat'; // V10.53 - Chat de Tarjetas Web
  static const permisosChatQR = '/tarjetas/permisos-chat'; // V10.56 - Permisos Chat QR
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO CLIMAS V10.13 + PROFESIONAL V10.50
  // ═══════════════════════════════════════════════════════════════════════════════
  static const climasDashboard = '/climas';
  static const climasClientes = '/climas/clientes';
  static const climasProductos = '/climas/productos';
  static const climasTecnicos = '/climas/tecnicos';
  static const climasOrdenes = '/climas/ordenes';
  static const climasOrdenNueva = '/climas/ordenes/nueva';
  static const climasOrdenDetalle = '/climas/ordenes/detalle';
  static const climasOrdenEditar = '/climas/ordenes/editar';
  static const climasEquipos = '/climas/equipos';
  static const climasCotizaciones = '/climas/cotizaciones';
  static const climasCotizacionNueva = '/climas/cotizaciones/nueva';
  // V10.50 - Módulo Climas Profesional
  static const climasTareas = '/climas/tareas';
  static const climasClientePortal = '/climas/cliente/portal';
  static const climasClienteDetalle = '/climas/cliente/detalle';
  static const climasClienteFacturas = '/climas/cliente/facturas';
  static const climasClienteGarantias = '/climas/cliente/garantias';
  static const climasClienteHistorial = '/climas/cliente/historial';
  static const climasTecnicoApp = '/climas/tecnico/app';
  static const climasTecnicoOrden = '/climas/tecnico/orden';
  static const climasTecnicoCertificaciones = '/climas/tecnico/certificaciones';
  static const climasTecnicoMetricas = '/climas/tecnico/metricas';
  static const climasTecnicoZonas = '/climas/tecnico/zonas';
  static const climasAdminDashboard = '/climas/admin';
  static const climasAdminConfig = '/climas/admin/configuracion';
  static const climasCalendario = '/climas/calendario';
  static const climasReportes = '/climas/reportes';
  static const climasZonas = '/climas/zonas';
  static const climasSolicitudes = '/climas/solicitudes';
  static const climasSolicitudDetalle = '/climas/solicitudes/detalle';
  static const climasIncidencias = '/climas/incidencias';
  static const climasComisiones = '/climas/comisiones';
  static const climasGarantias = '/climas/garantias';
  static const climasGenerarQrTarjeta = '/climas/generar-qr-tarjeta'; // V10.52 - Generador QR
  static const climasSolicitudesAdmin = '/climas/solicitudes-admin'; // V10.52 - Admin solicitudes QR
  static const climasTarjetasQr = '/climas/tarjetas-qr';
  static const climasFacturas = '/climas/facturas';
  // V10.55 - Mejoras Módulo Climas
  static const climasAnalyticsAvanzado = '/climas/analytics-avanzado';
  static const climasContratos = '/climas/contratos';
  static const climasRutasGps = '/climas/rutas-gps';
  static const climasBaseConocimiento = '/climas/base-conocimiento';
  static const climasAlertas = '/climas/alertas';
  static const climasEvaluaciones = '/climas/evaluaciones';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO VENTAS/CATÁLOGO V10.13
  // ═══════════════════════════════════════════════════════════════════════════════
  static const ventasDashboard = '/ventas';
  static const ventasClientes = '/ventas/clientes';
  static const ventasProductos = '/ventas/productos';
  static const ventasCategorias = '/ventas/categorias';
  static const ventasPedidos = '/ventas/pedidos';
  static const ventasPedidoNuevo = '/ventas/pedidos/nuevo';
  static const ventasApartados = '/ventas/apartados';
  static const ventasVendedores = '/ventas/vendedores';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO PURIFICADORA V10.13
  // ═══════════════════════════════════════════════════════════════════════════════
  static const purificadoraDashboard = '/purificadora';
  static const purificadoraClientes = '/purificadora/clientes';
  static const purificadoraRepartidores = '/purificadora/repartidores';
  static const purificadoraRutas = '/purificadora/rutas';
  static const purificadoraEntregas = '/purificadora/entregas';
  static const purificadoraEntregaNueva = '/purificadora/entregas/nueva';
  static const purificadoraProduccion = '/purificadora/produccion';
  static const purificadoraCortes = '/purificadora/cortes';
  static const purificadoraTarjetasQr = '/purificadora/tarjetas-qr';
  static const purificadoraFacturas = '/purificadora/facturas';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO NICE JOYERÍA MLM V10.20
  // ═══════════════════════════════════════════════════════════════════════════════
  static const niceDashboard = '/nice';
  static const niceVendedoras = '/nice/vendedoras';
  static const niceProductos = '/nice/productos';
  static const nicePedidos = '/nice/pedidos';
  static const niceClientes = '/nice/clientes';
  static const niceComisiones = '/nice/comisiones';
  static const niceEquipo = '/nice/equipo';
  static const niceCategorias = '/nice/categorias'; // V10.22
  static const niceNiveles = '/nice/niveles'; // V10.22
  static const niceCatalogos = '/nice/catalogos'; // V10.22
  static const niceInventario = '/nice/inventario'; // V10.22
  static const niceTarjetasQr = '/nice/tarjetas-qr';
  static const niceFacturas = '/nice/facturas';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // RUTAS ADICIONALES V10.22
  // ═══════════════════════════════════════════════════════════════════════════════
  static const purificadoraProductos = '/purificadora/productos';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // INTEGRACIÓN STRIPE V10.6
  // ═══════════════════════════════════════════════════════════════════════════════
  static const stripeConfig = '/stripe/config';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // CENTRO DE PAGOS Y TARJETAS V10.25 - Vista Unificada
  // ═══════════════════════════════════════════════════════════════════════════════
  static const centroPagosTarjetas = '/centro-pagos-tarjetas';
  static const misPagosPendientes = '/mis-pagos'; // V10.25 - Pagos del cliente
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // SISTEMA QR COBROS V10.7
  // ═══════════════════════════════════════════════════════════════════════════════
  static const qrGenerarCobro = '/qr/generar';
  static const qrEscanearCobro = '/qr/escanear';
  static const qrMonitorCobros = '/qr/monitor';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO CONTABILIDAD Y RRHH V10.11
  // ═══════════════════════════════════════════════════════════════════════════════
  static const contabilidad = '/contabilidad';
  static const recursosHumanos = '/recursos-humanos';
  static const empleadosUniversal = '/empleados/universal';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // RUTAS SUPERADMIN EXCLUSIVAS V10.30
  // ═══════════════════════════════════════════════════════════════════════════════
  static const superadminInversionGlobal = '/superadmin/inversion-global';
  static const gaveterosModulares = '/superadmin/gaveteros';
  static const configuracionApis = '/superadmin/apis';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // SISTEMA MULTI-NEGOCIO V10.31 - Business Switcher + HUB V10.32
  // ═══════════════════════════════════════════════════════════════════════════════
  static const superadminHub = '/superadmin/hub';
  static const superadminNegocios = '/superadmin/negocios';
  static const negocioDashboard = '/negocio-dashboard';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MI CAPITAL - Control de Inversiones V10.52
  // ═══════════════════════════════════════════════════════════════════════════════
  static const miCapital = '/mi-capital';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // TARJETAS DE SERVICIO QR MULTI-NEGOCIO V10.52
  // Sistema profesional para generar tarjetas de presentación con QR
  // Soporta: Climas, Préstamos, Tandas, Servicios, General
  // ═══════════════════════════════════════════════════════════════════════════════
  static const tarjetasServicio = '/tarjetas-servicio';
  static const tarjetasServicioNueva = '/tarjetas-servicio/nueva';
  static const configuradorFormulariosQR = '/configurador-formularios-qr';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // SISTEMA QR AVANZADO V10.54
  // Analytics, Leads CRM, Templates, Compartir Masivo, Impresión Profesional
  // ═══════════════════════════════════════════════════════════════════════════════
  static const qrAnalytics = '/qr/analytics';
  static const qrLeadsBandeja = '/qr/leads';
  static const qrTemplatesPremium = '/qr/templates';
  static const qrCompartirMasivo = '/qr/compartir-masivo';
  static const qrImpresionProfesional = '/qr/impresion-profesional';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO POLLOS ASADOS V10.60
  // Sistema de pedidos para negocio de pollos asados
  // ═══════════════════════════════════════════════════════════════════════════════
  static const pollosDashboard = '/pollos';
  static const pollosPedidos = '/pollos/pedidos';
  static const pollosMenu = '/pollos/menu';
  static const pollosConfig = '/pollos/config';
  static const pollosHistorial = '/pollos/historial';
  static const pollosReportes = '/pollos/reportes';
}
