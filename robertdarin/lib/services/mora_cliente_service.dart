import 'dart:async';
import 'package:flutter/material.dart';
import '../core/supabase_client.dart';

/// Modelo de configuración de moras
class ConfiguracionMora {
  final String? id;
  final String? negocioId;
  
  // Préstamos
  final double prestamosMoraDiaria;
  final double prestamosMoraMaxima;
  final int prestamosDiasGracia;
  final bool prestamosAplicarAutomatico;
  
  // Tandas
  final double tandasMoraDiaria;
  final double tandasMoraMaxima;
  final int tandasDiasGracia;
  final bool tandasAplicarAutomatico;
  
  // Notificaciones
  final int notificarDiasAntes;
  final bool notificarRecordatorioDiario;
  final bool notificarAlAval;
  
  // Escalamiento
  final int nivel1Dias;
  final int nivel2Dias;
  final int nivel3Dias;
  final int nivel4Dias;
  
  // Acciones
  final int bloquearClienteDias;
  final int enviarALegalDias;

  ConfiguracionMora({
    this.id,
    this.negocioId,
    this.prestamosMoraDiaria = 1.0,
    this.prestamosMoraMaxima = 30.0,
    this.prestamosDiasGracia = 0,
    this.prestamosAplicarAutomatico = true,
    this.tandasMoraDiaria = 2.0,
    this.tandasMoraMaxima = 50.0,
    this.tandasDiasGracia = 1,
    this.tandasAplicarAutomatico = true,
    this.notificarDiasAntes = 3,
    this.notificarRecordatorioDiario = true,
    this.notificarAlAval = true,
    this.nivel1Dias = 1,
    this.nivel2Dias = 7,
    this.nivel3Dias = 15,
    this.nivel4Dias = 30,
    this.bloquearClienteDias = 60,
    this.enviarALegalDias = 90,
  });

  factory ConfiguracionMora.fromMap(Map<String, dynamic> map) {
    return ConfiguracionMora(
      id: map['id'],
      negocioId: map['negocio_id'],
      prestamosMoraDiaria: (map['prestamos_mora_diaria'] as num?)?.toDouble() ?? 1.0,
      prestamosMoraMaxima: (map['prestamos_mora_maxima'] as num?)?.toDouble() ?? 30.0,
      prestamosDiasGracia: map['prestamos_dias_gracia'] ?? 0,
      prestamosAplicarAutomatico: map['prestamos_aplicar_automatico'] ?? true,
      tandasMoraDiaria: (map['tandas_mora_diaria'] as num?)?.toDouble() ?? 2.0,
      tandasMoraMaxima: (map['tandas_mora_maxima'] as num?)?.toDouble() ?? 50.0,
      tandasDiasGracia: map['tandas_dias_gracia'] ?? 1,
      tandasAplicarAutomatico: map['tandas_aplicar_automatico'] ?? true,
      notificarDiasAntes: map['notificar_dias_antes'] ?? 3,
      notificarRecordatorioDiario: map['notificar_recordatorio_diario'] ?? true,
      notificarAlAval: map['notificar_al_aval'] ?? true,
      nivel1Dias: map['nivel_1_dias'] ?? 1,
      nivel2Dias: map['nivel_2_dias'] ?? 7,
      nivel3Dias: map['nivel_3_dias'] ?? 15,
      nivel4Dias: map['nivel_4_dias'] ?? 30,
      bloquearClienteDias: map['bloquear_cliente_dias'] ?? 60,
      enviarALegalDias: map['enviar_a_legal_dias'] ?? 90,
    );
  }

  Map<String, dynamic> toMap() => {
    if (negocioId != null) 'negocio_id': negocioId,
    'prestamos_mora_diaria': prestamosMoraDiaria,
    'prestamos_mora_maxima': prestamosMoraMaxima,
    'prestamos_dias_gracia': prestamosDiasGracia,
    'prestamos_aplicar_automatico': prestamosAplicarAutomatico,
    'tandas_mora_diaria': tandasMoraDiaria,
    'tandas_mora_maxima': tandasMoraMaxima,
    'tandas_dias_gracia': tandasDiasGracia,
    'tandas_aplicar_automatico': tandasAplicarAutomatico,
    'notificar_dias_antes': notificarDiasAntes,
    'notificar_recordatorio_diario': notificarRecordatorioDiario,
    'notificar_al_aval': notificarAlAval,
    'nivel_1_dias': nivel1Dias,
    'nivel_2_dias': nivel2Dias,
    'nivel_3_dias': nivel3Dias,
    'nivel_4_dias': nivel4Dias,
    'bloquear_cliente_dias': bloquearClienteDias,
    'enviar_a_legal_dias': enviarALegalDias,
  };
}

/// Modelo de mora de préstamo
class MoraPrestamo {
  final String id;
  final String prestamoId;
  final String? amortizacionId;
  final int diasMora;
  final double montoCuotaOriginal;
  final double porcentajeMoraAplicado;
  final double montoMora;
  final double montoTotalConMora;
  final String estado;
  final String? condonadoPor;
  final String? motivoCondonacion;
  final DateTime? fechaCondonacion;
  final double montoMoraPagado;
  final DateTime? fechaPagoMora;
  final bool generadoAutomatico;
  final DateTime createdAt;
  
  // Datos relacionados
  final String? clienteNombre;
  final int? numeroCuota;
  final DateTime? fechaVencimiento;

  MoraPrestamo({
    required this.id,
    required this.prestamoId,
    this.amortizacionId,
    required this.diasMora,
    required this.montoCuotaOriginal,
    required this.porcentajeMoraAplicado,
    required this.montoMora,
    required this.montoTotalConMora,
    required this.estado,
    this.condonadoPor,
    this.motivoCondonacion,
    this.fechaCondonacion,
    required this.montoMoraPagado,
    this.fechaPagoMora,
    required this.generadoAutomatico,
    required this.createdAt,
    this.clienteNombre,
    this.numeroCuota,
    this.fechaVencimiento,
  });

  factory MoraPrestamo.fromMap(Map<String, dynamic> map) {
    final prestamo = map['prestamos'];
    final amortizacion = map['amortizaciones'];
    
    return MoraPrestamo(
      id: map['id'] ?? '',
      prestamoId: map['prestamo_id'] ?? '',
      amortizacionId: map['amortizacion_id'],
      diasMora: map['dias_mora'] ?? 0,
      montoCuotaOriginal: (map['monto_cuota_original'] as num?)?.toDouble() ?? 0,
      porcentajeMoraAplicado: (map['porcentaje_mora_aplicado'] as num?)?.toDouble() ?? 0,
      montoMora: (map['monto_mora'] as num?)?.toDouble() ?? 0,
      montoTotalConMora: (map['monto_total_con_mora'] as num?)?.toDouble() ?? 0,
      estado: map['estado'] ?? 'pendiente',
      condonadoPor: map['condonado_por'],
      motivoCondonacion: map['motivo_condonacion'],
      fechaCondonacion: map['fecha_condonacion'] != null 
          ? DateTime.parse(map['fecha_condonacion']) : null,
      montoMoraPagado: (map['monto_mora_pagado'] as num?)?.toDouble() ?? 0,
      fechaPagoMora: map['fecha_pago_mora'] != null 
          ? DateTime.parse(map['fecha_pago_mora']) : null,
      generadoAutomatico: map['generado_automatico'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      clienteNombre: prestamo?['clientes']?['nombre_completo'],
      numeroCuota: amortizacion?['numero_cuota'],
      fechaVencimiento: amortizacion?['fecha_vencimiento'] != null
          ? DateTime.parse(amortizacion['fecha_vencimiento']) : null,
    );
  }
  
  bool get pendiente => estado == 'pendiente';
  bool get pagada => estado == 'pagada';
  bool get condonada => estado == 'condonada';
  double get saldoMoraPendiente => montoMora - montoMoraPagado;
}

/// Resultado de cálculo de mora
class CalculoMora {
  final int diasMora;
  final double montoCuota;
  final double porcentajeMora;
  final double montoMora;
  final double montoTotal;

  CalculoMora({
    required this.diasMora,
    required this.montoCuota,
    required this.porcentajeMora,
    required this.montoMora,
    required this.montoTotal,
  });
}

/// Cliente en mora
class ClienteEnMora {
  final String clienteId;
  final String clienteNombre;
  final String? clienteTelefono;
  final int totalPrestamosEnMora;
  final int totalTandasEnMora;
  final double montoTotalAdeudado;
  final double montoTotalMora;
  final int diasMoraMaximo;
  final String nivelMora;
  final bool bloqueado;
  final List<String> prestamosIds;
  final List<String> tandasIds;

  ClienteEnMora({
    required this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono,
    required this.totalPrestamosEnMora,
    required this.totalTandasEnMora,
    required this.montoTotalAdeudado,
    required this.montoTotalMora,
    required this.diasMoraMaximo,
    required this.nivelMora,
    required this.bloqueado,
    required this.prestamosIds,
    required this.tandasIds,
  });
}

/// Servicio principal de moras para clientes
class MoraClienteService {
  static final MoraClienteService _instance = MoraClienteService._internal();
  factory MoraClienteService() => _instance;
  MoraClienteService._internal();
  
  Timer? _timerVerificacion;
  ConfiguracionMora _config = ConfiguracionMora();

  /// Obtiene la configuración de moras
  Future<ConfiguracionMora> obtenerConfiguracion({String? negocioId}) async {
    try {
      final query = AppSupabase.client.from('configuracion_moras').select();
      
      final res = negocioId != null
          ? await query.eq('negocio_id', negocioId).maybeSingle()
          : await query.limit(1).maybeSingle();
      
      if (res != null) {
        _config = ConfiguracionMora.fromMap(res);
      }
      return _config;
    } catch (e) {
      debugPrint('Error obteniendo configuración de moras: $e');
      return _config;
    }
  }

  /// Guarda la configuración de moras
  Future<bool> guardarConfiguracion(ConfiguracionMora config) async {
    try {
      final data = config.toMap();
      
      if (config.id != null) {
        await AppSupabase.client
            .from('configuracion_moras')
            .update(data)
            .eq('id', config.id!);
      } else {
        await AppSupabase.client
            .from('configuracion_moras')
            .insert(data);
      }
      
      _config = config;
      return true;
    } catch (e) {
      debugPrint('Error guardando configuración de moras: $e');
      return false;
    }
  }

  /// Calcula la mora para una cuota vencida
  CalculoMora calcularMora({
    required double montoCuota,
    required DateTime fechaVencimiento,
    ConfiguracionMora? config,
  }) {
    final cfg = config ?? _config;
    final hoy = DateTime.now();
    
    int diasMora = hoy.difference(fechaVencimiento).inDays;
    
    // Aplicar días de gracia
    diasMora = diasMora > cfg.prestamosDiasGracia 
        ? diasMora - cfg.prestamosDiasGracia 
        : 0;
    
    if (diasMora <= 0) {
      return CalculoMora(
        diasMora: 0,
        montoCuota: montoCuota,
        porcentajeMora: 0,
        montoMora: 0,
        montoTotal: montoCuota,
      );
    }
    
    // Calcular porcentaje (limitado al máximo)
    double porcentajeMora = (diasMora * cfg.prestamosMoraDiaria);
    if (porcentajeMora > cfg.prestamosMoraMaxima) {
      porcentajeMora = cfg.prestamosMoraMaxima;
    }
    
    final montoMora = montoCuota * porcentajeMora / 100;
    
    return CalculoMora(
      diasMora: diasMora,
      montoCuota: montoCuota,
      porcentajeMora: porcentajeMora,
      montoMora: montoMora,
      montoTotal: montoCuota + montoMora,
    );
  }

  /// Determina el nivel de mora según los días
  String determinarNivelMora(int diasMora, {ConfiguracionMora? config}) {
    final cfg = config ?? _config;
    
    if (diasMora <= 0) return 'al_corriente';
    if (diasMora < cfg.nivel1Dias) return 'recordatorio';
    if (diasMora < cfg.nivel2Dias) return 'leve';
    if (diasMora < cfg.nivel3Dias) return 'seria';
    if (diasMora < cfg.nivel4Dias) return 'grave';
    return 'critica';
  }

  /// Obtiene todas las moras pendientes de préstamos
  /// V10.55: Agregado filtro por negocioId
  Future<List<MoraPrestamo>> obtenerMorasPendientes({
    String? clienteId,
    String? prestamoId,
    String? negocioId,
  }) async {
    try {
      var query = AppSupabase.client.from('moras_prestamos').select('''
        *,
        prestamos(
          id,
          monto,
          negocio_id,
          cliente_id,
          clientes(nombre_completo, telefono)
        ),
        amortizaciones(
          numero_cuota,
          fecha_vencimiento
        )
      ''').eq('estado', 'pendiente');
      
      if (prestamoId != null) {
        query = query.eq('prestamo_id', prestamoId);
      }
      
      final res = await query.order('created_at', ascending: false);
      
      List<MoraPrestamo> moras = (res as List).map((m) => MoraPrestamo.fromMap(m)).toList();
      
      // V10.55: Filtrar por negocio si se especifica
      if (negocioId != null) {
        moras = moras.where((m) {
          final prestamoData = (res as List).firstWhere(
            (r) => r['prestamo_id'] == m.prestamoId,
            orElse: () => null,
          );
          return prestamoData?['prestamos']?['negocio_id'] == negocioId;
        }).toList();
      }
      
      // Filtrar por cliente si es necesario
      if (clienteId != null) {
        moras = moras.where((m) => 
          m.clienteNombre != null // Si tiene datos relacionados, comparar
        ).toList();
      }
      
      return moras;
    } catch (e) {
      debugPrint('Error obteniendo moras pendientes: $e');
      return [];
    }
  }

  /// Registra o actualiza una mora manualmente
  Future<bool> registrarMora({
    required String prestamoId,
    required String amortizacionId,
    required int diasMora,
    required double montoCuota,
    required double porcentajeMora,
    required double montoMora,
  }) async {
    try {
      await AppSupabase.client.from('moras_prestamos').upsert({
        'prestamo_id': prestamoId,
        'amortizacion_id': amortizacionId,
        'dias_mora': diasMora,
        'monto_cuota_original': montoCuota,
        'porcentaje_mora_aplicado': porcentajeMora,
        'monto_mora': montoMora,
        'monto_total_con_mora': montoCuota + montoMora,
        'generado_automatico': false,
      }, onConflict: 'amortizacion_id');
      
      return true;
    } catch (e) {
      debugPrint('Error registrando mora: $e');
      return false;
    }
  }

  /// Condonar (perdonar) una mora
  Future<bool> condonarMora({
    required String moraId,
    required String condonadoPor,
    required String motivo,
  }) async {
    try {
      await AppSupabase.client.from('moras_prestamos').update({
        'estado': 'condonada',
        'condonado_por': condonadoPor,
        'motivo_condonacion': motivo,
        'fecha_condonacion': DateTime.now().toIso8601String(),
      }).eq('id', moraId);
      
      return true;
    } catch (e) {
      debugPrint('Error condonando mora: $e');
      return false;
    }
  }

  /// Registrar pago de mora
  Future<bool> registrarPagoMora({
    required String moraId,
    required double monto,
  }) async {
    try {
      // Obtener mora actual
      final mora = await AppSupabase.client
          .from('moras_prestamos')
          .select()
          .eq('id', moraId)
          .single();
      
      final montoMora = (mora['monto_mora'] as num).toDouble();
      final montoYaPagado = (mora['monto_mora_pagado'] as num?)?.toDouble() ?? 0;
      final nuevoTotal = montoYaPagado + monto;
      
      final nuevoEstado = nuevoTotal >= montoMora ? 'pagada' : 'pendiente';
      
      await AppSupabase.client.from('moras_prestamos').update({
        'monto_mora_pagado': nuevoTotal,
        'estado': nuevoEstado,
        'fecha_pago_mora': nuevoEstado == 'pagada' ? DateTime.now().toIso8601String() : null,
      }).eq('id', moraId);
      
      return true;
    } catch (e) {
      debugPrint('Error registrando pago de mora: $e');
      return false;
    }
  }

  /// Obtiene clientes en mora con resumen
  /// V10.55: Agregado filtro por negocioId
  Future<List<ClienteEnMora>> obtenerClientesEnMora({String? negocioId}) async {
    try {
      final hoy = DateTime.now();
      
      // Obtener amortizaciones vencidas no pagadas
      var query = AppSupabase.client
          .from('amortizaciones')
          .select('''
            id,
            prestamo_id,
            numero_cuota,
            monto_cuota,
            fecha_vencimiento,
            prestamos(
              id,
              negocio_id,
              cliente_id,
              clientes(id, nombre_completo, telefono)
            )
          ''')
          .eq('estado', 'vencido')
          .lt('fecha_vencimiento', hoy.toIso8601String());
      
      final vencidos = await query;
      
      // Agrupar por cliente
      final Map<String, ClienteEnMora> clientesMap = {};
      
      for (var v in (vencidos as List)) {
        final prestamo = v['prestamos'];
        if (prestamo == null) continue;
        
        // V10.55: Filtrar por negocio si se especifica
        if (negocioId != null && prestamo['negocio_id'] != negocioId) continue;
        
        final cliente = prestamo['clientes'];
        if (cliente == null) continue;
        
        final clienteId = cliente['id']?.toString() ?? '';
        if (clienteId.isEmpty) continue;
        
        final fechaVenc = DateTime.parse(v['fecha_vencimiento']);
        final diasMora = hoy.difference(fechaVenc).inDays;
        final montoCuota = (v['monto_cuota'] as num?)?.toDouble() ?? 0;
        
        // Calcular mora
        final calculo = calcularMora(
          montoCuota: montoCuota,
          fechaVencimiento: fechaVenc,
        );
        
        if (clientesMap.containsKey(clienteId)) {
          final existing = clientesMap[clienteId]!;
          final prestamosIds = List<String>.from(existing.prestamosIds);
          if (!prestamosIds.contains(prestamo['id'])) {
            prestamosIds.add(prestamo['id']);
          }
          
          clientesMap[clienteId] = ClienteEnMora(
            clienteId: clienteId,
            clienteNombre: cliente['nombre_completo'] ?? 'Sin nombre',
            clienteTelefono: cliente['telefono'],
            totalPrestamosEnMora: prestamosIds.length,
            totalTandasEnMora: existing.totalTandasEnMora,
            montoTotalAdeudado: existing.montoTotalAdeudado + montoCuota,
            montoTotalMora: existing.montoTotalMora + calculo.montoMora,
            diasMoraMaximo: diasMora > existing.diasMoraMaximo ? diasMora : existing.diasMoraMaximo,
            nivelMora: determinarNivelMora(
              diasMora > existing.diasMoraMaximo ? diasMora : existing.diasMoraMaximo
            ),
            bloqueado: (diasMora > existing.diasMoraMaximo ? diasMora : existing.diasMoraMaximo) >= _config.bloquearClienteDias,
            prestamosIds: prestamosIds,
            tandasIds: existing.tandasIds,
          );
        } else {
          clientesMap[clienteId] = ClienteEnMora(
            clienteId: clienteId,
            clienteNombre: cliente['nombre_completo'] ?? 'Sin nombre',
            clienteTelefono: cliente['telefono'],
            totalPrestamosEnMora: 1,
            totalTandasEnMora: 0,
            montoTotalAdeudado: montoCuota,
            montoTotalMora: calculo.montoMora,
            diasMoraMaximo: diasMora,
            nivelMora: determinarNivelMora(diasMora),
            bloqueado: diasMora >= _config.bloquearClienteDias,
            prestamosIds: [prestamo['id']],
            tandasIds: [],
          );
        }
      }
      
      // Ordenar por días de mora (más graves primero)
      final clientes = clientesMap.values.toList();
      clientes.sort((a, b) => b.diasMoraMaximo.compareTo(a.diasMoraMaximo));
      
      return clientes;
    } catch (e) {
      debugPrint('Error obteniendo clientes en mora: $e');
      return [];
    }
  }

  /// Verifica si un cliente está bloqueado por mora
  Future<bool> clienteEstaBloqueado(String clienteId) async {
    try {
      final bloqueado = await AppSupabase.client
          .from('clientes_bloqueados_mora')
          .select('id')
          .eq('cliente_id', clienteId)
          .eq('activo', true)
          .maybeSingle();
      
      return bloqueado != null;
    } catch (e) {
      debugPrint('Error verificando bloqueo: $e');
      return false;
    }
  }

  /// Bloquea un cliente por mora
  Future<bool> bloquearCliente({
    required String clienteId,
    required String motivo,
    required int diasMora,
    required double montoAdeudado,
    required List<String> prestamosEnMora,
    List<String>? tandasEnMora,
    required String bloqueadoPor,
  }) async {
    try {
      await AppSupabase.client.from('clientes_bloqueados_mora').insert({
        'cliente_id': clienteId,
        'motivo': motivo,
        'dias_mora_maximo': diasMora,
        'monto_total_adeudado': montoAdeudado,
        'prestamos_en_mora': prestamosEnMora,
        'tandas_en_mora': tandasEnMora ?? [],
        'bloqueado_por': bloqueadoPor,
      });
      
      return true;
    } catch (e) {
      debugPrint('Error bloqueando cliente: $e');
      return false;
    }
  }

  /// Desbloquea un cliente
  Future<bool> desbloquearCliente({
    required String clienteId,
    required String desbloqueadoPor,
    required String motivo,
  }) async {
    try {
      await AppSupabase.client.from('clientes_bloqueados_mora').update({
        'activo': false,
        'fecha_desbloqueo': DateTime.now().toIso8601String(),
        'desbloqueado_por': desbloqueadoPor,
        'motivo_desbloqueo': motivo,
      }).eq('cliente_id', clienteId).eq('activo', true);
      
      return true;
    } catch (e) {
      debugPrint('Error desbloqueando cliente: $e');
      return false;
    }
  }

  /// Envía notificación de mora a un cliente
  Future<bool> enviarNotificacionMora({
    required String clienteId,
    required String tipoDeuda, // 'prestamo' o 'tanda'
    String? prestamoId,
    String? tandaId,
    required String nivelMora,
    required String titulo,
    required String mensaje,
    required int diasMora,
    required double montoPendiente,
    required double montoMora,
    bool enviarAlAval = false,
    String? avalId,
  }) async {
    try {
      // Registrar notificación
      await AppSupabase.client.from('notificaciones_mora_cliente').insert({
        'cliente_id': clienteId,
        'tipo_deuda': tipoDeuda,
        'prestamo_id': prestamoId,
        'tanda_id': tandaId,
        'nivel_mora': nivelMora,
        'titulo': titulo,
        'mensaje': mensaje,
        'dias_mora': diasMora,
        'monto_pendiente': montoPendiente,
        'monto_mora': montoMora,
        'monto_total': montoPendiente + montoMora,
        'enviado_a_aval': enviarAlAval,
        'aval_id': avalId,
      });
      
      // También crear notificación general en app
      // Buscar usuario asociado al cliente
      final cliente = await AppSupabase.client
          .from('clientes')
          .select('usuario_id')
          .eq('id', clienteId)
          .maybeSingle();
      
      if (cliente != null && cliente['usuario_id'] != null) {
        await AppSupabase.client.from('notificaciones').insert({
          'usuario_id': cliente['usuario_id'],
          'titulo': titulo,
          'mensaje': mensaje,
          'tipo': _getTipoNotificacion(nivelMora),
        });
      }
      
      return true;
    } catch (e) {
      debugPrint('Error enviando notificación de mora: $e');
      return false;
    }
  }

  String _getTipoNotificacion(String nivelMora) {
    switch (nivelMora) {
      case 'recordatorio':
        return 'info';
      case 'leve':
        return 'warning';
      case 'seria':
      case 'grave':
        return 'error';
      case 'critica':
        return 'urgent';
      default:
        return 'info';
    }
  }

  /// Obtiene el mensaje según el nivel de mora
  static String obtenerMensajeMora({
    required String nivelMora,
    required String clienteNombre,
    required int diasMora,
    required double montoPendiente,
    required double montoMora,
  }) {
    final total = montoPendiente + montoMora;
    
    switch (nivelMora) {
      case 'recordatorio':
        return 'Hola $clienteNombre, te recordamos que tienes un pago pendiente de \$${montoPendiente.toStringAsFixed(2)}. Por favor ponte al corriente para evitar cargos adicionales.';
      
      case 'leve':
        return 'Estimado $clienteNombre, tu pago tiene $diasMora día(s) de retraso. El monto adeudado es \$${total.toStringAsFixed(2)} (incluye \$${montoMora.toStringAsFixed(2)} de mora). Te invitamos a regularizar tu situación.';
      
      case 'seria':
        return '⚠️ $clienteNombre, llevas $diasMora días de retraso. Tu deuda actual es de \$${total.toStringAsFixed(2)}. Es importante que te pongas al corriente lo antes posible.';
      
      case 'grave':
        return '🔴 URGENTE: $clienteNombre, tu cuenta presenta $diasMora días de mora. Debes \$${total.toStringAsFixed(2)}. De no regularizar, tu caso podría escalarse a cobranza.';
      
      case 'critica':
        return '⛔ AVISO FINAL: $clienteNombre, tu cuenta con $diasMora días de mora será turnada a cobranza legal. Monto total: \$${total.toStringAsFixed(2)}. Contacta inmediatamente para evitar acciones legales.';
      
      default:
        return 'Tienes un pago pendiente de \$${montoPendiente.toStringAsFixed(2)}.';
    }
  }

  /// Inicia verificación automática de moras
  void iniciarVerificacionAutomatica() {
    detenerVerificacionAutomatica();
    
    // Verificar cada hora
    _timerVerificacion = Timer.periodic(
      const Duration(hours: 1),
      (_) => _ejecutarVerificacionMoras(),
    );
    
    // Verificar inmediatamente
    _ejecutarVerificacionMoras();
  }

  void detenerVerificacionAutomatica() {
    _timerVerificacion?.cancel();
    _timerVerificacion = null;
  }

  Future<void> _ejecutarVerificacionMoras() async {
    try {
      debugPrint('🔍 Ejecutando verificación automática de moras...');
      
      await obtenerConfiguracion();
      
      final hoy = DateTime.now();
      
      // 1. Marcar amortizaciones vencidas
      await AppSupabase.client
          .from('amortizaciones')
          .update({'estado': 'vencido'})
          .eq('estado', 'pendiente')
          .lt('fecha_vencimiento', hoy.toIso8601String().split('T')[0]);
      
      // V10.55: Actualizar estado de préstamos a 'mora' si tienen amortizaciones vencidas
      final prestamosConVencidos = await AppSupabase.client
          .from('amortizaciones')
          .select('prestamo_id')
          .eq('estado', 'vencido');
      
      final prestamosIds = (prestamosConVencidos as List)
          .map((a) => a['prestamo_id'])
          .toSet()
          .toList();
      
      for (var prestamoId in prestamosIds) {
        if (prestamoId == null) continue;
        await AppSupabase.client
            .from('prestamos')
            .update({'estado': 'mora'})
            .eq('id', prestamoId)
            .eq('estado', 'activo'); // Solo actualizar si está activo
      }
      debugPrint('📌 ${prestamosIds.length} préstamos actualizados a estado MORA');
      
      // 2. Obtener vencidos para procesar
      final vencidos = await AppSupabase.client
          .from('amortizaciones')
          .select('''
            id,
            prestamo_id,
            numero_cuota,
            monto_cuota,
            fecha_vencimiento,
            prestamos(
              id,
              cliente_id,
              aval_id,
              clientes(id, nombre_completo, usuario_id)
            )
          ''')
          .eq('estado', 'vencido');
      
      for (var v in (vencidos as List)) {
        final prestamo = v['prestamos'];
        if (prestamo == null) continue;
        
        final cliente = prestamo['clientes'];
        if (cliente == null) continue;
        
        final fechaVenc = DateTime.parse(v['fecha_vencimiento']);
        final diasMora = hoy.difference(fechaVenc).inDays;
        final montoCuota = (v['monto_cuota'] as num).toDouble();
        
        // Solo procesar si pasaron días de gracia
        if (diasMora <= _config.prestamosDiasGracia) continue;
        
        final diasMoraReal = diasMora - _config.prestamosDiasGracia;
        final nivelMora = determinarNivelMora(diasMoraReal);
        
        // Calcular mora
        final calculo = calcularMora(
          montoCuota: montoCuota,
          fechaVencimiento: fechaVenc,
        );
        
        // Registrar mora si aplica
        if (_config.prestamosAplicarAutomatico && calculo.montoMora > 0) {
          await registrarMora(
            prestamoId: v['prestamo_id'],
            amortizacionId: v['id'],
            diasMora: diasMoraReal,
            montoCuota: montoCuota,
            porcentajeMora: calculo.porcentajeMora,
            montoMora: calculo.montoMora,
          );
        }
        
        // Verificar si debe enviar notificación hoy
        if (_config.notificarRecordatorioDiario) {
          final yaNotificado = await _yaSeNotifico(
            cliente['id'],
            v['prestamo_id'],
            nivelMora,
          );
          
          if (!yaNotificado) {
            final mensaje = obtenerMensajeMora(
              nivelMora: nivelMora,
              clienteNombre: cliente['nombre_completo'] ?? 'Cliente',
              diasMora: diasMoraReal,
              montoPendiente: montoCuota,
              montoMora: calculo.montoMora,
            );
            
            await enviarNotificacionMora(
              clienteId: cliente['id'],
              tipoDeuda: 'prestamo',
              prestamoId: v['prestamo_id'],
              nivelMora: nivelMora,
              titulo: _getTituloMora(nivelMora),
              mensaje: mensaje,
              diasMora: diasMoraReal,
              montoPendiente: montoCuota,
              montoMora: calculo.montoMora,
              enviarAlAval: _config.notificarAlAval && prestamo['aval_id'] != null,
              avalId: prestamo['aval_id'],
            );
          }
        }
        
        // Verificar si debe bloquearse el cliente
        if (diasMoraReal >= _config.bloquearClienteDias) {
          final yaBloqueado = await clienteEstaBloqueado(cliente['id']);
          if (!yaBloqueado) {
            // TODO: Implementar bloqueo automático si se desea
            debugPrint('⚠️ Cliente ${cliente['nombre_completo']} debería bloquearse ($diasMoraReal días mora)');
          }
        }
      }
      
      debugPrint('✅ Verificación de moras completada');
    } catch (e) {
      debugPrint('❌ Error en verificación automática de moras: $e');
    }
  }

  Future<bool> _yaSeNotifico(String clienteId, String prestamoId, String nivel) async {
    try {
      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
      
      final existente = await AppSupabase.client
          .from('notificaciones_mora_cliente')
          .select('id')
          .eq('cliente_id', clienteId)
          .eq('prestamo_id', prestamoId)
          .eq('nivel_mora', nivel)
          .gte('created_at', inicioHoy.toIso8601String())
          .maybeSingle();
      
      return existente != null;
    } catch (e) {
      return false;
    }
  }

  String _getTituloMora(String nivel) {
    switch (nivel) {
      case 'recordatorio':
        return '📋 Recordatorio de Pago';
      case 'leve':
        return '⏰ Pago Atrasado';
      case 'seria':
        return '⚠️ Pago Vencido';
      case 'grave':
        return '🔴 Urgente: Pago Vencido';
      case 'critica':
        return '⛔ AVISO FINAL: Acción Legal Pendiente';
      default:
        return 'Recordatorio de Pago';
    }
  }

  /// Resumen rápido de moras
  /// V10.55: Agregado filtro por negocioId
  Future<Map<String, dynamic>> obtenerResumenMoras({String? negocioId}) async {
    try {
      final clientes = await obtenerClientesEnMora(negocioId: negocioId);
      
      double totalAdeudado = 0;
      double totalMoras = 0;
      int totalClientes = clientes.length;
      int clientesCriticos = 0;
      int clientesGraves = 0;
      
      for (var c in clientes) {
        totalAdeudado += c.montoTotalAdeudado;
        totalMoras += c.montoTotalMora;
        
        if (c.nivelMora == 'critica') clientesCriticos++;
        if (c.nivelMora == 'grave') clientesGraves++;
      }
      
      return {
        'total_clientes_mora': totalClientes,
        'total_adeudado': totalAdeudado,
        'total_moras': totalMoras,
        'clientes_criticos': clientesCriticos,
        'clientes_graves': clientesGraves,
      };
    } catch (e) {
      debugPrint('Error obteniendo resumen: $e');
      return {
        'total_clientes_mora': 0,
        'total_adeudado': 0.0,
        'total_moras': 0.0,
        'clientes_criticos': 0,
        'clientes_graves': 0,
      };
    }
  }
}
