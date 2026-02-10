// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// WIDGET BOTÓN COBRO QR - Robert Darin Fintech V10.7
/// ═══════════════════════════════════════════════════════════════════════════════
/// Widget reutilizable para agregar botón de cobro con QR en cualquier pantalla
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../screens/qr_cobros/generar_qr_cobro_screen.dart';
import '../screens/qr_cobros/escanear_qr_cobro_screen.dart';

/// Botón para que el COBRADOR genere QR después de recibir efectivo
class BotonGenerarQrCobro extends StatelessWidget {
  final String negocioId;
  final String cobradorId;
  final String clienteId;
  final String clienteNombre;
  final String tipoCobro;
  final String referenciaId;
  final String? referenciaTabla;
  final double monto;
  final String concepto;
  final VoidCallback? onCobroConfirmado;

  const BotonGenerarQrCobro({
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
    this.onCobroConfirmado,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (ctx) => GenerarQrCobroScreen(
              negocioId: negocioId,
              cobradorId: cobradorId,
              clienteId: clienteId,
              clienteNombre: clienteNombre,
              tipoCobro: tipoCobro,
              referenciaId: referenciaId,
              referenciaTabla: referenciaTabla,
              monto: monto,
              concepto: concepto,
            ),
          ),
        );
        if (result == true && onCobroConfirmado != null) {
          onCobroConfirmado!();
        }
      },
      icon: const Icon(Icons.qr_code, size: 20),
      label: const Text('Cobrar con QR'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00D9FF),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Botón para que el CLIENTE escanee QR y confirme pago
class BotonEscanearQrCobro extends StatelessWidget {
  final String clienteId;
  final String? clienteNombre;
  final VoidCallback? onPagoConfirmado;

  const BotonEscanearQrCobro({
    super.key,
    required this.clienteId,
    this.clienteNombre,
    this.onPagoConfirmado,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (ctx) => EscanearQrCobroScreen(
              clienteId: clienteId,
              clienteNombre: clienteNombre,
            ),
          ),
        );
        if (result == true && onPagoConfirmado != null) {
          onPagoConfirmado!();
        }
      },
      icon: const Icon(Icons.qr_code_scanner, size: 20),
      label: const Text('Escanear QR de pago'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Card informativo para mostrar opción de cobro QR
class CardCobroQrInfo extends StatelessWidget {
  final bool esCliente;
  final VoidCallback onTap;

  const CardCobroQrInfo({
    super.key,
    required this.esCliente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: esCliente
              ? [const Color(0xFF10B981).withOpacity(0.2), const Color(0xFF059669).withOpacity(0.2)]
              : [const Color(0xFF00D9FF).withOpacity(0.2), const Color(0xFF0284C7).withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esCliente
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFF00D9FF).withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: esCliente
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFF00D9FF).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    esCliente ? Icons.qr_code_scanner : Icons.qr_code,
                    color: esCliente
                        ? const Color(0xFF10B981)
                        : const Color(0xFF00D9FF),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esCliente
                            ? 'Confirmar Pago en Efectivo'
                            : 'Cobrar en Efectivo con QR',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        esCliente
                            ? 'Escanea el código QR del cobrador para confirmar tu pago'
                            : 'Genera un código QR para verificar el cobro en efectivo',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: esCliente
                      ? const Color(0xFF10B981)
                      : const Color(0xFF00D9FF),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// FAB para acceso rápido al escáner QR (para clientes)
class FabEscanearQr extends StatelessWidget {
  final String clienteId;
  final String? clienteNombre;
  final VoidCallback? onPagoConfirmado;

  const FabEscanearQr({
    super.key,
    required this.clienteId,
    this.clienteNombre,
    this.onPagoConfirmado,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (ctx) => EscanearQrCobroScreen(
              clienteId: clienteId,
              clienteNombre: clienteNombre,
            ),
          ),
        );
        if (result == true && onPagoConfirmado != null) {
          onPagoConfirmado!();
        }
      },
      backgroundColor: const Color(0xFF10B981),
      icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
      label: const Text(
        'Escanear QR',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Indicador de QR pendiente para notificaciones
class IndicadorQrPendiente extends StatelessWidget {
  final int cantidad;
  final VoidCallback onTap;

  const IndicadorQrPendiente({
    super.key,
    required this.cantidad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cantidad == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFBBF24).withOpacity(0.2),
              const Color(0xFFF59E0B).withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code,
                color: Color(0xFFFBBF24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tienes $cantidad pago${cantidad > 1 ? 's' : ''} pendiente${cantidad > 1 ? 's' : ''} de confirmar',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Toca para ver detalles',
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFFFBBF24),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
