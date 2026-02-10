import 'package:flutter/foundation.dart';
import 'app_routes.dart';

class MenuItemConPermiso {
  final String titulo;
  final String? ruta;
  final String icono;
  final String? color;
  final int? tabIndex;
  final bool esDivider;
  const MenuItemConPermiso({
    required this.titulo,
    this.ruta,
    required this.icono,
    this.color,
    this.tabIndex,
    this.esDivider = false,
  });
}

/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
/// MENÃš COMPLETO POR ROL - V10.29
/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class MenusApp {
  static List<MenuItemConPermiso> obtenerItemsParaRol(String? rol) {
    final List<MenuItemConPermiso> items = [];
    final rolNormalizado = (rol ?? '').trim().toLowerCase();
    
    // DEBUG - quitar despuÃ©s
    debugPrint('ðŸ” MenusApp: rol recibido = "$rol", normalizado = "$rolNormalizado"');
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // SUPERADMIN - ACCESO TOTAL
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    if (rolNormalizado == 'superadmin') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Dashboard', ruta: AppRoutes.dashboardSuperadmin, icono: 'dashboard'),
        MenuItemConPermiso(titulo: 'Centro de Control', ruta: AppRoutes.controlCenter, icono: 'tune', color: 'deepOrange'),
        MenuItemConPermiso(titulo: 'Multi-Empresa', ruta: AppRoutes.centroMultiEmpresa, icono: 'business_center', color: 'deepPurple'),
        MenuItemConPermiso(titulo: 'Sucursales', ruta: AppRoutes.sucursales, icono: 'store', color: 'orange'),

        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),

        MenuItemConPermiso(titulo: 'Finanzas', ruta: AppRoutes.finanzasDashboard, icono: 'account_balance', color: 'green'),
        MenuItemConPermiso(titulo: 'Calendario', ruta: AppRoutes.calendario, icono: 'calendar_month'),

        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),

        MenuItemConPermiso(titulo: 'Contabilidad', ruta: AppRoutes.contabilidad, icono: 'account_balance', color: 'green'),
        MenuItemConPermiso(titulo: 'Facturacion CFDI', ruta: AppRoutes.facturacionDashboard, icono: 'receipt_long', color: 'indigo'),
        MenuItemConPermiso(titulo: 'Tarjetas Virtuales', ruta: AppRoutes.tarjetasDashboard, icono: 'credit_card', color: 'cyan'),
        MenuItemConPermiso(titulo: 'Inventario', ruta: AppRoutes.inventario, icono: 'inventory_2', color: 'orange'),
        MenuItemConPermiso(titulo: 'Historial', ruta: AppRoutes.historial, icono: 'history'),

        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),

        MenuItemConPermiso(titulo: 'Mis empleados', ruta: AppRoutes.empleadosUniversal, icono: 'groups', color: 'orange'),
        MenuItemConPermiso(titulo: 'Empleados', ruta: AppRoutes.empleados, icono: 'badge'),
        MenuItemConPermiso(titulo: 'Recursos Humanos', ruta: AppRoutes.recursosHumanos, icono: 'groups', color: 'indigo'),
        MenuItemConPermiso(titulo: 'Colaboradores', ruta: AppRoutes.colaboradores, icono: 'group_add', color: 'teal'),
        MenuItemConPermiso(titulo: 'Compensaciones', ruta: AppRoutes.compensacionesConfig, icono: 'payments', color: 'green'),
        MenuItemConPermiso(titulo: 'Chat Colaboradores', ruta: AppRoutes.chatColaboradores, icono: 'forum', color: 'purple'),
        MenuItemConPermiso(titulo: 'Rendimientos', ruta: AppRoutes.rendimientosInversionista, icono: 'trending_up', color: 'green'),

        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),

        MenuItemConPermiso(titulo: 'Mensajeria', ruta: AppRoutes.chat, icono: 'chat_bubble_outline', color: 'lightBlue'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),

        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),

        MenuItemConPermiso(titulo: 'Reportes', ruta: AppRoutes.reportes, icono: 'analytics', color: 'green'),
        MenuItemConPermiso(titulo: 'Dashboard KPIs', ruta: AppRoutes.dashboardKpi, icono: 'trending_up', color: 'purple'),
        MenuItemConPermiso(titulo: 'Auditoria Sistema', ruta: AppRoutes.auditoria, icono: 'security'),
        MenuItemConPermiso(titulo: 'Auditoria Legal', ruta: AppRoutes.auditoriaLegal, icono: 'gavel', color: 'red'),
        MenuItemConPermiso(titulo: 'Inversion Global', ruta: AppRoutes.superadminInversionGlobal, icono: 'analytics', color: 'deepOrange'),

        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),

        MenuItemConPermiso(titulo: 'Climas', ruta: AppRoutes.climasDashboard, icono: 'ac_unit', color: 'cyan'),
        MenuItemConPermiso(titulo: 'Tarjetas QR', ruta: AppRoutes.tarjetasServicio, icono: 'qr_code_2', color: 'cyan'),
        MenuItemConPermiso(titulo: 'Ventas', ruta: AppRoutes.ventasDashboard, icono: 'storefront', color: 'purple'),
        MenuItemConPermiso(titulo: 'Agua', ruta: AppRoutes.purificadoraDashboard, icono: 'water_drop', color: 'lightBlue'),
        MenuItemConPermiso(titulo: 'NICE', ruta: AppRoutes.niceDashboard, icono: 'diamond', color: 'purple'),

        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),

        MenuItemConPermiso(titulo: 'Usuarios', ruta: AppRoutes.usuarios, icono: 'manage_accounts', color: 'orange'),
        MenuItemConPermiso(titulo: 'Roles y Permisos', ruta: AppRoutes.roles, icono: 'admin_panel_settings', color: 'orange'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
        MenuItemConPermiso(titulo: 'Gaveteros Modulares', ruta: AppRoutes.gaveterosModulares, icono: 'view_module', color: 'deepOrange'),
        MenuItemConPermiso(titulo: 'Config. APIs', ruta: AppRoutes.configuracionApis, icono: 'api', color: 'indigo'),
        MenuItemConPermiso(titulo: 'Mis Propiedades', ruta: AppRoutes.misPropiedades, icono: 'landscape', color: 'teal'),
        MenuItemConPermiso(titulo: 'Pagos Asignados', ruta: AppRoutes.pagosPropiedadesEmpleado, icono: 'assignment', color: 'cyan'),
      ]);
    }
    else if (rolNormalizado == 'admin') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Dashboard', ruta: AppRoutes.dashboardAdmin, icono: 'dashboard'),
        MenuItemConPermiso(titulo: 'Finanzas', ruta: AppRoutes.finanzasDashboard, icono: 'account_balance', color: 'green'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Mis empleados', ruta: AppRoutes.empleadosUniversal, icono: 'groups', color: 'orange'),
        MenuItemConPermiso(titulo: 'Empleados', ruta: AppRoutes.empleados, icono: 'badge'),
        MenuItemConPermiso(titulo: 'Calendario', ruta: AppRoutes.calendario, icono: 'calendar_month'),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Reportes', ruta: AppRoutes.reportes, icono: 'analytics', color: 'green'),
        MenuItemConPermiso(titulo: 'Dashboard KPIs', ruta: AppRoutes.dashboardKpi, icono: 'trending_up', color: 'purple'),
        MenuItemConPermiso(titulo: 'AuditorÃ­a Sistema', ruta: AppRoutes.auditoria, icono: 'security'),
        MenuItemConPermiso(titulo: 'AuditorÃ­a Legal', ruta: AppRoutes.auditoriaLegal, icono: 'gavel', color: 'red'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // OPERADOR - ACCESO OPERATIVO DIARIO
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'operador') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Dashboard', ruta: AppRoutes.dashboardOperador, icono: 'dashboard'),
        MenuItemConPermiso(titulo: 'Finanzas', ruta: AppRoutes.finanzasDashboard, icono: 'account_balance', color: 'green'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Calendario', ruta: AppRoutes.calendario, icono: 'calendar_month'),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // CLIENTE - SOLO SU INFORMACIÃ“N
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'cliente') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Mi Panel', ruta: AppRoutes.dashboardCliente, icono: 'home'),
        MenuItemConPermiso(titulo: 'Mis PrÃ©stamos', ruta: AppRoutes.prestamos, icono: 'attach_money'),
        MenuItemConPermiso(titulo: 'Mis Tandas', ruta: AppRoutes.tandas, icono: 'group_work'),
        MenuItemConPermiso(titulo: 'Mis Pagos', ruta: AppRoutes.pagos, icono: 'payments'),
        MenuItemConPermiso(titulo: 'ðŸ’³ Mis Tarjetas', ruta: AppRoutes.misTarjetas, icono: 'credit_card', color: 'blue'), // V10.52
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Soporte', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // AVAL - SOLO LO QUE AVALA
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'aval') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Mi Panel', ruta: AppRoutes.dashboardAval, icono: 'shield'),
        MenuItemConPermiso(titulo: 'PrÃ©stamos Avalados', ruta: AppRoutes.prestamos, icono: 'attach_money'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Soporte', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // CONTADOR - ACCESO FINANCIERO
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'contador') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Dashboard', ruta: AppRoutes.dashboard, icono: 'dashboard'),
        MenuItemConPermiso(titulo: 'ðŸ“Š Contabilidad', ruta: AppRoutes.contabilidad, icono: 'account_balance', color: 'green'),
        MenuItemConPermiso(titulo: 'Reportes', ruta: AppRoutes.reportes, icono: 'analytics', color: 'green'),
        MenuItemConPermiso(titulo: 'Finanzas', ruta: AppRoutes.finanzasDashboard, icono: 'account_balance', color: 'green'),
        MenuItemConPermiso(titulo: 'ðŸ§¾ FacturaciÃ³n', ruta: AppRoutes.facturacionDashboard, icono: 'receipt_long', color: 'indigo'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // RECURSOS HUMANOS
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'recursos_humanos') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Dashboard', ruta: AppRoutes.dashboard, icono: 'dashboard'),
        MenuItemConPermiso(titulo: 'ðŸ‘” Recursos Humanos', ruta: AppRoutes.recursosHumanos, icono: 'groups', color: 'indigo'),
        MenuItemConPermiso(titulo: 'Mis empleados', ruta: AppRoutes.empleadosUniversal, icono: 'groups', color: 'orange'),
        MenuItemConPermiso(titulo: 'Empleados', ruta: AppRoutes.empleados, icono: 'badge'),
        MenuItemConPermiso(titulo: 'ðŸ’° Compensaciones', ruta: AppRoutes.compensacionesConfig, icono: 'payments', color: 'green'),
        MenuItemConPermiso(titulo: 'Reportes', ruta: AppRoutes.reportes, icono: 'analytics', color: 'green'),
        MenuItemConPermiso(titulo: 'Calendario', ruta: AppRoutes.calendario, icono: 'calendar_month'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // VENDEDORA NICE
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'vendedora_nice') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Mi Panel', ruta: AppRoutes.dashboardVendedoraNice, icono: 'diamond'),
        MenuItemConPermiso(titulo: 'ðŸ’Ž NICE JoyerÃ­a', ruta: AppRoutes.niceDashboard, icono: 'diamond', color: 'pink'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // TÃ‰CNICO CLIMAS - Panel de trabajo en campo
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'tecnico_climas') {
      items.addAll([
        MenuItemConPermiso(titulo: 'ðŸ‘· Mi Panel', ruta: AppRoutes.dashboardTecnicoClimas, icono: 'ac_unit', color: 'cyan'),
        MenuItemConPermiso(titulo: 'ðŸ“‹ Ã“rdenes de Hoy', ruta: AppRoutes.climasTecnicoApp, icono: 'assignment', color: 'orange'),
        MenuItemConPermiso(titulo: 'ðŸ“… Mi Agenda', ruta: AppRoutes.climasTareas, icono: 'event_note', color: 'blue'),
        MenuItemConPermiso(titulo: 'ðŸ“† Calendario', ruta: AppRoutes.calendario, icono: 'calendar_month'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'ðŸ’¬ MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'ðŸ”” Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'âš™ï¸ Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // CLIENTE CLIMAS - Portal de autoservicio para clientes de A/C
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'cliente_climas') {
      items.addAll([
        MenuItemConPermiso(titulo: 'â„ï¸ Mi Portal A/C', ruta: AppRoutes.climasClientePortal, icono: 'ac_unit', color: 'cyan'),
        MenuItemConPermiso(titulo: 'ðŸ› ï¸ Mis Equipos', ruta: AppRoutes.climasClientePortal, icono: 'hvac', color: 'blue'),
        MenuItemConPermiso(titulo: 'ðŸ“‹ Mis Servicios', ruta: AppRoutes.climasClientePortal, icono: 'build', color: 'orange'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }

    // CLIENTE PURIFICADORA
    else if (rolNormalizado == 'cliente_purificadora') {
      items.addAll([
        MenuItemConPermiso(titulo: 'ðŸ’§ Mi Portal Agua', ruta: AppRoutes.dashboardClientePurificadora, icono: 'water_drop', color: 'lightBlue'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }

    // CLIENTE VENTAS
    else if (rolNormalizado == 'cliente_ventas') {
      items.addAll([
        MenuItemConPermiso(titulo: 'ðŸ›’ Mi Portal Ventas', ruta: AppRoutes.dashboardClienteVentas, icono: 'storefront', color: 'purple'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }

    // CLIENTE NICE
    else if (rolNormalizado == 'cliente_nice') {
      items.addAll([
        MenuItemConPermiso(titulo: 'ðŸ’Ž Mi Portal NICE', ruta: AppRoutes.dashboardClienteNice, icono: 'diamond', color: 'pink'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // REPARTIDOR PURIFICADORA
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'repartidor_purificadora') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Mi Panel', ruta: AppRoutes.dashboardRepartidorPurificadora, icono: 'water_drop'),
        MenuItemConPermiso(titulo: 'ðŸ’§ Purificadora', ruta: AppRoutes.purificadoraDashboard, icono: 'water_drop', color: 'lightBlue'),
        MenuItemConPermiso(titulo: 'Calendario', ruta: AppRoutes.calendario, icono: 'calendar_month'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // VENDEDOR VENTAS
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    else if (rolNormalizado == 'vendedor_ventas') {
      items.addAll([
        MenuItemConPermiso(titulo: 'Mi Panel', ruta: AppRoutes.dashboardVendedorVentas, icono: 'storefront'),
        MenuItemConPermiso(titulo: 'ðŸ›’ Ventas', ruta: AppRoutes.ventasDashboard, icono: 'storefront', color: 'purple'),
        MenuItemConPermiso(titulo: 'Clientes', ruta: AppRoutes.clientes, icono: 'people'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }

    // COLABORADORES
    else if (rolNormalizado.startsWith('colaborador_')) {
      items.addAll([
        MenuItemConPermiso(titulo: 'Mi Panel', ruta: AppRoutes.dashboardColaborador, icono: 'dashboard'),
        MenuItemConPermiso(titulo: 'Estado de Cuenta', ruta: AppRoutes.estadoCuentaInversionista, icono: 'account_balance', color: 'green'),
        MenuItemConPermiso(titulo: 'Mis Facturas', ruta: AppRoutes.misFacturasColaborador, icono: 'receipt_long', color: 'indigo'),
        MenuItemConPermiso(esDivider: true, titulo: '', icono: ''),
        MenuItemConPermiso(titulo: 'MensajerÃ­a', ruta: AppRoutes.chat, icono: 'chat_bubble_outline'),
        MenuItemConPermiso(titulo: 'Notificaciones', ruta: AppRoutes.notificaciones, icono: 'notifications'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    // Fallback - menÃº bÃ¡sico
    else {
      items.addAll([
        MenuItemConPermiso(titulo: 'Dashboard', ruta: AppRoutes.dashboard, icono: 'dashboard'),
        MenuItemConPermiso(titulo: 'Ajustes', ruta: AppRoutes.settings, icono: 'settings'),
      ]);
    }
    
    return items;
  }
}

