/// Modelo para la tabla `empleados` de Supabase
/// Representa un empleado del sistema
class EmpleadoModel {
  final String id;
  final String? usuarioId;
  final String? negocioId;
  final String? sucursalId;
  final String nombre;
  final String? apellidos;
  final String? email;
  final String? telefono;
  final String? direccion;
  final String? puesto;
  final String? departamento;
  final double? salarioBase;
  final double? comisionPorcentaje;
  final String? tipoPagoComision; // al_liquidar, proporcional, primer_pago
  final DateTime? fechaIngreso;
  final String? numeroEmpleado;
  final String? curp;
  final String? rfc;
  final String? nss; // Número de seguro social
  final String? cuentaBanco;
  final String? banco;
  final String? fotoUrl;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EmpleadoModel({
    required this.id,
    this.usuarioId,
    this.negocioId,
    this.sucursalId,
    required this.nombre,
    this.apellidos,
    this.email,
    this.telefono,
    this.direccion,
    this.puesto,
    this.departamento,
    this.salarioBase,
    this.comisionPorcentaje,
    this.tipoPagoComision,
    this.fechaIngreso,
    this.numeroEmpleado,
    this.curp,
    this.rfc,
    this.nss,
    this.cuentaBanco,
    this.banco,
    this.fotoUrl,
    this.activo = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Nombre completo del empleado
  String get nombreCompleto {
    if (apellidos != null && apellidos!.isNotEmpty) {
      return '$nombre $apellidos';
    }
    return nombre;
  }

  /// Iniciales para avatar
  String get iniciales {
    final partes = nombreCompleto.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
  }

  /// Antigüedad en texto
  String get antiguedad {
    if (fechaIngreso == null) return 'No especificada';
    final diferencia = DateTime.now().difference(fechaIngreso!);
    final anos = diferencia.inDays ~/ 365;
    final meses = (diferencia.inDays % 365) ~/ 30;
    
    if (anos > 0) {
      return '$anos año${anos > 1 ? 's' : ''}${meses > 0 ? ', $meses mes${meses > 1 ? 'es' : ''}' : ''}';
    } else if (meses > 0) {
      return '$meses mes${meses > 1 ? 'es' : ''}';
    } else {
      return '${diferencia.inDays} día${diferencia.inDays > 1 ? 's' : ''}';
    }
  }

  factory EmpleadoModel.fromMap(Map<String, dynamic> map) {
    return EmpleadoModel(
      id: map['id'] ?? '',
      usuarioId: map['usuario_id'],
      negocioId: map['negocio_id'],
      sucursalId: map['sucursal_id'],
      nombre: map['nombre'] ?? '',
      apellidos: map['apellidos'],
      email: map['email'],
      telefono: map['telefono'],
      direccion: map['direccion'],
      puesto: map['puesto'],
      departamento: map['departamento'],
      salarioBase: map['salario_base'] != null ? double.tryParse(map['salario_base'].toString()) : null,
      comisionPorcentaje: map['comision_porcentaje'] != null ? double.tryParse(map['comision_porcentaje'].toString()) : null,
      tipoPagoComision: map['tipo_pago_comision'],
      fechaIngreso: map['fecha_ingreso'] != null ? DateTime.tryParse(map['fecha_ingreso']) : null,
      numeroEmpleado: map['numero_empleado'],
      curp: map['curp'],
      rfc: map['rfc'],
      nss: map['nss'],
      cuentaBanco: map['cuenta_banco'],
      banco: map['banco'],
      fotoUrl: map['foto_url'],
      activo: map['activo'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'usuario_id': usuarioId,
    'negocio_id': negocioId,
    'sucursal_id': sucursalId,
    'nombre': nombre,
    'apellidos': apellidos,
    'email': email,
    'telefono': telefono,
    'direccion': direccion,
    'puesto': puesto,
    'departamento': departamento,
    'salario_base': salarioBase,
    'comision_porcentaje': comisionPorcentaje,
    'tipo_pago_comision': tipoPagoComision,
    'fecha_ingreso': fechaIngreso?.toIso8601String().split('T').first,
    'numero_empleado': numeroEmpleado,
    'curp': curp,
    'rfc': rfc,
    'nss': nss,
    'cuenta_banco': cuentaBanco,
    'banco': banco,
    'foto_url': fotoUrl,
    'activo': activo,
  };

  Map<String, dynamic> toMapForInsert() => {
    'usuario_id': usuarioId,
    'negocio_id': negocioId,
    'sucursal_id': sucursalId,
    'nombre': nombre,
    'apellidos': apellidos,
    'email': email,
    'telefono': telefono,
    'direccion': direccion,
    'puesto': puesto,
    'departamento': departamento,
    'salario_base': salarioBase,
    'comision_porcentaje': comisionPorcentaje,
    'tipo_pago_comision': tipoPagoComision,
    'fecha_ingreso': fechaIngreso?.toIso8601String().split('T').first,
    'numero_empleado': numeroEmpleado,
    'curp': curp,
    'rfc': rfc,
    'nss': nss,
    'cuenta_banco': cuentaBanco,
    'banco': banco,
    'foto_url': fotoUrl,
    'activo': activo,
  };

  EmpleadoModel copyWith({
    String? id,
    String? usuarioId,
    String? negocioId,
    String? sucursalId,
    String? nombre,
    String? apellidos,
    String? email,
    String? telefono,
    String? direccion,
    String? puesto,
    String? departamento,
    double? salarioBase,
    double? comisionPorcentaje,
    String? tipoPagoComision,
    DateTime? fechaIngreso,
    String? numeroEmpleado,
    String? curp,
    String? rfc,
    String? nss,
    String? cuentaBanco,
    String? banco,
    String? fotoUrl,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmpleadoModel(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      negocioId: negocioId ?? this.negocioId,
      sucursalId: sucursalId ?? this.sucursalId,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      puesto: puesto ?? this.puesto,
      departamento: departamento ?? this.departamento,
      salarioBase: salarioBase ?? this.salarioBase,
      comisionPorcentaje: comisionPorcentaje ?? this.comisionPorcentaje,
      tipoPagoComision: tipoPagoComision ?? this.tipoPagoComision,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      numeroEmpleado: numeroEmpleado ?? this.numeroEmpleado,
      curp: curp ?? this.curp,
      rfc: rfc ?? this.rfc,
      nss: nss ?? this.nss,
      cuentaBanco: cuentaBanco ?? this.cuentaBanco,
      banco: banco ?? this.banco,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'EmpleadoModel(id: $id, nombre: $nombreCompleto, puesto: $puesto)';
}
