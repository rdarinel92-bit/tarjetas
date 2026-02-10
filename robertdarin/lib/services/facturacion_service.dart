import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/supabase_client.dart';
import '../data/models/facturacion_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE FACTURACIÓN ELECTRÓNICA (CFDI 4.0)
// Integración con FacturAPI, Facturama, FiscoClic
// Robert Darin Platform v10.13
// ═══════════════════════════════════════════════════════════════════════════════

class FacturacionService {
  static final FacturacionService _instance = FacturacionService._internal();
  factory FacturacionService() => _instance;
  FacturacionService._internal();

  // URLs base de APIs de facturación
  static const String _facturApiBaseUrl = 'https://www.facturapi.io/v2';
  static const String _facturApiSandbox = 'https://www.facturapi.io/v2';
  // ignore: unused_field
  static const String _facturamaBaseUrl = 'https://api.facturama.mx';
  // ignore: unused_field
  static const String _facturamaSandbox = 'https://apisandbox.facturama.mx';

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN DEL EMISOR
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener configuración del emisor para el negocio actual
  Future<FacturacionEmisorModel?> obtenerEmisor(String negocioId) async {
    try {
      final response = await AppSupabase.client
          .from('facturacion_emisores')
          .select()
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .maybeSingle();

      if (response != null) {
        return FacturacionEmisorModel.fromMap(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error al obtener emisor: $e');
      return null;
    }
  }

  /// Guardar o actualizar configuración del emisor
  Future<bool> guardarEmisor(FacturacionEmisorModel emisor) async {
    try {
      // Verificar si ya existe
      final existente = await AppSupabase.client
          .from('facturacion_emisores')
          .select('id')
          .eq('negocio_id', emisor.negocioId)
          .maybeSingle();

      if (existente != null) {
        // Actualizar
        await AppSupabase.client
            .from('facturacion_emisores')
            .update(emisor.toMapForInsert())
            .eq('id', existente['id']);
      } else {
        // Crear
        await AppSupabase.client
            .from('facturacion_emisores')
            .insert(emisor.toMapForInsert());
      }

      await _registrarLog(emisor.negocioId, null, 'configuracion_emisor', 
          'Configuración de emisor actualizada', 'exito', null);
      return true;
    } catch (e) {
      debugPrint('Error al guardar emisor: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLIENTES FISCALES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener todos los clientes fiscales de un negocio
  Future<List<FacturacionClienteModel>> obtenerClientesFiscales(String negocioId) async {
    try {
      final response = await AppSupabase.client
          .from('facturacion_clientes')
          .select()
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .order('razon_social');

      return (response as List)
          .map((e) => FacturacionClienteModel.fromMap(e))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener clientes fiscales: $e');
      return [];
    }
  }

  /// Buscar cliente fiscal por RFC
  Future<FacturacionClienteModel?> buscarPorRfc(String negocioId, String rfc) async {
    try {
      final response = await AppSupabase.client
          .from('facturacion_clientes')
          .select()
          .eq('negocio_id', negocioId)
          .eq('rfc', rfc.toUpperCase())
          .maybeSingle();

      if (response != null) {
        return FacturacionClienteModel.fromMap(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error al buscar por RFC: $e');
      return null;
    }
  }

  /// Guardar cliente fiscal
  Future<String?> guardarClienteFiscal(FacturacionClienteModel cliente) async {
    try {
      final response = await AppSupabase.client
          .from('facturacion_clientes')
          .insert(cliente.toMapForInsert())
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      debugPrint('Error al guardar cliente fiscal: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTURAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener facturas con filtros
  Future<List<FacturaModel>> obtenerFacturas({
    required String negocioId,
    String? estado,
    String? moduloOrigen,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int limit = 50,
  }) async {
    try {
      var query = AppSupabase.client
          .from('v_facturas_completas')
          .select()
          .eq('negocio_id', negocioId);

      if (estado != null) {
        query = query.eq('estado', estado);
      }
      if (moduloOrigen != null) {
        query = query.eq('modulo_origen', moduloOrigen);
      }
      if (fechaInicio != null) {
        query = query.gte('fecha_emision', fechaInicio.toIso8601String());
      }
      if (fechaFin != null) {
        query = query.lte('fecha_emision', fechaFin.toIso8601String());
      }

      final response = await query
          .order('fecha_emision', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => FacturaModel.fromMap(e))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener facturas: $e');
      return [];
    }
  }

  /// Crear borrador de factura
  Future<String?> crearBorradorFactura({
    required String negocioId,
    required String emisorId,
    required String clienteFiscalId,
    required List<FacturaConceptoModel> conceptos,
    String? moduloOrigen,
    String? referenciaOrigenId,
    String? referenciaTipo,
    String formaPago = '99',
    String metodoPago = 'PUE',
    String usoCfdi = 'G03',
    String? notas,
  }) async {
    try {
      // Calcular totales
      double subtotal = 0;
      double iva = 0;
      
      for (var concepto in conceptos) {
        subtotal += concepto.cantidad * concepto.valorUnitario - concepto.descuento;
      }
      iva = subtotal * 0.16; // Por defecto 16% IVA
      final total = subtotal + iva;

      // Obtener emisor para CP
      final emisor = await obtenerEmisor(negocioId);

      // Crear factura
      final facturaData = {
        'negocio_id': negocioId,
        'emisor_id': emisorId,
        'cliente_fiscal_id': clienteFiscalId,
        'tipo_comprobante': 'I',
        'fecha_emision': DateTime.now().toIso8601String(),
        'modulo_origen': moduloOrigen,
        'referencia_origen_id': referenciaOrigenId,
        'referencia_tipo': referenciaTipo,
        'subtotal': subtotal,
        'iva': iva,
        'total': total,
        'forma_pago': formaPago,
        'metodo_pago': metodoPago,
        'uso_cfdi': usoCfdi,
        'lugar_expedicion': emisor?.codigoPostal,
        'estado': 'borrador',
        'notas': notas,
      };

      final response = await AppSupabase.client
          .from('facturas')
          .insert(facturaData)
          .select('id')
          .single();

      final facturaId = response['id'] as String;

      // Insertar conceptos
      for (var concepto in conceptos) {
        await AppSupabase.client.from('factura_conceptos').insert({
          'factura_id': facturaId,
          'clave_prod_serv': concepto.claveProdServ,
          'clave_unidad': concepto.claveUnidad,
          'unidad': concepto.unidad,
          'descripcion': concepto.descripcion,
          'no_identificacion': concepto.noIdentificacion,
          'cantidad': concepto.cantidad,
          'valor_unitario': concepto.valorUnitario,
          'descuento': concepto.descuento,
          'importe': concepto.cantidad * concepto.valorUnitario - concepto.descuento,
          'objeto_imp': '02',
        });
      }

      await _registrarLog(negocioId, facturaId, 'creacion', 
          'Borrador de factura creado', 'exito', null);

      return facturaId;
    } catch (e) {
      debugPrint('Error al crear borrador de factura: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TIMBRADO CON FACTURAPI
  // ═══════════════════════════════════════════════════════════════════════════

  /// Timbrar factura usando FacturAPI
  Future<Map<String, dynamic>> timbrarConFacturApi({
    required String facturaId,
    required String apiKey,
    required bool modoPruebas,
  }) async {
    try {
      // Obtener datos completos de la factura
      final facturaResponse = await AppSupabase.client
          .from('facturas')
          .select('''
            *,
            emisor:facturacion_emisores(*),
            cliente:facturacion_clientes(*),
            conceptos:factura_conceptos(*)
          ''')
          .eq('id', facturaId)
          .single();

      final emisor = facturaResponse['emisor'];
      final cliente = facturaResponse['cliente'];
      final conceptos = facturaResponse['conceptos'] as List;

      // Construir payload para FacturAPI
      final itemsList = conceptos.map((c) {
        return {
          'product': {
            'description': c['descripcion'],
            'product_key': c['clave_prod_serv'],
            'unit_key': c['clave_unidad'],
            'unit_name': c['unidad'] ?? 'Pieza',
            'price': c['valor_unitario'],
          },
          'quantity': c['cantidad'],
          'discount': c['descuento'],
        };
      }).toList();
      
      final payload = {
        'customer': {
          'legal_name': cliente['razon_social'],
          'tax_id': cliente['rfc'],
          'tax_system': cliente['regimen_fiscal'],
          'email': cliente['email'],
          'address': {
            'zip': cliente['codigo_postal'],
          }
        },
        'items': itemsList,
        'payment_form': facturaResponse['forma_pago'],
        'payment_method': facturaResponse['metodo_pago'],
        'use': facturaResponse['uso_cfdi'],
        'series': emisor['serie_facturas'],
        'folio_number': emisor['folio_actual_facturas'],
      };

      // Hacer petición a FacturAPI
      final url = modoPruebas 
          ? '$_facturApiSandbox/invoices' 
          : '$_facturApiBaseUrl/invoices';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Actualizar factura con datos del timbrado
        await AppSupabase.client.from('facturas').update({
          'uuid_fiscal': data['uuid'],
          'fecha_timbrado': DateTime.now().toIso8601String(),
          'serie': data['series'],
          'folio': data['folio_number'],
          'estado': 'timbrada',
          'xml_content': data['xml'],
          'pac_response': data,
          'cadena_original': data['cadena_original'],
          'sello_cfdi': data['sello_cfdi'],
          'sello_sat': data['sello_sat'],
          'certificado_sat': data['certificado_sat'],
        }).eq('id', facturaId);

        // Incrementar folio
        await AppSupabase.client.from('facturacion_emisores').update({
          'folio_actual_facturas': emisor['folio_actual_facturas'] + 1,
        }).eq('id', emisor['id']);

        await _registrarLog(
          facturaResponse['negocio_id'], 
          facturaId, 
          'timbrado', 
          'Factura timbrada exitosamente: ${data['uuid']}',
          'exito',
          {'uuid': data['uuid'], 'folio': data['folio_number']},
        );

        return {'success': true, 'uuid': data['uuid'], 'data': data};
      } else {
        final error = jsonDecode(response.body);
        
        await _registrarLog(
          facturaResponse['negocio_id'], 
          facturaId, 
          'timbrado', 
          'Error al timbrar: ${error['message'] ?? response.body}',
          'error',
          error,
        );

        return {'success': false, 'error': error['message'] ?? 'Error desconocido'};
      }
    } catch (e) {
      debugPrint('Error al timbrar con FacturAPI: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CANCELACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cancelar factura
  Future<Map<String, dynamic>> cancelarFactura({
    required String facturaId,
    required String apiKey,
    required String motivo,
    String? uuidSustitucion,
    required bool modoPruebas,
  }) async {
    try {
      final factura = await AppSupabase.client
          .from('facturas')
          .select('*, emisor:facturacion_emisores(*)')
          .eq('id', facturaId)
          .single();

      if (factura['uuid_fiscal'] == null) {
        return {'success': false, 'error': 'La factura no está timbrada'};
      }

      final url = modoPruebas 
          ? '$_facturApiSandbox/invoices/${factura['uuid_fiscal']}' 
          : '$_facturApiBaseUrl/invoices/${factura['uuid_fiscal']}';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'motive': motivo,
          'substitution': uuidSustitucion,
        }),
      );

      if (response.statusCode == 200) {
        await AppSupabase.client.from('facturas').update({
          'estado': 'cancelada',
          'fecha_cancelacion': DateTime.now().toIso8601String(),
          'motivo_cancelacion': motivo,
          'uuid_sustitucion': uuidSustitucion,
        }).eq('id', facturaId);

        await _registrarLog(
          factura['negocio_id'], 
          facturaId, 
          'cancelacion', 
          'Factura cancelada: ${factura['uuid_fiscal']}',
          'exito',
          {'motivo': motivo},
        );

        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['message'] ?? 'Error al cancelar'};
      }
    } catch (e) {
      debugPrint('Error al cancelar factura: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESCARGAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Descargar PDF de factura
  Future<String?> descargarPdf(String facturaId, String apiKey, bool modoPruebas) async {
    try {
      final factura = await AppSupabase.client
          .from('facturas')
          .select('uuid_fiscal')
          .eq('id', facturaId)
          .single();

      if (factura['uuid_fiscal'] == null) return null;

      final url = modoPruebas 
          ? '$_facturApiSandbox/invoices/${factura['uuid_fiscal']}/pdf' 
          : '$_facturApiBaseUrl/invoices/${factura['uuid_fiscal']}/pdf';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        // Retornar base64 del PDF
        return base64Encode(response.bodyBytes);
      }
      return null;
    } catch (e) {
      debugPrint('Error al descargar PDF: $e');
      return null;
    }
  }

  /// Descargar XML de factura
  Future<String?> descargarXml(String facturaId) async {
    try {
      final factura = await AppSupabase.client
          .from('facturas')
          .select('xml_content')
          .eq('id', facturaId)
          .single();

      return factura['xml_content'];
    } catch (e) {
      debugPrint('Error al descargar XML: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ENVÍO POR EMAIL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enviar factura por email
  Future<bool> enviarPorEmail(String facturaId, String email, String apiKey, bool modoPruebas) async {
    try {
      final factura = await AppSupabase.client
          .from('facturas')
          .select('uuid_fiscal, negocio_id')
          .eq('id', facturaId)
          .single();

      if (factura['uuid_fiscal'] == null) return false;

      final url = modoPruebas 
          ? '$_facturApiSandbox/invoices/${factura['uuid_fiscal']}/email' 
          : '$_facturApiBaseUrl/invoices/${factura['uuid_fiscal']}/email';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        await AppSupabase.client.from('facturas').update({
          'estado': 'enviada',
        }).eq('id', facturaId);

        await _registrarLog(
          factura['negocio_id'], 
          facturaId, 
          'envio', 
          'Factura enviada a: $email',
          'exito',
          {'email': email},
        );

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error al enviar por email: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CATÁLOGOS SAT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener regímenes fiscales
  Future<List<RegimenFiscalModel>> obtenerRegimenesFiscales({bool? personaFisica}) async {
    try {
      var query = AppSupabase.client
          .from('catalogo_regimen_fiscal')
          .select()
          .eq('activo', true);

      if (personaFisica == true) {
        query = query.eq('aplica_persona_fisica', true);
      } else if (personaFisica == false) {
        query = query.eq('aplica_persona_moral', true);
      }

      final response = await query.order('clave');
      return (response as List).map((e) => RegimenFiscalModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener regímenes fiscales: $e');
      return [];
    }
  }

  /// Obtener usos de CFDI
  Future<List<UsoCfdiModel>> obtenerUsosCfdi() async {
    try {
      final response = await AppSupabase.client
          .from('catalogo_uso_cfdi')
          .select()
          .order('clave');

      return (response as List).map((e) => UsoCfdiModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener usos CFDI: $e');
      return [];
    }
  }

  /// Obtener formas de pago
  Future<List<FormaPagoModel>> obtenerFormasPago() async {
    try {
      final response = await AppSupabase.client
          .from('catalogo_forma_pago')
          .select()
          .order('clave');

      return (response as List).map((e) => FormaPagoModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener formas de pago: $e');
      return [];
    }
  }

  /// Obtener productos/servicios frecuentes
  Future<List<FacturacionProductoModel>> obtenerProductosFrecuentes({
    String? negocioId,
    String? modulo,
  }) async {
    try {
      var query = AppSupabase.client
          .from('facturacion_productos')
          .select()
          .eq('activo', true);

      if (modulo != null) {
        query = query.eq('modulo', modulo);
      }

      final response = await query.order('descripcion');
      return (response as List).map((e) => FacturacionProductoModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener productos frecuentes: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener estadísticas de facturación
  Future<Map<String, dynamic>> obtenerEstadisticas(String negocioId, {int? mes, int? anio}) async {
    try {
      final ahora = DateTime.now();
      final mesActual = mes ?? ahora.month;
      final anioActual = anio ?? ahora.year;
      
      final inicioMes = DateTime(anioActual, mesActual, 1);
      final finMes = DateTime(anioActual, mesActual + 1, 0, 23, 59, 59);

      final response = await AppSupabase.client
          .from('facturas')
          .select('estado, total')
          .eq('negocio_id', negocioId)
          .gte('fecha_emision', inicioMes.toIso8601String())
          .lte('fecha_emision', finMes.toIso8601String());

      final facturas = response as List;
      
      int totalFacturas = facturas.length;
      int timbradas = 0;
      int canceladas = 0;
      double montoTotal = 0;
      double montoCancelado = 0;

      for (var f in facturas) {
        if (f['estado'] == 'timbrada' || f['estado'] == 'enviada') {
          timbradas++;
          montoTotal += (f['total'] ?? 0).toDouble();
        } else if (f['estado'] == 'cancelada') {
          canceladas++;
          montoCancelado += (f['total'] ?? 0).toDouble();
        }
      }

      return {
        'total_facturas': totalFacturas,
        'timbradas': timbradas,
        'canceladas': canceladas,
        'borradores': totalFacturas - timbradas - canceladas,
        'monto_total': montoTotal,
        'monto_cancelado': montoCancelado,
        'mes': mesActual,
        'anio': anioActual,
      };
    } catch (e) {
      debugPrint('Error al obtener estadísticas: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validar RFC
  bool validarRfc(String rfc) {
    // RFC Persona Moral: 3 letras + 6 números + 3 caracteres
    // RFC Persona Física: 4 letras + 6 números + 3 caracteres
    final regExp = RegExp(r'^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$');
    
    if (regExp.hasMatch(rfc.toUpperCase())) return true;
    if (rfc == 'XAXX010101000') return true; // Público general
    if (rfc == 'XEXX010101000') return true; // Extranjero
    
    return false;
  }

  /// Determinar si RFC es persona física
  bool esPersonaFisica(String rfc) {
    return rfc.length == 13;
  }

  /// Registrar log de actividad
  Future<void> _registrarLog(
    String negocioId,
    String? facturaId,
    String accion,
    String descripcion,
    String resultado,
    Map<String, dynamic>? detalles,
  ) async {
    try {
      await AppSupabase.client.from('facturacion_logs').insert({
        'negocio_id': negocioId,
        'factura_id': facturaId,
        'accion': accion,
        'descripcion': descripcion,
        'resultado': resultado,
        'detalles': detalles,
      });
    } catch (e) {
      debugPrint('Error al registrar log: $e');
    }
  }
}
