// ═══════════════════════════════════════════════════════════════════════════════
// DEEP LINK SERVICE - V10.52 MULTI-MÓDULO
// Maneja los enlaces profundos para abrir la app desde QR
// Esquema: robertdarin://modulo/ruta?parametros
// Soporta: climas, prestamos, tandas, cobranza, servicios, general, purificadora, nice
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

/// Módulos soportados para deep links
enum DeepLinkModulo {
  climas,
  prestamos,
  tandas,
  cobranza,
  servicios,
  general,
  purificadora,
  nice,
}

/// Configuración de rutas por módulo
class ModuloRouteConfig {
  final String moduloName;
  final String defaultRoute;
  final Map<String, String> routes;
  
  const ModuloRouteConfig({
    required this.moduloName,
    required this.defaultRoute,
    required this.routes,
  });
}

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  
  // Callback para navegación
  Function(String route, Map<String, String> params)? onDeepLink;
  
  // Uri inicial (si la app se abrió desde un link)
  Uri? _initialUri;
  Uri? get initialUri => _initialUri;

  /// Configuración de rutas por módulo
  static final Map<String, ModuloRouteConfig> _moduloRoutes = {
    'climas': const ModuloRouteConfig(
      moduloName: 'climas',
      defaultRoute: '/climas/formulario-publico',
      routes: {
        'formulario': '/climas/formulario-publico',
        'solicitud': '/climas/formulario-publico',
        'chat': '/climas/chat',
        'seguimiento': '/climas/seguimiento',
        'cotizacion': '/climas/cotizacion-publica',
      },
    ),
    'prestamos': const ModuloRouteConfig(
      moduloName: 'prestamos',
      defaultRoute: '/prestamos/solicitar-publico',
      routes: {
        'formulario': '/prestamos/solicitar-publico',
        'solicitud': '/prestamos/solicitar-publico',
        'info': '/prestamos/info-publica',
        'calculadora': '/prestamos/calculadora-publica',
        'pago': '/prestamos/portal-pago',
      },
    ),
    'tandas': const ModuloRouteConfig(
      moduloName: 'tandas',
      defaultRoute: '/tandas/info-publica',
      routes: {
        'formulario': '/tandas/solicitar-publico',
        'info': '/tandas/info-publica',
        'unirse': '/tandas/unirse-publico',
        'consulta': '/tandas/consulta-publica',
      },
    ),
    'cobranza': const ModuloRouteConfig(
      moduloName: 'cobranza',
      defaultRoute: '/cobranza/portal-cliente',
      routes: {
        'portal': '/cobranza/portal-cliente',
        'pago': '/cobranza/realizar-pago',
        'estado': '/cobranza/estado-cuenta',
      },
    ),
    'servicios': const ModuloRouteConfig(
      moduloName: 'servicios',
      defaultRoute: '/servicios/solicitar-publico',
      routes: {
        'formulario': '/servicios/solicitar-publico',
        'catalogo': '/servicios/catalogo-publico',
        'contacto': '/servicios/contacto-publico',
      },
    ),
    'general': const ModuloRouteConfig(
      moduloName: 'general',
      defaultRoute: '/contacto-publico',
      routes: {
        'contacto': '/contacto-publico',
        'info': '/info-negocio',
        'landing': '/landing-negocio',
      },
    ),
    'purificadora': const ModuloRouteConfig(
      moduloName: 'purificadora',
      defaultRoute: '/purificadora',
      routes: {
        'formulario': '/purificadora',
        'portal': '/purificadora',
        'contacto': '/purificadora',
      },
    ),
    'nice': const ModuloRouteConfig(
      moduloName: 'nice',
      defaultRoute: '/nice',
      routes: {
        'formulario': '/nice',
        'catalogo': '/nice',
        'contacto': '/nice',
      },
    ),
  };

  /// Inicializar el servicio de deep links
  Future<void> init() async {
    _appLinks = AppLinks();
    
    // Obtener el link inicial si la app se abrió desde uno
    try {
      _initialUri = await _appLinks.getInitialLink();
      if (_initialUri != null) {
        debugPrint('🔗 Deep Link Inicial: $_initialUri');
        _handleDeepLink(_initialUri!);
      }
    } catch (e) {
      debugPrint('⚠️ Error obteniendo link inicial: $e');
    }
    
    // Escuchar links mientras la app está abierta
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('🔗 Deep Link Recibido: $uri');
        _handleDeepLink(uri);
      },
      onError: (error) {
        debugPrint('⚠️ Error en deep link stream: $error');
      },
    );
  }

  /// Procesar el deep link y extraer ruta + parámetros
  void _handleDeepLink(Uri uri) {
    // Formato esperado: robertdarin://modulo/ruta?negocio=XXX&tarjeta=YYY
    final modulo = uri.host;
    final params = Map<String, String>.from(uri.queryParameters);
    
    debugPrint('📍 Módulo: $modulo');
    debugPrint('📍 Path: ${uri.pathSegments}');
    debugPrint('📦 Parámetros: $params');
    
    // Mapear rutas de deep link a rutas de la app
    final appRoute = _mapDeepLinkToRoute(modulo, uri.pathSegments);
    
    if (onDeepLink != null && appRoute != null) {
      // Agregar módulo a los parámetros para tracking
      params['_modulo'] = modulo;
      onDeepLink!(appRoute, params);
    }
  }

  /// Mapear la estructura del deep link a rutas de Flutter
  String? _mapDeepLinkToRoute(String modulo, List<String> pathSegments) {
    final config = _moduloRoutes[modulo];
    if (config == null) {
      debugPrint('⚠️ Módulo no reconocido: $modulo');
      return null;
    }
    
    if (pathSegments.isEmpty) {
      return config.defaultRoute;
    }
    
    final route = pathSegments.first;
    return config.routes[route] ?? config.defaultRoute;
  }

  /// Obtener lista de módulos soportados
  static List<String> get modulosSoportados => _moduloRoutes.keys.toList();

  /// Obtener rutas disponibles para un módulo
  static List<String> getRutasModulo(String modulo) {
    return _moduloRoutes[modulo]?.routes.keys.toList() ?? [];
  }

  /// Generar URL de deep link para QR
  static String generarDeepLink({
    required String modulo,
    String? ruta,
    Map<String, String>? parametros,
  }) {
    final buffer = StringBuffer('robertdarin://$modulo');
    
    if (ruta != null && ruta.isNotEmpty) {
      buffer.write('/$ruta');
    }
    
    if (parametros != null && parametros.isNotEmpty) {
      buffer.write('?');
      buffer.write(parametros.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&'));
    }
    
    return buffer.toString();
  }

  /// Generar deep link específico para Climas
  static String generarDeepLinkClimas({
    required String negocioId,
    String tipo = 'formulario',
    String? tarjetaCodigo,
  }) {
    final params = {'negocio': negocioId};
    if (tarjetaCodigo != null) params['tarjeta'] = tarjetaCodigo;
    
    return generarDeepLink(
      modulo: 'climas',
      ruta: tipo,
      parametros: params,
    );
  }

  /// Generar deep link específico para Préstamos
  static String generarDeepLinkPrestamos({
    required String negocioId,
    String tipo = 'formulario',
    String? tarjetaCodigo,
  }) {
    final params = {'negocio': negocioId};
    if (tarjetaCodigo != null) params['tarjeta'] = tarjetaCodigo;
    
    return generarDeepLink(
      modulo: 'prestamos',
      ruta: tipo,
      parametros: params,
    );
  }

  /// Generar deep link específico para Tandas
  static String generarDeepLinkTandas({
    required String negocioId,
    String tipo = 'info',
    String? tarjetaCodigo,
  }) {
    final params = {'negocio': negocioId};
    if (tarjetaCodigo != null) params['tarjeta'] = tarjetaCodigo;
    
    return generarDeepLink(
      modulo: 'tandas',
      ruta: tipo,
      parametros: params,
    );
  }

  /// Generar deep link para Tarjeta de Servicio (cualquier módulo)
  static String generarDeepLinkTarjetaServicio({
    required String modulo,
    required String negocioId,
    required String tarjetaCodigo,
    String tipo = 'formulario',
  }) {
    return generarDeepLink(
      modulo: modulo,
      ruta: tipo,
      parametros: {
        'negocio': negocioId,
        'tarjeta': tarjetaCodigo,
      },
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}

/// Extensión para facilitar el uso
extension DeepLinkExtension on BuildContext {
  /// Navegar usando deep link
  void navigateFromDeepLink(String route, Map<String, String> params) {
    Navigator.of(this).pushNamed(route, arguments: params);
  }
}
