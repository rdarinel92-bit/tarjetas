/// ══════════════════════════════════════════════════════════════════════════════
/// SERVICIO DE CHAT EN TIEMPO REAL - Tarjetas QR
/// Robert Darin Fintech V10.54
/// ══════════════════════════════════════════════════════════════════════════════
/// Escucha mensajes nuevos del chat web de tarjetas y muestra notificaciones.
/// Usa Supabase Realtime para actualizaciones instantáneas.
/// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class TarjetasChatRealtimeService {
  static final TarjetasChatRealtimeService _instance = TarjetasChatRealtimeService._internal();
  factory TarjetasChatRealtimeService() => _instance;
  TarjetasChatRealtimeService._internal();

  RealtimeChannel? _channel;
  bool _isListening = false;
  List<String> _misNegociosIds = [];
  bool _esSuperAdmin = false;
  
  // Callback para notificar a la UI
  Function(Map<String, dynamic>)? onNuevoMensaje;
  
  // Notificaciones locales
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Canal específico para chat
  static const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
    'tarjetas_chat_channel',
    'Chat de Tarjetas',
    description: 'Notificaciones de mensajes nuevos de clientes',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Inicializar el servicio
  Future<void> inicializar() async {
    try {
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('🚀 INICIALIZANDO TarjetasChatRealtimeService');
      debugPrint('═══════════════════════════════════════════════');
      
      // Inicializar notificaciones locales
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
          debugPrint('📲 Tap en notificación de chat: ${response.payload}');
        },
      );
      
      // Crear canal de notificaciones en Android
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_chatChannel);
      
      debugPrint('✅ Notificaciones locales inicializadas');
      
      // Cargar negocios del usuario
      await _cargarMisNegocios();
      
      // Iniciar escucha
      await iniciarEscucha();
      
      debugPrint('✅ TarjetasChatRealtimeService LISTO');
      debugPrint('📊 esSuperAdmin: $_esSuperAdmin');
      debugPrint('📊 Negocios: ${_misNegociosIds.length}');
      debugPrint('═══════════════════════════════════════════════');
      
      // DEBUG: Mostrar notificación de prueba si está configurado
      if (_esSuperAdmin || _misNegociosIds.isNotEmpty) {
        debugPrint('🔔 Sistema de notificaciones ACTIVO para chat QR');
      }
    } catch (e) {
      debugPrint('❌ Error inicializando TarjetasChatRealtimeService: $e');
    }
  }
  
  /// Cargar los negocios a los que el usuario tiene acceso para CHAT QR
  /// V10.56 - Ahora verifica permisos granulares: chat_qr, es_administrador
  Future<void> _cargarMisNegocios() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ _cargarMisNegocios: Usuario no autenticado');
        return;
      }
      
      debugPrint('🔍 _cargarMisNegocios: Verificando permisos chat para ${user.email}');
      
      // Lista de emails de superadmin (owner)
      const ownerEmails = {'rdarinel992@gmail.com'};
      
      // 1. Verificar si es owner por email
      if (ownerEmails.contains(user.email?.toLowerCase())) {
        _esSuperAdmin = true;
        debugPrint('✅ Usuario es OWNER por email → superadmin');
      } else {
        // 2. Verificar si es superadmin/admin general por tabla usuarios_roles
        try {
          final rolInfo = await AppSupabase.client
              .from('usuarios_roles')
              .select('rol_id, roles!inner(nombre)')
              .eq('usuario_id', user.id)
              .maybeSingle();
          
          if (rolInfo != null) {
            final rolNombre = rolInfo['roles']?['nombre']?.toString().toLowerCase() ?? '';
            _esSuperAdmin = rolNombre == 'superadmin';
            debugPrint('🔍 Rol general en BD: $rolNombre → _esSuperAdmin=$_esSuperAdmin');
          }
        } catch (e) {
          debugPrint('⚠️ Error verificando rol en BD: $e');
        }
      }
      
      if (_esSuperAdmin) {
        // Superadmin ve todos los negocios
        final negocios = await AppSupabase.client
            .from('negocios')
            .select('id')
            .eq('activo', true);
        _misNegociosIds = negocios.map((n) => n['id'] as String).toList();
        debugPrint('✅ Superadmin: acceso a ${_misNegociosIds.length} negocios');
      } else {
        // 3. Empleado: buscar negocios donde tiene permiso de chat QR
        // Criterios para recibir notificaciones de chat:
        // - es_administrador = true (admin del negocio)
        // - permisos_especificos contiene 'chat_qr': true
        // - rol_modulo contiene 'admin' o 'gerente'
        final asignaciones = await AppSupabase.client
            .from('empleados_negocios')
            .select('negocio_id, es_administrador, permisos_especificos, rol_modulo')
            .eq('auth_uid', user.id)
            .eq('activo', true);
        
        for (final asig in asignaciones) {
          final negocioId = asig['negocio_id']?.toString();
          if (negocioId == null) continue;
          
          // Verificar si tiene permiso de chat
          bool tienePermisoChatQR = false;
          
          // a) Es administrador del negocio
          if (asig['es_administrador'] == true) {
            tienePermisoChatQR = true;
            debugPrint('✅ Negocio $negocioId: es_administrador=true');
          }
          
          // b) Tiene permiso específico chat_qr
          final permisos = asig['permisos_especificos'];
          if (permisos != null && permisos is Map) {
            if (permisos['chat_qr'] == true || permisos['recibir_notificaciones_qr'] == true) {
              tienePermisoChatQR = true;
              debugPrint('✅ Negocio $negocioId: permiso chat_qr=true');
            }
          }
          
          // c) Rol de módulo incluye admin/gerente
          final rolModulo = asig['rol_modulo']?.toString().toLowerCase() ?? '';
          if (rolModulo.contains('admin') || rolModulo.contains('gerente') || rolModulo.contains('supervisor')) {
            tienePermisoChatQR = true;
            debugPrint('✅ Negocio $negocioId: rol_modulo=$rolModulo incluye admin');
          }
          
          if (tienePermisoChatQR && !_misNegociosIds.contains(negocioId)) {
            _misNegociosIds.add(negocioId);
          }
        }
        
        // 4. Si no tiene asignaciones en empleados_negocios, buscar por empleado tradicional
        if (_misNegociosIds.isEmpty) {
          final empleado = await AppSupabase.client
              .from('empleados')
              .select('id, sucursal_id, sucursales!inner(negocio_id)')
              .eq('usuario_id', user.id)
              .eq('activo', true)
              .maybeSingle();
          
          if (empleado != null && empleado['sucursales'] != null) {
            final negocioId = empleado['sucursales']['negocio_id'];
            if (negocioId != null) {
              _misNegociosIds.add(negocioId as String);
              debugPrint('✅ Negocio por sucursal: $negocioId');
            }
          }
        }
      }
      
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('📋 Negocios con permiso CHAT QR: $_misNegociosIds');
      debugPrint('═══════════════════════════════════════════════');
    } catch (e) {
      debugPrint('❌ Error cargando negocios: $e');
    }
  }

  /// Iniciar escucha de mensajes en tiempo real
  Future<void> iniciarEscucha() async {
    if (_isListening) {
      debugPrint('⚠️ Ya está escuchando, ignorando');
      return;
    }
    
    try {
      // Cancelar canal anterior si existe
      await _channel?.unsubscribe();
      
      debugPrint('🎧 Creando canal de Realtime para tarjetas_chat...');
      
      // Crear nuevo canal de Realtime
      _channel = AppSupabase.client
          .channel('tarjetas_chat_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'tarjetas_chat',
            callback: (payload) {
              debugPrint('═══════════════════════════════════════════════');
              debugPrint('📨 🔔🔔🔔 MENSAJE REALTIME RECIBIDO 🔔🔔🔔');
              debugPrint('📋 Payload: ${payload.newRecord}');
              debugPrint('📋 esSuperAdmin: $_esSuperAdmin');
              debugPrint('📋 misNegociosIds: $_misNegociosIds');
              debugPrint('═══════════════════════════════════════════════');
              _procesarNuevoMensaje(payload.newRecord);
            },
          )
          .subscribe((status, error) {
            debugPrint('════════════════════════════════════════');
            debugPrint('📡 REALTIME STATUS: $status');
            if (error != null) {
              debugPrint('❌ Realtime ERROR: $error');
            }
            debugPrint('════════════════════════════════════════');
          });
      
      _isListening = true;
      debugPrint('✅ Escuchando mensajes de chat en tiempo real. Canal activo.');
    } catch (e) {
      debugPrint('❌ Error iniciando escucha realtime: $e');
    }
  }

  /// Procesar mensaje nuevo recibido
  Future<void> _procesarNuevoMensaje(Map<String, dynamic> mensaje) async {
    try {
      // Solo notificar mensajes de visitantes (no respuestas)
      if (mensaje['es_respuesta'] == true) return;
      
      final negocioId = mensaje['negocio_id']?.toString();
      
      // Verificar si el mensaje es para uno de mis negocios
      if (!_esSuperAdmin && negocioId != null && !_misNegociosIds.contains(negocioId)) {
        return; // No es para mí
      }
      
      debugPrint('📨 Nuevo mensaje de chat recibido: ${mensaje['mensaje']}');
      
      // Obtener info de la tarjeta para el título
      String nombreNegocio = 'Cliente';
      final tarjetaId = mensaje['tarjeta_id'];
      if (tarjetaId != null) {
        try {
          final tarjeta = await AppSupabase.client
              .from('tarjetas_servicio')
              .select('nombre_negocio')
              .eq('id', tarjetaId)
              .maybeSingle();
          nombreNegocio = tarjeta?['nombre_negocio'] ?? 'Cliente';
        } catch (_) {}
      }
      
      final visitanteNombre = mensaje['visitante_nombre'] ?? 'Visitante';
      final textoMensaje = mensaje['mensaje'] ?? '';
      
      // Mostrar notificación
      await _mostrarNotificacion(
        titulo: '💬 Mensaje de $nombreNegocio',
        mensaje: '$visitanteNombre: $textoMensaje',
        payload: mensaje,
      );
      
      // Notificar a la UI si hay callback
      onNuevoMensaje?.call(mensaje);
      
    } catch (e) {
      debugPrint('❌ Error procesando mensaje: $e');
    }
  }

  /// Mostrar notificación local
  Future<void> _mostrarNotificacion({
    required String titulo,
    required String mensaje,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        titulo,
        mensaje,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _chatChannel.id,
            _chatChannel.name,
            channelDescription: _chatChannel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
            styleInformation: BigTextStyleInformation(mensaje),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'chat_tarjetas',
      );
    } catch (e) {
      debugPrint('❌ Error mostrando notificación: $e');
    }
  }

  /// Detener escucha
  Future<void> detenerEscucha() async {
    try {
      await _channel?.unsubscribe();
      _channel = null;
      _isListening = false;
      debugPrint('🔇 Escucha de chat detenida');
    } catch (e) {
      debugPrint('Error deteniendo escucha: $e');
    }
  }

  /// Recargar negocios (cuando cambie la sesión)
  Future<void> recargarNegocios() async {
    await _cargarMisNegocios();
  }

  /// Verificar si está escuchando
  bool get isListening => _isListening;
  
  /// Obtener cantidad de negocios
  int get negociosCount => _misNegociosIds.length;
}
