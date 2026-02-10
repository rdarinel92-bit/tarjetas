/// Tipos de préstamo soportados:
/// - 'normal': Cuotas iguales de capital + interés (tradicional)
/// - 'diario': Préstamo con pagos diarios (monto + interés total / días)
/// - 'arquilado': Interés primero (cada cuota = solo interés), capital al final
enum TipoPrestamo {
  normal,
  diario,
  arquilado,
}

/// Variantes de arquilado:
/// - 'clasico': Paga solo interés cada período, capital + interés al final
/// - 'renovable': Puede renovar sin pagar capital al terminar el plazo
/// - 'acumulado': Intereses no pagados se acumulan al siguiente período
/// - 'mixto': Permite abonos a capital durante el préstamo
enum VarianteArquilado {
  clasico,
  renovable,
  acumulado,
  mixto,
}

class PrestamoModel {
  final String id;
  final String clienteId;
  final String? negocioId; // V10.30: Multi-negocio
  final String? sucursalId; // V10.30: Multi-sucursal
  final double monto;
  final double interes;
  final int plazoMeses;
  final String frecuenciaPago;
  final DateTime fechaCreacion;
  final String estado;
  
  // Nuevos campos para tipos de préstamo
  final String tipoPrestamo; // 'normal', 'diario', 'arquilado'
  final double interesDiario; // Para arquilado: interés por período
  final bool capitalAlFinal; // Para arquilado: si el capital se paga al final
  final String? varianteArquilado; // 'clasico', 'renovable', 'acumulado', 'mixto'
  
  // Campos adicionales V10.30
  final String? proposito;
  final String? garantia;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PrestamoModel({
    required this.id,
    required this.clienteId,
    this.negocioId,
    this.sucursalId,
    required this.monto,
    required this.interes,
    required this.plazoMeses,
    this.frecuenciaPago = 'Mensual',
    required this.fechaCreacion,
    required this.estado,
    this.tipoPrestamo = 'normal',
    this.interesDiario = 0.0,
    this.capitalAlFinal = false,
    this.varianteArquilado,
    this.proposito,
    this.garantia,
    this.createdAt,
    this.updatedAt,
  });

  factory PrestamoModel.fromMap(Map<String, dynamic> map) {
    return PrestamoModel(
      id: map['id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      negocioId: map['negocio_id'],
      sucursalId: map['sucursal_id'],
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      interes: (map['interes'] as num?)?.toDouble() ?? 0.0,
      plazoMeses: map['plazo_meses'] ?? 0,
      frecuenciaPago: map['frecuencia_pago'] ?? 'Mensual',
      fechaCreacion: map['fecha_creacion'] != null 
          ? DateTime.parse(map['fecha_creacion']) 
          : DateTime.now(),
      estado: map['estado'] ?? 'activo',
      tipoPrestamo: map['tipo_prestamo'] ?? 'normal',
      interesDiario: (map['interes_diario'] as num?)?.toDouble() ?? 0.0,
      capitalAlFinal: map['capital_al_final'] ?? false,
      varianteArquilado: map['variante_arquilado'],
      proposito: map['proposito'],
      garantia: map['garantia'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  /// toMap para INSERT (sin id, Supabase lo genera)
  Map<String, dynamic> toMapForInsert() {
    return {
      'cliente_id': clienteId,
      if (negocioId != null) 'negocio_id': negocioId,
      if (sucursalId != null) 'sucursal_id': sucursalId,
      'monto': monto,
      'interes': interes,
      'plazo_meses': plazoMeses,
      'frecuencia_pago': frecuenciaPago,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'estado': estado,
      'tipo_prestamo': tipoPrestamo,
      'interes_diario': interesDiario,
      'capital_al_final': capitalAlFinal,
      if (varianteArquilado != null) 'variante_arquilado': varianteArquilado,
      if (proposito != null) 'proposito': proposito,
      if (garantia != null) 'garantia': garantia,
    };
  }

  /// toMap para UPDATE (incluye id)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      if (negocioId != null) 'negocio_id': negocioId,
      if (sucursalId != null) 'sucursal_id': sucursalId,
      'monto': monto,
      'interes': interes,
      'plazo_meses': plazoMeses,
      'frecuencia_pago': frecuenciaPago,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'estado': estado,
      'tipo_prestamo': tipoPrestamo,
      'interes_diario': interesDiario,
      'capital_al_final': capitalAlFinal,
      if (varianteArquilado != null) 'variante_arquilado': varianteArquilado,
      if (proposito != null) 'proposito': proposito,
      if (garantia != null) 'garantia': garantia,
    };
  }
  
  /// Helper para obtener nombre legible del tipo
  String get tipoPrestamoNombre {
    switch (tipoPrestamo) {
      case 'diario':
        return 'Préstamo Diario';
      case 'arquilado':
        return 'Arquilado${varianteArquilado != null ? ' (${_nombreVariante})' : ''}';
      default:
        return 'Normal';
    }
  }
  
  String get _nombreVariante {
    switch (varianteArquilado) {
      case 'clasico': return 'Clásico';
      case 'renovable': return 'Renovable';
      case 'acumulado': return 'Acumulado';
      case 'mixto': return 'Mixto';
      default: return '';
    }
  }
}
