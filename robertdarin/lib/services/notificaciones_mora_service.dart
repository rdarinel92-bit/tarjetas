// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/supabase_client.dart';

/// Modelo de información de mora
class MoraInfo {
  final String prestamoId;
  final String clienteNombre;
  final double montoPendiente;
  final int diasMora;
  final DateTime fechaVencimiento;

  MoraInfo({
    required this.prestamoId,
    required this.clienteNombre,
    required this.montoPendiente,
    required this.diasMora,
    required this.fechaVencimiento,
  });
}

/// Servicio de Notificaciones de Mora para Avales
/// Envía notificaciones push cuando hay pagos vencidos en préstamos que garantizan
class NotificacionesMoraService {
  static final NotificacionesMoraService _instance = NotificacionesMoraService._internal();
  factory NotificacionesMoraService() => _instance;
  NotificacionesMoraService._internal();

  Timer? _timerVerificacion;

  /// Verifica moras activas para un aval específico
  static Future<List<MoraInfo>> verificarMorasParaAval(
    String avalId,
    List<Map<String, dynamic>> prestamos,
  ) async {
    final List<MoraInfo> morasActivas = [];
    final hoy = DateTime.now();

    try {
      for (var prestamo in prestamos) {
        final prestamoId = prestamo['id']?.toString();
        if (prestamoId == null) continue;

        // Buscar pagos vencidos de este préstamo
        final pagosVencidos = await AppSupabase.client
            .from('amortizaciones')
            .select('monto, fecha_vencimiento')
            .eq('prestamo_id', prestamoId)
            .eq('pagado', false)
            .lt('fecha_vencimiento', hoy.toIso8601String())
            .order('fecha_vencimiento')
            .limit(1);

        if ((pagosVencidos as List).isNotEmpty) {
          final pago = pagosVencidos.first;
          final fechaVencimiento = DateTime.parse(pago['fecha_vencimiento']);
          final diasMora = hoy.difference(fechaVencimiento).inDays;

          morasActivas.add(MoraInfo(
            prestamoId: prestamoId,
            clienteNombre: prestamo['clientes']?['nombre_completo'] ?? 'Cliente',
            montoPendiente: (pago['monto'] as num?)?.toDouble() ?? 0,
            diasMora: diasMora,
            fechaVencimiento: fechaVencimiento,
          ));
        }
      }
    } catch (e) {
      debugPrint("Error verificando moras para aval: $e");
    }

    return morasActivas;
  }

  /// Inicia el servicio de verificación periódica
  void iniciar() {
    // Verificar cada hora
    _timerVerificacion = Timer.periodic(
      const Duration(hours: 1),
      (_) => verificarMorasYNotificar(),
    );
    
    // Verificar inmediatamente al iniciar
    verificarMorasYNotificar();
  }

  void detener() {
    _timerVerificacion?.cancel();
    _timerVerificacion = null;
  }

  /// Verifica pagos vencidos y envía notificaciones a los avales
  Future<void> verificarMorasYNotificar() async {
    try {
      // 1. Obtener todos los pagos vencidos no pagados
      final hoy = DateTime.now();
      final pagosVencidos = await AppSupabase.client
          .from('amortizaciones')
          .select('''
            id, 
            monto, 
            fecha_vencimiento, 
            prestamo_id,
            prestamos(
              id, 
              monto, 
              estado,
              cliente_id,
              clientes(nombre_completo),
              aval_id
            )
          ''')
          .eq('pagado', false)
          .lt('fecha_vencimiento', hoy.toIso8601String())
          .order('fecha_vencimiento');

      if ((pagosVencidos as List).isEmpty) return;

      // 2. Agrupar por préstamo y obtener avales
      final prestamosProcesados = <String>{};
      
      for (var pago in pagosVencidos) {
        final prestamo = pago['prestamos'];
        if (prestamo == null) continue;

        final prestamoId = prestamo['id'];
        if (prestamosProcesados.contains(prestamoId)) continue;
        prestamosProcesados.add(prestamoId);

        final avalId = prestamo['aval_id'];
        if (avalId == null) continue;

        // 3. Obtener info del aval
        final aval = await AppSupabase.client
            .from('avales')
            .select('id, nombre, usuario_id')
            .eq('id', avalId)
            .maybeSingle();

        if (aval == null || aval['usuario_id'] == null) continue;

        // 4. Calcular días de mora
        final fechaVencimiento = DateTime.parse(pago['fecha_vencimiento']);
        final diasMora = hoy.difference(fechaVencimiento).inDays;

        // 5. Crear notificación según nivel de mora
        final tipoNotificacion = _determinarTipoNotificacion(diasMora);
        
        // Verificar si ya se envió notificación hoy para este préstamo
        final yaNotificado = await _yaSeNotifico(aval['usuario_id'], prestamoId, tipoNotificacion);
        if (yaNotificado) continue;

        // 6. Enviar notificación
        await _enviarNotificacionMora(
          usuarioId: aval['usuario_id'],
          avalNombre: aval['nombre'],
          clienteNombre: prestamo['clientes']?['nombre_completo'] ?? 'Cliente',
          prestamoId: prestamoId,
          montoPendiente: pago['monto']?.toDouble() ?? 0,
          diasMora: diasMora,
          tipoNotificacion: tipoNotificacion,
        );
      }

    } catch (e) {
      debugPrint("Error verificando moras: $e");
    }
  }

  String _determinarTipoNotificacion(int diasMora) {
    if (diasMora <= 3) return 'mora_leve';       // 1-3 días
    if (diasMora <= 7) return 'mora_moderada';   // 4-7 días
    if (diasMora <= 15) return 'mora_seria';     // 8-15 días
    if (diasMora <= 30) return 'mora_grave';     // 16-30 días
    return 'mora_critica';                        // +30 días
  }

  Future<bool> _yaSeNotifico(String usuarioId, String prestamoId, String tipo) async {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

    final existente = await AppSupabase.client
        .from('notificaciones')
        .select('id')
        .eq('usuario_id', usuarioId)
        .eq('tipo', tipo)
        .eq('referencia_id', prestamoId)
        .gte('created_at', inicioHoy.toIso8601String())
        .maybeSingle();

    return existente != null;
  }

  Future<void> _enviarNotificacionMora({
    required String usuarioId,
    required String avalNombre,
    required String clienteNombre,
    required String prestamoId,
    required double montoPendiente,
    required int diasMora,
    required String tipoNotificacion,
  }) async {
    final config = _obtenerConfigNotificacion(tipoNotificacion, clienteNombre, montoPendiente, diasMora);

    await AppSupabase.client.from('notificaciones').insert({
      'usuario_id': usuarioId,
      'titulo': config['titulo'],
      'mensaje': config['mensaje'],
      'tipo': tipoNotificacion,
      'prioridad': config['prioridad'],
      'icono': config['icono'],
      'referencia_id': prestamoId,
      'referencia_tipo': 'prestamo',
      'ruta_destino': '/dashboardAval',
      'leida': false,
    });

    debugPrint("📬 Notificación enviada: $tipoNotificacion para aval $avalNombre");
  }

  Map<String, dynamic> _obtenerConfigNotificacion(
    String tipo, 
    String clienteNombre, 
    double monto, 
    int dias,
  ) {
    switch (tipo) {
      case 'mora_leve':
        return {
          'titulo': '⚠️ Pago pendiente',
          'mensaje': 'El préstamo de $clienteNombre tiene $dias día(s) de retraso. Monto: \$${monto.toStringAsFixed(2)}',
          'prioridad': 'normal',
          'icono': 'warning',
        };
      
      case 'mora_moderada':
        return {
          'titulo': '🔔 Alerta de Pago',
          'mensaje': 'ATENCIÓN: El préstamo de $clienteNombre lleva $dias días vencido. Monto pendiente: \$${monto.toStringAsFixed(2)}',
          'prioridad': 'alta',
          'icono': 'notifications_active',
        };
      
      case 'mora_seria':
        return {
          'titulo': '🚨 Mora Seria',
          'mensaje': 'URGENTE: $dias días de mora en préstamo de $clienteNombre. Como aval, podrías ser contactado. Monto: \$${monto.toStringAsFixed(2)}',
          'prioridad': 'urgente',
          'icono': 'error',
        };
      
      case 'mora_grave':
        return {
          'titulo': '❌ MORA GRAVE',
          'mensaje': 'CRÍTICO: $dias días sin pago. El préstamo de $clienteNombre entra en proceso de cobranza intensiva. Monto: \$${monto.toStringAsFixed(2)}',
          'prioridad': 'critica',
          'icono': 'dangerous',
        };
      
      case 'mora_critica':
        return {
          'titulo': '🔴 ACCIÓN REQUERIDA',
          'mensaje': 'URGENTE: +$dias días de mora. Se requiere tu intervención como aval del préstamo de $clienteNombre. Monto: \$${monto.toStringAsFixed(2)}',
          'prioridad': 'critica',
          'icono': 'report',
        };
      
      default:
        return {
          'titulo': 'Notificación de Pago',
          'mensaje': 'Hay un pago pendiente en el préstamo de $clienteNombre',
          'prioridad': 'normal',
          'icono': 'info',
        };
    }
  }
}

/// Widget de banner de mora para mostrar en el dashboard del aval
class BannerMoraWidget extends StatelessWidget {
  final int diasMora;
  final double montoPendiente;
  final String clienteNombre;
  final VoidCallback? onContactar;

  const BannerMoraWidget({
    super.key,
    required this.diasMora,
    required this.montoPendiente,
    required this.clienteNombre,
    this.onContactar,
  });

  @override
  Widget build(BuildContext context) {
    final config = _obtenerConfig();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [config['color1'], config['color2']],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: config['color1'].withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(config['icono'], color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  config['titulo'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$diasMora días",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Préstamo de $clienteNombre",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            "Monto pendiente: \$${montoPendiente.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (onContactar != null) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onContactar,
                icon: const Icon(Icons.chat, size: 18),
                label: const Text("Contactar al deudor"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: config['color1'],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _obtenerConfig() {
    if (diasMora <= 3) {
      return {
        'titulo': 'Pago Pendiente',
        'icono': Icons.info,
        'color1': Colors.orange.shade600,
        'color2': Colors.orange.shade400,
      };
    } else if (diasMora <= 7) {
      return {
        'titulo': 'Alerta de Mora',
        'icono': Icons.warning,
        'color1': Colors.deepOrange.shade600,
        'color2': Colors.orange.shade600,
      };
    } else if (diasMora <= 15) {
      return {
        'titulo': 'Mora Seria',
        'icono': Icons.notification_important,
        'color1': Colors.red.shade600,
        'color2': Colors.deepOrange.shade600,
      };
    } else {
      return {
        'titulo': 'MORA CRÍTICA',
        'icono': Icons.dangerous,
        'color1': Colors.red.shade800,
        'color2': Colors.red.shade600,
      };
    }
  }
}

/// Tipos de notificaciones de mora
enum TipoMora {
  leve,       // 1-3 días
  moderada,   // 4-7 días
  seria,      // 8-15 días
  grave,      // 16-30 días
  critica,    // +30 días
}

extension TipoMoraExtension on TipoMora {
  String get nombre {
    switch (this) {
      case TipoMora.leve: return 'Leve';
      case TipoMora.moderada: return 'Moderada';
      case TipoMora.seria: return 'Seria';
      case TipoMora.grave: return 'Grave';
      case TipoMora.critica: return 'Crítica';
    }
  }

  Color get color {
    switch (this) {
      case TipoMora.leve: return Colors.orange;
      case TipoMora.moderada: return Colors.deepOrange;
      case TipoMora.seria: return Colors.red;
      case TipoMora.grave: return Colors.red.shade700;
      case TipoMora.critica: return Colors.red.shade900;
    }
  }

  IconData get icono {
    switch (this) {
      case TipoMora.leve: return Icons.info;
      case TipoMora.moderada: return Icons.warning;
      case TipoMora.seria: return Icons.notification_important;
      case TipoMora.grave: return Icons.error;
      case TipoMora.critica: return Icons.dangerous;
    }
  }

  static TipoMora fromDias(int dias) {
    if (dias <= 3) return TipoMora.leve;
    if (dias <= 7) return TipoMora.moderada;
    if (dias <= 15) return TipoMora.seria;
    if (dias <= 30) return TipoMora.grave;
    return TipoMora.critica;
  }
}
