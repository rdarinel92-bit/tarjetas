// ═══════════════════════════════════════════════════════════════════════════════
// MODELOS DE COLABORADORES, SOCIOS E INVERSIONISTAS
// Robert Darin Platform v10.15
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TIPO DE COLABORADOR
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradorTipoModel {
  final String id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final int nivelAcceso;
  final bool puedeVerFinanzas;
  final bool puedeVerClientes;
  final bool puedeVerPrestamos;
  final bool puedeOperar;
  final bool puedeAprobar;
  final bool puedeEmitirFacturas;
  final bool puedeVerReportes;
  final bool activo;

  ColaboradorTipoModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.nivelAcceso = 1,
    this.puedeVerFinanzas = false,
    this.puedeVerClientes = false,
    this.puedeVerPrestamos = false,
    this.puedeOperar = false,
    this.puedeAprobar = false,
    this.puedeEmitirFacturas = false,
    this.puedeVerReportes = false,
    this.activo = true,
  });

  factory ColaboradorTipoModel.fromMap(Map<String, dynamic> map) {
    return ColaboradorTipoModel(
      id: map['id'] ?? '',
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      nivelAcceso: map['nivel_acceso'] ?? 1,
      puedeVerFinanzas: map['puede_ver_finanzas'] ?? false,
      puedeVerClientes: map['puede_ver_clientes'] ?? false,
      puedeVerPrestamos: map['puede_ver_prestamos'] ?? false,
      puedeOperar: map['puede_operar'] ?? false,
      puedeAprobar: map['puede_aprobar'] ?? false,
      puedeEmitirFacturas: map['puede_emitir_facturas'] ?? false,
      puedeVerReportes: map['puede_ver_reportes'] ?? false,
      activo: map['activo'] ?? true,
    );
  }

  // Colores e iconos por tipo
  IconData get icono {
    switch (codigo) {
      case 'co_superadmin':
        return Icons.admin_panel_settings;
      case 'socio_operativo':
        return Icons.handshake;
      case 'socio_inversionista':
        return Icons.trending_up;
      case 'contador':
        return Icons.calculate;
      case 'asesor':
        return Icons.support_agent;
      case 'facturador':
        return Icons.receipt_long;
      default:
        return Icons.person;
    }
  }

  Color get color {
    switch (codigo) {
      case 'co_superadmin':
        return const Color(0xFFEF4444); // Rojo
      case 'socio_operativo':
        return const Color(0xFF8B5CF6); // Morado
      case 'socio_inversionista':
        return const Color(0xFF10B981); // Verde
      case 'contador':
        return const Color(0xFF3B82F6); // Azul
      case 'asesor':
        return const Color(0xFFFBBF24); // Amarillo
      case 'facturador':
        return const Color(0xFF06B6D4); // Cyan
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLABORADOR
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradorModel {
  final String id;
  final String negocioId;
  final String nombre;
  final String email;
  final String? telefono;
  final String? tipoId;
  final String? tipoCodigo;
  final String? authUid;
  final String? usuarioId;
  final bool tieneCuenta;
  final Map<String, dynamic> permisosCustom;
  
  // Inversión
  final bool esInversionista;
  final double montoInvertido;
  final double porcentajeParticipacion;
  final DateTime? fechaInversion;
  final double? rendimientoPactado;
  
  // Estado
  final String estado;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? notas;
  
  // Metadata
  final DateTime createdAt;

  // De la vista (datos adicionales)
  final String? tipoNombre;
  final int? nivelAcceso;
  final bool? tipoPuedeFacturar;

  ColaboradorModel({
    required this.id,
    required this.negocioId,
    required this.nombre,
    required this.email,
    this.telefono,
    this.tipoId,
    this.tipoCodigo,
    this.authUid,
    this.usuarioId,
    this.tieneCuenta = false,
    this.permisosCustom = const {},
    this.esInversionista = false,
    this.montoInvertido = 0,
    this.porcentajeParticipacion = 0,
    this.fechaInversion,
    this.rendimientoPactado,
    this.estado = 'activo',
    this.fechaInicio,
    this.fechaFin,
    this.notas,
    required this.createdAt,
    this.tipoNombre,
    this.nivelAcceso,
    this.tipoPuedeFacturar,
  });

  factory ColaboradorModel.fromMap(Map<String, dynamic> map) {
    return ColaboradorModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      nombre: map['nombre'] ?? '',
      email: map['email'] ?? '',
      telefono: map['telefono'],
      tipoId: map['tipo_id'],
      tipoCodigo: map['tipo_codigo'],
      authUid: map['auth_uid'],
      usuarioId: map['usuario_id'],
      tieneCuenta: map['tiene_cuenta'] ?? false,
      permisosCustom: map['permisos_custom'] is Map 
          ? Map<String, dynamic>.from(map['permisos_custom'])
          : {},
      esInversionista: map['es_inversionista'] ?? false,
      montoInvertido: (map['monto_invertido'] ?? 0).toDouble(),
      porcentajeParticipacion: (map['porcentaje_participacion'] ?? 0).toDouble(),
      fechaInversion: map['fecha_inversion'] != null 
          ? DateTime.parse(map['fecha_inversion']) 
          : null,
      rendimientoPactado: map['rendimiento_pactado']?.toDouble(),
      estado: map['estado'] ?? 'activo',
      fechaInicio: map['fecha_inicio'] != null 
          ? DateTime.parse(map['fecha_inicio']) 
          : null,
      fechaFin: map['fecha_fin'] != null 
          ? DateTime.parse(map['fecha_fin']) 
          : null,
      notas: map['notas'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      tipoNombre: map['tipo_nombre'],
      nivelAcceso: map['nivel_acceso'],
      tipoPuedeFacturar: map['puede_facturar_efectivo'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'nombre': nombre,
    'email': email,
    'telefono': telefono,
    'tipo_id': tipoId,
    'tipo_codigo': tipoCodigo,
    'permisos_custom': permisosCustom,
    'es_inversionista': esInversionista,
    'monto_invertido': montoInvertido,
    'porcentaje_participacion': porcentajeParticipacion,
    'fecha_inversion': fechaInversion?.toIso8601String().split('T')[0],
    'rendimiento_pactado': rendimientoPactado,
    'estado': estado,
    'notas': notas,
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    ...toMapForInsert(),
  };

  // Helpers
  String get estadoTexto {
    switch (estado) {
      case 'activo': return 'Activo';
      case 'suspendido': return 'Suspendido';
      case 'invitado': return 'Invitado';
      default: return estado;
    }
  }

  Color get estadoColor {
    switch (estado) {
      case 'activo': return const Color(0xFF10B981);
      case 'suspendido': return const Color(0xFFEF4444);
      case 'invitado': return const Color(0xFFFBBF24);
      default: return Colors.grey;
    }
  }

  String get iniciales {
    final parts = nombre.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
  }

  // Icono basado en tipo de colaborador
  IconData get iconData {
    switch (tipoCodigo) {
      case 'co_superadmin':
        return Icons.admin_panel_settings;
      case 'socio_operativo':
        return Icons.handshake;
      case 'socio_inversionista':
      case 'inversionista':
        return Icons.trending_up;
      case 'contador':
        return Icons.calculate;
      case 'asesor':
        return Icons.support_agent;
      case 'facturador':
        return Icons.receipt_long;
      default:
        return Icons.person;
    }
  }

  // Color basado en tipo de colaborador
  Color get colorValue {
    switch (tipoCodigo) {
      case 'co_superadmin':
        return const Color(0xFFEF4444); // Rojo
      case 'socio_operativo':
        return const Color(0xFF8B5CF6); // Morado
      case 'socio_inversionista':
      case 'inversionista':
        return const Color(0xFF10B981); // Verde
      case 'contador':
        return const Color(0xFF3B82F6); // Azul
      case 'asesor':
        return const Color(0xFFFBBF24); // Amarillo
      case 'facturador':
        return const Color(0xFF06B6D4); // Cyan
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Verificar permiso específico
  bool tienePermiso(String modulo) {
    // Verificar permiso custom primero
    if (permisosCustom.containsKey(modulo)) {
      return permisosCustom[modulo] == true;
    }
    // Si no hay custom, depende del tipo
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INVITACIÓN
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradorInvitacionModel {
  final String id;
  final String negocioId;
  final String? colaboradorId;
  final String email;
  final String? nombre;
  final String? tipoCodigo;
  final String token;
  final String? mensajePersonal;
  final String estado;
  final DateTime fechaEnvio;
  final DateTime fechaExpiracion;
  final DateTime? fechaRespuesta;
  final int vecesEnviada;

  ColaboradorInvitacionModel({
    required this.id,
    required this.negocioId,
    this.colaboradorId,
    required this.email,
    this.nombre,
    this.tipoCodigo,
    required this.token,
    this.mensajePersonal,
    this.estado = 'pendiente',
    required this.fechaEnvio,
    required this.fechaExpiracion,
    this.fechaRespuesta,
    this.vecesEnviada = 1,
  });

  factory ColaboradorInvitacionModel.fromMap(Map<String, dynamic> map) {
    return ColaboradorInvitacionModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      colaboradorId: map['colaborador_id'],
      email: map['email'] ?? '',
      nombre: map['nombre'],
      tipoCodigo: map['tipo_codigo'],
      token: map['token'] ?? '',
      mensajePersonal: map['mensaje_personal'],
      estado: map['estado'] ?? 'pendiente',
      fechaEnvio: DateTime.parse(map['fecha_envio'] ?? DateTime.now().toIso8601String()),
      fechaExpiracion: DateTime.parse(map['fecha_expiracion'] ?? DateTime.now().toIso8601String()),
      fechaRespuesta: map['fecha_respuesta'] != null 
          ? DateTime.parse(map['fecha_respuesta']) 
          : null,
      vecesEnviada: map['veces_enviada'] ?? 1,
    );
  }

  bool get estaExpirada => DateTime.now().isAfter(fechaExpiracion);
  bool get estaPendiente => estado == 'pendiente' && !estaExpirada;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INVERSIÓN
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradorInversionModel {
  final String id;
  final String negocioId;
  final String colaboradorId;
  final String tipo; // aportacion, retiro, rendimiento, ajuste
  final double monto;
  final String? concepto;
  final DateTime fecha;
  final String? comprobanteUrl;
  final String? referenciaBancaria;
  final DateTime createdAt;

  ColaboradorInversionModel({
    required this.id,
    required this.negocioId,
    required this.colaboradorId,
    required this.tipo,
    required this.monto,
    this.concepto,
    required this.fecha,
    this.comprobanteUrl,
    this.referenciaBancaria,
    required this.createdAt,
  });

  factory ColaboradorInversionModel.fromMap(Map<String, dynamic> map) {
    return ColaboradorInversionModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      colaboradorId: map['colaborador_id'] ?? '',
      tipo: map['tipo'] ?? '',
      monto: (map['monto'] ?? 0).toDouble(),
      concepto: map['concepto'],
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      comprobanteUrl: map['comprobante_url'],
      referenciaBancaria: map['referencia_bancaria'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'colaborador_id': colaboradorId,
    'tipo': tipo,
    'monto': monto,
    'concepto': concepto,
    'fecha': fecha.toIso8601String().split('T')[0],
    'comprobante_url': comprobanteUrl,
    'referencia_bancaria': referenciaBancaria,
  };

  String get tipoTexto {
    switch (tipo) {
      case 'aportacion': return 'Aportación';
      case 'retiro': return 'Retiro';
      case 'rendimiento': return 'Rendimiento';
      case 'ajuste': return 'Ajuste';
      default: return tipo;
    }
  }

  Color get tipoColor {
    switch (tipo) {
      case 'aportacion': return const Color(0xFF10B981);
      case 'retiro': return const Color(0xFFEF4444);
      case 'rendimiento': return const Color(0xFF3B82F6);
      case 'ajuste': return const Color(0xFFFBBF24);
      default: return Colors.grey;
    }
  }

  IconData get tipoIcono {
    switch (tipo) {
      case 'aportacion': return Icons.add_circle;
      case 'retiro': return Icons.remove_circle;
      case 'rendimiento': return Icons.trending_up;
      case 'ajuste': return Icons.tune;
      default: return Icons.attach_money;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERMISOS DE FACTURACIÓN
// ═══════════════════════════════════════════════════════════════════════════════

class FacturacionPermisoModel {
  final String id;
  final String negocioId;
  final String? usuarioId;
  final String? colaboradorId;
  final bool puedeEmitir;
  final bool puedeCancelar;
  final bool puedeVerTodas;
  final bool puedeConfigurar;
  final bool puedeAgregarClientes;
  final double? limiteMontoFactura;
  final int? limiteFacturasDiarias;
  final bool requiereAprobacion;
  final bool activo;

  FacturacionPermisoModel({
    required this.id,
    required this.negocioId,
    this.usuarioId,
    this.colaboradorId,
    this.puedeEmitir = false,
    this.puedeCancelar = false,
    this.puedeVerTodas = false,
    this.puedeConfigurar = false,
    this.puedeAgregarClientes = true,
    this.limiteMontoFactura,
    this.limiteFacturasDiarias,
    this.requiereAprobacion = false,
    this.activo = true,
  });

  factory FacturacionPermisoModel.fromMap(Map<String, dynamic> map) {
    return FacturacionPermisoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      usuarioId: map['usuario_id'],
      colaboradorId: map['colaborador_id'],
      puedeEmitir: map['puede_emitir'] ?? false,
      puedeCancelar: map['puede_cancelar'] ?? false,
      puedeVerTodas: map['puede_ver_todas'] ?? false,
      puedeConfigurar: map['puede_configurar_datos_fiscales'] ?? false,
      puedeAgregarClientes: map['puede_agregar_clientes'] ?? true,
      limiteMontoFactura: map['limite_monto_factura']?.toDouble(),
      limiteFacturasDiarias: map['limite_facturas_diarias'],
      requiereAprobacion: map['requiere_aprobacion'] ?? false,
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'usuario_id': usuarioId,
    'colaborador_id': colaboradorId,
    'puede_emitir': puedeEmitir,
    'puede_cancelar': puedeCancelar,
    'puede_ver_todas': puedeVerTodas,
    'puede_configurar_datos_fiscales': puedeConfigurar,
    'puede_agregar_clientes': puedeAgregarClientes,
    'limite_monto_factura': limiteMontoFactura,
    'limite_facturas_diarias': limiteFacturasDiarias,
    'requiere_aprobacion': requiereAprobacion,
    'activo': activo,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERMISO POR MÓDULO
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradorPermisoModuloModel {
  final String id;
  final String colaboradorId;
  final String modulo;
  final bool puedeVer;
  final bool puedeCrear;
  final bool puedeEditar;
  final bool puedeEliminar;
  final bool puedeExportar;
  final bool soloPropios;

  ColaboradorPermisoModuloModel({
    required this.id,
    required this.colaboradorId,
    required this.modulo,
    this.puedeVer = true,
    this.puedeCrear = false,
    this.puedeEditar = false,
    this.puedeEliminar = false,
    this.puedeExportar = false,
    this.soloPropios = true,
  });

  factory ColaboradorPermisoModuloModel.fromMap(Map<String, dynamic> map) {
    return ColaboradorPermisoModuloModel(
      id: map['id'] ?? '',
      colaboradorId: map['colaborador_id'] ?? '',
      modulo: map['modulo'] ?? '',
      puedeVer: map['puede_ver'] ?? true,
      puedeCrear: map['puede_crear'] ?? false,
      puedeEditar: map['puede_editar'] ?? false,
      puedeEliminar: map['puede_eliminar'] ?? false,
      puedeExportar: map['puede_exportar'] ?? false,
      soloPropios: map['solo_propios'] ?? true,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'colaborador_id': colaboradorId,
    'modulo': modulo,
    'puede_ver': puedeVer,
    'puede_crear': puedeCrear,
    'puede_editar': puedeEditar,
    'puede_eliminar': puedeEliminar,
    'puede_exportar': puedeExportar,
    'solo_propios': soloPropios,
  };
}
