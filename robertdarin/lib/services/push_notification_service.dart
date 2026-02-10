/// ══════════════════════════════════════════════════════════════════════════════
/// SERVICIO DE NOTIFICACIONES PUSH - Firebase Cloud Messaging
/// Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Maneja el envío y recepción de notificaciones push a través de FCM.
/// Soporta: Avales, Clientes, Operadores, Admins
/// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../core/supabase_client.dart';

/// Handler de mensajes en background (debe ser función top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 Push en background: ${message.notification?.title}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Canal de notificaciones para Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'robertdarin_notifications',
    'Robert Darin Fintech',
    description: 'Notificaciones de préstamos, tandas y pagos',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// ═══════════════════════════════════════════════════════════════════════════════
  /// INICIALIZACIÓN
  /// ═══════════════════════════════════════════════════════════════════════════════
  
  Future<void> initialize() async {
    try {
      // 1. Configurar handler de background
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Solicitar permisos
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('📱 Permisos push: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 3. Obtener token FCM
        _fcmToken = await _messaging.getToken();
        debugPrint('🔑 FCM Token: $_fcmToken');

        // 4. Configurar notificaciones locales (para mostrar cuando app está en foreground)
        await _setupLocalNotifications();

        // 5. Escuchar mensajes en foreground
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // 6. Escuchar cuando se toca una notificación
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // 7. Escuchar renovación de token
        _messaging.onTokenRefresh.listen(_handleTokenRefresh);
      }
    } catch (e) {
      debugPrint('❌ Error inicializando push: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    // Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Manejar tap en notificación local
        debugPrint('📲 Tap en notificación local: ${response.payload}');
      },
    );

    // Crear canal en Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// ═══════════════════════════════════════════════════════════════════════════════
  /// HANDLERS DE MENSAJES
  /// ═══════════════════════════════════════════════════════════════════════════════

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Push en foreground: ${message.notification?.title}');
    
    final notification = message.notification;
    if (notification != null) {
      // Mostrar notificación local
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📲 Usuario tocó notificación: ${message.data}');
    // Aquí puedes navegar a la pantalla correspondiente según message.data
  }

  void _handleTokenRefresh(String newToken) async {
    debugPrint('🔄 Token FCM renovado: $newToken');
    _fcmToken = newToken;
    // Actualizar en BD si el usuario está logueado
    await _actualizarTokenEnBD(newToken);
  }

  /// ═══════════════════════════════════════════════════════════════════════════════
  /// GUARDAR TOKEN EN BASE DE DATOS
  /// ═══════════════════════════════════════════════════════════════════════════════

  /// Guardar token FCM para un usuario (en tabla dispositivos_fcm - V10.56)
  Future<void> guardarTokenUsuario(String userId) async {
    if (_fcmToken == null) return;
    
    try {
      // Usar UPSERT para evitar duplicados
      await AppSupabase.client
          .from('dispositivos_fcm')
          .upsert({
            'usuario_id': userId,
            'fcm_token': _fcmToken,
            'plataforma': 'android',
            'activo': true,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'usuario_id,fcm_token');
      debugPrint('✅ Token FCM guardado en dispositivos_fcm para: $userId');
    } catch (e) {
      debugPrint('❌ Error guardando token: $e');
    }
  }

  /// Guardar token FCM para un aval
  Future<void> guardarTokenAval(String avalId) async {
    if (_fcmToken == null) return;
    
    try {
      await AppSupabase.client
          .from('avales')
          .update({'fcm_token': _fcmToken})
          .eq('id', avalId);
      debugPrint('✅ Token FCM guardado para aval: $avalId');
    } catch (e) {
      debugPrint('❌ Error guardando token aval: $e');
    }
  }

  Future<void> _actualizarTokenEnBD(String token) async {
    // Actualizar en tabla dispositivos_fcm si hay sesión activa (V10.56)
    final session = AppSupabase.client.auth.currentSession;
    if (session != null) {
      try {
        await AppSupabase.client
            .from('dispositivos_fcm')
            .upsert({
              'usuario_id': session.user.id,
              'fcm_token': token,
              'plataforma': 'android',
              'activo': true,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'usuario_id,fcm_token');
        debugPrint('🔄 Token actualizado en dispositivos_fcm');
      } catch (e) {
        debugPrint('⚠️ Error actualizando token: $e');
      }
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════════
  /// ENVIAR NOTIFICACIONES (Desde el servidor/admin)
  /// ═══════════════════════════════════════════════════════════════════════════════
  
  /// Enviar notificación a un token específico
  /// NOTA: En producción, esto debe hacerse desde un servidor seguro con la API Key
  /// Por ahora usamos Supabase Edge Functions o la API Legacy de FCM
  static Future<bool> enviarNotificacion({
    required String fcmToken,
    required String titulo,
    required String mensaje,
    Map<String, String>? data,
  }) async {
    try {
      // Obtener Server Key de la configuración
      final configRes = await AppSupabase.client
          .from('configuracion_apis')
          .select('api_key')
          .eq('servicio', 'firebase_fcm')
          .eq('activo', true)
          .maybeSingle();
      
      final serverKey = configRes?['api_key'];
      if (serverKey == null) {
        debugPrint('⚠️ Firebase Server Key no configurado');
        return false;
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': fcmToken,
          'notification': {
            'title': titulo,
            'body': mensaje,
            'sound': 'default',
          },
          'data': data ?? {},
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Push enviado a: $fcmToken');
        return true;
      } else {
        debugPrint('❌ Error enviando push: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error en enviarNotificacion: $e');
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════════
  /// MÉTODOS DE CONVENIENCIA
  /// ═══════════════════════════════════════════════════════════════════════════════

  /// Notificar al aval que su documento fue aprobado
  static Future<void> notificarDocumentoAprobado({
    required String avalId,
    required String tipoDocumento,
  }) async {
    try {
      final avalRes = await AppSupabase.client
          .from('avales')
          .select('fcm_token, nombre')
          .eq('id', avalId)
          .maybeSingle();
      
      final fcmToken = avalRes?['fcm_token'];
      if (fcmToken == null) {
        debugPrint('⚠️ Aval sin token FCM');
        return;
      }

      await enviarNotificacion(
        fcmToken: fcmToken,
        titulo: '✅ Documento Verificado',
        mensaje: 'Tu $tipoDocumento ha sido aprobado correctamente.',
        data: {
          'tipo': 'documento_aprobado',
          'aval_id': avalId,
          'ruta': '/dashboardAval',
        },
      );
    } catch (e) {
      debugPrint('Error notificando documento aprobado: $e');
    }
  }

  /// Notificar al aval que su documento fue rechazado
  static Future<void> notificarDocumentoRechazado({
    required String avalId,
    required String tipoDocumento,
    String? motivo,
  }) async {
    try {
      final avalRes = await AppSupabase.client
          .from('avales')
          .select('fcm_token, nombre')
          .eq('id', avalId)
          .maybeSingle();
      
      final fcmToken = avalRes?['fcm_token'];
      if (fcmToken == null) {
        debugPrint('⚠️ Aval sin token FCM');
        return;
      }

      await enviarNotificacion(
        fcmToken: fcmToken,
        titulo: '⚠️ Documento Rechazado',
        mensaje: 'Tu $tipoDocumento fue rechazado${motivo != null ? ": $motivo" : ""}. Por favor sube uno nuevo.',
        data: {
          'tipo': 'documento_rechazado',
          'aval_id': avalId,
          'ruta': '/dashboardAval',
        },
      );
    } catch (e) {
      debugPrint('Error notificando documento rechazado: $e');
    }
  }

  /// Notificar pago próximo a vencer
  static Future<void> notificarPagoProximo({
    required String userId,
    required String clienteNombre,
    required double monto,
    required DateTime fechaVencimiento,
  }) async {
    try {
      final userRes = await AppSupabase.client
          .from('usuarios')
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle();
      
      final fcmToken = userRes?['fcm_token'];
      if (fcmToken == null) return;

      await enviarNotificacion(
        fcmToken: fcmToken,
        titulo: '📅 Pago Próximo',
        mensaje: 'Tienes un pago de \$${monto.toStringAsFixed(2)} que vence pronto.',
        data: {
          'tipo': 'pago_proximo',
          'ruta': '/pagos',
        },
      );
    } catch (e) {
      debugPrint('Error notificando pago: $e');
    }
  }

  /// Notificar pago confirmado
  static Future<void> notificarPagoConfirmado({
    required String userId,
    required double monto,
    required String concepto,
  }) async {
    try {
      final userRes = await AppSupabase.client
          .from('usuarios')
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle();
      
      final fcmToken = userRes?['fcm_token'];
      if (fcmToken == null) return;

      await enviarNotificacion(
        fcmToken: fcmToken,
        titulo: '✅ Pago Confirmado',
        mensaje: 'Tu pago de \$${monto.toStringAsFixed(2)} por $concepto ha sido registrado.',
        data: {
          'tipo': 'pago_confirmado',
          'ruta': '/pagos',
        },
      );
    } catch (e) {
      debugPrint('Error notificando pago confirmado: $e');
    }
  }

  /// Notificar mora al aval
  static Future<void> notificarMoraAval({
    required String avalId,
    required String clienteNombre,
    required int diasMora,
    required double montoPendiente,
  }) async {
    try {
      final avalRes = await AppSupabase.client
          .from('avales')
          .select('fcm_token')
          .eq('id', avalId)
          .maybeSingle();
      
      final fcmToken = avalRes?['fcm_token'];
      if (fcmToken == null) return;

      await enviarNotificacion(
        fcmToken: fcmToken,
        titulo: '⚠️ Alerta de Mora',
        mensaje: 'El cliente $clienteNombre tiene $diasMora días de atraso. Monto: \$${montoPendiente.toStringAsFixed(2)}',
        data: {
          'tipo': 'mora_aval',
          'aval_id': avalId,
          'ruta': '/dashboardAval',
        },
      );
    } catch (e) {
      debugPrint('Error notificando mora: $e');
    }
  }

  /// Enviar notificación masiva a múltiples tokens
  static Future<int> enviarNotificacionMasiva({
    required List<String> tokens,
    required String titulo,
    required String mensaje,
    Map<String, String>? data,
  }) async {
    int enviados = 0;
    
    for (final token in tokens) {
      final ok = await enviarNotificacion(
        fcmToken: token,
        titulo: titulo,
        mensaje: mensaje,
        data: data,
      );
      if (ok) enviados++;
    }
    
    return enviados;
  }
}
