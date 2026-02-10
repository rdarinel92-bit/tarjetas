// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// PANTALLA PAGOS PENDIENTES QR - CLIENTE
/// Robert Darin Fintech V10.7
/// ═══════════════════════════════════════════════════════════════════════════════
/// Lista de pagos QR pendientes de confirmar por el cliente
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../components/premium_scaffold.dart';
import '../../../services/qr_cobros_service.dart';
import '../../../data/models/qr_cobro_model.dart';
import 'escanear_qr_cobro_screen.dart';

class PagosPendientesQrScreen extends StatefulWidget {
  final String clienteId;
  final String? clienteNombre;

  const PagosPendientesQrScreen({
    super.key,
    required this.clienteId,
    this.clienteNombre,
  });

  @override
  State<PagosPendientesQrScreen> createState() => _PagosPendientesQrScreenState();
}

class _PagosPendientesQrScreenState extends State<PagosPendientesQrScreen> {
  bool _isLoading = true;
  List<QrCobroModel> _pendientes = [];

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    setState(() => _isLoading = true);
    try {
      final pendientes = await QrCobrosService.obtenerPendientesCliente(widget.clienteId);
      if (mounted) {
        setState(() {
          _pendientes = pendientes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando pendientes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _irAEscanear() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => EscanearQrCobroScreen(
          clienteId: widget.clienteId,
          clienteNombre: widget.clienteNombre,
        ),
      ),
    );
    if (result == true) {
      _cargarPendientes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Mis Pagos Pendientes',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF)))
          : _buildContenido(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irAEscanear,
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text(
          'Escanear QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_pendientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF10B981),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Todo al día!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No tienes pagos pendientes de confirmar',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _irAEscanear,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear nuevo QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00D9FF),
                side: const BorderSide(color: Color(0xFF00D9FF)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarPendientes,
      color: const Color(0xFF00D9FF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendientes.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return _buildHeader();
          }
          return _buildPagoCard(_pendientes[i - 1]);
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFBBF24).withOpacity(0.2),
            const Color(0xFFF59E0B).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFFBBF24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tienes ${_pendientes.length} pago${_pendientes.length > 1 ? 's' : ''} esperando tu confirmación',
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagoCard(QrCobroModel pago) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalle(pago),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.pending,
                        color: Color(0xFFFBBF24),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pago.concepto,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            pago.tipoCobroDisplay,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${pago.monto.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM HH:mm').format(pago.createdAt),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (pago.cobradorNombre != null) ...[
                      Icon(Icons.person_outline, color: Colors.white38, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Cobrador: ${pago.cobradorNombre}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pago.cobradorConfirmo
                            ? const Color(0xFF10B981).withOpacity(0.2)
                            : const Color(0xFFFBBF24).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pago.cobradorConfirmo
                            ? 'Cobrador confirmó'
                            : 'Esperando cobrador',
                        style: TextStyle(
                          color: pago.cobradorConfirmo
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalle(QrCobroModel pago) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DetalleSheet(
        pago: pago,
        clienteId: widget.clienteId,
        onConfirmado: () {
          Navigator.pop(ctx);
          _cargarPendientes();
        },
      ),
    );
  }
}

class _DetalleSheet extends StatefulWidget {
  final QrCobroModel pago;
  final String clienteId;
  final VoidCallback onConfirmado;

  const _DetalleSheet({
    required this.pago,
    required this.clienteId,
    required this.onConfirmado,
  });

  @override
  State<_DetalleSheet> createState() => _DetalleSheetState();
}

class _DetalleSheetState extends State<_DetalleSheet> {
  bool _isLoading = false;

  Future<void> _confirmar() async {
    setState(() => _isLoading = true);
    try {
      final result = await QrCobrosService.confirmarCobroCliente(
        codigoQr: widget.pago.codigoQr,
        clienteId: widget.clienteId,
        latitud: 0,
        longitud: 0,
      );

      if (result['success'] == true) {
        widget.onConfirmado();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Pago confirmado exitosamente!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Error desconocido'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Confirmar este pago?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildFila('Concepto', widget.pago.concepto),
                _buildFila('Monto', '\$${widget.pago.monto.toStringAsFixed(2)}'),
                _buildFila('Código', widget.pago.codigoQr),
                if (widget.pago.cobradorNombre != null)
                  _buildFila('Cobrador', widget.pago.cobradorNombre!),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Color(0xFFFBBF24), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solo confirma si ya entregaste el dinero en efectivo',
                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirmar Pago',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Flexible(
            child: Text(
              valor,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
