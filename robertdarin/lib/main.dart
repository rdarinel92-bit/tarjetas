import 'dart:ui'; // V10.26 PlatformDispatcher para Crashlytics
import 'dart:io' show Platform; // V10.50 Detectar plataforma
import 'package:flutter/foundation.dart' show kIsWeb; // V10.50 Detectar web
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart'; // V10.26 Push Notifications
import 'package:firebase_messaging/firebase_messaging.dart'; // V10.26 Push Notifications
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // V10.26 Crashlytics
import 'package:firebase_analytics/firebase_analytics.dart'; // V10.26 Analytics
import 'core/app_navigator.dart';
import 'core/supabase_client.dart';
import 'services/push_notification_service.dart'; // V10.26 Push Notifications
import 'services/deep_link_service.dart'; // V10.51 Deep Links para QR
import 'services/tarjetas_chat_realtime_service.dart'; // V10.54 Chat Realtime
import 'ui/navigation/app_routes.dart';
import 'ui/navigation/app_shell.dart';
import 'ui/viewmodels/auth_viewmodel.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/clientes_screen.dart';
import 'ui/screens/prestamos_screen.dart';
import 'ui/screens/tandas_screen.dart';
import 'ui/screens/empleados_screen.dart';
import 'ui/screens/empleados_universal_screen.dart';
import 'ui/screens/chat_lista_screen.dart';
import 'ui/screens/chat_mensajes_screen.dart';
import 'ui/screens/pagos_screen.dart';
import 'ui/screens/calendario_screen.dart';
import 'ui/screens/roles_permisos_screen.dart';
import 'ui/screens/dashboard_avanzado_screen.dart';
import 'ui/screens/dashboard_cliente_screen.dart';
import 'ui/screens/usuarios_screen.dart';
import 'ui/screens/sucursales_screen.dart';
import 'ui/screens/inventario_screen.dart';
import 'ui/screens/entregas_screen.dart';
import 'ui/screens/reportes_screen.dart';
import 'ui/screens/admin_panel_screen.dart';
import 'ui/screens/auditoria_screen.dart';
import 'ui/screens/auditoria_legal_screen.dart'; // V10.1 Sistema Legal
import 'ui/screens/historial_screen.dart';
import 'ui/screens/aportaciones_screen.dart';
import 'ui/screens/comprobantes_screen.dart';
import 'ui/screens/empleado_form_screen.dart';
import 'ui/screens/settings_screen.dart'; // Nueva pantalla
import 'ui/screens/detalle_tanda_screen.dart';
import 'ui/screens/editar_tanda_screen.dart';
import 'ui/screens/migracion_tanda_screen_v2.dart';
import 'ui/screens/avales_screen.dart';
import 'ui/screens/dashboard_aval_screen.dart';
import 'ui/screens/superadmin_control_center_screen.dart';
import 'ui/screens/formulario_cliente_screen.dart';
import 'ui/screens/migracion_prestamo_screen_v2.dart';
import 'ui/screens/notificaciones_screen.dart';
import 'ui/screens/cobros_pendientes_screen.dart';
import 'ui/screens/ruta_cobro_screen.dart'; // V10.26 Ruta de Cobro (pagos efectivo)
import 'ui/screens/verificar_documentos_aval_screen.dart'; // V10.26 Verificar docs avales
import 'ui/screens/mis_propiedades_screen.dart'; // V10.5 Propiedades Personales
import 'ui/screens/pagos_propiedades_empleado_screen.dart'; // V10.5 Pagos para empleados
import 'ui/screens/moras_screen.dart'; // V10.6 Gestión de Moras
import 'ui/screens/cotizador_prestamo_screen.dart';
import 'ui/screens/finanzas_dashboard_screen.dart';
import 'ui/screens/finanzas_tarjetas_qr_screen.dart';
import 'ui/screens/registrar_cobro_screen.dart'; // V10.10 ConfigurarMetodosPago
import 'ui/screens/detalle_prestamo_screen.dart'; // V10.10 Detalle Préstamo
import 'ui/screens/editar_prestamo_screen.dart';
import 'ui/screens/centro_control_multi_empresa_screen.dart'; // V10.11 Multi-Empresa
import 'ui/screens/terminos_condiciones_screen.dart'; // V10.51 Términos y Condiciones
import 'ui/screens/politica_privacidad_screen.dart'; // V10.51 Política de Privacidad
import 'ui/screens/informacion_legal_screen.dart'; // V10.51 Información Legal
import 'data/models/prestamo_model.dart'; // V10.10 Modelo para detalle

// ═══════════════════════════════════════════════════════════════════════════════
// FACTURACIÓN CFDI 4.0 V10.13
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/facturas_screen.dart';
import 'ui/screens/facturacion_config_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TARJETAS VIRTUALES V10.14 - SISTEMA UNIFICADO
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/tarjetas_screen.dart';
import 'ui/screens/tarjetas_digitales_config_screen.dart'; // V10.22 - Config unificada
import 'ui/screens/mis_tarjetas_screen.dart'; // V10.22 - Tarjetas del cliente
import 'ui/screens/tarjetas_titular_nuevo_screen.dart';
import 'ui/screens/solicitudes_tarjetas_screen.dart'; // V10.52 - Solicitudes QR
import 'ui/screens/tarjetas_chat_screen.dart'; // V10.53 - Chat Web Tarjetas
import 'ui/screens/permisos_chat_qr_screen.dart'; // V10.56 - Permisos Chat QR

// ═══════════════════════════════════════════════════════════════════════════════
// COLABORADORES V10.16 - Socios, Inversionistas, Familiares + Pantallas Completas
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/colaboradores_screen.dart';
import 'ui/screens/dashboard_colaborador_screen.dart';
import 'ui/screens/registro_colaborador_screen.dart'; // V10.7 Registro con código
import 'ui/screens/dashboard_vendedora_nice_screen.dart';
import 'ui/screens/nueva_factura_screen.dart';
import 'ui/screens/estado_cuenta_inversionista_screen.dart';
import 'ui/screens/mis_facturas_colaborador_screen.dart';
import 'ui/screens/simple_table_screen.dart';
import 'ui/screens/negocio_resolver_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// COMPENSACIONES Y CHAT V10.17
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/compensaciones_config_screen.dart';
import 'ui/screens/pagos_colaboradores_screen.dart';
import 'ui/screens/chat_colaboradores_screen.dart';
import 'ui/screens/rendimientos_inversionista_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULOS ADICIONALES V10.13 - Climas, Ventas, Purificadora
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/climas_dashboard_screen.dart';
import 'ui/screens/climas_clientes_screen.dart';
import 'ui/screens/climas_cotizaciones_screen.dart';
import 'ui/screens/climas_ordenes_screen.dart';
import 'ui/screens/climas_tecnicos_screen.dart';
import 'ui/screens/climas_cliente_detalle_screen.dart';
import 'ui/screens/ventas_cliente_detalle_screen.dart';
import 'ui/screens/purificadora_cliente_detalle_screen.dart';
import 'ui/screens/ventas_dashboard_screen.dart';
import 'ui/screens/ventas_clientes_screen.dart';
import 'ui/screens/ventas_productos_screen.dart';
import 'ui/screens/ventas_pedidos_screen.dart';
import 'ui/screens/ventas_vendedores_screen.dart'; // V10.22 Vendedores con auth
import 'ui/screens/ventas_categorias_screen.dart'; // V10.22 Categorías de productos
import 'ui/screens/purificadora_dashboard_screen.dart';
import 'ui/screens/purificadora_clientes_screen.dart';
import 'ui/screens/purificadora_entregas_screen.dart';
import 'ui/screens/purificadora_cortes_screen.dart';
import 'ui/screens/purificadora_repartidores_screen.dart'; // V10.22 Repartidores con auth
import 'ui/screens/purificadora_productos_screen.dart'; // V10.22 Productos
import 'ui/screens/purificadora_rutas_screen.dart'; // V10.22 Rutas de entrega

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO CLIMAS - EQUIPOS V10.22 + PROFESIONAL V10.50
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/climas_equipos_screen.dart'; // V10.22 Equipos A/C
import 'ui/screens/climas_tareas_screen.dart'; // V10.50 Gestión de Tareas
import 'ui/screens/climas_cliente_portal_screen.dart'; // V10.50 Portal Cliente
import 'ui/screens/climas_tecnico_app_screen.dart'; // V10.50 App Técnico Campo
import 'ui/screens/climas_admin_dashboard_screen.dart'; // V10.50 Dashboard Admin
import 'ui/screens/climas_formulario_publico_screen.dart'; // V10.51 Formulario QR Público
import 'ui/screens/climas_solicitudes_admin_screen.dart'; // V10.51 Admin Solicitudes QR
import 'ui/screens/formulario_qr_publico_screen.dart'; // V10.52 Formulario QR Dinámico
// ignore: unused_import
import 'ui/screens/climas_chat_solicitud_screen.dart'; // V10.51 Chat Tiempo Real (usado desde admin panel)
import 'ui/screens/climas_generar_qr_tarjeta_screen.dart'; // V10.51 Generador QR Tarjeta
import 'ui/screens/tarjetas_servicio_screen.dart'; // V10.52 Tarjetas de Servicio QR Multi-Negocio
import 'ui/screens/qr_analytics_dashboard_screen.dart'; // V10.54 Analytics QR
import 'ui/screens/bandeja_leads_qr_screen.dart'; // V10.54 Bandeja Leads QR CRM
import 'ui/screens/templates_premium_qr_screen.dart'; // V10.54 Templates Premium QR
import 'ui/screens/compartir_masivo_qr_screen.dart'; // V10.54 Compartir Masivo QR
import 'ui/screens/impresion_profesional_qr_screen.dart'; // V10.54 Impresión Profesional QR
import 'ui/screens/configurador_formularios_qr_screen.dart'; // V10.52 Configurador Formularios QR
import 'ui/screens/climas_tarjetas_qr_screen.dart';
// V10.55 - Mejoras Módulo Climas
import 'ui/screens/climas_analytics_avanzado_screen.dart';
import 'ui/screens/climas_contratos_screen.dart';
import 'ui/screens/climas_rutas_gps_screen.dart';
import 'ui/screens/climas_base_conocimiento_screen.dart';
import 'ui/screens/climas_alertas_screen.dart';
import 'ui/screens/climas_evaluaciones_screen.dart';
import 'ui/screens/purificadora_tarjetas_qr_screen.dart';
import 'ui/screens/nice_tarjetas_qr_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO NICE JOYERÍA MLM V10.20
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/nice_dashboard_screen.dart';
import 'ui/screens/nice_categorias_screen.dart'; // V10.22 Categorías
import 'ui/screens/nice_niveles_screen.dart'; // V10.22 Niveles MLM
import 'ui/screens/nice_catalogos_screen.dart'; // V10.22 Catálogos
import 'ui/screens/nice_comisiones_screen.dart'; // V10.22 Comisiones MLM
import 'ui/screens/nice_inventario_screen.dart'; // V10.22 Inventario vendedoras
import 'ui/screens/nice_clientes_screen.dart';
import 'ui/screens/nice_productos_screen.dart';
import 'ui/screens/nice_pedidos_screen.dart';
import 'ui/screens/nice_vendedoras_screen.dart';
// Nota: rutas NICE usan negocioId resuelto en runtime

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO POLLOS ASADOS V10.60
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/pollos_dashboard_screen.dart';
import 'ui/screens/pollos_pedidos_screen.dart';
import 'ui/screens/pollos_menu_screen.dart';
import 'ui/screens/pollos_config_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SISTEMA QR COBROS V10.7 - Pantallas
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/qr_cobros/generar_qr_cobro_screen.dart';
import 'ui/screens/qr_cobros/escanear_qr_cobro_screen.dart';
import 'ui/screens/qr_cobros/monitor_qr_cobros_screen.dart';
// pagos_pendientes_qr_screen se usa internamente por otras pantallas

// ═══════════════════════════════════════════════════════════════════════════════
// COLABORADORES - Pantallas adicionales V10.16
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/colaborador_permisos_screen.dart';
import 'ui/screens/colaborador_inversiones_screen.dart';
import 'ui/screens/colaborador_actividad_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARDS TÉCNICOS, REPARTIDORES Y CLIENTES V10.21
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/dashboard_tecnico_climas_screen.dart';
import 'ui/screens/dashboard_repartidor_purificadora_screen.dart';
import 'ui/screens/dashboard_cliente_climas_screen.dart';
import 'ui/screens/dashboard_cliente_purificadora_screen.dart';
import 'ui/screens/dashboard_cliente_ventas_screen.dart'; // V10.22 Cliente Ventas
import 'ui/screens/dashboard_cliente_nice_screen.dart'; // V10.22 Cliente Nice MLM
import 'ui/screens/dashboard_vendedor_ventas_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO CONTABILIDAD Y RRHH V10.11
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/contabilidad_screen.dart';
import 'ui/screens/recursos_humanos_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLAS DETALLE COMPLETAS V10.18
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/detalle_empleado_screen.dart';
import 'ui/screens/detalle_cliente_completo_screen.dart';
import 'ui/screens/usuarios_gestion_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRACIÓN STRIPE V10.6 + CENTRO PAGOS Y TARJETAS V10.25
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/stripe_config_screen.dart';
import 'ui/screens/centro_pagos_tarjetas_screen.dart';
import 'ui/screens/mis_pagos_pendientes_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SUPERADMIN EXCLUSIVO V10.30
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/superadmin_inversion_global_screen.dart';
import 'ui/screens/gaveteros_modulares_screen.dart';
import 'ui/screens/configuracion_apis_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SISTEMA MULTI-NEGOCIO V10.31 - Business Switcher
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/superadmin_negocios_screen.dart';
import 'ui/screens/superadmin_hub_screen.dart'; // V10.32 Hub Central Superadmin
import 'ui/screens/negocio_dashboard_screen.dart';
import 'ui/viewmodels/negocio_activo_provider.dart';
import 'data/models/negocio_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MI CAPITAL - Control de Inversiones V10.52
// ═══════════════════════════════════════════════════════════════════════════════
import 'ui/screens/mi_capital_screen.dart';

// Importaciones de módulos existentes
import 'modules/finanzas/prestamos/views/nuevo_prestamo_view.dart';
import 'modules/finanzas/prestamos/controllers/prestamos_controller.dart';
import 'modules/finanzas/prestamos/controllers/pagos_controller.dart';
import 'modules/finanzas/tandas/views/nueva_tanda_view.dart';
import 'modules/finanzas/tandas/controllers/tandas_controller.dart';
import 'modules/clientes/controllers/usuarios_controller.dart';
import 'modules/finanzas/avales/controllers/avales_controller.dart';
import 'data/repositories/prestamos_repository.dart';
import 'data/repositories/tandas_repository.dart';
import 'data/repositories/usuarios_repository.dart';
import 'data/repositories/avales_repository.dart';
import 'dart:async';
import 'data/repositories/pagos_repository.dart';
import 'ui/viewmodels/theme_viewmodel.dart';

// V10.26 Handler para notificaciones en background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 Notificación en background: ${message.notification?.title}');
}

// V10.26 - Instancia global de Analytics
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

// V10.50 - Función para detectar si Firebase está disponible (solo móvil)
bool get _isFirebaseAvailable {
  if (kIsWeb) return false; // Web no soportado
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

void main() async {
  // Capturar errores de Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
    // V10.50 - Solo enviar a Crashlytics en móvil
    if (_isFirebaseAvailable) {
      try {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } catch (_) {}
    }
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // V10.50 - Inicializar Firebase SOLO en plataformas móviles (Android/iOS)
    if (_isFirebaseAvailable) {
      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        
        // Crashlytics - capturar errores asíncronos
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
        
        // Crashlytics - capturar errores de Dart fuera de Flutter
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
        
        debugPrint('✅ Firebase + Crashlytics + Analytics inicializados');
      } catch (e) {
        debugPrint('⚠️ Error inicializando Firebase: $e');
      }
    } else {
      debugPrint('ℹ️ Firebase deshabilitado en esta plataforma (desktop/web)');
    }
    
    try {
      await initializeDateFormatting('es_MX', null);
    } catch (e) {
      debugPrint('Error inicializando fechas: $e');
    }
    
    try {
      await AppSupabase.init();
    } catch (e) {
      debugPrint('Error inicializando Supabase: $e');
      // Continuar de todos modos para mostrar pantalla de error
    }
    
    // V10.50 - Inicializar servicio de Push Notifications SOLO en móvil
    if (_isFirebaseAvailable) {
      try {
        await PushNotificationService().initialize();
        debugPrint('✅ PushNotificationService inicializado');
      } catch (e) {
        debugPrint('⚠️ Error inicializando PushNotificationService: $e');
      }
    }
    
    // V10.51 - Inicializar Deep Links para QR (solo móvil)
    if (!kIsWeb) {
      try {
        await DeepLinkService().init();
        debugPrint('✅ DeepLinkService inicializado');
      } catch (e) {
        debugPrint('⚠️ Error inicializando DeepLinkService: $e');
      }
    }
    
    // V10.54 - Inicializar Chat Realtime si hay sesión activa
    if (!kIsWeb && Supabase.instance.client.auth.currentSession != null) {
      try {
        await TarjetasChatRealtimeService().inicializar();
        debugPrint('✅ TarjetasChatRealtimeService inicializado');
      } catch (e) {
        debugPrint('⚠️ Error inicializando TarjetasChatRealtimeService: $e');
      }
    }
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          ChangeNotifierProvider(create: (_) => ThemeViewModel()),
          ChangeNotifierProvider(create: (_) => NegocioActivoProvider()), // V10.31 Business Switcher
          Provider(create: (_) => PrestamosController(repository: PrestamosRepository())),
          Provider(create: (_) => TandasController(repository: TandasRepository())),
          Provider(create: (_) => UsuariosController(repository: UsuariosRepository())),
          Provider(create: (_) => AvalesController(repository: AvalesRepository())),
          Provider(create: (_) => PagosController(repository: PagosRepository())),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Error en zona: $error');
    debugPrint('Stack: $stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupDeepLinks();
  }
  
  void _setupDeepLinks() {
    // Configurar callback para deep links
    DeepLinkService().onDeepLink = (route, params) {
      debugPrint('🔗 Navegando a: $route con params: $params');
      // Navegar a la ruta con los parámetros
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appNavigatorKey.currentState?.pushNamed(route, arguments: params);
      });
    };
    
    // Si hay un link inicial pendiente, procesarlo
    final initialUri = DeepLinkService().initialUri;
    if (initialUri != null) {
      final path = initialUri.path.isNotEmpty ? initialUri.path : '/${initialUri.host}';
      final params = Map<String, String>.from(initialUri.queryParameters);
      
      // Mapear ruta
      String? appRoute;
      if (initialUri.host == 'climas') {
        appRoute = '/climas/formulario-publico';
      }
      
      if (appRoute != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appNavigatorKey.currentState?.pushNamed(appRoute!, arguments: params);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeViewModel>(
      builder: (context, themeVm, child) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Uniko',
          theme: themeVm.buildTheme(),
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return child;
          },
          initialRoute: '/',
          onGenerateRoute: (settings) {
            final session = Supabase.instance.client.auth.currentSession;
            final rawName = settings.name ?? '';
            final uri = Uri.tryParse(rawName);
            final routePath = uri?.path ?? rawName;
            final normalizedPath = routePath.endsWith('/') && routePath.length > 1
                ? routePath.substring(0, routePath.length - 1)
                : routePath;
            
            // V10.51 - Rutas públicas (no requieren login)
            final rutasPublicas = [
              '/climas/formulario-publico',
              '/prestamos/solicitar-publico',
              '/prestamos/info-publica',
              '/prestamos/calculadora-publica',
              '/tandas/solicitar-publico',
              '/tandas/info-publica',
              '/tandas/unirse-publico',
              '/tandas/consulta-publica',
              '/servicios/solicitar-publico',
              '/servicios/catalogo-publico',
              '/servicios/contacto-publico',
              '/contacto-publico',
              '/cobranza/portal-cliente',
              '/cobranza/realizar-pago',
              '/cobranza/estado-cuenta',
              '/qr',
              AppRoutes.login,
            ];

            if (normalizedPath == '/qr') {
              final params = uri?.queryParameters ?? const <String, String>{};
              return MaterialPageRoute(
                builder: (_) => FormularioQrPublicoScreen(
                  modulo: (params['modulo'] ?? 'general').toString(),
                  negocioId: params['negocio'] ?? params['negocioId'],
                  tarjetaCodigo: params['tarjeta'] ?? params['tarjetaCodigo'],
                ),
              );
            }
            
            if (session == null && !rutasPublicas.contains(normalizedPath)) {
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            }
            
            // Rutas con argumentos
            switch (normalizedPath) {
        case AppRoutes.detalleTanda:
            final args = settings.arguments;
            String? tandaId;
            var abrirAgregar = false;
            if (args is Map) {
              final map = Map<String, dynamic>.from(args);
              tandaId = map['tandaId']?.toString() ?? map['id']?.toString();
              abrirAgregar = map['abrirAgregarParticipante'] == true || map['abrirAgregar'] == true;
            } else if (args is String) {
              tandaId = args;
            }
              if (tandaId == null || tandaId.isEmpty) {
                return MaterialPageRoute(builder: (_) => const TandasScreen());
              }
              final String tandaIdFinal = tandaId;
              return MaterialPageRoute(
                builder: (_) => DetalleTandaScreen(
                  tandaId: tandaIdFinal,
                  abrirAgregarParticipante: abrirAgregar,
                ),
              );
          case AppRoutes.formularioTandaExistente:
            return MaterialPageRoute(
              builder: (_) => const MigracionTandaScreenV2(),
            );
          case AppRoutes.chatDetalle:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ChatMensajesScreen(
                conversacionId: args?['conversacionId'] ?? '',
                nombreChat: args?['nombre'] ?? 'Chat',
              ),
            );
          case AppRoutes.registrarCobro:
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (_) => RegistrarCobroScreen(
                  clienteId: args['clienteId'] ?? '',
                  clienteNombre: args['clienteNombre'] ?? '',
                  montoEsperado: (args['montoEsperado'] ?? 0).toDouble(),
                  prestamoId: args['prestamoId'],
                  tandaId: args['tandaId'],
                  amortizacionId: args['amortizacionId'],
                  numeroCuota: args['numeroCuota'],
                ),
              );
            }
            return null;
          case AppRoutes.detallePrestamo:
            final prestamo = settings.arguments;
            if (prestamo is PrestamoModel) {
              return MaterialPageRoute(
                builder: (_) => DetallePrestamoScreen(prestamo: prestamo),
              );
            }
            return null;
          case '/climas/cliente/detalle':
            final clienteId = settings.arguments as String?;
            if (clienteId != null) {
              return MaterialPageRoute(
                builder: (_) => ClimasClienteDetalleScreen(clienteId: clienteId),
              );
            }
            return null;
          case '/ventas/cliente/detalle':
            final clienteId = settings.arguments as String?;
            if (clienteId != null) {
              return MaterialPageRoute(
                builder: (_) => VentasClienteDetalleScreen(clienteId: clienteId),
              );
            }
            return null;
          case '/purificadora/cliente/detalle':
            final clienteId = settings.arguments as String?;
            if (clienteId != null) {
              return MaterialPageRoute(
                builder: (_) => PurificadoraClienteDetalleScreen(clienteId: clienteId),
              );
            }
            return null;
          // ════════════════════════════════════════════════════════════════════
          // V10.51 - FORMULARIO PÚBLICO CLIMAS (QR / Deep Link)
          // Soporta: robertdarin://climas/formulario?negocio=XXX
          // ════════════════════════════════════════════════════════════════════
          case '/climas/formulario-publico':
            final args = settings.arguments;
            String? negocioId;
            if (args is Map<String, String>) {
              negocioId = args['negocio'];
            } else if (args is String) {
              negocioId = args;
            }
            return MaterialPageRoute(
              builder: (_) => ClimasFormularioPublicoScreen(negocioId: negocioId),
            );
          case '/prestamos/solicitar-publico':
          case '/prestamos/info-publica':
          case '/prestamos/calculadora-publica':
            return _buildFormularioQrRoute(settings, modulo: 'prestamos');
          case '/tandas/solicitar-publico':
          case '/tandas/info-publica':
          case '/tandas/unirse-publico':
          case '/tandas/consulta-publica':
            return _buildFormularioQrRoute(settings, modulo: 'tandas');
          case '/servicios/solicitar-publico':
          case '/servicios/catalogo-publico':
          case '/servicios/contacto-publico':
            return _buildFormularioQrRoute(settings, modulo: 'servicios');
          case '/contacto-publico':
            return _buildFormularioQrRoute(settings, modulo: 'general');
          case '/cobranza/portal-cliente':
          case '/cobranza/realizar-pago':
          case '/cobranza/estado-cuenta':
            return _buildFormularioQrRoute(settings, modulo: 'cobranza');
          // ════════════════════════════════════════════════════════════════════
          // RUTAS CON ARGUMENTOS PARA DETALLES V10.18
          // ════════════════════════════════════════════════════════════════════
          case AppRoutes.detalleEmpleado:
            final empleadoId = settings.arguments as String?;
            if (empleadoId != null) {
              return MaterialPageRoute(
                builder: (_) => DetalleEmpleadoScreen(empleadoId: empleadoId),
              );
            }
            return null;
          case AppRoutes.detalleClienteCompleto:
            final clienteId = settings.arguments as String?;
            if (clienteId != null) {
              return MaterialPageRoute(
                builder: (_) => DetalleClienteCompletoScreen(clienteId: clienteId),
              );
            }
            return null;
          case AppRoutes.editarPrestamo:
            final args = settings.arguments;
            String? prestamoId;
            if (args is String) prestamoId = args;
            if (args is Map<String, dynamic>) {
              prestamoId = args['prestamoId'] ?? args['id'];
            }
            if (prestamoId != null) {
              final id = prestamoId;
              return MaterialPageRoute(
                builder: (_) => EditarPrestamoScreen(prestamoId: id),
              );
            }
            return null;
          case AppRoutes.editarTanda:
            final args = settings.arguments;
            String? tandaId;
            if (args is String) tandaId = args;
            if (args is Map<String, dynamic>) {
              tandaId = args['tandaId'] ?? args['id'];
            }
            if (tandaId != null) {
              final id = tandaId;
              return MaterialPageRoute(
                builder: (_) => EditarTandaScreen(tandaId: id),
              );
            }
            return null;
          case AppRoutes.tarjetasDetalle:
            final args = settings.arguments;
            String? tarjetaId;
            if (args is String) tarjetaId = args;
            if (args is Map<String, dynamic>) {
              tarjetaId = args['tarjetaId'] ?? args['id'];
            }
            if (tarjetaId != null) {
              return MaterialPageRoute(
                builder: (_) => TarjetasScreen(tarjetaId: tarjetaId),
              );
            }
            return null;
          case '/climas/ordenes/detalle':
          case '/climas/ordenes/editar':
          case '/climas/tecnico/orden':
            final args = settings.arguments;
            String? ordenId;
            if (args is String) ordenId = args;
            if (args is Map<String, dynamic>) {
              ordenId = args['ordenId'] ?? args['id'];
            }
            if (ordenId != null) {
              return MaterialPageRoute(
                builder: (_) => ClimasOrdenesScreen(ordenId: ordenId),
              );
            }
            return null;
          case '/climas/solicitudes/detalle':
            final args = settings.arguments;
            String? solicitudId;
            if (args is String) solicitudId = args;
            if (args is Map<String, dynamic>) {
              solicitudId = args['solicitudId'] ?? args['id'];
            }
            if (solicitudId != null) {
              return MaterialPageRoute(
                builder: (_) => ClimasSolicitudesAdminScreen(solicitudId: solicitudId),
              );
            }
            return null;
          case '/climas/cliente/facturas':
          case '/climas/cliente/garantias':
          case '/climas/cliente/historial':
            final args = settings.arguments;
            String? clienteId;
            if (args is String) clienteId = args;
            if (args is Map<String, dynamic>) {
              clienteId = args['clienteId'] ?? args['id'];
            }
            if (clienteId != null) {
              final id = clienteId;
              return MaterialPageRoute(
                builder: (_) => ClimasClienteDetalleScreen(clienteId: id),
              );
            }
            return null;
          case '/climas/tecnico/certificaciones':
          case '/climas/tecnico/metricas':
          case '/climas/tecnico/zonas':
            final args = settings.arguments;
            String? tecnicoId;
            if (args is String) tecnicoId = args;
            if (args is Map<String, dynamic>) {
              tecnicoId = args['tecnicoId'] ?? args['id'];
            }
            String table = 'climas_certificaciones_tecnico';
            String title = 'Certificaciones';
            if (settings.name == '/climas/tecnico/metricas') {
              table = 'climas_metricas_tecnico';
              title = 'Métricas Técnico';
            } else if (settings.name == '/climas/tecnico/zonas') {
              table = 'climas_tecnico_zonas';
              title = 'Zonas Técnico';
            }
            return MaterialPageRoute(
              builder: (_) => SimpleTableScreen(
                title: title,
                table: table,
                filters: tecnicoId != null ? {'tecnico_id': tecnicoId} : null,
                orderBy: 'created_at',
              ),
            );
          // ════════════════════════════════════════════════════════════════════
          // SISTEMA QR COBROS V10.7 - Rutas con argumentos
          // ════════════════════════════════════════════════════════════════════
          case AppRoutes.qrGenerarCobro:
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (_) => GenerarQrCobroScreen(
                  negocioId: args['negocioId'] ?? '',
                  cobradorId: args['cobradorId'] ?? '',
                  clienteId: args['clienteId'] ?? '',
                  clienteNombre: args['clienteNombre'] ?? '',
                  tipoCobro: args['tipoCobro'] ?? 'prestamo',
                  referenciaId: args['referenciaId'] ?? '',
                  monto: (args['monto'] ?? 0).toDouble(),
                  concepto: args['concepto'] ?? '',
                ),
              );
            }
            return null;
          case AppRoutes.qrEscanearCobro:
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (_) => EscanearQrCobroScreen(
                  clienteId: args['clienteId'] ?? '',
                ),
              );
            }
            return null;
          case AppRoutes.qrMonitorCobros:
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (_) => MonitorQrCobrosScreen(
                  negocioId: args['negocioId'] ?? '',
                ),
              );
            }
            return null;
          // ════════════════════════════════════════════════════════════════════
          // COLABORADORES - Rutas con argumentos V10.16
          // ════════════════════════════════════════════════════════════════════
          case AppRoutes.colaboradoresPermisos:
            final colaboradorId = settings.arguments as String?;
            if (colaboradorId != null) {
              return MaterialPageRoute(
                builder: (_) => ColaboradorPermisosScreen(colaboradorId: colaboradorId),
              );
            }
            return null;
          case AppRoutes.colaboradorInversiones:
            final colaboradorId = settings.arguments as String?;
            if (colaboradorId != null) {
              return MaterialPageRoute(
                builder: (_) => ColaboradorInversionesScreen(colaboradorId: colaboradorId),
              );
            }
            return null;
          case AppRoutes.colaboradorActividad:
            final colaboradorId = settings.arguments as String?;
            if (colaboradorId != null) {
              return MaterialPageRoute(
                builder: (_) => ColaboradorActividadScreen(colaboradorId: colaboradorId),
              );
            }
            return null;
        }
        return null;
      },
      routes: {
        '/': (context) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null) return const LoginScreen();
          return const AuthWrapper();
        },
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.dashboard: (context) => const AppShell(),
        AppRoutes.dashboardSuperadmin: (context) => const AppShell(),
        AppRoutes.dashboardAdmin: (context) => const AppShell(),
        AppRoutes.dashboardOperador: (context) => const AppShell(),
        AppRoutes.dashboardCliente: (context) => const DashboardClienteScreen(),
        AppRoutes.dashboardAval: (context) => const DashboardAvalScreen(),
        AppRoutes.dashboardColaborador: (context) => const DashboardColaboradorScreen(),
        AppRoutes.dashboardVendedoraNice: (context) => const DashboardVendedoraNiceScreen(),
        AppRoutes.dashboardTecnicoClimas: (context) => const DashboardTecnicoClimasScreen(),
        AppRoutes.dashboardRepartidorPurificadora: (context) => const DashboardRepartidorPurificadoraScreen(),
        AppRoutes.dashboardClienteClimas: (context) => const DashboardClienteClimasScreen(),
        AppRoutes.dashboardClientePurificadora: (context) => const DashboardClientePurificadoraScreen(),
        AppRoutes.dashboardClienteVentas: (context) => const DashboardClienteVentasScreen(), // V10.22
        AppRoutes.dashboardClienteNice: (context) => const DashboardClienteNiceScreen(), // V10.22
        AppRoutes.dashboardVendedorVentas: (context) => const DashboardVendedorVentasScreen(),
        AppRoutes.clientes: (context) => const ClientesScreen(),
        AppRoutes.prestamos: (context) => const PrestamosScreen(),
        AppRoutes.tandas: (context) => const TandasScreen(),
        AppRoutes.empleados: (context) => const EmpleadosScreen(),
        AppRoutes.empleadosUniversal: (context) => const EmpleadosUniversalScreen(),
        AppRoutes.chat: (context) => const ChatListaScreen(),
        // chatDetalle manejado en onGenerateRoute
        AppRoutes.pagos: (context) => const PagosScreen(),
        AppRoutes.calendario: (context) => const CalendarioScreen(),
        AppRoutes.roles: (context) => const RolesPermisosScreen(),
        AppRoutes.dashboardKpi: (context) => const DashboardAvanzadoScreen(),
        AppRoutes.usuarios: (context) => const UsuariosScreen(),
        AppRoutes.sucursales: (context) => const SucursalesScreen(),
        AppRoutes.inventario: (context) => const InventarioScreen(),
        AppRoutes.facturacion: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return FacturasScreen(
            moduloOrigen: args?['moduloOrigen'] as String?,
          );
        },  // Pantalla completa de facturación
        AppRoutes.entregas: (context) => const EntregasScreen(),
        AppRoutes.reportes: (context) => const ReportesScreen(),
        AppRoutes.adminPanel: (context) => const AdminPanelScreen(),
        AppRoutes.auditoria: (context) => const AuditoriaScreen(),
        AppRoutes.historial: (context) => const HistorialScreen(),
        AppRoutes.aportaciones: (context) => const AportacionesScreen(),
        AppRoutes.comprobantes: (context) => const ComprobantesScreen(),
        AppRoutes.settings: (context) => const SettingsScreen(),
        AppRoutes.avales: (context) => const AvalesScreen(),
        AppRoutes.controlCenter: (context) => const SuperadminControlCenterScreen(),
        AppRoutes.auditoriaLegal: (context) => const AuditoriaLegalScreen(),
        AppRoutes.verificarDocumentosAval: (context) => const VerificarDocumentosAvalScreen(),
        AppRoutes.notificaciones: (context) => const NotificacionesScreen(),
        AppRoutes.cobrosPendientes: (context) => const CobrosPendientesScreen(),
        AppRoutes.rutaCobro: (context) => const RutaCobroScreen(),
        AppRoutes.misPropiedades: (context) => const MisPropiedadesScreen(),
        AppRoutes.pagosPropiedadesEmpleado: (context) => const PagosPropiedadesEmpleadoScreen(),
        AppRoutes.moras: (context) => const MorasScreen(),
        AppRoutes.configurarMetodosPago: (context) => const ConfigurarMetodosPagoScreen(),
        AppRoutes.centroMultiEmpresa: (context) => const CentroControlMultiEmpresaScreen(),
        AppRoutes.cotizadorPrestamo: (context) => const CotizadorPrestamoScreen(), // V10.27
        AppRoutes.finanzasDashboard: (context) => const FinanzasDashboardScreen(),
        AppRoutes.finanzasTarjetasQr: (context) => const FinanzasTarjetasQrScreen(),
        AppRoutes.finanzasFacturas: (context) => const FacturasScreen(moduloOrigen: 'fintech'),
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // INFORMACIÓN LEGAL Y COPYRIGHT V10.51
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.informacionLegal: (context) => const InformacionLegalScreen(),
        AppRoutes.terminosCondiciones: (context) => const TerminosCondicionesScreen(),
        AppRoutes.politicaPrivacidad: (context) => const PoliticaPrivacidadScreen(),
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // MÓDULO CONTABILIDAD Y RRHH V10.11
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.contabilidad: (context) => const ContabilidadScreen(),
        AppRoutes.recursosHumanos: (context) => const RecursosHumanosScreen(),
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // INTEGRACIÓN STRIPE V10.6 + CENTRO PAGOS Y TARJETAS V10.25
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.stripeConfig: (context) => const StripeConfigScreen(),
        AppRoutes.centroPagosTarjetas: (context) => const CentroPagosTarjetasScreen(),
        AppRoutes.misPagosPendientes: (context) => const MisPagosPendientesScreen(),
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // FACTURACIÓN CFDI 4.0 V10.13
        // ═══════════════════════════════════════════════════════════════════════════════
        // facturacion usa FacturasScreen (definida arriba)
        AppRoutes.facturacionDashboard: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return FacturasScreen(
            moduloOrigen: args?['moduloOrigen'] as String?,
          );
        },
        AppRoutes.facturacionClientes: (context) => SimpleTableScreen(
          title: 'Clientes Fiscales',
          table: 'facturacion_clientes',
          orderBy: 'created_at',
        ),
        AppRoutes.facturacionProductos: (context) => SimpleTableScreen(
          title: 'Productos Facturables',
          table: 'facturacion_productos',
          orderBy: 'created_at',
        ),
        '/nueva-factura': (context) => const NuevaFacturaScreen(),
        AppRoutes.facturacionConfig: (context) => const FacturacionConfigScreen(),
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // TARJETAS VIRTUALES V10.14 - SISTEMA UNIFICADO
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.tarjetasDashboard: (context) => const TarjetasScreen(),
        AppRoutes.tarjetasConfig: (context) => const TarjetasDigitalesConfigScreen(), // V10.22 - Unificado
        AppRoutes.misTarjetas: (context) => const MisTarjetasScreen(), // V10.22
        AppRoutes.solicitudesTarjetas: (context) => const SolicitudesTarjetasScreen(), // V10.52
        AppRoutes.tarjetasChat: (context) => const TarjetasChatScreen(), // V10.53 - Chat Web
        AppRoutes.permisosChatQR: (context) => const PermisosChatQRScreen(), // V10.56 - Permisos Chat QR
        AppRoutes.tarjetasNueva: (context) => const TarjetasScreen(abrirNuevaTarjeta: true),
        AppRoutes.tarjetasTitulares: (context) => const TarjetasScreen(initialTabIndex: 1),
        AppRoutes.tarjetasTitularNuevo: (context) => const TarjetasTitularNuevoScreen(),
        
        // NOTA: QR Cobros y Colaboradores (permisos, inversiones, actividad) se manejan via onGenerateRoute (requieren argumentos)
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // COLABORADORES V10.16 - Socios, Inversionistas, Familiares + Pantallas Completas
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.colaboradores: (context) => const ColaboradoresScreen(),
        AppRoutes.colaboradoresInversionistas: (context) => const ColaboradoresScreen(),
        AppRoutes.registroColaborador: (context) => const RegistroColaboradorScreen(), // V10.7
        AppRoutes.facturacionNueva: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return NuevaFacturaScreen(
              moduloOrigen: args['moduloOrigen'] ?? args['modulo_origen'],
              referenciaOrigenId: args['referenciaOrigenId'] ?? args['referencia_origen_id'],
              referenciaTipo: args['referenciaTipo'] ?? args['referencia_tipo'],
            );
          }
          return const NuevaFacturaScreen();
        },
        AppRoutes.estadoCuentaInversionista: (context) => const EstadoCuentaInversionistaScreen(),
        AppRoutes.misFacturasColaborador: (context) => const MisFacturasColaboradorScreen(),
        // colaboradoresPermisos, colaboradorInversiones, colaboradorActividad → onGenerateRoute
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // COMPENSACIONES Y CHAT V10.17
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.compensacionesConfig: (context) => const CompensacionesConfigScreen(),
        AppRoutes.pagosColaboradores: (context) => const PagosColaboradoresScreen(),
        AppRoutes.chatColaboradores: (context) => const ChatColaboradoresScreen(),
        AppRoutes.rendimientosInversionista: (context) => const RendimientosInversionistaScreen(),
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // MÓDULO CLIMAS V10.13 + CRUD V10.18 + PROFESIONAL V10.50 + QR V10.51
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.climasDashboard: (context) => const ClimasDashboardScreen(),
        AppRoutes.climasClientes: (context) => const ClimasClientesScreen(),
        AppRoutes.climasOrdenes: (context) => const ClimasOrdenesScreen(),
        AppRoutes.climasOrdenNueva: (context) => const ClimasOrdenesScreen(abrirNueva: true),
        AppRoutes.climasTecnicos: (context) => const ClimasTecnicosScreen(),
        AppRoutes.climasEquipos: (context) => const ClimasEquiposScreen(), // V10.22
        AppRoutes.climasProductos: (context) => SimpleTableScreen(
          title: 'Productos Climas',
          table: 'climas_productos',
          orderBy: 'created_at',
        ),
        AppRoutes.climasCotizaciones: (context) => const ClimasCotizacionesScreen(),
        '/climas/cotizaciones/nueva': (context) => const ClimasCotizacionesScreen(abrirNueva: true),
        // V10.50 - Climas Profesional
        AppRoutes.climasTareas: (context) => const ClimasTareasScreen(),
        AppRoutes.climasClientePortal: (context) => const ClimasClientePortalScreen(),
        AppRoutes.climasTecnicoApp: (context) => const ClimasTecnicoAppScreen(),
        AppRoutes.climasAdminDashboard: (context) => const ClimasAdminDashboardScreen(),
        '/climas/admin/configuracion': (context) => SimpleTableScreen(
          title: 'Configuración Climas',
          table: 'climas_configuracion',
          orderBy: 'updated_at',
        ),
        '/climas/calendario': (context) => SimpleTableScreen(
          title: 'Calendario Climas',
          table: 'climas_calendario',
          orderBy: 'fecha',
          ascending: true,
        ),
        '/climas/reportes': (context) => const ClimasAdminDashboardScreen(),
        '/climas/zonas': (context) => SimpleTableScreen(
          title: 'Zonas Climas',
          table: 'climas_zonas',
          orderBy: 'created_at',
        ),
        '/climas/comisiones': (context) => SimpleTableScreen(
          title: 'Comisiones Técnicos',
          table: 'climas_comisiones',
          orderBy: 'created_at',
        ),
        '/climas/garantias': (context) => SimpleTableScreen(
          title: 'Garantías Climas',
          table: 'climas_garantias',
          orderBy: 'created_at',
        ),
        '/climas/incidencias': (context) => SimpleTableScreen(
          title: 'Incidencias Climas',
          table: 'climas_incidencias',
          orderBy: 'created_at',
        ),
        // V10.51 - Sistema QR y Chat
        AppRoutes.climasSolicitudesAdmin: (context) => const ClimasSolicitudesAdminScreen(),
        '/climas/solicitudes': (context) => const ClimasSolicitudesAdminScreen(),
        AppRoutes.climasGenerarQrTarjeta: (context) => const ClimasGenerarQrTarjetaScreen(),
        AppRoutes.climasTarjetasQr: (context) => const ClimasTarjetasQrScreen(),
        AppRoutes.climasFacturas: (context) => const FacturasScreen(moduloOrigen: 'climas'),
        // V10.55 - Mejoras Módulo Climas
        AppRoutes.climasAnalyticsAvanzado: (context) => const ClimasAnalyticsAvanzadoScreen(),
        AppRoutes.climasContratos: (context) => const ClimasContratosScreen(),
        AppRoutes.climasRutasGps: (context) => const ClimasRutasGpsScreen(),
        AppRoutes.climasBaseConocimiento: (context) => const ClimasBaseConocimientoScreen(),
        AppRoutes.climasAlertas: (context) => const ClimasAlertasScreen(),
        AppRoutes.climasEvaluaciones: (context) => const ClimasEvaluacionesScreen(),
        // V10.52 - Tarjetas de Servicio QR Multi-Negocio
        AppRoutes.tarjetasServicio: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final modulosPermitidosRaw = args?['modulosPermitidos'];
          final modulosPermitidos = modulosPermitidosRaw is List
              ? modulosPermitidosRaw.map((e) => e.toString()).toList()
              : null;
          return TarjetasServicioScreen(
            abrirCrear: args?['abrirCrear'] == true,
            moduloInicial: args?['modulo'] as String?,
            templateInicial: args?['template'] as String?,
            negocioIdInicial: args?['negocioId'] as String?,
            modulosPermitidos: modulosPermitidos,
          );
        },
        AppRoutes.tarjetasServicioNueva: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final modulosPermitidosRaw = args?['modulosPermitidos'];
          final modulosPermitidos = modulosPermitidosRaw is List
              ? modulosPermitidosRaw.map((e) => e.toString()).toList()
              : null;
          return TarjetasServicioScreen(
            abrirCrear: args?['abrirCrear'] == true,
            moduloInicial: args?['modulo'] as String?,
            templateInicial: args?['template'] as String?,
            negocioIdInicial: args?['negocioId'] as String?,
            modulosPermitidos: modulosPermitidos,
          );
        },
        AppRoutes.configuradorFormulariosQR: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ConfiguradorFormulariosQRScreen(
            negocioId: args?['negocioId'] as String?,
            tarjetaId: args?['tarjetaId'] as String?,
            modulo: (args?['modulo'] as String?) ?? 'general',
          );
        },
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // SISTEMA QR AVANZADO V10.54
        // Analytics, Leads CRM, Templates, Compartir Masivo, Impresión Profesional
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.qrAnalytics: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return QrAnalyticsDashboardScreen(
            negocioId: args?['negocioId'] as String?,
            tarjetaId: args?['tarjetaId'] as String?,
          );
        },
        AppRoutes.qrLeadsBandeja: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return BandejaLeadsQrScreen(
            negocioId: args?['negocioId'] as String?,
            tarjetaId: args?['tarjetaId'] as String?,
            filtroModulo: args?['modulo'] as String?,
          );
        },
        AppRoutes.qrTemplatesPremium: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return TemplatesPremiumQrScreen(
            tarjetaId: args?['tarjetaId'] as String?,
            qrData: args?['qrData'] as String?,
            titulo: args?['titulo'] as String?,
          );
        },
        AppRoutes.qrCompartirMasivo: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return CompartirMasivoQrScreen(
            tarjetaId: args?['tarjetaId'] as String?,
            qrUrl: args?['qrUrl'] as String?,
            titulo: args?['titulo'] as String?,
          );
        },
        AppRoutes.qrImpresionProfesional: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ImpresionProfesionalQrScreen(
            tarjetaId: args?['tarjetaId'] as String?,
            qrData: args?['qrData'] as String?,
            titulo: args?['titulo'] as String?,
            templateDatos: args?['datos'] as Map<String, dynamic>?,
          );
        },
        '/qr_impresion_profesional': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ImpresionProfesionalQrScreen(
            tarjetaId: args?['tarjetaId'] as String?,
            qrData: args?['qr_data'] as String?,
            titulo: args?['titulo'] as String?,
            templateDatos: args?['datos'] as Map<String, dynamic>?,
          );
        },
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // MÓDULO VENTAS/CATÁLOGO V10.13 + CRUD V10.18
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.ventasDashboard: (context) => const VentasDashboardScreen(),
        AppRoutes.ventasClientes: (context) => const VentasClientesScreen(),
        AppRoutes.ventasProductos: (context) => const VentasProductosScreen(),
        AppRoutes.ventasPedidos: (context) => const VentasPedidosScreen(),
        AppRoutes.ventasPedidoNuevo: (context) => const VentasPedidosScreen(abrirNuevo: true),
        AppRoutes.ventasApartados: (context) => SimpleTableScreen(
          title: 'Apartados Ventas',
          table: 'ventas_pedidos',
          filters: {'tipo_venta': 'apartado'},
          orderBy: 'created_at',
        ),
        AppRoutes.ventasVendedores: (context) => const VentasVendedoresScreen(), // V10.22
        AppRoutes.ventasCategorias: (context) => const VentasCategoriasScreen(), // V10.22 Categorías
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // MÓDULO PURIFICADORA V10.13 + CRUD V10.18
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.purificadoraDashboard: (context) => const PurificadoraDashboardScreen(),
        AppRoutes.purificadoraTarjetasQr: (context) => const PurificadoraTarjetasQrScreen(),
        AppRoutes.purificadoraFacturas: (context) => const FacturasScreen(moduloOrigen: 'purificadora'),
        AppRoutes.purificadoraClientes: (context) => const PurificadoraClientesScreen(),
        AppRoutes.purificadoraEntregas: (context) => const PurificadoraEntregasScreen(),
        AppRoutes.purificadoraEntregaNueva: (context) => const PurificadoraEntregasScreen(abrirNueva: true),
        AppRoutes.purificadoraCortes: (context) => const PurificadoraCortesScreen(),
        AppRoutes.purificadoraProduccion: (context) => SimpleTableScreen(
          title: 'Producción Purificadora',
          table: 'purificadora_produccion',
          orderBy: 'fecha',
          ascending: false,
        ),
        AppRoutes.purificadoraRepartidores: (context) => const PurificadoraRepartidoresScreen(), // V10.22
        AppRoutes.purificadoraRutas: (context) => const PurificadoraRutasScreen(), // V10.22 Rutas
        '/purificadora/productos': (context) => const PurificadoraProductosScreen(), // V10.22 Productos
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // MÓDULO NICE JOYERÍA MLM V10.20
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.niceDashboard: (context) => NegocioResolverScreen(
          title: 'Nice MLM',
          builder: (negocioId) => NiceDashboardScreen(negocioId: negocioId),
        ),
        AppRoutes.niceTarjetasQr: (context) => const NiceTarjetasQrScreen(),
        AppRoutes.niceFacturas: (context) => const FacturasScreen(moduloOrigen: 'nice'),
        '/nice/categorias': (context) => const NiceCategoriasScreen(), // V10.22 Categorías
        '/nice/niveles': (context) => const NiceNivelesScreen(), // V10.22 Niveles MLM
        '/nice/catalogos': (context) => const NiceCatalogosScreen(), // V10.22 Catálogos
        AppRoutes.niceComisiones: (context) => const NiceComisionesScreen(), // V10.22 Comisiones
        '/nice/inventario': (context) => const NiceInventarioScreen(), // V10.22 Inventario
        AppRoutes.niceClientes: (context) => NegocioResolverScreen(
          title: 'Clientes Nice',
          builder: (negocioId) => NiceClientesScreen(negocioId: negocioId),
        ),
        AppRoutes.niceVendedoras: (context) => NegocioResolverScreen(
          title: 'Vendedoras Nice',
          builder: (negocioId) => NiceVendedorasScreen(negocioId: negocioId),
        ),
        AppRoutes.niceEquipo: (context) => NegocioResolverScreen(
          title: 'Equipo Nice',
          builder: (negocioId) => NiceVendedorasScreen(negocioId: negocioId),
        ),
        AppRoutes.niceProductos: (context) => NegocioResolverScreen(
          title: 'Productos Nice',
          builder: (negocioId) => NiceProductosScreen(negocioId: negocioId),
        ),
        AppRoutes.nicePedidos: (context) => NegocioResolverScreen(
          title: 'Pedidos Nice',
          builder: (negocioId) => NicePedidosScreen(negocioId: negocioId),
        ),
        // Nota: Las pantallas de NICE requieren negocioId
        // Se resuelven con NegocioResolverScreen cuando se navega por ruta
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // MÓDULO POLLOS ASADOS V10.60
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.pollosDashboard: (context) => const PollosDashboardScreen(),
        AppRoutes.pollosPedidos: (context) => const PollosPedidosScreen(),
        AppRoutes.pollosMenu: (context) => const PollosMenuScreen(),
        AppRoutes.pollosConfig: (context) => const PollosConfigScreen(),
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // PANTALLAS DETALLE COMPLETAS V10.18
        // ═══════════════════════════════════════════════════════════════════════════════
        // Nota: detalleEmpleado y detalleClienteCompleto requieren argumentos
        // Se manejan via Navigator.push con argumentos directamente
        AppRoutes.usuariosGestion: (context) => const UsuariosGestionScreen(),
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // SUPERADMIN EXCLUSIVO V10.30
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.superadminInversionGlobal: (context) => const SuperadminInversionGlobalScreen(),
        AppRoutes.gaveterosModulares: (context) => const GaveterosModularesScreen(),
        AppRoutes.configuracionApis: (context) => const ConfiguracionApisScreen(),
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // SISTEMA MULTI-NEGOCIO V10.31 - Business Switcher + HUB V10.32
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.superadminHub: (context) => const SuperadminHubScreen(),
        AppRoutes.superadminNegocios: (context) => const SuperadminNegociosScreen(),
        AppRoutes.negocioDashboard: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is NegocioModel) {
            return NegocioDashboardScreen(negocio: args);
          }
          return const NegocioDashboardScreen();
        },
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // MI CAPITAL - Control de Inversiones V10.52
        // ═══════════════════════════════════════════════════════════════════════════════
        AppRoutes.miCapital: (context) => const MiCapitalScreen(),
        
        AppRoutes.formularioEmpleado: (context) => const EmpleadoFormScreen(),
        AppRoutes.formularioPrestamo: (context) => NuevoPrestamoView(
          controller: Provider.of<PrestamosController>(context, listen: false),
          usuariosController: Provider.of<UsuariosController>(context, listen: false),
          avalesController: Provider.of<AvalesController>(context, listen: false),
        ),
        AppRoutes.formularioTanda: (context) => NuevaTandaView(
          controller: Provider.of<TandasController>(context, listen: false),
        ),
        AppRoutes.formularioCliente: (context) => const FormularioClienteScreen(),
        AppRoutes.formularioPrestamoExistente: (context) => const MigracionPrestamoScreenV2(),
      },
    );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false).navegarSegunRol(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

MaterialPageRoute _buildFormularioQrRoute(RouteSettings settings,
    {required String modulo}) {
  final args = settings.arguments;
  String? negocioId;
  String? tarjetaCodigo;

  if (args is Map) {
    final map = Map<String, dynamic>.from(args);
    negocioId = map['negocio']?.toString() ?? map['negocioId']?.toString();
    tarjetaCodigo = map['tarjeta']?.toString() ?? map['tarjetaCodigo']?.toString();
  } else if (args is String) {
    negocioId = args;
  }

  return MaterialPageRoute(
    builder: (_) => FormularioQrPublicoScreen(
      modulo: modulo,
      negocioId: negocioId,
      tarjetaCodigo: tarjetaCodigo,
    ),
  );
}
