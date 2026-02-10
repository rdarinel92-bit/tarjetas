/// ══════════════════════════════════════════════════════════════════════════════
/// ANALYTICS SERVICE - Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Servicio para trackear eventos importantes del negocio con Firebase Analytics.
/// Permite entender cómo los usuarios usan la aplicación.
/// ══════════════════════════════════════════════════════════════════════════════

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Obtener observer para navegación automática
  FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  // ═══════════════════════════════════════════════════════════════════════════════
  // EVENTOS DE AUTENTICACIÓN
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Usuario inició sesión
  Future<void> logLogin({required String metodo}) async {
    try {
      await _analytics.logLogin(loginMethod: metodo);
      debugPrint('📊 Analytics: login ($metodo)');
    } catch (e) {
      debugPrint('⚠️ Error analytics login: $e');
    }
  }

  /// Usuario cerró sesión
  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: 'logout');
      debugPrint('📊 Analytics: logout');
    } catch (e) {
      debugPrint('⚠️ Error analytics logout: $e');
    }
  }

  /// Establecer ID de usuario (para seguimiento anónimo)
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
      debugPrint('📊 Analytics: userId set');
    } catch (e) {
      debugPrint('⚠️ Error analytics setUserId: $e');
    }
  }

  /// Establecer propiedades del usuario
  Future<void> setUserRole(String rol) async {
    try {
      await _analytics.setUserProperty(name: 'user_role', value: rol);
      debugPrint('📊 Analytics: rol=$rol');
    } catch (e) {
      debugPrint('⚠️ Error analytics setUserRole: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // EVENTOS DE PRÉSTAMOS
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Nuevo préstamo creado
  Future<void> logPrestamoCreado({
    required double monto,
    required int plazoMeses,
    required String tipoPrestamo,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'prestamo_creado',
        parameters: {
          'monto': monto,
          'plazo_meses': plazoMeses,
          'tipo': tipoPrestamo,
        },
      );
      debugPrint('📊 Analytics: prestamo_creado \$${monto.toStringAsFixed(0)}');
    } catch (e) {
      debugPrint('⚠️ Error analytics prestamo: $e');
    }
  }

  /// Pago registrado
  Future<void> logPagoRegistrado({
    required double monto,
    required String metodoPago,
    required String tipoPrestamo,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'pago_registrado',
        parameters: {
          'monto': monto,
          'metodo': metodoPago,
          'tipo_prestamo': tipoPrestamo,
        },
      );
      debugPrint('📊 Analytics: pago \$${monto.toStringAsFixed(0)} via $metodoPago');
    } catch (e) {
      debugPrint('⚠️ Error analytics pago: $e');
    }
  }

  /// Préstamo liquidado
  Future<void> logPrestamoLiquidado({
    required double montoTotal,
    required int diasParaLiquidar,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'prestamo_liquidado',
        parameters: {
          'monto_total': montoTotal,
          'dias_para_liquidar': diasParaLiquidar,
        },
      );
      debugPrint('📊 Analytics: prestamo_liquidado');
    } catch (e) {
      debugPrint('⚠️ Error analytics liquidado: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // EVENTOS DE TANDAS
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Nueva tanda creada
  Future<void> logTandaCreada({
    required double montoSemanal,
    required int numeroParticipantes,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'tanda_creada',
        parameters: {
          'monto_semanal': montoSemanal,
          'participantes': numeroParticipantes,
        },
      );
      debugPrint('📊 Analytics: tanda_creada');
    } catch (e) {
      debugPrint('⚠️ Error analytics tanda: $e');
    }
  }

  /// Aportación de tanda
  Future<void> logAportacionTanda({required double monto}) async {
    try {
      await _analytics.logEvent(
        name: 'aportacion_tanda',
        parameters: {'monto': monto},
      );
      debugPrint('📊 Analytics: aportacion_tanda');
    } catch (e) {
      debugPrint('⚠️ Error analytics aportacion: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // EVENTOS DE AVALES
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Documento de aval subido
  Future<void> logDocumentoAvalSubido({required String tipoDocumento}) async {
    try {
      await _analytics.logEvent(
        name: 'documento_aval_subido',
        parameters: {'tipo': tipoDocumento},
      );
      debugPrint('📊 Analytics: documento_aval_subido ($tipoDocumento)');
    } catch (e) {
      debugPrint('⚠️ Error analytics doc aval: $e');
    }
  }

  /// Documento de aval verificado
  Future<void> logDocumentoAvalVerificado({
    required String tipoDocumento,
    required bool aprobado,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'documento_aval_verificado',
        parameters: {
          'tipo': tipoDocumento,
          'aprobado': aprobado ? 1 : 0,
        },
      );
      debugPrint('📊 Analytics: documento_aval_verificado ($tipoDocumento, aprobado: $aprobado)');
    } catch (e) {
      debugPrint('⚠️ Error analytics verificacion: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // EVENTOS DE PANTALLAS
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Pantalla visitada (se puede llamar manualmente si no usas observer)
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      debugPrint('📊 Analytics: screen $screenName');
    } catch (e) {
      debugPrint('⚠️ Error analytics screen: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // EVENTOS DE ERRORES (complementa Crashlytics)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Error no fatal para analytics
  Future<void> logError({
    required String errorType,
    String? errorMessage,
    String? pantalla,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'error_message': errorMessage ?? 'unknown',
          'pantalla': pantalla ?? 'unknown',
        },
      );
      debugPrint('📊 Analytics: error $errorType');
    } catch (e) {
      debugPrint('⚠️ Error analytics error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // EVENTOS DE NEGOCIO GENERAL
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Cliente creado
  Future<void> logClienteCreado() async {
    try {
      await _analytics.logEvent(name: 'cliente_creado');
      debugPrint('📊 Analytics: cliente_creado');
    } catch (e) {
      debugPrint('⚠️ Error analytics cliente: $e');
    }
  }

  /// Cobro en efectivo registrado
  Future<void> logCobroEfectivo({required double monto}) async {
    try {
      await _analytics.logEvent(
        name: 'cobro_efectivo',
        parameters: {'monto': monto},
      );
      debugPrint('📊 Analytics: cobro_efectivo \$${monto.toStringAsFixed(0)}');
    } catch (e) {
      debugPrint('⚠️ Error analytics cobro: $e');
    }
  }

  /// Mora generada
  Future<void> logMoraGenerada({
    required double monto,
    required int diasRetraso,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'mora_generada',
        parameters: {
          'monto': monto,
          'dias_retraso': diasRetraso,
        },
      );
      debugPrint('📊 Analytics: mora_generada');
    } catch (e) {
      debugPrint('⚠️ Error analytics mora: $e');
    }
  }

  /// Evento personalizado genérico
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters?.map((k, v) => MapEntry(k, v.toString())),
      );
      debugPrint('📊 Analytics: $eventName');
    } catch (e) {
      debugPrint('⚠️ Error analytics custom: $e');
    }
  }
}
