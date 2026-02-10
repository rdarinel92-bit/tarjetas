/// ══════════════════════════════════════════════════════════════════════════════
/// SISTEMA DE PERMISOS POR ROL
/// ══════════════════════════════════════════════════════════════════════════════
/// Define qué puede ver y hacer cada rol en la aplicación
/// ══════════════════════════════════════════════════════════════════════════════

class PermisosRol {
  /// Módulos disponibles en el sistema
  static const String modDashboard = 'dashboard';
  static const String modClientes = 'clientes';
  static const String modPrestamos = 'prestamos';
  static const String modTandas = 'tandas';
  static const String modAvales = 'avales';
  static const String modEmpleados = 'empleados';
  static const String modPagos = 'pagos';
  static const String modChat = 'chat';
  static const String modCalendario = 'calendario';
  static const String modReportes = 'reportes';
  static const String modAuditoria = 'auditoria';
  static const String modAuditoriaLegal = 'auditoria_legal';
  static const String modUsuarios = 'usuarios';
  static const String modRoles = 'roles';
  static const String modSucursales = 'sucursales';
  static const String modConfiguracion = 'configuracion';
  static const String modControlCenter = 'control_center';
  static const String modCobros = 'cobros';
  static const String modNotificaciones = 'notificaciones';
  static const String modDashboardKpi = 'dashboard_kpi';
  static const String modMisPropiedades = 'mis_propiedades';
  static const String modPagosPropiedadesEmpleado = 'pagos_propiedades_empleado';
  static const String modMoras = 'moras';
  static const String modMultiEmpresa = 'multi_empresa';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO FACTURACIÓN CFDI 4.0 V10.13
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modFacturacion = 'facturacion';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO TARJETAS VIRTUALES V10.14
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modTarjetas = 'tarjetas';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO COLABORADORES V10.15
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modColaboradores = 'colaboradores';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // COMPENSACIONES Y CHAT V10.17
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modCompensaciones = 'compensaciones';
  static const String modChatColaboradores = 'chat_colaboradores';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULOS ADICIONALES V10.13 - Climas, Ventas, Purificadora
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modClimas = 'climas';
  static const String modVentas = 'ventas';
  static const String modPurificadora = 'purificadora';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO NICE JOYERÍA MLM V10.20
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modNiceJoyeria = 'nice_joyeria';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO POLLOS ASADOS V10.60
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modPollos = 'pollos_asados';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO STRIPE PAGOS HÍBRIDOS V10.6
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modStripe = 'stripe';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO CONTABILIDAD V10.11
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modContabilidad = 'contabilidad';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO RECURSOS HUMANOS V10.11
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modRecursosHumanos = 'recursos_humanos';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULOS ADICIONALES V10.25 - Aportaciones, Comprobantes, Ruta Cobro, Inventario
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modAportaciones = 'aportaciones';
  static const String modComprobantes = 'comprobantes';
  static const String modRutaCobro = 'ruta_cobro';
  static const String modInventario = 'inventario';
  static const String modHistorial = 'historial';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // GAVETEROS MODULARES Y APIS V10.28
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modGaveteros = 'gaveteros';
  static const String modConfigApis = 'config_apis';
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // MÓDULO MI CAPITAL V10.52 - Control de inversiones y envíos
  // ═══════════════════════════════════════════════════════════════════════════════
  static const String modMiCapital = 'mi_capital';

  /// Permisos por rol
  static const Map<String, List<String>> permisosPorRol = {
    'superadmin': [
      // TODO - Acceso completo
      modDashboard,
      modClientes,
      modPrestamos,
      modTandas,
      modAvales,
      modEmpleados,
      modPagos,
      modChat,
      modCalendario,
      modReportes,
      modAuditoria,
      modAuditoriaLegal,
      modUsuarios,
      modRoles,
      modSucursales,
      modConfiguracion,
      modControlCenter,
      modCobros,
      modNotificaciones,
      modDashboardKpi,
      modMisPropiedades,
      modPagosPropiedadesEmpleado,
      modMoras,
      modMultiEmpresa,
      // Módulo Facturación CFDI
      modFacturacion,
      // Módulo Tarjetas Virtuales V10.14
      modTarjetas,
      // Módulo Colaboradores V10.15
      modColaboradores,
      // Compensaciones y Chat V10.17
      modCompensaciones,
      modChatColaboradores,
      // Módulos adicionales V10.13
      modClimas,
      modVentas,
      modPurificadora,
      // Módulo NICE Joyería MLM V10.20
      modNiceJoyeria,
      // Módulo Pollos Asados V10.60
      modPollos,
      // Módulo Stripe Pagos Híbridos V10.6
      modStripe,
      // Módulo Contabilidad V10.11
      modContabilidad,
      // Módulo Recursos Humanos V10.11
      modRecursosHumanos,
      // Módulos adicionales V10.25
      modAportaciones,
      modComprobantes,
      modRutaCobro,
      modInventario,
      modHistorial,
      // Gaveteros y APIs V10.28
      modGaveteros,
      modConfigApis,
      // Mi Capital V10.52 - Solo superadmin
      modMiCapital,
    ],
    'admin': [
      // Operativo + Reportes (sin config global ni control center)
      modDashboard,
      modClientes,
      modPrestamos,
      modTandas,
      modAvales,
      modEmpleados,
      modPagos,
      modChat,
      modCalendario,
      modReportes,
      modAuditoria,
      modAuditoriaLegal,
      modCobros,
      modNotificaciones,
      modDashboardKpi,
      modConfiguracion,
      modPagosPropiedadesEmpleado, // Puede pagar propiedades asignadas
      modMoras, // Gestión de moras
      // Módulos V10.25
      modComprobantes,
      modRutaCobro,
      modInventario,
      modHistorial,
    ],
    'operador': [
      // Solo operativo diario
      modDashboard,
      modClientes,
      modPrestamos,
      modTandas,
      modAvales,
      modPagos,
      modChat,
      modCalendario,
      modCobros,
      modNotificaciones,
      modConfiguracion,
      modPagosPropiedadesEmpleado, // Puede pagar propiedades asignadas
      // Módulos V10.25
      modRutaCobro,
      modComprobantes,
    ],
    'cliente': [
      // Solo su información personal - V10.52 MEJORADO
      modDashboard,
      modPrestamos, // Solo los suyos
      modTandas,    // Solo las suyas
      modPagos,     // Solo los suyos
      modChat,
      modNotificaciones,
      modTarjetas,  // V10.52: Sus tarjetas virtuales asignadas
    ],
    'aval': [
      // Solo lo que avala
      modDashboard,
      modPrestamos, // Solo donde es aval
      modChat,
      modNotificaciones,
    ],
    // ═══════════════════════════════════════════════════════════════════════════════
    // ROL VENDEDORA NICE V10.20 - Acceso al módulo de joyería MLM
    // ═══════════════════════════════════════════════════════════════════════════════
    'vendedora_nice': [
      modDashboard,        // Su dashboard personal
      modNiceJoyeria,      // Acceso completo al módulo
      modChat,             // Comunicación
      modNotificaciones,   // Alertas
    ],
    // ═══════════════════════════════════════════════════════════════════════════════
    // ROL TÉCNICO DE CLIMAS V10.21 - Acceso al módulo de aires acondicionados
    // ═══════════════════════════════════════════════════════════════════════════════
    'tecnico_climas': [
      modDashboard,        // Su dashboard de trabajo
      modClimas,           // Módulo de climas/servicios
      modChat,             // Comunicación con clientes y admin
      modNotificaciones,   // Alertas de servicios
      modCalendario,       // Ver su agenda de servicios
    ],
    // ═══════════════════════════════════════════════════════════════════════════════
    // ROL REPARTIDOR PURIFICADORA V10.21 - Acceso al módulo de purificadora
    // ═══════════════════════════════════════════════════════════════════════════════
    'repartidor_purificadora': [
      modDashboard,        // Su dashboard de entregas
      modPurificadora,     // Módulo de purificadora/rutas
      modChat,             // Comunicación con clientes y admin
      modNotificaciones,   // Alertas de entregas
      modCalendario,       // Ver su agenda de rutas
    ],
    // ═══════════════════════════════════════════════════════════════════════════════
    // ROL CLIENTE CLIMAS V10.21 - Acceso para clientes del módulo climas
    // ═══════════════════════════════════════════════════════════════════════════════
    'cliente_climas': [
      modDashboard,        // Su panel de servicios
      modClimas,           // Ver sus equipos y servicios
      modChat,             // Contactar técnicos/admin
      modNotificaciones,   // Alertas de citas
    ],
    // ═══════════════════════════════════════════════════════════════════════════════
    // ROL CLIENTE PURIFICADORA V10.21 - Acceso para clientes del módulo purificadora
    // ═══════════════════════════════════════════════════════════════════════════════
    'cliente_purificadora': [
      modDashboard,        // Su panel de pedidos
      modPurificadora,     // Hacer pedidos, ver historial
      modChat,             // Contactar repartidor/admin
      modNotificaciones,   // Alertas de entregas
    ],
    // ═══════════════════════════════════════════════════════════════════════════════
    // ROL VENDEDOR VENTAS V10.21 - Para empleados del módulo de ventas/catálogo
    // ═══════════════════════════════════════════════════════════════════════════════
    'vendedor_ventas': [
      modDashboard,        // Dashboard de ventas
      modVentas,           // Módulo de ventas completo
      modClientes,         // Gestionar sus clientes
      modChat,             // Comunicación
      modNotificaciones,   // Alertas
    ],
    // ═══════════════════════════════════════════════════════════════════════════════
    // ROL CONTADOR V10.11 - Acceso a información financiera y contable
    // ═══════════════════════════════════════════════════════════════════════════════
    'contador': [
      modDashboard,        // Dashboard financiero
      modContabilidad,     // Panel de contabilidad completo
      modReportes,         // Reportes financieros
      modPrestamos,        // Ver préstamos (solo lectura)
      modPagos,            // Ver pagos recibidos
      modTandas,           // Ver tandas (solo lectura)
      modNotificaciones,   // Alertas
      modFacturacion,      // Facturación CFDI
    ],
    // ═══════════════════════════════════════════════════════════════════════════════
    // ROL RECURSOS HUMANOS V10.11 - Gestión de personal y nómina
    // ═══════════════════════════════════════════════════════════════════════════════
    'recursos_humanos': [
      modDashboard,        // Dashboard de RRHH
      modRecursosHumanos,  // Panel de recursos humanos completo
      modEmpleados,        // Gestión de empleados
      modCompensaciones,   // Comisiones y compensaciones
      modReportes,         // Reportes de personal
      modNotificaciones,   // Alertas
      modCalendario,       // Calendario de eventos
    ],
  };

  /// Verifica si un rol tiene acceso a un módulo
  static bool tieneAcceso(String? rol, String modulo) {
    if (rol == null) return false;
    final permisos = permisosPorRol[rol.toLowerCase()] ?? [];
    return permisos.contains(modulo);
  }

  /// Obtiene todos los módulos de un rol
  static List<String> obtenerModulos(String? rol) {
    if (rol == null) return [];
    return permisosPorRol[rol.toLowerCase()] ?? [];
  }

  /// Verifica si es admin o superior
  static bool esAdminOSuperior(String? rol) {
    return rol == 'superadmin' || rol == 'admin';
  }

  /// Verifica si es operador o superior
  static bool esOperadorOSuperior(String? rol) {
    return rol == 'superadmin' || rol == 'admin' || rol == 'operador';
  }

  /// Verifica si es superadmin
  static bool esSuperadmin(String? rol) {
    return rol == 'superadmin';
  }
}

/// Clase para definir items del menú con permisos
class MenuItemConPermiso {
  final String id;
  final String titulo;
  final dynamic icono; // IconData o String (para rutas de assets)
  final String? ruta;
  final int? tabIndex;
  final String moduloRequerido;
  final bool esDivider;
  final String? color;
  // V10.52: Control granular de roles
  final List<String>? rolesPermitidos;  // Si se especifica, SOLO estos roles ven el item
  final List<String>? rolesExcluidos;   // Si se especifica, estos roles NO ven el item

  const MenuItemConPermiso({
    required this.id,
    required this.titulo,
    this.icono,
    this.ruta,
    this.tabIndex,
    required this.moduloRequerido,
    this.esDivider = false,
    this.color,
    this.rolesPermitidos,
    this.rolesExcluidos,
  });

  const MenuItemConPermiso.divider()
      : id = 'divider',
        titulo = '',
        icono = null,
        ruta = null,
        tabIndex = null,
        moduloRequerido = '',
        esDivider = true,
        color = null,
        rolesPermitidos = null,
        rolesExcluidos = null;
  
  /// V10.52: Verifica si el item es visible para un rol específico
  bool esVisibleParaRol(String rol) {
    // Si hay roles permitidos, solo esos pueden ver
    if (rolesPermitidos != null && rolesPermitidos!.isNotEmpty) {
      return rolesPermitidos!.contains(rol);
    }
    // Si hay roles excluidos, esos no pueden ver
    if (rolesExcluidos != null && rolesExcluidos!.isNotEmpty) {
      return !rolesExcluidos!.contains(rol);
    }
    // Por defecto, visible para todos
    return true;
  }
}

/// Definición de menús por sección
class MenusApp {
  /// Items del drawer lateral
  static const List<MenuItemConPermiso> drawerItems = [
    // Navegación principal
    MenuItemConPermiso(
      id: 'dashboard',
      titulo: 'Dashboard',
      icono: 'dashboard',
      tabIndex: 0,
      moduloRequerido: PermisosRol.modDashboard,
    ),
    MenuItemConPermiso(
      id: 'clientes',
      titulo: 'Clientes',
      icono: 'people',
      ruta: '/clientes',
      moduloRequerido: PermisosRol.modClientes,
    ),
    MenuItemConPermiso(
      id: 'prestamos',
      titulo: 'Préstamos',
      icono: 'attach_money',
      ruta: '/prestamos',
      moduloRequerido: PermisosRol.modPrestamos,
    ),
    MenuItemConPermiso(
      id: 'cotizador',
      titulo: '🧮 Cotizador',
      icono: 'calculate',
      ruta: '/cotizador',
      moduloRequerido: PermisosRol.modPrestamos,
      color: 'cyan',
    ),
    MenuItemConPermiso(
      id: 'tandas',
      titulo: 'Tandas',
      icono: 'group_work',
      ruta: '/tandas',
      moduloRequerido: PermisosRol.modTandas,
    ),
    MenuItemConPermiso(
      id: 'avales',
      titulo: 'Avales',
      icono: 'shield',
      ruta: '/avales',
      moduloRequerido: PermisosRol.modAvales,
    ),
    MenuItemConPermiso(
      id: 'verificar_docs_aval',
      titulo: 'Verificar Docs Avales',
      icono: 'fact_check',
      ruta: '/verificarDocumentosAval',
      moduloRequerido: PermisosRol.modAvales,
      color: 'purple',
    ),
    MenuItemConPermiso(
      id: 'pagos',
      titulo: 'Pagos',
      icono: 'payments',
      ruta: '/pagos',
      moduloRequerido: PermisosRol.modPagos,
    ),
    
    MenuItemConPermiso.divider(),
    
    // Gestión
    MenuItemConPermiso(
      id: 'empleados',
      titulo: 'Empleados',
      icono: 'badge',
      ruta: '/empleados',
      moduloRequerido: PermisosRol.modEmpleados,
    ),
    MenuItemConPermiso(
      id: 'contabilidad',
      titulo: '📊 Contabilidad',
      icono: 'account_balance',
      ruta: '/contabilidad',
      moduloRequerido: PermisosRol.modContabilidad,
      color: 'green',
    ),
    MenuItemConPermiso(
      id: 'aportaciones',
      titulo: '💵 Aportaciones',
      icono: 'savings',
      ruta: '/aportaciones',
      moduloRequerido: PermisosRol.modAportaciones,
      color: 'amber',
    ),
    MenuItemConPermiso(
      id: 'comprobantes',
      titulo: '🧾 Comprobantes',
      icono: 'receipt',
      ruta: '/comprobantes',
      moduloRequerido: PermisosRol.modComprobantes,
      color: 'cyan',
    ),
    MenuItemConPermiso(
      id: 'inventario',
      titulo: '📦 Inventario',
      icono: 'inventory_2',
      ruta: '/inventario',
      moduloRequerido: PermisosRol.modInventario,
      color: 'brown',
    ),
    MenuItemConPermiso(
      id: 'historial',
      titulo: '📜 Historial',
      icono: 'history',
      ruta: '/historial',
      moduloRequerido: PermisosRol.modHistorial,
      color: 'blueGrey',
    ),
    MenuItemConPermiso(
      id: 'recursos_humanos',
      titulo: '👔 Recursos Humanos',
      icono: 'groups',
      ruta: '/recursos-humanos',
      moduloRequerido: PermisosRol.modRecursosHumanos,
      color: 'indigo',
    ),
    MenuItemConPermiso(
      id: 'cobros',
      titulo: 'Cobros Pendientes',
      icono: 'receipt_long',
      ruta: '/cobrosPendientes',
      moduloRequerido: PermisosRol.modCobros,
    ),
    MenuItemConPermiso(
      id: 'ruta_cobro',
      titulo: '🚶 Ruta de Cobro',
      icono: 'directions_walk',
      ruta: '/rutaCobro',
      moduloRequerido: PermisosRol.modRutaCobro,
      color: 'green',
    ),
    MenuItemConPermiso(
      id: 'calendario',
      titulo: 'Calendario',
      icono: 'calendar_month',
      ruta: '/calendario',
      moduloRequerido: PermisosRol.modCalendario,
    ),
    
    MenuItemConPermiso.divider(),
    
    // Comunicación
    MenuItemConPermiso(
      id: 'chat',
      titulo: 'Mensajería',
      icono: 'chat_bubble_outline',
      ruta: '/chat',
      moduloRequerido: PermisosRol.modChat,
      color: 'lightBlue',
    ),
    MenuItemConPermiso(
      id: 'notificaciones',
      titulo: 'Notificaciones',
      icono: 'notifications',
      ruta: '/notificaciones',
      moduloRequerido: PermisosRol.modNotificaciones,
    ),
    
    MenuItemConPermiso.divider(),
    
    // Reportes y Análisis (Admin+)
    MenuItemConPermiso(
      id: 'reportes',
      titulo: 'Reportes',
      icono: 'analytics',
      ruta: '/reportes',
      moduloRequerido: PermisosRol.modReportes,
      color: 'green',
    ),
    MenuItemConPermiso(
      id: 'dashboard_kpi',
      titulo: 'Dashboard KPIs',
      icono: 'trending_up',
      ruta: '/dashboardKpi',
      moduloRequerido: PermisosRol.modDashboardKpi,
      color: 'purple',
    ),
    MenuItemConPermiso(
      id: 'auditoria',
      titulo: 'Auditoría Sistema',
      icono: 'security',
      ruta: '/auditoria',
      moduloRequerido: PermisosRol.modAuditoria,
    ),
    MenuItemConPermiso(
      id: 'auditoria_legal',
      titulo: 'Auditoría Legal',
      icono: 'gavel',
      ruta: '/auditoriaLegal',
      moduloRequerido: PermisosRol.modAuditoriaLegal,
      color: 'red',
    ),
    MenuItemConPermiso(
      id: 'moras',
      titulo: 'Gestión de Moras',
      icono: 'warning_amber',
      ruta: '/moras',
      moduloRequerido: PermisosRol.modMoras,
      color: 'amber',
    ),
    
    MenuItemConPermiso.divider(),
    
    // Administración (Superadmin)
    MenuItemConPermiso(
      id: 'usuarios',
      titulo: 'Usuarios',
      icono: 'manage_accounts',
      ruta: '/usuarios',
      moduloRequerido: PermisosRol.modUsuarios,
      color: 'orange',
    ),
    MenuItemConPermiso(
      id: 'roles',
      titulo: 'Roles y Permisos',
      icono: 'admin_panel_settings',
      ruta: '/roles',
      moduloRequerido: PermisosRol.modRoles,
      color: 'orange',
    ),
    MenuItemConPermiso(
      id: 'sucursales',
      titulo: 'Sucursales',
      icono: 'store',
      ruta: '/sucursales',
      moduloRequerido: PermisosRol.modSucursales,
      color: 'orange',
    ),
    MenuItemConPermiso(
      id: 'configuracion',
      titulo: 'Ajustes',
      icono: 'settings',
      ruta: '/settings',
      moduloRequerido: PermisosRol.modConfiguracion,
    ),
    MenuItemConPermiso(
      id: 'control_center',
      titulo: 'Centro de Control',
      icono: 'tune',
      ruta: '/controlCenter',
      moduloRequerido: PermisosRol.modControlCenter,
      color: 'deepOrange',
    ),
    MenuItemConPermiso(
      id: 'multi_empresa',
      titulo: 'Multi-Empresa',
      icono: 'business_center',
      ruta: '/centroMultiEmpresa',
      moduloRequerido: PermisosRol.modMultiEmpresa,
      color: 'deepPurple',
    ),
    
    MenuItemConPermiso.divider(),
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // COLABORADORES V10.15 - Socios, Inversionistas, Familiares
    // ═══════════════════════════════════════════════════════════════════════════════
    MenuItemConPermiso(
      id: 'colaboradores',
      titulo: '👥 Colaboradores',
      icono: 'group_add',
      ruta: '/colaboradores',
      moduloRequerido: PermisosRol.modColaboradores,
      color: 'teal',
    ),
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // COMPENSACIONES Y CHAT V10.17
    // ═══════════════════════════════════════════════════════════════════════════════
    MenuItemConPermiso(
      id: 'compensaciones',
      titulo: '💰 Compensaciones',
      icono: 'payments',
      ruta: '/compensaciones',
      moduloRequerido: PermisosRol.modCompensaciones,
      color: 'green',
    ),
    MenuItemConPermiso(
      id: 'chat_colaboradores',
      titulo: '💬 Chat Colaboradores',
      icono: 'forum',
      ruta: '/chat-colaboradores',
      moduloRequerido: PermisosRol.modChatColaboradores,
      color: 'purple',
    ),
    MenuItemConPermiso(
      id: 'rendimientos',
      titulo: '📈 Rendimientos',
      icono: 'trending_up',
      ruta: '/rendimientos-inversionista',
      moduloRequerido: PermisosRol.modCompensaciones,
      color: 'green',
    ),
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // TARJETAS VIRTUALES V10.14 / V10.52 MEJORADO
    // ═══════════════════════════════════════════════════════════════════════════════
    MenuItemConPermiso(
      id: 'tarjetas',
      titulo: '💳 Tarjetas Virtuales',
      icono: 'credit_card',
      ruta: '/tarjetas',
      moduloRequerido: PermisosRol.modTarjetas,
      color: 'blue',
      rolesExcluidos: ['cliente', 'aval'], // Admin ve gestión completa
    ),
    MenuItemConPermiso(
      id: 'mis_tarjetas',
      titulo: '💳 Mis Tarjetas',
      icono: 'credit_card',
      ruta: '/mis-tarjetas',
      moduloRequerido: PermisosRol.modTarjetas,
      color: 'blue',
      rolesPermitidos: ['cliente'], // Solo clientes ven sus tarjetas
    ),
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // FACTURACIÓN CFDI 4.0 V10.13
    // ═══════════════════════════════════════════════════════════════════════════════
    MenuItemConPermiso(
      id: 'facturacion',
      titulo: '🧾 Facturación CFDI',
      icono: 'receipt_long',
      ruta: '/facturacion',
      moduloRequerido: PermisosRol.modFacturacion,
      color: 'indigo',
    ),
    
    MenuItemConPermiso.divider(),
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // MÓDULOS ADICIONALES V10.13 - Climas, Ventas, Purificadora
    // ═══════════════════════════════════════════════════════════════════════════════
    MenuItemConPermiso(
      id: 'climas',
      titulo: '❄️ Climas/Aires',
      icono: 'ac_unit',
      ruta: '/climas',
      moduloRequerido: PermisosRol.modClimas,
      color: 'cyan',
    ),
    MenuItemConPermiso(
      id: 'ventas',
      titulo: '🛒 Ventas/Catálogo',
      icono: 'storefront',
      ruta: '/ventas',
      moduloRequerido: PermisosRol.modVentas,
      color: 'purple',
    ),
    MenuItemConPermiso(
      id: 'purificadora',
      titulo: '💧 Purificadora',
      icono: 'water_drop',
      ruta: '/purificadora',
      moduloRequerido: PermisosRol.modPurificadora,
      color: 'lightBlue',
    ),
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // MÓDULO NICE JOYERÍA MLM V10.20
    // ═══════════════════════════════════════════════════════════════════════════════
    MenuItemConPermiso(
      id: 'nice_joyeria',
      titulo: '💎 NICE Joyería',
      icono: 'diamond',
      ruta: '/nice',
      moduloRequerido: PermisosRol.modNiceJoyeria,
      color: 'pink',
    ),
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // MÓDULO POLLOS ASADOS V10.60
    // ═══════════════════════════════════════════════════════════════════════════════
    MenuItemConPermiso(
      id: 'pollos_asados',
      titulo: '🍗 Pollos Asados',
      icono: 'fastfood',
      ruta: '/pollos',
      moduloRequerido: PermisosRol.modPollos,
      color: 'orange',
    ),
    
    MenuItemConPermiso.divider(),
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // GAVETEROS MODULARES Y APIS V10.28
    // ═══════════════════════════════════════════════════════════════════════════════
    MenuItemConPermiso(
      id: 'gaveteros',
      titulo: '🗄️ Gaveteros Modulares',
      icono: 'view_module',
      ruta: '/gaveteros',
      moduloRequerido: PermisosRol.modGaveteros,
      color: 'deepOrange',
    ),
    MenuItemConPermiso(
      id: 'config_apis',
      titulo: '🔌 Config. APIs',
      icono: 'api',
      ruta: '/superadmin/apis',
      moduloRequerido: PermisosRol.modConfigApis,
      color: 'indigo',
    ),
    
    MenuItemConPermiso.divider(),
    
    // Propiedades Personales (Solo Superadmin)
    MenuItemConPermiso(
      id: 'mis_propiedades',
      titulo: 'Mis Propiedades',
      icono: 'landscape',
      ruta: '/misPropiedades',
      moduloRequerido: PermisosRol.modMisPropiedades,
      color: 'teal',
    ),
    // ═══════════════════════════════════════════════════════════════════════════════
    // MI CAPITAL V10.52 - Control de Inversiones (Solo Superadmin)
    // ═══════════════════════════════════════════════════════════════════════════════
    MenuItemConPermiso(
      id: 'mi_capital',
      titulo: '💰 Mi Capital',
      icono: 'account_balance_wallet',
      ruta: '/mi-capital',
      moduloRequerido: PermisosRol.modMiCapital,
      color: 'green',
    ),
    // Pagos de Propiedades (Para empleados asignados)
    MenuItemConPermiso(
      id: 'pagos_propiedades_empleado',
      titulo: 'Pagos Asignados',
      icono: 'assignment',
      ruta: '/pagosPropiedadesEmpleado',
      moduloRequerido: PermisosRol.modPagosPropiedadesEmpleado,
      color: 'cyan',
    ),
  ];

  // Drawer minimal: solo accesos de cuenta
  // V10.61: Habilitar drawer completo para ver todos los módulos
  static const bool _drawerSoloCuenta = false;
  static const Set<String> _itemsCuentaDrawer = {
    'chat',
    'notificaciones',
    'configuracion',
  };
  static const Set<String> _rolesDrawerSoloAjustes = {
    // V10.61: Vacío para mostrar todo el menú
  };
  // Para roles que NO tienen chat en bottom bar, conservar chat en drawer
  static const Set<String> _rolesConChatEnDrawer = {
    'superadmin',
    'admin',
    'operador',
  };

  /// Ocultar accesos duplicados del dashboard de Finanzas (para roles con ese panel)
  static const Set<String> _rolesConDashboardFinanzas = {
    'superadmin',
    'admin',
    'operador',
  };

  static const Set<String> _rolesConDashboardPrincipal = {
    'superadmin',
    'admin',
    'operador',
  };

  static const Set<String> _duplicadosDashboardFinanzas = {
    'clientes',
    'prestamos',
    'cotizador',
    'tandas',
    'avales',
    'verificar_docs_aval',
    'pagos',
    'cobros',
    'moras',
    'aportaciones',
    'comprobantes',
  };

  static const Set<String> _duplicadosDashboardPrincipal = {
    'dashboard',
    'reportes',
    'cobros',
    'notificaciones',
    'climas',
    'ventas',
    'purificadora',
    'nice_joyeria',
    'control_center',
  };

  /// Filtra items según el rol del usuario - V10.52 MEJORADO
  static List<MenuItemConPermiso> obtenerItemsParaRol(String? rol) {
    final items = <MenuItemConPermiso>[];
    bool ultimoFueDivider = true; // Para evitar dividers al inicio
    final rolActual = rol ?? 'cliente';
    final soloCuenta = _drawerSoloCuenta;
    final ocultarDuplicadosFinanzas =
        !soloCuenta && _rolesConDashboardFinanzas.contains(rolActual);
    final ocultarDuplicadosDashboardPrincipal =
        !soloCuenta && _rolesConDashboardPrincipal.contains(rolActual);
    final mostrarChatEnDrawer = _rolesConChatEnDrawer.contains(rolActual);
    final itemsCuentaPermitidos = _rolesDrawerSoloAjustes.contains(rolActual)
        ? const {'configuracion'}
        : _itemsCuentaDrawer;

    for (final item in drawerItems) {
      if (item.esDivider) {
        if (soloCuenta) {
          continue;
        }
        // Solo agregar divider si el anterior no fue divider y hay items después
        if (!ultimoFueDivider && items.isNotEmpty) {
          items.add(item);
          ultimoFueDivider = true;
        }
        continue;
      }

      if (soloCuenta) {
        if (!itemsCuentaPermitidos.contains(item.id)) {
          continue;
        }
        if (item.id == 'chat' && !mostrarChatEnDrawer) {
          continue;
        }
        if (!item.esVisibleParaRol(rolActual)) {
          continue;
        }
        final tienePermiso = item.id == 'configuracion' ||
            PermisosRol.tieneAcceso(rol, item.moduloRequerido);
        if (!tienePermiso) {
          continue;
        }
        items.add(item);
        ultimoFueDivider = false;
        continue;
      }

      if (PermisosRol.tieneAcceso(rol, item.moduloRequerido) &&
          item.esVisibleParaRol(rolActual)) {
        if (ocultarDuplicadosFinanzas &&
            _duplicadosDashboardFinanzas.contains(item.id)) {
          continue;
        }
        if (ocultarDuplicadosDashboardPrincipal &&
            _duplicadosDashboardPrincipal.contains(item.id)) {
          continue;
        }
        // V10.52: Ahora también verifica si el item es visible para el rol
        items.add(item);
        ultimoFueDivider = false;
      }
    }

    // Eliminar divider final si existe
    if (items.isNotEmpty && items.last.esDivider) {
      items.removeLast();
    }

    return items;
  }
}
