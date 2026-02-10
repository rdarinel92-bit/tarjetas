// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// PANTALLA GENERAR QR - COBRADOR
/// Robert Darin Fintech V10.7
/// ═══════════════════════════════════════════════════════════════════════════════
/// Pantalla para que el cobrador genere QR después de recibir efectivo
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../components/premium_scaffold.dart';
// ignore: unused_import
import '../../../core/supabase_client.dart';
import '../../../services/qr_cobros_service.dart';
import '../../../data/models/qr_cobro_model.dart';

class GenerarQrCobroScreen extends StatefulWidget {
  final String negocioId;
  final String cobradorId;
  final String clienteId;
  final String clienteNombre;
  final String tipoCobro;
  final String referenciaId;
  final String? referenciaTabla;
  final double monto;
  final String concepto;

  const GenerarQrCobroScreen({
    super.key,
    required this.negocioId,
    required this.cobradorId,
    required this.clienteId,
    required this.clienteNombre,
    required this.tipoCobro,
    required this.referenciaId,
    this.referenciaTabla,
    required this.monto,
    required this.concepto,
  });

  @override
  State<GenerarQrCobroScreen> createState() => _GenerarQrCobroScreenState();
}

class _GenerarQrCobroScreenState extends State<GenerarQrCobroScreen> {
  bool _isLoading = false;
  bool _isConfirming = false;
  QrCobroModel? _qrGenerado;
  Position? _ubicacion;
  String? _error;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      
      _ubicacion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');
    }
  }

  Future<void> _generarQr() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final qr = await QrCobrosService.crearQrCobro(
        negocioId: widget.negocioId,
        cobradorId: widget.cobradorId,
        clienteId: widget.clienteId,
        tipoCobro: widget.tipoCobro,
        referenciaId: widget.referenciaId,
        referenciaTabla: widget.referenciaTabla,
        monto: widget.monto,
        concepto: widget.concepto,
      );

      if (qr != null) {
        setState(() => _qrGenerado = qr);
      } else {
        setState(() => _error = 'Error al generar el código QR');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmarCobro() async {
    if (_qrGenerado == null) return;

    setState(() => _isConfirming = true);

    try {
      // Obtener ubicación actualizada
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {}

      final success = await QrCobrosService.confirmarCobroCobrador(
        qrCobroId: _qrGenerado!.id,
        latitud: pos?.latitude ?? 0,
        longitud: pos?.longitude ?? 0,
        direccion: 'Cobro en campo',
      );

      if (success && mounted) {
        // Recargar QR para ver estado
        final qr = await QrCobrosService.obtenerPorCodigo(_qrGenerado!.codigoQr);
        if (qr != null) {
          setState(() => _qrGenerado = qr);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cobro confirmado! Esperando confirmación del cliente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Generar QR de Cobro',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            if (_qrGenerado == null) _buildGenerarButton(),
            if (_qrGenerado != null) ...[
              _buildQrCard(),
              const SizedBox(height: 20),
              _buildCodigoVerificacion(),
              const SizedBox(height: 20),
              _buildEstadoCard(),
              const SizedBox(height: 20),
              if (!_qrGenerado!.cobradorConfirmo) _buildConfirmarButton(),
            ],
            if (_error != null) _buildErrorCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long, color: Color(0xFF00D9FF), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clienteNombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.concepto,
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Monto: ',
                  style: TextStyle(color: Colors.white60, fontSize: 18),
                ),
                Text(
                  '\$${widget.monto.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerarButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _generarQr,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D9FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code, color: Colors.black, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Generar Código QR',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildQrCard() {
    final qrData = QrCobrosService.generarDatosQr(_qrGenerado!);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D9FF).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Muestra este QR al cliente',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
            errorStateBuilder: (cxt, err) => const Center(
              child: Text('Error al generar QR'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _qrGenerado!.codigoQr,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 3,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodigoVerificacion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF8B5CF6).withOpacity(0.3), const Color(0xFF6D28D9).withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Text(
            'Código de Verificación',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _qrGenerado!.codigoVerificacion ?? '------',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 8,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white70),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _qrGenerado!.codigoVerificacion ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'El cliente puede usar este código si no puede escanear el QR',
            style: TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoCard() {
    final qr = _qrGenerado!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text(
            'Estado de Confirmación',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildConfirmacionItem(
                  'Cobrador',
                  qr.cobradorConfirmo,
                  Icons.person,
                ),
              ),
              Container(
                width: 2,
                height: 60,
                color: Colors.white12,
              ),
              Expanded(
                child: _buildConfirmacionItem(
                  'Cliente',
                  qr.clienteConfirmo,
                  Icons.person_outline,
                ),
              ),
            ],
          ),
          if (qr.ambosConfirmaron)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    '¡Pago verificado completamente!',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmacionItem(String label, bool confirmado, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: confirmado
                ? const Color(0xFF10B981).withOpacity(0.2)
                : Colors.white10,
            shape: BoxShape.circle,
          ),
          child: Icon(
            confirmado ? Icons.check : icon,
            color: confirmado ? const Color(0xFF10B981) : Colors.white54,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: confirmado ? const Color(0xFF10B981) : Colors.white54,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          confirmado ? 'Confirmado' : 'Pendiente',
          style: TextStyle(
            color: confirmado ? const Color(0xFF10B981) : Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmarButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isConfirming ? null : _confirmarCobro,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isConfirming
            ? const CircularProgressIndicator(color: Colors.white)
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Confirmar que recibí el efectivo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Color(0xFFEF4444)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }
}
