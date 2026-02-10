// =====================================================
// MODELOS DE COMPENSACIONES Y CHAT
// =====================================================

import 'package:flutter/material.dart';

/// Tipo de compensación disponible
class CompensacionTipoModel {
  final String id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final String icono;
  final bool activo;

  CompensacionTipoModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.icono = 'payments',
    this.activo = true,
  });

  factory CompensacionTipoModel.fromMap(Map<String, dynamic> map) {
    return CompensacionTipoModel(
      id: map['id'] ?? '',
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      icono: map['icono'] ?? 'payments',
      activo: map['activo'] ?? true,
    );
  }

  IconData get iconData {
    switch (icono) {
      case 'pie_chart':
        return Icons.pie_chart;
      case 'trending_up':
        return Icons.trending_up;
      case 'account_balance':
        return Icons.account_balance;
      case 'payments':
        return Icons.payments;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'person_add':
        return Icons.person_add;
      case 'tune':
        return Icons.tune;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.payments;
    }
  }

  Color get color {
    switch (codigo) {
      case 'porcentaje_cartera':
        return const Color(0xFF8B5CF6);
      case 'porcentaje_cobranza':
        return const Color(0xFF10B981);
      case 'porcentaje_utilidades':
        return const Color(0xFFF59E0B);
      case 'honorarios_fijos':
        return const Color(0xFF3B82F6);
      case 'por_factura':
        return const Color(0xFFEC4899);
      case 'por_cliente':
        return const Color(0xFF06B6D4);
      case 'mixto':
        return const Color(0xFF6366F1);
      case 'rendimiento_inversion':
        return const Color(0xFF14B8A6);
      default:
        return const Color(0xFF8B5CF6);
    }
  }
}

/// Configuración de compensación para un colaborador
class ColaboradorCompensacionModel {
  final String id;
  final String colaboradorId;
  final String negocioId;
  final String tipoCompensacionId;
  final String? tipoNombre;
  final String? tipoCodigo;
  final double porcentaje;
  final double montoFijo;
  final double montoPorUnidad;
  final double topeMinimo;
  final double? topeMaximo;
  final String periodoPago;
  final int diaPago;
  final bool activo;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? notas;
  final DateTime createdAt;

  ColaboradorCompensacionModel({
    required this.id,
    required this.colaboradorId,
    required this.negocioId,
    required this.tipoCompensacionId,
    this.tipoNombre,
    this.tipoCodigo,
    this.porcentaje = 0,
    this.montoFijo = 0,
    this.montoPorUnidad = 0,
    this.topeMinimo = 0,
    this.topeMaximo,
    this.periodoPago = 'mensual',
    this.diaPago = 1,
    this.activo = true,
    this.fechaInicio,
    this.fechaFin,
    this.notas,
    required this.createdAt,
  });

  factory ColaboradorCompensacionModel.fromMap(Map<String, dynamic> map) {
    return ColaboradorCompensacionModel(
      id: map['id'] ?? '',
      colaboradorId: map['colaborador_id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      tipoCompensacionId: map['tipo_compensacion_id'] ?? '',
      tipoNombre: map['tipo_nombre'] ?? map['compensacion_tipos']?['nombre'],
      tipoCodigo: map['tipo_codigo'] ?? map['compensacion_tipos']?['codigo'],
      porcentaje: (map['porcentaje'] ?? 0).toDouble(),
      montoFijo: (map['monto_fijo'] ?? 0).toDouble(),
      montoPorUnidad: (map['monto_por_unidad'] ?? 0).toDouble(),
      topeMinimo: (map['tope_minimo'] ?? 0).toDouble(),
      topeMaximo: map['tope_maximo']?.toDouble(),
      periodoPago: map['periodo_pago'] ?? 'mensual',
      diaPago: map['dia_pago'] ?? 1,
      activo: map['activo'] ?? true,
      fechaInicio: map['fecha_inicio'] != null
          ? DateTime.parse(map['fecha_inicio'])
          : null,
      fechaFin:
          map['fecha_fin'] != null ? DateTime.parse(map['fecha_fin']) : null,
      notas: map['notas'],
      createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
        'colaborador_id': colaboradorId,
        'negocio_id': negocioId,
        'tipo_compensacion_id': tipoCompensacionId,
        'porcentaje': porcentaje,
        'monto_fijo': montoFijo,
        'monto_por_unidad': montoPorUnidad,
        'tope_minimo': topeMinimo,
        'tope_maximo': topeMaximo,
        'periodo_pago': periodoPago,
        'dia_pago': diaPago,
        'activo': activo,
        'fecha_inicio': fechaInicio?.toIso8601String().split('T')[0],
        'fecha_fin': fechaFin?.toIso8601String().split('T')[0],
        'notas': notas,
      };

  String get periodoLabel {
    switch (periodoPago) {
      case 'semanal':
        return 'Semanal';
      case 'quincenal':
        return 'Quincenal';
      case 'mensual':
        return 'Mensual';
      case 'trimestral':
        return 'Trimestral';
      default:
        return periodoPago;
    }
  }

  String get valorPrincipal {
    if (porcentaje > 0) return '${porcentaje.toStringAsFixed(1)}%';
    if (montoFijo > 0) return '\$${montoFijo.toStringAsFixed(0)}';
    if (montoPorUnidad > 0) return '\$${montoPorUnidad.toStringAsFixed(0)}/u';
    return '-';
  }
}

/// Pago realizado a colaborador
class ColaboradorPagoModel {
  final String id;
  final String colaboradorId;
  final String? colaboradorNombre;
  final String negocioId;
  final String? compensacionId;
  final DateTime periodoInicio;
  final DateTime periodoFin;
  final double montoBase;
  final double montoComisiones;
  final double montoBonos;
  final double montoAjustes;
  final double montoTotal;
  final Map<String, dynamic>? detalleCalculo;
  final String estado;
  final DateTime? fechaAprobacion;
  final DateTime? fechaPago;
  final String? metodoPago;
  final String? referenciaPago;
  final String? comprobanteUrl;
  final String? notas;
  final DateTime createdAt;

  ColaboradorPagoModel({
    required this.id,
    required this.colaboradorId,
    this.colaboradorNombre,
    required this.negocioId,
    this.compensacionId,
    required this.periodoInicio,
    required this.periodoFin,
    this.montoBase = 0,
    this.montoComisiones = 0,
    this.montoBonos = 0,
    this.montoAjustes = 0,
    required this.montoTotal,
    this.detalleCalculo,
    this.estado = 'pendiente',
    this.fechaAprobacion,
    this.fechaPago,
    this.metodoPago,
    this.referenciaPago,
    this.comprobanteUrl,
    this.notas,
    required this.createdAt,
  });

  factory ColaboradorPagoModel.fromMap(Map<String, dynamic> map) {
    return ColaboradorPagoModel(
      id: map['id'] ?? '',
      colaboradorId: map['colaborador_id'] ?? '',
      colaboradorNombre: map['colaborador_nombre'] ??
          map['colaboradores']?['nombre'],
      negocioId: map['negocio_id'] ?? '',
      compensacionId: map['compensacion_id'],
      periodoInicio: DateTime.parse(map['periodo_inicio']),
      periodoFin: DateTime.parse(map['periodo_fin']),
      montoBase: (map['monto_base'] ?? 0).toDouble(),
      montoComisiones: (map['monto_comisiones'] ?? 0).toDouble(),
      montoBonos: (map['monto_bonos'] ?? 0).toDouble(),
      montoAjustes: (map['monto_ajustes'] ?? 0).toDouble(),
      montoTotal: (map['monto_total'] ?? 0).toDouble(),
      detalleCalculo: map['detalle_calculo'],
      estado: map['estado'] ?? 'pendiente',
      fechaAprobacion: map['fecha_aprobacion'] != null
          ? DateTime.parse(map['fecha_aprobacion'])
          : null,
      fechaPago: map['fecha_pago'] != null
          ? DateTime.parse(map['fecha_pago'])
          : null,
      metodoPago: map['metodo_pago'],
      referenciaPago: map['referencia_pago'],
      comprobanteUrl: map['comprobante_url'],
      notas: map['notas'],
      createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Color get estadoColor {
    switch (estado) {
      case 'pendiente':
        return const Color(0xFFF59E0B);
      case 'aprobado':
        return const Color(0xFF3B82F6);
      case 'pagado':
        return const Color(0xFF10B981);
      case 'cancelado':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String get estadoLabel {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'aprobado':
        return 'Aprobado';
      case 'pagado':
        return 'Pagado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }

  IconData get estadoIcon {
    switch (estado) {
      case 'pendiente':
        return Icons.schedule;
      case 'aprobado':
        return Icons.thumb_up;
      case 'pagado':
        return Icons.check_circle;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}

/// Meta de colaborador
class ColaboradorMetaModel {
  final String id;
  final String colaboradorId;
  final String negocioId;
  final String nombre;
  final String? descripcion;
  final String tipoMeta;
  final double metaValor;
  final double valorActual;
  final double bonoMonto;
  final double bonoPorcentaje;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool cumplida;
  final DateTime? fechaCumplimiento;
  final bool bonoPagado;

  ColaboradorMetaModel({
    required this.id,
    required this.colaboradorId,
    required this.negocioId,
    required this.nombre,
    this.descripcion,
    required this.tipoMeta,
    required this.metaValor,
    this.valorActual = 0,
    this.bonoMonto = 0,
    this.bonoPorcentaje = 0,
    required this.fechaInicio,
    required this.fechaFin,
    this.cumplida = false,
    this.fechaCumplimiento,
    this.bonoPagado = false,
  });

  factory ColaboradorMetaModel.fromMap(Map<String, dynamic> map) {
    return ColaboradorMetaModel(
      id: map['id'] ?? '',
      colaboradorId: map['colaborador_id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      tipoMeta: map['tipo_meta'] ?? '',
      metaValor: (map['meta_valor'] ?? 0).toDouble(),
      valorActual: (map['valor_actual'] ?? 0).toDouble(),
      bonoMonto: (map['bono_monto'] ?? 0).toDouble(),
      bonoPorcentaje: (map['bono_porcentaje'] ?? 0).toDouble(),
      fechaInicio: DateTime.parse(map['fecha_inicio']),
      fechaFin: DateTime.parse(map['fecha_fin']),
      cumplida: map['cumplida'] ?? false,
      fechaCumplimiento: map['fecha_cumplimiento'] != null
          ? DateTime.parse(map['fecha_cumplimiento'])
          : null,
      bonoPagado: map['bono_pagado'] ?? false,
    );
  }

  double get progreso => metaValor > 0 ? (valorActual / metaValor) : 0;
  bool get vencida => DateTime.now().isAfter(fechaFin) && !cumplida;
}

// =====================================================
// MODELOS DE CHAT
// =====================================================

/// Conversación de chat
class ChatConversacionModel {
  final String id;
  final String negocioId;
  final String tipo; // privada, grupal, anuncio
  final String? nombre;
  final String? descripcion;
  final String icono;
  final String color;
  final String creadorId;
  final bool activa;
  final bool archivada;
  final DateTime? ultimoMensajeAt;
  final String? ultimoMensajePreview;
  final int numParticipantes;
  final int mensajesNoLeidos;
  final DateTime createdAt;

  ChatConversacionModel({
    required this.id,
    required this.negocioId,
    required this.tipo,
    this.nombre,
    this.descripcion,
    this.icono = 'chat',
    this.color = '#8B5CF6',
    required this.creadorId,
    this.activa = true,
    this.archivada = false,
    this.ultimoMensajeAt,
    this.ultimoMensajePreview,
    this.numParticipantes = 0,
    this.mensajesNoLeidos = 0,
    required this.createdAt,
  });

  factory ChatConversacionModel.fromMap(Map<String, dynamic> map) {
    final estado = map['estado'];
    final ultimoMensajeAt = map['ultimo_mensaje_at'] ?? map['fecha_ultimo_mensaje'];
    return ChatConversacionModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      tipo: map['tipo'] ?? map['tipo_conversacion'] ?? 'privada',
      nombre: map['nombre'],
      descripcion: map['descripcion'],
      icono: map['icono'] ?? 'chat',
      color: map['color'] ?? '#8B5CF6',
      creadorId: map['creador_id'] ?? map['creado_por_usuario_id'] ?? '',
      activa: map['activa'] ?? (estado == null ? true : estado == 'activo'),
      archivada: map['archivada'] ?? false,
      ultimoMensajeAt: ultimoMensajeAt != null
          ? DateTime.parse(ultimoMensajeAt)
          : null,
      ultimoMensajePreview: map['ultimo_mensaje_preview'] ?? map['ultimo_mensaje'],
      numParticipantes: map['num_participantes'] ?? 0,
      mensajesNoLeidos: map['mensajes_no_leidos'] ?? 0,
      createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Color get colorValue {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF8B5CF6);
    }
  }

  IconData get iconData {
    switch (icono) {
      case 'campaign':
        return Icons.campaign;
      case 'trending_up':
        return Icons.trending_up;
      case 'settings':
        return Icons.settings;
      case 'calculate':
        return Icons.calculate;
      case 'group':
        return Icons.group;
      case 'person':
        return Icons.person;
      default:
        return Icons.chat;
    }
  }
}

/// Mensaje de chat
class ChatMensajeModel {
  final String id;
  final String conversacionId;
  final String remitenteId;
  final String? remitenteNombre;
  final String? remitenteAvatar;
  final String contenido;
  final String tipoContenido;
  final String? archivoUrl;
  final String? archivoNombre;
  final String? archivoTipo;
  final int? archivoTamanio;
  final String? respuestaAId;
  final String? respuestaPreview;
  final bool editado;
  final DateTime? fechaEdicion;
  final bool eliminado;
  final bool leido;
  final DateTime createdAt;

  ChatMensajeModel({
    required this.id,
    required this.conversacionId,
    required this.remitenteId,
    this.remitenteNombre,
    this.remitenteAvatar,
    required this.contenido,
    this.tipoContenido = 'texto',
    this.archivoUrl,
    this.archivoNombre,
    this.archivoTipo,
    this.archivoTamanio,
    this.respuestaAId,
    this.respuestaPreview,
    this.editado = false,
    this.fechaEdicion,
    this.eliminado = false,
    this.leido = false,
    required this.createdAt,
  });

  factory ChatMensajeModel.fromMap(Map<String, dynamic> map) {
    final remitenteId = map['remitente_id'] ?? map['remitente_usuario_id'];
    final contenido = map['contenido'] ?? map['contenido_texto'];
    final tipoContenido = map['tipo_contenido'] ?? map['tipo_mensaje'];
    return ChatMensajeModel(
      id: map['id'] ?? '',
      conversacionId: map['conversacion_id'] ?? '',
      remitenteId: remitenteId ?? '',
      remitenteNombre: map['remitente_nombre'],
      remitenteAvatar: map['remitente_avatar'],
      contenido: contenido ?? '',
      tipoContenido: tipoContenido ?? 'texto',
      archivoUrl: map['archivo_url'] ?? map['url_adjunto'],
      archivoNombre: map['archivo_nombre'],
      archivoTipo: map['archivo_tipo'],
      archivoTamanio: map['archivo_tamanio'],
      respuestaAId: map['respuesta_a_id'],
      respuestaPreview: map['respuesta_preview'],
      editado: map['editado'] ?? false,
      fechaEdicion: map['fecha_edicion'] != null
          ? DateTime.parse(map['fecha_edicion'])
          : null,
      eliminado: map['eliminado'] ?? false,
      leido: map['leido'] ?? false,
      createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get esArchivo => tipoContenido != 'texto';
  bool get esImagen => tipoContenido == 'imagen';
}

/// Participante de conversación
class ChatParticipanteModel {
  final String id;
  final String conversacionId;
  final String usuarioId;
  final String? colaboradorId;
  final String? nombre;
  final String? avatar;
  final String? tipoColaborador;
  final bool puedeEscribir;
  final bool esAdmin;
  final DateTime? ultimoLeidoAt;
  final int mensajesNoLeidos;
  final bool notificacionesActivas;
  final bool activo;

  ChatParticipanteModel({
    required this.id,
    required this.conversacionId,
    required this.usuarioId,
    this.colaboradorId,
    this.nombre,
    this.avatar,
    this.tipoColaborador,
    this.puedeEscribir = true,
    this.esAdmin = false,
    this.ultimoLeidoAt,
    this.mensajesNoLeidos = 0,
    this.notificacionesActivas = true,
    this.activo = true,
  });

  factory ChatParticipanteModel.fromMap(Map<String, dynamic> map) {
    final silenciado = map['silenciado'];
    return ChatParticipanteModel(
      id: map['id'] ?? '',
      conversacionId: map['conversacion_id'] ?? '',
      usuarioId: map['usuario_id'] ?? '',
      colaboradorId: map['colaborador_id'],
      nombre: map['nombre'] ?? map['colaboradores']?['nombre'],
      avatar: map['avatar'],
      tipoColaborador: map['tipo_colaborador'] ?? map['rol_chat'] ?? map['rol_en_chat'],
      puedeEscribir: map['puede_escribir'] ?? true,
      esAdmin: map['es_admin'] ?? false,
      ultimoLeidoAt: map['ultimo_leido_at'] != null
          ? DateTime.parse(map['ultimo_leido_at'])
          : null,
      mensajesNoLeidos: map['mensajes_no_leidos'] ?? 0,
      notificacionesActivas: map['notificaciones_activas'] ?? (silenciado == null ? true : !silenciado),
      activo: map['activo'] ?? true,
    );
  }
}
