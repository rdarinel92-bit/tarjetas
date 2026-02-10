import 'package:flutter/foundation.dart';
import '../models/amortizacion_model.dart';
import '../services/api_service.dart';

class AmortizacionesRepository {
  final client = ApiService.client;

  /// Obtener amortizaciones de un préstamo
  Future<List<AmortizacionModel>> obtenerAmortizacionesPorPrestamo(String prestamoId) async {
    try {
      final response = await client
          .from('amortizaciones')
          .select()
          .eq('prestamo_id', prestamoId)
          .order('numero_cuota');
      return (response as List).map((e) => AmortizacionModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener amortizaciones: $e');
      return [];
    }
  }

  /// Crear una amortización
  Future<bool> crearAmortizacion(AmortizacionModel amortizacion) async {
    try {
      await client.from('amortizaciones').insert(amortizacion.toMapForInsert());
      return true;
    } catch (e) {
      debugPrint('Error al crear amortización: $e');
      return false;
    }
  }

  /// Crear amortizaciones en lote (para migración de préstamos)
  Future<bool> crearAmortizacionesEnLote(List<AmortizacionModel> amortizaciones) async {
    try {
      final data = amortizaciones.map((a) => a.toMapForInsert()).toList();
      await client.from('amortizaciones').insert(data);
      return true;
    } catch (e) {
      debugPrint('Error al crear amortizaciones en lote: $e');
      return false;
    }
  }

  /// Actualizar estado de una amortización
  Future<bool> actualizarEstado(String amortizacionId, String estado, {DateTime? fechaPago}) async {
    try {
      final Map<String, dynamic> data = {'estado': estado};
      if (fechaPago != null) {
        data['fecha_pago'] = fechaPago.toIso8601String();
      }
      await client.from('amortizaciones').update(data).eq('id', amortizacionId);
      return true;
    } catch (e) {
      debugPrint('Error al actualizar amortización: $e');
      return false;
    }
  }

  /// Marcar amortización como pagada
  Future<bool> marcarComoPagada(String amortizacionId) async {
    return await actualizarEstado(amortizacionId, 'pagado', fechaPago: DateTime.now());
  }

  /// Obtener amortizaciones pendientes (vencidas)
  Future<List<AmortizacionModel>> obtenerAmortizacionesPendientes() async {
    try {
      final response = await client
          .from('amortizaciones')
          .select()
          .eq('estado', 'pendiente')
          .lte('fecha_vencimiento', DateTime.now().toIso8601String())
          .order('fecha_vencimiento');
      return (response as List).map((e) => AmortizacionModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener amortizaciones pendientes: $e');
      return [];
    }
  }

  /// Obtener próximas amortizaciones a vencer (para notificaciones)
  Future<List<AmortizacionModel>> obtenerProximasAVencer({int dias = 7}) async {
    try {
      final hoy = DateTime.now();
      final limite = hoy.add(Duration(days: dias));
      final response = await client
          .from('amortizaciones')
          .select()
          .eq('estado', 'pendiente')
          .gte('fecha_vencimiento', hoy.toIso8601String())
          .lte('fecha_vencimiento', limite.toIso8601String())
          .order('fecha_vencimiento');
      return (response as List).map((e) => AmortizacionModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener próximas amortizaciones: $e');
      return [];
    }
  }

  /// Obtener resumen de amortizaciones por préstamo
  Future<Map<String, dynamic>> obtenerResumenPorPrestamo(String prestamoId) async {
    final amortizaciones = await obtenerAmortizacionesPorPrestamo(prestamoId);
    
    final total = amortizaciones.length;
    final pagadas = amortizaciones.where((a) => a.estado == 'pagado').length;
    final pendientes = amortizaciones.where((a) => a.estado == 'pendiente').length;
    final montoTotal = amortizaciones.fold<double>(0, (sum, a) => sum + a.monto);
    final montoPagado = amortizaciones.where((a) => a.estado == 'pagado').fold<double>(0, (sum, a) => sum + a.monto);
    final montoPendiente = amortizaciones.where((a) => a.estado == 'pendiente').fold<double>(0, (sum, a) => sum + a.monto);

    return {
      'total': total,
      'pagadas': pagadas,
      'pendientes': pendientes,
      'montoTotal': montoTotal,
      'montoPagado': montoPagado,
      'montoPendiente': montoPendiente,
      'progreso': total > 0 ? pagadas / total : 0.0,
    };
  }

  /// Eliminar amortizaciones de un préstamo (para rehacer plan de pagos)
  Future<bool> eliminarAmortizacionesPorPrestamo(String prestamoId) async {
    try {
      await client.from('amortizaciones').delete().eq('prestamo_id', prestamoId);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar amortizaciones: $e');
      return false;
    }
  }
}
