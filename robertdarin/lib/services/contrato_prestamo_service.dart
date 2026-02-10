// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE CONTRATOS LEGALES - UNIKO
// Generación de contratos PDF para préstamos
// V10.51 - Robert-Darin © 2026
// ═══════════════════════════════════════════════════════════════════════════════
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ContratoPrestamoService {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  static String _formatMoney(double amount) => _currencyFormat.format(amount);

  static String _numeroALetras(double numero) {
    final unidades = ['', 'UN', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE'];
    final decenas = ['', 'DIEZ', 'VEINTE', 'TREINTA', 'CUARENTA', 'CINCUENTA', 'SESENTA', 'SETENTA', 'OCHENTA', 'NOVENTA'];
    final especiales = {
      11: 'ONCE', 12: 'DOCE', 13: 'TRECE', 14: 'CATORCE', 15: 'QUINCE',
      16: 'DIECISÉIS', 17: 'DIECISIETE', 18: 'DIECIOCHO', 19: 'DIECINUEVE',
    };
    final centenas = ['', 'CIENTO', 'DOSCIENTOS', 'TRESCIENTOS', 'CUATROCIENTOS', 
                      'QUINIENTOS', 'SEISCIENTOS', 'SETECIENTOS', 'OCHOCIENTOS', 'NOVECIENTOS'];

    int entero = numero.truncate();
    int centavos = ((numero - entero) * 100).round();

    String convertirMenorMil(int n) {
      if (n == 0) return '';
      if (n == 100) return 'CIEN';
      if (n < 10) return unidades[n];
      if (n < 20 && especiales.containsKey(n)) return especiales[n]!;
      if (n < 100) {
        int d = n ~/ 10;
        int u = n % 10;
        if (n >= 21 && n <= 29) return 'VEINTI${unidades[u]}';
        return '${decenas[d]}${u > 0 ? ' Y ${unidades[u]}' : ''}';
      }
      int c = n ~/ 100;
      int resto = n % 100;
      return '${centenas[c]}${resto > 0 ? ' ${convertirMenorMil(resto)}' : ''}';
    }

    String resultado = '';
    
    if (entero >= 1000000) {
      int millones = entero ~/ 1000000;
      entero %= 1000000;
      resultado += millones == 1 ? 'UN MILLÓN ' : '${convertirMenorMil(millones)} MILLONES ';
    }
    
    if (entero >= 1000) {
      int miles = entero ~/ 1000;
      entero %= 1000;
      resultado += miles == 1 ? 'MIL ' : '${convertirMenorMil(miles)} MIL ';
    }
    
    if (entero > 0) {
      resultado += convertirMenorMil(entero);
    }
    
    if (resultado.isEmpty) resultado = 'CERO';
    
    return '$resultado PESOS ${centavos.toString().padLeft(2, '0')}/100 M.N.';
  }

  /// Genera y muestra contrato de préstamo en PDF
  static Future<void> generarContratoPrestamo({
    required String numeroContrato,
    required String nombreDeudor,
    required String direccionDeudor,
    required String telefonoDeudor,
    required String curpDeudor,
    required String nombreAcreedor,
    required String direccionAcreedor,
    required double montoCapital,
    required double tasaInteres,
    required int plazoMeses,
    required double pagoMensual,
    required DateTime fechaInicio,
    required DateTime fechaPrimerPago,
    String? nombreAval,
    String? direccionAval,
    String? telefonoAval,
    String? curpAval,
    String? garantias,
  }) async {
    final pdf = pw.Document();
    final fechaFormateada = DateFormat('d \'de\' MMMM \'de\' yyyy', 'es_MX').format(fechaInicio);
    final montoTotal = pagoMensual * plazoMeses;
    final interesTotal = montoTotal - montoCapital;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(numeroContrato, fechaInicio),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildTitulo(),
          pw.SizedBox(height: 20),
          _buildSeccion('DECLARACIONES', [
            'I. Declara el ACREEDOR:',
            '   a) Que es una persona física/moral con capacidad legal para celebrar el presente contrato.',
            '   b) Que cuenta con los recursos económicos suficientes para otorgar el préstamo.',
            '   c) Que su domicilio para efectos del presente contrato es: $nombreAcreedor - $direccionAcreedor',
            '',
            'II. Declara el DEUDOR:',
            '   a) Que es $nombreDeudor, persona física mayor de edad, con capacidad legal.',
            '   b) Que su CURP es: $curpDeudor',
            '   c) Que su domicilio es: $direccionDeudor',
            '   d) Que su teléfono de contacto es: $telefonoDeudor',
            '   e) Que requiere el préstamo para fines lícitos y reconoce la obligación de pago.',
          ]),
          pw.SizedBox(height: 15),
          _buildSeccion('CLÁUSULAS', [
            'PRIMERA. OBJETO DEL CONTRATO.',
            'El ACREEDOR otorga en calidad de préstamo al DEUDOR la cantidad de:',
          ]),
          _buildMontoDestacado(montoCapital),
          _buildTexto('(${_numeroALetras(montoCapital)})'),
          pw.SizedBox(height: 10),
          _buildSeccion('', [
            'SEGUNDA. PLAZO Y FORMA DE PAGO.',
            'El DEUDOR se compromete a pagar el préstamo en $plazoMeses mensualidades de ${_formatMoney(pagoMensual)} cada una, iniciando el pago el día ${DateFormat('d \'de\' MMMM \'de\' yyyy', 'es_MX').format(fechaPrimerPago)}.',
            '',
            'TERCERA. TASA DE INTERÉS.',
            'Se aplicará una tasa de interés del ${tasaInteres.toStringAsFixed(2)}% mensual sobre saldos insolutos.',
            'El monto total a pagar será de ${_formatMoney(montoTotal)}, desglosado en:',
            '   • Capital: ${_formatMoney(montoCapital)}',
            '   • Intereses: ${_formatMoney(interesTotal)}',
            '',
            'CUARTA. INTERESES MORATORIOS.',
            'En caso de mora, se aplicará un interés adicional del 5% mensual sobre el saldo vencido, sin perjuicio de las acciones legales correspondientes.',
            '',
            'QUINTA. LUGAR DE PAGO.',
            'Los pagos se realizarán en el domicilio del ACREEDOR o mediante transferencia bancaria a la cuenta que este designe.',
            '',
            'SEXTA. VENCIMIENTO ANTICIPADO.',
            'El ACREEDOR podrá dar por vencido anticipadamente el crédito y exigir el pago total en los siguientes casos:',
            '   a) Falta de pago de una o más mensualidades.',
            '   b) Falsedad en la información proporcionada.',
            '   c) Deterioro de la situación económica del DEUDOR.',
            '',
            'SÉPTIMA. GASTOS Y COSTOS.',
            'En caso de incumplimiento, el DEUDOR cubrirá todos los gastos judiciales, extrajudiciales y honorarios de abogados que se generen para hacer efectivo el cobro.',
          ]),
          if (nombreAval != null) ...[
            pw.SizedBox(height: 15),
            _buildSeccion('OCTAVA. GARANTÍA PERSONAL (AVAL)', [
              'El C. $nombreAval, con domicilio en $direccionAval, teléfono ${telefonoAval ?? "N/A"} y CURP ${curpAval ?? "N/A"}, se constituye como AVAL del DEUDOR, obligándose solidariamente al cumplimiento de todas las obligaciones derivadas del presente contrato.',
            ]),
          ],
          if (garantias != null && garantias.isNotEmpty) ...[
            pw.SizedBox(height: 15),
            _buildSeccion('NOVENA. GARANTÍAS ADICIONALES', [
              garantias,
            ]),
          ],
          pw.SizedBox(height: 15),
          _buildSeccion('DÉCIMA. JURISDICCIÓN', [
            'Para la interpretación y cumplimiento del presente contrato, las partes se someten expresamente a la jurisdicción de los tribunales competentes de Tabasco, México, renunciando a cualquier otro fuero que pudiera corresponderles.',
          ]),
          pw.SizedBox(height: 30),
          _buildTexto('Leído que fue el presente contrato y enteradas las partes de su contenido y alcance legal, lo firman de conformidad en la ciudad de Emiliano Zapata, Tabasco, a los $fechaFormateada.'),
          pw.SizedBox(height: 50),
          _buildFirmas(nombreDeudor, nombreAcreedor, nombreAval),
        ],
      ),
    );

    // Agregar tabla de amortización
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(numeroContrato, fechaInicio),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'TABLA DE AMORTIZACIÓN',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildTablaAmortizacion(montoCapital, tasaInteres, plazoMeses, pagoMensual, fechaPrimerPago),
        ],
      ),
    );

    // Mostrar/imprimir PDF
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Contrato_Prestamo_$numeroContrato.pdf',
    );
  }

  static pw.Widget _buildHeader(String numeroContrato, DateTime fecha) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('UNIKO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Multi System', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Contrato N° $numeroContrato', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('© 2026 Robert-Darin - Todos los derechos reservados', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _buildTitulo() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 15),
      child: pw.Center(
        child: pw.Text(
          'CONTRATO DE PRÉSTAMO PERSONAL',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  static pw.Widget _buildSeccion(String titulo, List<String> contenido) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (titulo.isNotEmpty) ...[
          pw.Text(titulo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
        ],
        ...contenido.map((linea) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(linea, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.justify),
        )),
      ],
    );
  }

  static pw.Widget _buildTexto(String texto) {
    return pw.Text(texto, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.justify);
  }

  static pw.Widget _buildMontoDestacado(double monto) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 10),
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(
        child: pw.Text(
          _formatMoney(monto),
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  static pw.Widget _buildFirmas(String deudor, String acreedor, String? aval) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildBloqueQueFirma('EL DEUDOR', deudor),
        _buildBloqueQueFirma('EL ACREEDOR', acreedor),
        if (aval != null) _buildBloqueQueFirma('EL AVAL', aval),
      ],
    );
  }

  static pw.Widget _buildBloqueQueFirma(String rol, String nombre) {
    return pw.Container(
      width: 150,
      child: pw.Column(
        children: [
          pw.Container(
            width: 120,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1)),
            ),
            height: 50,
          ),
          pw.SizedBox(height: 5),
          pw.Text(rol, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text(nombre, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _buildTablaAmortizacion(
    double capital,
    double tasaMensual,
    int plazo,
    double pagoMensual,
    DateTime fechaInicio,
  ) {
    List<List<String>> datos = [];
    double saldo = capital;
    double interesPagado = 0;
    double capitalPagado = 0;

    for (int i = 1; i <= plazo; i++) {
      final fechaPago = DateTime(fechaInicio.year, fechaInicio.month + (i - 1), fechaInicio.day);
      final interes = saldo * (tasaMensual / 100);
      final capitalPago = pagoMensual - interes;
      saldo -= capitalPago;
      if (saldo < 0) saldo = 0;
      
      interesPagado += interes;
      capitalPagado += capitalPago;

      datos.add([
        i.toString(),
        DateFormat('dd/MM/yyyy').format(fechaPago),
        _formatMoney(pagoMensual),
        _formatMoney(capitalPago),
        _formatMoney(interes),
        _formatMoney(saldo),
      ]);
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FixedColumnWidth(70),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
        5: const pw.FixedColumnWidth(80),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: ['#', 'Fecha', 'Pago', 'Capital', 'Interés', 'Saldo'].map((h) => 
            pw.Container(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
            ),
          ).toList(),
        ),
        ...datos.map((row) => pw.TableRow(
          children: row.map((cell) => 
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(cell, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
            ),
          ).toList(),
        )),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(_formatMoney(pagoMensual * plazo), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(_formatMoney(capitalPagado), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(_formatMoney(interesPagado), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(_formatMoney(0), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
          ],
        ),
      ],
    );
  }

  /// Genera pagaré asociado al contrato
  static Future<void> generarPagare({
    required String numeroPagare,
    required String nombreDeudor,
    required String direccionDeudor,
    required double monto,
    required DateTime fechaVencimiento,
    required String nombreBeneficiario,
    required String lugarPago,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 2),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('P A G A R É', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('N° $numeroPagare', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('BUENO POR: ${_formatMoney(monto)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),
              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 8),
                  children: [
                    const pw.TextSpan(text: 'Debo y pagaré incondicionalmente a la orden de '),
                    pw.TextSpan(text: nombreBeneficiario, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ', en '),
                    pw.TextSpan(text: lugarPago, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ', el día '),
                    pw.TextSpan(text: DateFormat('d \'de\' MMMM \'de\' yyyy', 'es_MX').format(fechaVencimiento), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ', la cantidad de '),
                    pw.TextSpan(text: _formatMoney(monto), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ' ('),
                    pw.TextSpan(text: _numeroALetras(monto)),
                    const pw.TextSpan(text: ').'),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                'Valor recibido a mi entera satisfacción. Este pagaré causará intereses moratorios del 5% mensual a partir de la fecha de su vencimiento y hasta su total liquidación. Se firma el presente pagaré en señal de conformidad.',
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 30),
              pw.Text('Suscriptor:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Nombre: $nombreDeudor', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Domicilio: $direccionDeudor', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 50),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: 200,
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                      height: 40,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('FIRMA DEL SUSCRIPTOR', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text(nombreDeudor, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('© 2026 Uniko - Robert-Darin', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Documento con validez legal', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Pagare_$numeroPagare.pdf',
    );
  }
}
