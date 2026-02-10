// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE CONTRATO DE PRÉSTAMO - UNIKO
// Visualización y generación de contratos legales PDF
// V10.51 - Robert-Darin © 2026
// ═══════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../services/contrato_prestamo_service.dart';

class ContratoPrestamoPantallaScreen extends StatefulWidget {
  final Map<String, dynamic>? prestamo;
  final Map<String, dynamic>? cliente;
  final Map<String, dynamic>? aval;
  
  const ContratoPrestamoPantallaScreen({
    super.key,
    this.prestamo,
    this.cliente,
    this.aval,
  });

  @override
  State<ContratoPrestamoPantallaScreen> createState() => _ContratoPrestamoPantallaScreenState();
}

class _ContratoPrestamoPantallaScreenState extends State<ContratoPrestamoPantallaScreen> {
  bool _generandoContrato = false;
  bool _generandoPagare = false;
  
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  String get _formatMoney => _currencyFormat.format(widget.prestamo?['monto_capital'] ?? 0);
  String get _formatPago => _currencyFormat.format(widget.prestamo?['pago_mensual'] ?? 0);
  
  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Contrato de Préstamo',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildInfoContrato(),
            const SizedBox(height: 20),
            _buildInfoDeudor(),
            const SizedBox(height: 20),
            if (widget.aval != null) _buildInfoAval(),
            const SizedBox(height: 24),
            _buildResumenFinanciero(),
            const SizedBox(height: 30),
            _buildBotones(),
            const SizedBox(height: 20),
            _buildNotaLegal(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.1),
            const Color(0xFF8B5CF6).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.description, color: Color(0xFF00D9FF), size: 48),
          const SizedBox(height: 12),
          const Text(
            'CONTRATO DE PRÉSTAMO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contrato N° ${widget.prestamo?['numero_contrato'] ?? 'N/A'}',
            style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoContrato() {
    return _buildSeccion(
      'Información del Contrato',
      Icons.article,
      const Color(0xFF00D9FF),
      [
        _buildInfoRow('Número de Contrato', widget.prestamo?['numero_contrato'] ?? 'N/A'),
        _buildInfoRow('Fecha de Emisión', _formatFecha(widget.prestamo?['fecha_desembolso'])),
        _buildInfoRow('Fecha Primer Pago', _formatFecha(widget.prestamo?['fecha_inicio'])),
        _buildInfoRow('Plazo', '${widget.prestamo?['plazo_meses'] ?? 0} meses'),
        _buildInfoRow('Estado', widget.prestamo?['estado'] ?? 'activo'),
      ],
    );
  }

  Widget _buildInfoDeudor() {
    return _buildSeccion(
      'Información del Deudor',
      Icons.person,
      const Color(0xFF8B5CF6),
      [
        _buildInfoRow('Nombre Completo', widget.cliente?['nombre_completo'] ?? 'N/A'),
        _buildInfoRow('Teléfono', widget.cliente?['telefono'] ?? 'N/A'),
        _buildInfoRow('Dirección', widget.cliente?['direccion'] ?? 'N/A'),
        _buildInfoRow('CURP', widget.cliente?['curp'] ?? 'No registrado'),
      ],
    );
  }

  Widget _buildInfoAval() {
    return _buildSeccion(
      'Información del Aval',
      Icons.verified_user,
      const Color(0xFF10B981),
      [
        _buildInfoRow('Nombre del Aval', widget.aval?['nombre_completo'] ?? 'N/A'),
        _buildInfoRow('Teléfono', widget.aval?['telefono'] ?? 'N/A'),
        _buildInfoRow('Dirección', widget.aval?['direccion'] ?? 'N/A'),
        _buildInfoRow('CURP', widget.aval?['curp'] ?? 'No registrado'),
      ],
    );
  }

  Widget _buildResumenFinanciero() {
    final monto = (widget.prestamo?['monto_capital'] ?? 0).toDouble();
    final tasa = (widget.prestamo?['tasa_interes'] ?? 0).toDouble();
    final plazo = widget.prestamo?['plazo_meses'] ?? 1;
    final pagoMensual = (widget.prestamo?['pago_mensual'] ?? 0).toDouble();
    final montoTotal = pagoMensual * plazo;
    final interesTotal = montoTotal - monto;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFBBF24).withOpacity(0.1),
            const Color(0xFFF97316).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.attach_money, color: Color(0xFFFBBF24), size: 24),
              SizedBox(width: 8),
              Text(
                'RESUMEN FINANCIERO',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFinancieroRow('Capital Prestado', _currencyFormat.format(monto), true),
          _buildFinancieroRow('Tasa de Interés', '${tasa.toStringAsFixed(2)}% mensual', false),
          _buildFinancieroRow('Plazo', '$plazo meses', false),
          _buildFinancieroRow('Pago Mensual', _currencyFormat.format(pagoMensual), false),
          const Divider(color: Colors.white24, height: 24),
          _buildFinancieroRow('Total de Intereses', _currencyFormat.format(interesTotal), false),
          _buildFinancieroRow('MONTO TOTAL A PAGAR', _currencyFormat.format(montoTotal), true),
        ],
      ),
    );
  }

  Widget _buildFinancieroRow(String label, String value, bool destacado) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: destacado ? Colors.white : Colors.white70,
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: destacado ? const Color(0xFFFBBF24) : Colors.white,
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
              fontSize: destacado ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotones() {
    return Column(
      children: [
        // Botón Generar Contrato PDF
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generandoContrato ? null : _generarContratoPDF,
            icon: _generandoContrato 
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(_generandoContrato ? 'Generando...' : 'GENERAR CONTRATO PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Botón Generar Pagaré
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _generandoPagare ? null : _generarPagarePDF,
            icon: _generandoPagare 
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long),
            label: Text(_generandoPagare ? 'Generando...' : 'GENERAR PAGARÉ'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotaLegal() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5), size: 18),
              const SizedBox(width: 8),
              Text(
                'AVISO LEGAL',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Este contrato tiene validez legal conforme a las leyes mexicanas. '
            'La firma del contrato implica aceptación de todas las cláusulas y '
            'condiciones establecidas. Las partes se someten a los tribunales '
            'competentes de Tabasco, México para cualquier controversia.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© 2026 Robert-Darin • Todos los derechos reservados',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion(String titulo, IconData icono, Color color, List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                titulo.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return 'N/A';
    try {
      final dt = DateTime.parse(fecha.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (e) {
      return fecha.toString();
    }
  }

  Future<void> _generarContratoPDF() async {
    setState(() => _generandoContrato = true);
    
    try {
      await ContratoPrestamoService.generarContratoPrestamo(
        numeroContrato: widget.prestamo?['numero_contrato'] ?? 'CONT-${DateTime.now().millisecondsSinceEpoch}',
        nombreDeudor: widget.cliente?['nombre_completo'] ?? 'Nombre no disponible',
        direccionDeudor: widget.cliente?['direccion'] ?? 'Dirección no disponible',
        telefonoDeudor: widget.cliente?['telefono'] ?? '',
        curpDeudor: widget.cliente?['curp'] ?? '',
        nombreAcreedor: 'Uniko Multi System',
        direccionAcreedor: 'Emiliano Zapata, Tabasco, México',
        montoCapital: (widget.prestamo?['monto_capital'] ?? 0).toDouble(),
        tasaInteres: (widget.prestamo?['tasa_interes'] ?? 0).toDouble(),
        plazoMeses: widget.prestamo?['plazo_meses'] ?? 12,
        pagoMensual: (widget.prestamo?['pago_mensual'] ?? 0).toDouble(),
        fechaInicio: DateTime.tryParse(widget.prestamo?['fecha_desembolso'] ?? '') ?? DateTime.now(),
        fechaPrimerPago: DateTime.tryParse(widget.prestamo?['fecha_inicio'] ?? '') ?? DateTime.now(),
        nombreAval: widget.aval?['nombre_completo'],
        direccionAval: widget.aval?['direccion'],
        telefonoAval: widget.aval?['telefono'],
        curpAval: widget.aval?['curp'],
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Contrato generado exitosamente'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoContrato = false);
    }
  }

  Future<void> _generarPagarePDF() async {
    setState(() => _generandoPagare = true);
    
    try {
      final montoTotal = (widget.prestamo?['pago_mensual'] ?? 0).toDouble() * 
                         (widget.prestamo?['plazo_meses'] ?? 1);
      
      await ContratoPrestamoService.generarPagare(
        numeroPagare: 'PAG-${widget.prestamo?['numero_contrato'] ?? DateTime.now().millisecondsSinceEpoch}',
        nombreDeudor: widget.cliente?['nombre_completo'] ?? 'Nombre no disponible',
        direccionDeudor: widget.cliente?['direccion'] ?? 'Dirección no disponible',
        monto: montoTotal,
        fechaVencimiento: DateTime.tryParse(widget.prestamo?['fecha_fin'] ?? '')?.add(const Duration(days: 30)) ?? DateTime.now().add(const Duration(days: 365)),
        nombreBeneficiario: 'Uniko Multi System',
        lugarPago: 'Emiliano Zapata, Tabasco, México',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pagaré generado exitosamente'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPagare = false);
    }
  }
}
