// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// WIDGET: Selector de Método de Pago
/// Robert Darin Fintech V10.6
/// ═══════════════════════════════════════════════════════════════════════════════
/// Widget reutilizable para seleccionar método de pago (Efectivo/Stripe)
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../data/models/stripe_config_model.dart';

class MetodoPagoSelector extends StatelessWidget {
  final MetodoPago metodoSeleccionado;
  final Function(MetodoPago) onMetodoChanged;
  final List<MetodoPago> metodosDisponibles;
  final bool clientePrefiereEfectivo;
  final bool compacto;

  const MetodoPagoSelector({
    super.key,
    required this.metodoSeleccionado,
    required this.onMetodoChanged,
    this.metodosDisponibles = const [
      MetodoPago.efectivo,
      MetodoPago.transferencia,
      MetodoPago.tarjetaStripe,
      MetodoPago.linkPago,
    ],
    this.clientePrefiereEfectivo = false,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compacto) {
      return _buildDropdownCompacto(context);
    }
    return _buildTarjetasExpandidas(context);
  }

  Widget _buildDropdownCompacto(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MetodoPago>(
          value: metodoSeleccionado,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A2E),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: metodosDisponibles.map((metodo) {
            return DropdownMenuItem<MetodoPago>(
              value: metodo,
              child: Row(
                children: [
                  Icon(
                    _getIconoMetodo(metodo),
                    color: _getColorMetodo(metodo),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(metodo.label),
                  if (clientePrefiereEfectivo && metodo == MetodoPago.efectivo) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Preferido',
                        style: TextStyle(fontSize: 10, color: Colors.green),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onMetodoChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildTarjetasExpandidas(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Método de Pago',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metodosDisponibles.map((metodo) {
            final isSelected = metodo == metodoSeleccionado;
            final colorMetodo = _getColorMetodo(metodo);
            
            return GestureDetector(
              onTap: () => onMetodoChanged(metodo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? colorMetodo.withOpacity(0.2) 
                      : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? colorMetodo : Colors.white12,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colorMetodo.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconoMetodo(metodo),
                      color: isSelected ? colorMetodo : Colors.white54,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metodo.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (clientePrefiereEfectivo && metodo == MetodoPago.efectivo)
                          const Text(
                            'Preferido por cliente',
                            style: TextStyle(fontSize: 10, color: Colors.green),
                          ),
                      ],
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, color: colorMetodo, size: 18),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getIconoMetodo(MetodoPago metodo) {
    switch (metodo) {
      case MetodoPago.efectivo:
        return Icons.payments_outlined;
      case MetodoPago.transferencia:
        return Icons.account_balance_outlined;
      case MetodoPago.tarjetaStripe:
        return Icons.credit_card;
      case MetodoPago.linkPago:
        return Icons.link;
      case MetodoPago.domiciliacion:
        return Icons.autorenew;
      case MetodoPago.oxxo:
        return Icons.store;
      case MetodoPago.spei:
        return Icons.swap_horiz;
    }
  }

  Color _getColorMetodo(MetodoPago metodo) {
    switch (metodo) {
      case MetodoPago.efectivo:
        return const Color(0xFF10B981); // Green
      case MetodoPago.transferencia:
        return const Color(0xFF3B82F6); // Blue
      case MetodoPago.tarjetaStripe:
        return const Color(0xFF6366F1); // Indigo (Stripe)
      case MetodoPago.linkPago:
        return const Color(0xFF8B5CF6); // Purple
      case MetodoPago.domiciliacion:
        return const Color(0xFFF59E0B); // Amber
      case MetodoPago.oxxo:
        return const Color(0xFFEF4444); // Red
      case MetodoPago.spei:
        return const Color(0xFF00D9FF); // Cyan
    }
  }
}

/// Widget para mostrar el método de pago en una fila de tabla/lista
class MetodoPagoBadge extends StatelessWidget {
  final String metodoPago;
  final bool mostrarIcono;

  const MetodoPagoBadge({
    super.key,
    required this.metodoPago,
    this.mostrarIcono = true,
  });

  @override
  Widget build(BuildContext context) {
    final metodo = MetodoPagoExtension.fromString(metodoPago);
    final color = _getColorBadge(metodo);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mostrarIcono) ...[
            Icon(_getIconoBadge(metodo), color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            metodo.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconoBadge(MetodoPago metodo) {
    switch (metodo) {
      case MetodoPago.efectivo:
        return Icons.payments_outlined;
      case MetodoPago.transferencia:
        return Icons.account_balance_outlined;
      case MetodoPago.tarjetaStripe:
        return Icons.credit_card;
      case MetodoPago.linkPago:
        return Icons.link;
      case MetodoPago.domiciliacion:
        return Icons.autorenew;
      case MetodoPago.oxxo:
        return Icons.store;
      case MetodoPago.spei:
        return Icons.swap_horiz;
    }
  }

  Color _getColorBadge(MetodoPago metodo) {
    switch (metodo) {
      case MetodoPago.efectivo:
        return const Color(0xFF10B981);
      case MetodoPago.transferencia:
        return const Color(0xFF3B82F6);
      case MetodoPago.tarjetaStripe:
        return const Color(0xFF6366F1);
      case MetodoPago.linkPago:
        return const Color(0xFF8B5CF6);
      case MetodoPago.domiciliacion:
        return const Color(0xFFF59E0B);
      case MetodoPago.oxxo:
        return const Color(0xFFEF4444);
      case MetodoPago.spei:
        return const Color(0xFF00D9FF);
    }
  }
}

/// Widget para resumen de pagos por método
class ResumenMetodosPagoCard extends StatelessWidget {
  final Map<String, double> resumen;
  final bool mostrarGrafico;

  const ResumenMetodosPagoCard({
    super.key,
    required this.resumen,
    this.mostrarGrafico = true,
  });

  @override
  Widget build(BuildContext context) {
    final total = resumen['total'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart, color: Color(0xFF00D9FF), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cobros por Método',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Lista de métodos
          ...['efectivo', 'transferencia', 'tarjeta_stripe', 'link_pago', 'domiciliacion']
              .where((m) => (resumen[m] ?? 0) > 0)
              .map((metodoClave) {
            final monto = resumen[metodoClave] ?? 0;
            final porcentaje = total > 0 ? (monto / total * 100) : 0;
            final metodo = MetodoPagoExtension.fromString(metodoClave);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getColorMetodo(metodo),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            metodo.label,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        '\$${_formatMonto(monto)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (mostrarGrafico)
                    LinearProgressIndicator(
                      value: porcentaje / 100,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(_getColorMetodo(metodo)),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                ],
              ),
            );
          }),
          
          const Divider(color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
              Text(
                '\$${_formatMonto(total)}',
                style: const TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorMetodo(MetodoPago metodo) {
    switch (metodo) {
      case MetodoPago.efectivo:
        return const Color(0xFF10B981);
      case MetodoPago.transferencia:
        return const Color(0xFF3B82F6);
      case MetodoPago.tarjetaStripe:
        return const Color(0xFF6366F1);
      case MetodoPago.linkPago:
        return const Color(0xFF8B5CF6);
      case MetodoPago.domiciliacion:
        return const Color(0xFFF59E0B);
      case MetodoPago.oxxo:
        return const Color(0xFFEF4444);
      case MetodoPago.spei:
        return const Color(0xFF00D9FF);
    }
  }

  String _formatMonto(double monto) {
    if (monto >= 1000000) {
      return '${(monto / 1000000).toStringAsFixed(1)}M';
    } else if (monto >= 1000) {
      return '${(monto / 1000).toStringAsFixed(1)}K';
    }
    return monto.toStringAsFixed(2);
  }
}
