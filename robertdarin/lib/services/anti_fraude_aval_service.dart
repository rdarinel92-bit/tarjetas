import 'package:flutter/material.dart';
import '../core/supabase_client.dart';

/// Sistema Anti-Fraude para Avales
/// Verifica identidad, previene estafas y asegura cumplimiento
class AntiFraudeAvalService {
  
  /// Nivel de riesgo del aval
  static const int RIESGO_BAJO = 1;
  static const int RIESGO_MEDIO = 2;
  static const int RIESGO_ALTO = 3;
  static const int RIESGO_CRITICO = 4;

  /// Realiza validación completa del aval antes de aprobar
  static Future<ValidacionAval> validarAval({
    required String avalId,
    required String curp,
    required String telefono,
    String? ineFrente,
    String? ineReverso,
    String? selfie,
    double? latitud,
    double? longitud,
  }) async {
    final List<AlertaFraude> alertas = [];
    int puntajeRiesgo = 0;

    // 1. Validar CURP (formato y estructura)
    final validacionCurp = _validarCURP(curp);
    if (!validacionCurp.valido) {
      alertas.add(AlertaFraude(
        tipo: 'curp_invalido',
        mensaje: validacionCurp.mensaje,
        severidad: RIESGO_ALTO,
      ));
      puntajeRiesgo += 30;
    }

    // 2. Verificar si el CURP ya fue usado como aval en otro préstamo activo
    final avalExistente = await _verificarAvalDuplicado(curp, avalId);
    if (avalExistente) {
      alertas.add(AlertaFraude(
        tipo: 'aval_duplicado',
        mensaje: 'Este CURP ya está registrado como aval en otro préstamo activo',
        severidad: RIESGO_CRITICO,
      ));
      puntajeRiesgo += 50;
    }

    // 3. Verificar historial de incumplimientos
    final historialMalo = await _verificarHistorialNegativo(curp);
    if (historialMalo.tieneHistorial) {
      alertas.add(AlertaFraude(
        tipo: 'historial_negativo',
        mensaje: 'El aval tiene ${historialMalo.incumplimientos} incumplimientos previos',
        severidad: RIESGO_ALTO,
        detalles: historialMalo.detalles,
      ));
      puntajeRiesgo += historialMalo.incumplimientos * 15;
    }

    // 4. Validar teléfono (no sea el mismo del deudor)
    final telDuplicado = await _verificarTelefonoDuplicado(telefono, avalId);
    if (telDuplicado) {
      alertas.add(AlertaFraude(
        tipo: 'telefono_duplicado',
        mensaje: 'El teléfono coincide con otro usuario del sistema',
        severidad: RIESGO_MEDIO,
      ));
      puntajeRiesgo += 15;
    }

    // 5. Verificar documentos (si se proporcionan)
    if (ineFrente == null || ineReverso == null) {
      alertas.add(AlertaFraude(
        tipo: 'documentos_faltantes',
        mensaje: 'No se han cargado los documentos de identificación',
        severidad: RIESGO_MEDIO,
      ));
      puntajeRiesgo += 20;
    }

    // 6. Verificar selfie de verificación
    if (selfie == null) {
      alertas.add(AlertaFraude(
        tipo: 'selfie_faltante',
        mensaje: 'No se ha tomado la selfie de verificación',
        severidad: RIESGO_MEDIO,
      ));
      puntajeRiesgo += 15;
    }

    // 7. Verificar ubicación (si está muy lejos del domicilio declarado)
    if (latitud != null && longitud != null) {
      final ubicacionSospechosa = await _verificarUbicacion(avalId, latitud, longitud);
      if (ubicacionSospechosa.esSospechosa) {
        alertas.add(AlertaFraude(
          tipo: 'ubicacion_sospechosa',
          mensaje: ubicacionSospechosa.mensaje,
          severidad: RIESGO_MEDIO,
        ));
        puntajeRiesgo += 10;
      }
    }

    // 8. Verificar relación con el deudor
    final relacionValida = await _verificarRelacion(avalId);
    if (!relacionValida) {
      alertas.add(AlertaFraude(
        tipo: 'relacion_no_verificada',
        mensaje: 'No se ha podido verificar la relación con el deudor',
        severidad: RIESGO_BAJO,
      ));
      puntajeRiesgo += 5;
    }

    // Determinar nivel de riesgo final
    int nivelRiesgo = RIESGO_BAJO;
    if (puntajeRiesgo >= 70) nivelRiesgo = RIESGO_CRITICO;
    else if (puntajeRiesgo >= 40) nivelRiesgo = RIESGO_ALTO;
    else if (puntajeRiesgo >= 20) nivelRiesgo = RIESGO_MEDIO;

    // Guardar resultado de validación
    await _guardarValidacion(avalId, alertas, puntajeRiesgo, nivelRiesgo);

    return ValidacionAval(
      avalId: avalId,
      aprobado: nivelRiesgo <= RIESGO_MEDIO,
      nivelRiesgo: nivelRiesgo,
      puntajeRiesgo: puntajeRiesgo,
      alertas: alertas,
      requiereRevisionManual: nivelRiesgo == RIESGO_ALTO,
      bloqueado: nivelRiesgo == RIESGO_CRITICO,
    );
  }

  /// Verifica la identidad del aval con reconocimiento facial básico
  static Future<VerificacionIdentidad> verificarIdentidad({
    required String avalId,
    required String ineFotoUrl,
    required String selfieUrl,
  }) async {
    // En producción, aquí se integraría un servicio como:
    // - Facephi
    // - Jumio
    // - Onfido
    // - AWS Rekognition
    
    // Por ahora, registramos la verificación manual
    try {
      await AppSupabase.client.from('verificaciones_identidad').insert({
        'aval_id': avalId,
        'ine_url': ineFotoUrl,
        'selfie_url': selfieUrl,
        'estado': 'pendiente_revision',
        'metodo': 'manual',
        'created_at': DateTime.now().toIso8601String(),
      });

      return VerificacionIdentidad(
        verificado: false,
        estado: 'pendiente_revision',
        mensaje: 'Verificación enviada para revisión manual',
        requiereAccion: true,
      );
    } catch (e) {
      return VerificacionIdentidad(
        verificado: false,
        estado: 'error',
        mensaje: 'Error al procesar verificación: $e',
        requiereAccion: true,
      );
    }
  }

  /// Lista de verificación que debe completar el aval
  static List<RequisitoAval> obtenerRequisitos() {
    return [
      RequisitoAval(
        id: 'ine_frente',
        nombre: 'INE/IFE (Frente)',
        descripcion: 'Fotografía clara del frente de tu identificación',
        obligatorio: true,
        icono: Icons.credit_card,
      ),
      RequisitoAval(
        id: 'ine_reverso',
        nombre: 'INE/IFE (Reverso)',
        descripcion: 'Fotografía clara del reverso de tu identificación',
        obligatorio: true,
        icono: Icons.credit_card_outlined,
      ),
      RequisitoAval(
        id: 'selfie',
        nombre: 'Selfie de Verificación',
        descripcion: 'Fotografía de tu rostro sosteniendo tu INE',
        obligatorio: true,
        icono: Icons.face,
      ),
      RequisitoAval(
        id: 'comprobante_domicilio',
        nombre: 'Comprobante de Domicilio',
        descripcion: 'Recibo de luz, agua o teléfono (máximo 3 meses)',
        obligatorio: true,
        icono: Icons.home,
      ),
      RequisitoAval(
        id: 'firma_digital',
        nombre: 'Firma Digital',
        descripcion: 'Tu firma para los documentos legales',
        obligatorio: true,
        icono: Icons.draw,
      ),
      RequisitoAval(
        id: 'contrato_firmado',
        nombre: 'Contrato Firmado',
        descripcion: 'Aceptación del contrato de garantía',
        obligatorio: true,
        icono: Icons.description,
      ),
      RequisitoAval(
        id: 'ubicacion',
        nombre: 'Verificación de Ubicación',
        descripcion: 'Confirmar tu ubicación actual',
        obligatorio: false,
        icono: Icons.location_on,
      ),
      RequisitoAval(
        id: 'referencias',
        nombre: 'Referencias Personales',
        descripcion: 'Datos de 2 referencias personales',
        obligatorio: false,
        icono: Icons.people,
      ),
    ];
  }

  /// Verifica el estado de cumplimiento de requisitos
  static Future<EstadoRequisitos> verificarRequisitos(String avalId) async {
    try {
      final aval = await AppSupabase.client
          .from('avales')
          .select()
          .eq('id', avalId)
          .single();

      final documentos = await AppSupabase.client
          .from('documentos_aval')
          .select()
          .eq('aval_id', avalId);

      final requisitos = obtenerRequisitos();
      final completados = <String>[];
      final pendientes = <String>[];

      for (var req in requisitos) {
        bool cumplido = false;
        
        switch (req.id) {
          case 'ine_frente':
            cumplido = aval['ine_frente_url'] != null || 
                documentos.any((d) => d['tipo'] == 'ine_frente');
            break;
          case 'ine_reverso':
            cumplido = aval['ine_reverso_url'] != null ||
                documentos.any((d) => d['tipo'] == 'ine_reverso');
            break;
          case 'selfie':
            cumplido = aval['selfie_url'] != null ||
                documentos.any((d) => d['tipo'] == 'selfie');
            break;
          case 'comprobante_domicilio':
            cumplido = documentos.any((d) => d['tipo'] == 'comprobante_domicilio');
            break;
          case 'firma_digital':
            cumplido = aval['firma_digital_url'] != null;
            break;
          case 'contrato_firmado':
            cumplido = documentos.any((d) => d['tipo'] == 'contrato_garantia' && d['firmado'] == true);
            break;
          case 'ubicacion':
            cumplido = aval['ubicacion_consentida'] == true;
            break;
          case 'referencias':
            final refs = await AppSupabase.client
                .from('referencias_aval')
                .select()
                .eq('aval_id', avalId);
            cumplido = refs.length >= 2;
            break;
        }

        if (cumplido) {
          completados.add(req.id);
        } else if (req.obligatorio) {
          pendientes.add(req.id);
        }
      }

      final porcentaje = (completados.length / requisitos.length * 100).round();
      final obligatoriosCompletos = pendientes.isEmpty;

      return EstadoRequisitos(
        completados: completados,
        pendientes: pendientes,
        porcentajeCompletado: porcentaje,
        puedeSerAprobado: obligatoriosCompletos,
        mensaje: obligatoriosCompletos 
            ? '✅ Todos los requisitos obligatorios están completos'
            : '⚠️ Faltan ${pendientes.length} requisitos obligatorios',
      );
    } catch (e) {
      return EstadoRequisitos(
        completados: [],
        pendientes: [],
        porcentajeCompletado: 0,
        puedeSerAprobado: false,
        mensaje: 'Error verificando requisitos: $e',
      );
    }
  }

  /// Bloquea un aval por actividad sospechosa
  static Future<void> bloquearAval(String avalId, String motivo) async {
    await AppSupabase.client.from('avales').update({
      'estado': 'bloqueado',
      'motivo_bloqueo': motivo,
      'fecha_bloqueo': DateTime.now().toIso8601String(),
    }).eq('id', avalId);

    // Registrar en log de fraude
    await AppSupabase.client.from('log_fraude').insert({
      'tipo_entidad': 'aval',
      'entidad_id': avalId,
      'accion': 'bloqueo',
      'motivo': motivo,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // === MÉTODOS PRIVADOS DE VALIDACIÓN ===

  static _ValidacionCURP _validarCURP(String curp) {
    if (curp.length != 18) {
      return _ValidacionCURP(false, 'CURP debe tener 18 caracteres');
    }
    
    final regex = RegExp(r'^[A-Z]{4}[0-9]{6}[HM][A-Z]{5}[0-9A-Z][0-9]$');
    if (!regex.hasMatch(curp.toUpperCase())) {
      return _ValidacionCURP(false, 'Formato de CURP inválido');
    }

    // Validar fecha de nacimiento
    final anio = int.tryParse(curp.substring(4, 6));
    final mes = int.tryParse(curp.substring(6, 8));
    final dia = int.tryParse(curp.substring(8, 10));
    
    if (anio == null || mes == null || dia == null) {
      return _ValidacionCURP(false, 'Fecha de nacimiento inválida en CURP');
    }

    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) {
      return _ValidacionCURP(false, 'Fecha de nacimiento inválida en CURP');
    }

    return _ValidacionCURP(true, 'CURP válido');
  }

  static Future<bool> _verificarAvalDuplicado(String curp, String avalIdActual) async {
    final res = await AppSupabase.client
        .from('avales')
        .select('id, prestamos_avales(prestamo_id, prestamos(estado))')
        .eq('curp', curp)
        .neq('id', avalIdActual);

    for (var aval in res) {
      final prestamosAval = aval['prestamos_avales'] as List?;
      if (prestamosAval != null) {
        for (var pa in prestamosAval) {
          final prestamo = pa['prestamos'];
          if (prestamo != null && prestamo['estado'] == 'activo') {
            return true; // Ya es aval activo en otro préstamo
          }
        }
      }
    }
    return false;
  }

  static Future<_HistorialNegativo> _verificarHistorialNegativo(String curp) async {
    final res = await AppSupabase.client
        .from('avales')
        .select('id, notificaciones_mora_aval(nivel_mora, dias_mora)')
        .eq('curp', curp);

    int totalIncumplimientos = 0;
    List<String> detalles = [];

    for (var aval in res) {
      final moras = aval['notificaciones_mora_aval'] as List?;
      if (moras != null) {
        for (var mora in moras) {
          if (mora['nivel_mora'] == 'grave' || mora['nivel_mora'] == 'critica') {
            totalIncumplimientos++;
            detalles.add('Mora ${mora['nivel_mora']}: ${mora['dias_mora']} días');
          }
        }
      }
    }

    return _HistorialNegativo(
      tieneHistorial: totalIncumplimientos > 0,
      incumplimientos: totalIncumplimientos,
      detalles: detalles,
    );
  }

  static Future<bool> _verificarTelefonoDuplicado(String telefono, String avalId) async {
    // Verificar en clientes y otros avales
    final clientes = await AppSupabase.client
        .from('clientes')
        .select('id')
        .eq('telefono', telefono);

    if (clientes.isNotEmpty) return true;

    final avales = await AppSupabase.client
        .from('avales')
        .select('id')
        .eq('telefono', telefono)
        .neq('id', avalId);

    return avales.isNotEmpty;
  }

  static Future<_UbicacionSospechosa> _verificarUbicacion(
    String avalId, double lat, double lng
  ) async {
    try {
      final aval = await AppSupabase.client
          .from('avales')
          .select('direccion, ultima_latitud, ultima_longitud')
          .eq('id', avalId)
          .maybeSingle();

      if (aval == null || aval['ultima_latitud'] == null) {
        return _UbicacionSospechosa(false, '');
      }

      // Calcular distancia aproximada
      final latDiff = (lat - (aval['ultima_latitud'] as num).toDouble()).abs();
      final lngDiff = (lng - (aval['ultima_longitud'] as num).toDouble()).abs();
      
      // Si está a más de ~50km de diferencia (aproximado)
      if (latDiff > 0.5 || lngDiff > 0.5) {
        return _UbicacionSospechosa(
          true, 
          'La ubicación actual está muy lejos del domicilio registrado'
        );
      }

      return _UbicacionSospechosa(false, '');
    } catch (e) {
      return _UbicacionSospechosa(false, '');
    }
  }

  static Future<bool> _verificarRelacion(String avalId) async {
    final aval = await AppSupabase.client
        .from('avales')
        .select('relacion')
        .eq('id', avalId)
        .maybeSingle();

    return aval != null && aval['relacion'] != null && aval['relacion'].isNotEmpty;
  }

  static Future<void> _guardarValidacion(
    String avalId,
    List<AlertaFraude> alertas,
    int puntaje,
    int nivel,
  ) async {
    await AppSupabase.client.from('validaciones_aval').insert({
      'aval_id': avalId,
      'puntaje_riesgo': puntaje,
      'nivel_riesgo': nivel,
      'alertas': alertas.map((a) => a.toJson()).toList(),
      'fecha': DateTime.now().toIso8601String(),
    });
  }
}

// === CLASES DE DATOS ===

class ValidacionAval {
  final String avalId;
  final bool aprobado;
  final int nivelRiesgo;
  final int puntajeRiesgo;
  final List<AlertaFraude> alertas;
  final bool requiereRevisionManual;
  final bool bloqueado;

  ValidacionAval({
    required this.avalId,
    required this.aprobado,
    required this.nivelRiesgo,
    required this.puntajeRiesgo,
    required this.alertas,
    required this.requiereRevisionManual,
    required this.bloqueado,
  });

  String get nivelRiesgoTexto {
    switch (nivelRiesgo) {
      case 1: return 'Bajo';
      case 2: return 'Medio';
      case 3: return 'Alto';
      case 4: return 'Crítico';
      default: return 'Desconocido';
    }
  }

  Color get colorRiesgo {
    switch (nivelRiesgo) {
      case 1: return Colors.green;
      case 2: return Colors.orange;
      case 3: return Colors.deepOrange;
      case 4: return Colors.red;
      default: return Colors.grey;
    }
  }
}

class AlertaFraude {
  final String tipo;
  final String mensaje;
  final int severidad;
  final List<String>? detalles;

  AlertaFraude({
    required this.tipo,
    required this.mensaje,
    required this.severidad,
    this.detalles,
  });

  Map<String, dynamic> toJson() => {
    'tipo': tipo,
    'mensaje': mensaje,
    'severidad': severidad,
    'detalles': detalles,
  };
}

class VerificacionIdentidad {
  final bool verificado;
  final String estado;
  final String mensaje;
  final bool requiereAccion;
  final double? confianza;

  VerificacionIdentidad({
    required this.verificado,
    required this.estado,
    required this.mensaje,
    required this.requiereAccion,
    this.confianza,
  });
}

class RequisitoAval {
  final String id;
  final String nombre;
  final String descripcion;
  final bool obligatorio;
  final IconData icono;

  RequisitoAval({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.obligatorio,
    required this.icono,
  });
}

class EstadoRequisitos {
  final List<String> completados;
  final List<String> pendientes;
  final int porcentajeCompletado;
  final bool puedeSerAprobado;
  final String mensaje;

  EstadoRequisitos({
    required this.completados,
    required this.pendientes,
    required this.porcentajeCompletado,
    required this.puedeSerAprobado,
    required this.mensaje,
  });
}

class _ValidacionCURP {
  final bool valido;
  final String mensaje;
  _ValidacionCURP(this.valido, this.mensaje);
}

class _HistorialNegativo {
  final bool tieneHistorial;
  final int incumplimientos;
  final List<String> detalles;
  _HistorialNegativo({
    required this.tieneHistorial,
    required this.incumplimientos,
    required this.detalles,
  });
}

class _UbicacionSospechosa {
  final bool esSospechosa;
  final String mensaje;
  _UbicacionSospechosa(this.esSospechosa, this.mensaje);
}
