// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// PANTALLA ESCANEAR QR - CLIENTE
/// Robert Darin Fintech V10.7
/// ═══════════════════════════════════════════════════════════════════════════════
/// Pantalla para que el cliente escanee y confirme el pago
/// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import '../../components/premium_scaffold.dart';
import '../../../services/qr_cobros_service.dart';
import '../../../data/models/qr_cobro_model.dart';

class EscanearQrCobroScreen extends StatefulWidget {
  final String clienteId;
  final String? clienteNombre;

  const EscanearQrCobroScreen({
    super.key,
    required this.clienteId,
    this.clienteNombre,
  });

  @override
  State<EscanearQrCobroScreen> createState() => _EscanearQrCobroScreenState();
}

class _EscanearQrCobroScreenState extends State<EscanearQrCobroScreen> {
  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  bool _flashOn = false;
  QrCobroModel? _qrEncontrado;
  String? _error;
  bool _showManualInput = false;
  final _codigoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _qrEncontrado != null) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _procesarQr(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _procesarQr(String qrData) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Pausar cámara mientras procesamos
      _scannerController?.stop();

      // Parsear datos del QR
      final datos = QrCobrosService.parsearDatosQr(qrData);
      if (datos == null) {
        setState(() => _error = 'Código QR no válido');
        _scannerController?.start();
        return;
      }

      final codigoQr = datos['code'] as String;
      
      // Buscar el QR en la base de datos
      final qr = await QrCobrosService.obtenerPorCodigo(codigoQr);
      
      if (qr == null) {
        setState(() => _error = 'QR no encontrado o ya expiró');
        _scannerController?.start();
        return;
      }

      // Verificar que es para este cliente
      if (qr.clienteId != widget.clienteId) {
        setState(() => _error = 'Este código no es para tu cuenta');
        _scannerController?.start();
        return;
      }

      setState(() => _qrEncontrado = qr);
    } catch (e) {
      setState(() => _error = 'Error al procesar: $e');
      _scannerController?.start();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _buscarPorCodigo() async {
    final codigo = _codigoController.text.trim().toUpperCase();
    if (codigo.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un código válido')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final qr = await QrCobrosService.obtenerPorCodigo(codigo);
      
      if (qr == null) {
        setState(() => _error = 'Código no encontrado');
        return;
      }

      if (qr.clienteId != widget.clienteId) {
        setState(() => _error = 'Este código no es para tu cuenta');
        return;
      }

      setState(() {
        _qrEncontrado = qr;
        _showManualInput = false;
      });
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmarPago() async {
    if (_qrEncontrado == null) return;

    setState(() => _isProcessing = true);

    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {}

      final resultado = await QrCobrosService.confirmarCobroCliente(
        codigoQr: _qrEncontrado!.codigoQr,
        clienteId: widget.clienteId,
        latitud: pos?.latitude ?? 0,
        longitud: pos?.longitude ?? 0,
        dispositivo: Platform.operatingSystem,
      );

      if (resultado['success'] == true) {
        if (mounted) {
          _mostrarExito(resultado['completado'] == true);
        }
      } else {
        setState(() => _error = resultado['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rechazarPago() async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogMotivo(),
    );

    if (motivo == null || motivo.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final success = await QrCobrosService.rechazarCobro(
        _qrEncontrado!.id,
        widget.clienteId,
        motivo,
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago rechazado. Se notificará al cobrador.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _mostrarExito(bool completado) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              completado ? '¡Pago Verificado!' : '¡Confirmación Registrada!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              completado
                  ? 'El pago ha sido verificado por ambas partes.'
                  : 'Tu confirmación fue registrada. El cobrador completará el proceso.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Confirmar Pago',
      body: _qrEncontrado != null
          ? _buildDetalleQr()
          : _showManualInput
              ? _buildInputManual()
              : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
              // Overlay con bordes
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF00D9FF), width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  onPressed: () async {
                    await _scannerController?.toggleTorch();
                    setState(() => _flashOn = !_flashOn);
                  },
                  icon: Icon(
                    _flashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            color: const Color(0xFF0D0D14),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Escanea el código QR que te muestra el cobrador',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _showManualInput = true),
                  icon: const Icon(Icons.keyboard, color: Color(0xFF00D9FF)),
                  label: const Text(
                    'Ingresar código manualmente',
                    style: TextStyle(color: Color(0xFF00D9FF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputManual() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.dialpad,
            color: Color(0xFF00D9FF),
            size: 64,
          ),
          const SizedBox(height: 20),
          const Text(
            'Ingresa el código del cobrador',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Puede ser el código QR (12 caracteres) o el código de verificación (6 dígitos)',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _codigoController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              letterSpacing: 4,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'ABC123XYZ456',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 20),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00D9FF), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _buscarPorCodigo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Buscar',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() {
              _showManualInput = false;
              _error = null;
              _scannerController?.start();
            }),
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white54),
            label: const Text(
              'Volver a escanear',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleQr() {
    final qr = _qrEncontrado!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Ícono y estado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Color(0xFF00D9FF),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Confirmas este pago?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Detalles del cobro
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _buildDetalleFila('Concepto', qr.concepto),
                const Divider(color: Colors.white12),
                _buildDetalleFila('Tipo', qr.tipoCobroDisplay),
                const Divider(color: Colors.white12),
                _buildDetalleFila('Cobrador', qr.cobradorNombre ?? 'N/A'),
                const Divider(color: Colors.white12),
                _buildDetalleFila(
                  'Monto',
                  '\$${qr.monto.toStringAsFixed(2)}',
                  destacar: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Advertencia
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFBBF24)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Confirma solo si ya entregaste el dinero en efectivo al cobrador.',
                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botones
          if (!qr.clienteConfirmo) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _confirmarPago,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Sí, confirmo el pago',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isProcessing ? null : _rechazarPago,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'No, rechazar',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 16),
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    'Ya confirmaste este pago',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _qrEncontrado = null;
              _error = null;
              _scannerController?.start();
            }),
            child: const Text(
              'Escanear otro código',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleFila(String label, String valor, {bool destacar = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54),
          ),
          Text(
            valor,
            style: TextStyle(
              color: destacar ? const Color(0xFF10B981) : Colors.white,
              fontWeight: destacar ? FontWeight.bold : FontWeight.normal,
              fontSize: destacar ? 20 : 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog para ingresar motivo de rechazo
class _DialogMotivo extends StatefulWidget {
  @override
  State<_DialogMotivo> createState() => _DialogMotivoState();
}

class _DialogMotivoState extends State<_DialogMotivo> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Motivo del rechazo',
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: _controller,
        style: const TextStyle(color: Colors.white),
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Explica por qué rechazas este cobro...',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
          ),
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}
