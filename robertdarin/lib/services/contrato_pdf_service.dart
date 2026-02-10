import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../core/supabase_client.dart';

/// Servicio para generar contratos PDF para avales
/// Incluye: Contrato de garantía, Pagaré, Acuerdo de responsabilidad
class ContratoPdfService {
  static final _currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
  static final _dateFormat = DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es_MX');

  /// Genera el contrato completo de aval en PDF
  static Future<Uint8List> generarContratoAval({
    required Map<String, dynamic> aval,
    required Map<String, dynamic> prestamo,
    required Map<String, dynamic> cliente,
    required Map<String, dynamic> empresa,
  }) async {
    final pdf = pw.Document();
    
    final montoTotal = (prestamo['monto_total'] ?? prestamo['monto'] ?? 0).toDouble();
    final fechaPrestamo = DateTime.tryParse(prestamo['fecha_desembolso'] ?? '') ?? DateTime.now();
    final fechaVencimiento = DateTime.tryParse(prestamo['fecha_vencimiento'] ?? '') ?? 
        fechaPrestamo.add(const Duration(days: 365));

    // === PÁGINA 1: CONTRATO DE GARANTÍA ===
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(50),
        header: (context) => _buildHeader(empresa),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'CONTRATO DE GARANTÍA PERSONAL (AVAL)',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          
          pw.Text(
            'Contrato No. ${prestamo['folio'] ?? prestamo['id']?.toString().substring(0, 8) ?? 'N/A'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),
          
          // DECLARACIONES
          pw.Text('DECLARACIONES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          
          pw.Text(
            'En la ciudad de ${empresa['ciudad'] ?? 'México'}, a ${_dateFormat.format(fechaPrestamo)}, '
            'comparecen por una parte "${empresa['nombre'] ?? 'LA EMPRESA'}" (en adelante "EL ACREEDOR"), '
            'representada en este acto, y por otra parte:',
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),
          
          // DATOS DEL DEUDOR
          _buildSeccionDatos('I. EL DEUDOR PRINCIPAL:', [
            'Nombre: ${cliente['nombre_completo'] ?? 'N/A'}',
            'CURP: ${cliente['curp'] ?? 'N/A'}',
            'Domicilio: ${cliente['direccion'] ?? 'N/A'}',
            'Teléfono: ${cliente['telefono'] ?? 'N/A'}',
          ]),
          pw.SizedBox(height: 10),
          
          // DATOS DEL AVAL
          _buildSeccionDatos('II. EL AVAL (GARANTE):', [
            'Nombre: ${aval['nombre'] ?? 'N/A'}',
            'CURP: ${aval['curp'] ?? 'N/A'}',
            'Domicilio: ${aval['direccion'] ?? 'N/A'}',
            'Teléfono: ${aval['telefono'] ?? 'N/A'}',
            'Relación con el deudor: ${aval['relacion'] ?? 'N/A'}',
          ]),
          pw.SizedBox(height: 15),
          
          // CLÁUSULAS
          pw.Text('CLÁUSULAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          
          _buildClausula('PRIMERA - OBJETO', 
            'El presente contrato tiene por objeto establecer la garantía personal que '
            '"EL AVAL" otorga a favor de "EL ACREEDOR" para garantizar el cumplimiento '
            'de las obligaciones derivadas del préstamo otorgado a "EL DEUDOR PRINCIPAL".'),
          
          _buildClausula('SEGUNDA - MONTO GARANTIZADO',
            'El monto total garantizado asciende a ${_currencyFormat.format(montoTotal)} '
            '(${_numeroALetras(montoTotal)} PESOS 00/100 M.N.), incluyendo capital, '
            'intereses ordinarios, intereses moratorios y gastos de cobranza que se generen.'),
          
          _buildClausula('TERCERA - OBLIGACIONES DEL AVAL',
            '"EL AVAL" se obliga solidariamente con "EL DEUDOR PRINCIPAL" a:\n'
            'a) Responder por el pago total de la deuda en caso de incumplimiento.\n'
            'b) Mantener actualizada su información de contacto.\n'
            'c) Informar cualquier cambio de domicilio en un plazo no mayor a 5 días.\n'
            'd) Facilitar la verificación de su domicilio cuando sea requerido.\n'
            'e) No ausentarse del domicilio declarado por más de 30 días sin notificación.'),
          
          _buildClausula('CUARTA - RESPONSABILIDAD SOLIDARIA',
            '"EL AVAL" reconoce y acepta que su responsabilidad es SOLIDARIA, lo que significa '
            'que "EL ACREEDOR" puede exigirle el pago total de la deuda sin necesidad de '
            'agotar primero el cobro contra "EL DEUDOR PRINCIPAL". Esta responsabilidad '
            'incluye capital, intereses, comisiones y gastos de cobranza.'),
          
          _buildClausula('QUINTA - VIGENCIA',
            'El presente contrato estará vigente desde la fecha de su firma hasta que '
            '"EL DEUDOR PRINCIPAL" liquide totalmente el préstamo garantizado, o en su '
            'defecto, hasta que "EL AVAL" cubra la totalidad de la deuda. '
            'Fecha de vencimiento del préstamo: ${_dateFormat.format(fechaVencimiento)}.'),
          
          _buildClausula('SEXTA - VERIFICACIÓN DE IDENTIDAD',
            '"EL AVAL" declara bajo protesta de decir verdad que:\n'
            'a) Los datos proporcionados son verídicos.\n'
            'b) La identificación presentada es auténtica.\n'
            'c) Tiene capacidad legal para obligarse.\n'
            'd) No tiene impedimento legal para fungir como aval.'),
          
          _buildClausula('SÉPTIMA - JURISDICCIÓN',
            'Para la interpretación y cumplimiento del presente contrato, las partes se '
            'someten a la jurisdicción de los tribunales competentes de ${empresa['ciudad'] ?? 'la ciudad'}, '
            'renunciando expresamente a cualquier otro fuero que pudiera corresponderles.'),
        ],
      ),
    );

    // === PÁGINA 2: PAGARÉ ===
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(50),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text('PAGARÉ', 
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text('(Suscrito por el Aval como obligado solidario)',
                style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.SizedBox(height: 20),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('No. ${prestamo['folio'] ?? prestamo['id']?.toString().substring(0, 8) ?? 'N/A'}'),
                pw.Text('Bueno por: ${_currencyFormat.format(montoTotal)}'),
              ],
            ),
            pw.SizedBox(height: 20),
            
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Text(
                'Debo(emos) y pagaré(mos) incondicionalmente a la orden de '
                '"${empresa['nombre'] ?? 'EL ACREEDOR'}" en ${empresa['ciudad'] ?? 'esta ciudad'}, '
                'el día ${_dateFormat.format(fechaVencimiento)}, la cantidad de '
                '${_currencyFormat.format(montoTotal)} (${_numeroALetras(montoTotal)} PESOS 00/100 M.N.).\n\n'
                'Valor recibido a mi(nuestra) entera satisfacción.\n\n'
                'Este pagaré forma parte del Contrato de Garantía Personal y se rige por las '
                'disposiciones de la Ley General de Títulos y Operaciones de Crédito.\n\n'
                'En caso de falta de pago, este documento causará intereses moratorios a razón '
                'del ${prestamo['tasa_moratoria'] ?? '5'}% mensual sobre saldos insolutos.',
                textAlign: pw.TextAlign.justify,
              ),
            ),
            pw.SizedBox(height: 30),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 200, height: 60, decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: const pw.BorderSide()),
                    )),
                    pw.SizedBox(height: 5),
                    pw.Text('FIRMA DEL AVAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(aval['nombre'] ?? '', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 200, height: 60, decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: const pw.BorderSide()),
                    )),
                    pw.SizedBox(height: 5),
                    pw.Text('HUELLA DIGITAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('(Índice derecho)', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 40),
            
            pw.Text('Lugar y fecha de suscripción: ${empresa['ciudad'] ?? 'México'}, '
                '${_dateFormat.format(fechaPrestamo)}'),
            pw.SizedBox(height: 10),
            pw.Text('Domicilio del suscriptor: ${aval['direccion'] ?? 'N/A'}'),
          ],
        ),
      ),
    );

    // === PÁGINA 3: CARTA RESPONSIVA Y AUTORIZACIÓN ===
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(50),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text('CARTA RESPONSIVA Y AUTORIZACIÓN',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 30),
            
            pw.Text(
              '${empresa['ciudad'] ?? 'México'}, a ${_dateFormat.format(DateTime.now())}',
              textAlign: pw.TextAlign.right,
            ),
            pw.SizedBox(height: 20),
            
            pw.Text('A QUIEN CORRESPONDA:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 15),
            
            pw.Text(
              'Por medio de la presente, yo ${aval['nombre'] ?? 'EL AVAL'}, con CURP '
              '${aval['curp'] ?? 'N/A'}, me constituyo como AVAL/FIADOR SOLIDARIO de '
              '${cliente['nombre_completo'] ?? 'EL DEUDOR'}, en el préstamo con folio '
              '${prestamo['folio'] ?? prestamo['id']?.toString().substring(0, 8) ?? 'N/A'}, '
              'otorgado por "${empresa['nombre'] ?? 'LA EMPRESA'}".',
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 15),
            
            pw.Text('DECLARO Y AUTORIZO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            
            _buildListaDeclaraciones([
              'Que conozco plenamente las condiciones del préstamo y las acepto.',
              'Que mi responsabilidad es solidaria e incondicional.',
              'Que autorizo la verificación de mis datos personales y crediticios.',
              'Que autorizo el uso de mi información para fines de cobranza.',
              'Que autorizo la geolocalización voluntaria de mi domicilio.',
              'Que me comprometo a cubrir la deuda si el titular incumple.',
              'Que renuncio al beneficio de orden y excusión.',
              'Que proporcioné documentos de identificación auténticos.',
            ]),
            pw.SizedBox(height: 20),
            
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('AVISO DE PRIVACIDAD:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Sus datos personales serán tratados conforme a la Ley Federal de Protección '
                    'de Datos Personales en Posesión de los Particulares (LFPDPPP). Tiene derecho '
                    'a acceder, rectificar, cancelar u oponerse al tratamiento de sus datos.',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.justify,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            
            pw.Text('ATENTAMENTE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 40),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 250, decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: const pw.BorderSide()),
                    ), child: pw.SizedBox(height: 50)),
                    pw.SizedBox(height: 5),
                    pw.Text(aval['nombre'] ?? 'NOMBRE DEL AVAL'),
                    pw.Text('AVAL/FIADOR SOLIDARIO', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  /// Genera solo el pagaré del aval
  static Future<Uint8List> generarPagareAval({
    required Map<String, dynamic> aval,
    required Map<String, dynamic> prestamo,
    required Map<String, dynamic> empresa,
  }) async {
    final pdf = pw.Document();
    final montoTotal = (prestamo['monto_total'] ?? prestamo['monto'] ?? 0).toDouble();
    final fechaVencimiento = DateTime.tryParse(prestamo['fecha_vencimiento'] ?? '') ?? 
        DateTime.now().add(const Duration(days: 365));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(50),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('PAGARÉ', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('(Obligado Solidario)', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 30),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Folio: ${prestamo['folio'] ?? 'N/A'}'),
                pw.Text('Por: ${_currencyFormat.format(montoTotal)}'),
              ],
            ),
            pw.SizedBox(height: 20),
            
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
              child: pw.Text(
                'Debo y pagaré incondicionalmente a la orden de "${empresa['nombre'] ?? 'EL ACREEDOR'}" '
                'la cantidad de ${_currencyFormat.format(montoTotal)} '
                '(${_numeroALetras(montoTotal)} PESOS 00/100 M.N.) '
                'el día ${_dateFormat.format(fechaVencimiento)}.\n\n'
                'Este pagaré es parte integral del contrato de garantía personal.',
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
              ),
            ),
            pw.SizedBox(height: 50),
            
            pw.Container(width: 200, height: 80, decoration: pw.BoxDecoration(
              border: pw.Border(bottom: const pw.BorderSide(width: 2)),
            )),
            pw.Text(aval['nombre'] ?? 'AVAL'),
            pw.Text('Firma del Obligado Solidario', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // === HELPERS ===
  
  static pw.Widget _buildHeader(Map<String, dynamic> empresa) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(empresa['nombre'] ?? 'EMPRESA', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('RFC: ${empresa['rfc'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Divider(),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Documento generado electrónicamente', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', 
              style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSeccionDatos(String titulo, List<String> datos) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...datos.map((d) => pw.Padding(
          padding: const pw.EdgeInsets.only(left: 15, top: 2),
          child: pw.Text(d, style: const pw.TextStyle(fontSize: 11)),
        )),
      ],
    );
  }

  static pw.Widget _buildClausula(String titulo, String contenido) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.SizedBox(height: 3),
        pw.Text(contenido, textAlign: pw.TextAlign.justify, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildListaDeclaraciones(List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.asMap().entries.map((e) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${e.key + 1}. ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Expanded(child: pw.Text(e.value, style: const pw.TextStyle(fontSize: 10))),
          ],
        ),
      )).toList(),
    );
  }

  static String _numeroALetras(double numero) {
    final unidades = ['', 'UN', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE'];
    final decenas = ['', 'DIEZ', 'VEINTE', 'TREINTA', 'CUARENTA', 'CINCUENTA', 'SESENTA', 'SETENTA', 'OCHENTA', 'NOVENTA'];
    final especiales = ['DIEZ', 'ONCE', 'DOCE', 'TRECE', 'CATORCE', 'QUINCE'];
    final centenas = ['', 'CIENTO', 'DOSCIENTOS', 'TRESCIENTOS', 'CUATROCIENTOS', 'QUINIENTOS', 'SEISCIENTOS', 'SETECIENTOS', 'OCHOCIENTOS', 'NOVECIENTOS'];
    
    int n = numero.truncate();
    if (n == 0) return 'CERO';
    if (n == 100) return 'CIEN';
    
    String resultado = '';
    
    if (n >= 1000000) {
      int millones = n ~/ 1000000;
      resultado += millones == 1 ? 'UN MILLÓN ' : '${_numeroALetras(millones.toDouble())} MILLONES ';
      n %= 1000000;
    }
    
    if (n >= 1000) {
      int miles = n ~/ 1000;
      resultado += miles == 1 ? 'MIL ' : '${_numeroALetras(miles.toDouble())} MIL ';
      n %= 1000;
    }
    
    if (n >= 100) {
      resultado += '${centenas[n ~/ 100]} ';
      n %= 100;
    }
    
    if (n >= 10 && n <= 15) {
      resultado += especiales[n - 10];
      return resultado.trim();
    }
    
    if (n >= 10) {
      resultado += '${decenas[n ~/ 10]} ';
      n %= 10;
      if (n > 0) resultado += 'Y ';
    }
    
    if (n > 0) {
      resultado += unidades[n];
    }
    
    return resultado.trim();
  }

  /// Vista previa e impresión del contrato
  static Future<void> verContrato({
    required BuildContext context,
    required Map<String, dynamic> aval,
    required Map<String, dynamic> prestamo,
    required Map<String, dynamic> cliente,
    Map<String, dynamic>? empresa,
  }) async {
    // Obtener datos de empresa si no se proporcionan
    final empresaData = empresa ?? await _obtenerDatosEmpresa();
    
    final pdfBytes = await generarContratoAval(
      aval: aval,
      prestamo: prestamo,
      cliente: cliente,
      empresa: empresaData,
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdfBytes,
      name: 'Contrato_Aval_${aval['nombre'] ?? 'N-A'}.pdf',
    );
  }

  /// Guarda el contrato en Supabase Storage y registra en BD
  static Future<String?> guardarContratoFirmado({
    required Uint8List pdfBytes,
    required String avalId,
    required String prestamoId,
    Uint8List? firmaBytes,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'contrato_aval_${avalId}_$timestamp.pdf';
      
      // Subir PDF
      await AppSupabase.client.storage
          .from('contratos')
          .uploadBinary(fileName, pdfBytes);
      
      final url = AppSupabase.client.storage.from('contratos').getPublicUrl(fileName);
      
      // Registrar en BD
      await AppSupabase.client.from('documentos_aval').insert({
        'aval_id': avalId,
        'prestamo_id': prestamoId,
        'tipo': 'contrato_garantia',
        'archivo_url': url,
        'firmado': firmaBytes != null,
        'fecha_firma': firmaBytes != null ? DateTime.now().toIso8601String() : null,
      });
      
      return url;
    } catch (e) {
      debugPrint('Error guardando contrato: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _obtenerDatosEmpresa() async {
    try {
      final res = await AppSupabase.client
          .from('configuracion_global')
          .select()
          .eq('clave', 'empresa_principal')
          .maybeSingle();
      
      if (res != null && res['valor'] != null) {
        return Map<String, dynamic>.from(res['valor']);
      }
    } catch (e) {
      debugPrint('Error obteniendo datos empresa: $e');
    }
    
    return {
      'nombre': 'ROBERT DARIN FINTECH',
      'rfc': 'RDF000000XXX',
      'ciudad': 'Ciudad de México',
    };
  }
}
