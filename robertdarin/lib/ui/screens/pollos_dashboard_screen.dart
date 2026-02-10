// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/pollos_models.dart';
import '../navigation/app_routes.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DASHBOARD POLLOS ASADOS
/// Panel principal para gestión de pedidos de pollos asados
/// ═══════════════════════════════════════════════════════════════════════════════
class PollosDashboardScreen extends StatefulWidget {
  const PollosDashboardScreen({super.key});

  @override
  State<PollosDashboardScreen> createState() => _PollosDashboardScreenState();
}

class _PollosDashboardScreenState extends State<PollosDashboardScreen> {
  bool _isLoading = true;
  List<PollosPedidoModel> _pedidosActivos = [];
  PollosConfigModel? _config;
  
  // Estadísticas del día
  int _pedidosHoy = 0;
  double _ventasHoy = 0;
  int _pendientes = 0;
  int _preparando = 0;
  int _listos = 0;
  int _enCamino = 0;

  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar configuración
      final configRes = await AppSupabase.client
          .from('pollos_config')
          .select()
          .maybeSingle();
      
      if (configRes != null) {
        _config = PollosConfigModel.fromMap(configRes);
      }

      // Cargar pedidos activos de hoy
      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
      
      final pedidosRes = await AppSupabase.client
          .from('pollos_pedidos')
          .select('*, pollos_pedido_detalle(*)')
          .gte('hora_pedido', inicioHoy.toIso8601String())
          .order('hora_pedido', ascending: false);

      final pedidos = (pedidosRes as List).map((e) => PollosPedidoModel.fromMap(e)).toList();
      
      if (mounted) {
        setState(() {
          _pedidosActivos = pedidos.where((p) => p.estaActivo).toList();
          _pedidosHoy = pedidos.length;
          _ventasHoy = pedidos.where((p) => p.estado != 'cancelado').fold(0.0, (sum, p) => sum + p.total);
          _pendientes = pedidos.where((p) => p.estado == 'pendiente').length;
          _preparando = pedidos.where((p) => p.estado == 'preparando' || p.estado == 'confirmado').length;
          _listos = pedidos.where((p) => p.estado == 'listo').length;
          _enCamino = pedidos.where((p) => p.estado == 'en_camino').length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🍗 Pollos Asados',
      subtitle: _config?.nombreNegocio ?? 'Panel de Control',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
          tooltip: 'Actualizar',
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.pollosConfig),
          tooltip: 'Configuración',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              color: const Color(0xFFFF6B00),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEstadisticasRapidas(),
                    const SizedBox(height: 20),
                    _buildAccionesRapidas(),
                    const SizedBox(height: 20),
                    _buildPedidosActivos(),
                    const SizedBox(height: 20),
                    _buildMenuRapido(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.pollosPedidos),
        backgroundColor: const Color(0xFFFF6B00),
        icon: const Icon(Icons.receipt_long, color: Colors.white),
        label: const Text('Ver Pedidos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEstadisticasRapidas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 Resumen del Día',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Pedidos', _pedidosHoy.toString(), const Color(0xFFFF6B00), Icons.receipt)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Ventas', _currencyFormat.format(_ventasHoy), const Color(0xFF10B981), Icons.attach_money)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMiniStat('⏳', 'Pendientes', _pendientes, const Color(0xFFFBBF24))),
            Expanded(child: _buildMiniStat('🍳', 'Preparando', _preparando, const Color(0xFF3B82F6))),
            Expanded(child: _buildMiniStat('🔔', 'Listos', _listos, const Color(0xFF10B981))),
            Expanded(child: _buildMiniStat('🚗', 'En camino', _enCamino, const Color(0xFF8B5CF6))),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚡ Acciones Rápidas',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAccionCard(
                Icons.add_shopping_cart,
                'Nuevo Pedido',
                const Color(0xFFFF6B00),
                () => _mostrarNuevoPedido(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAccionCard(
                Icons.restaurant_menu,
                'Menú',
                const Color(0xFF10B981),
                () => Navigator.pushNamed(context, AppRoutes.pollosMenu),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAccionCard(
                Icons.qr_code_2,
                'QR Pedidos',
                const Color(0xFF8B5CF6),
                () => _mostrarQR(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccionCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidosActivos() {
    if (_pedidosActivos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text('🍗', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'Sin pedidos activos',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              'Los nuevos pedidos aparecerán aquí',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📋 Pedidos Activos',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.pollosPedidos),
              child: const Text('Ver todos →', style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._pedidosActivos.take(5).map((p) => _buildPedidoCard(p)),
      ],
    );
  }

  Widget _buildPedidoCard(PollosPedidoModel pedido) {
    final colorEstado = _getColorEstado(pedido.estado);
    final hora = pedido.horaPedido != null 
        ? DateFormat('HH:mm').format(pedido.horaPedido!)
        : '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorEstado.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetallePedido(pedido),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Número y hora
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '#${pedido.numeroPedido ?? '---'}',
                        style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        hora,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pedido.clienteNombre,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            pedido.tipoEntregaDisplay,
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${pedido.items.length} items',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Total y estado
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(pedido.total),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pedido.estadoDisplay,
                        style: TextStyle(color: colorEstado, fontSize: 10, fontWeight: FontWeight.bold),
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

  Widget _buildMenuRapido() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔧 Gestión',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMenuChip(Icons.history, 'Historial', () => Navigator.pushNamed(context, AppRoutes.pollosHistorial)),
            _buildMenuChip(Icons.bar_chart, 'Reportes', () => Navigator.pushNamed(context, AppRoutes.pollosReportes)),
            _buildMenuChip(Icons.inventory_2, 'Inventario', () {}),
            _buildMenuChip(Icons.settings, 'Config', () => Navigator.pushNamed(context, AppRoutes.pollosConfig)),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFF6B00), size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente': return const Color(0xFFFBBF24);
      case 'confirmado': return const Color(0xFF3B82F6);
      case 'preparando': return const Color(0xFFFF6B00);
      case 'listo': return const Color(0xFF10B981);
      case 'en_camino': return const Color(0xFF8B5CF6);
      case 'entregado': return const Color(0xFF6B7280);
      case 'cancelado': return const Color(0xFFEF4444);
      default: return Colors.white54;
    }
  }

  void _mostrarNuevoPedido() {
    // TODO: Implementar formulario de nuevo pedido manual
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nuevo pedido manual - Próximamente')),
    );
  }

  void _mostrarQR() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔗 Link de Pedidos', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Comparte este link con tus clientes para que hagan pedidos:',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SelectableText(
                'https://rdarinel92-bit.github.io/pollos/',
                style: TextStyle(color: Color(0xFFFF6B00), fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDetallePedido(PollosPedidoModel pedido) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PedidoDetalleSheet(
        pedido: pedido,
        onEstadoCambiado: () {
          Navigator.pop(ctx);
          _cargarDatos();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET: Detalle del pedido
// ═══════════════════════════════════════════════════════════════════════════════
class _PedidoDetalleSheet extends StatelessWidget {
  final PollosPedidoModel pedido;
  final VoidCallback onEstadoCambiado;

  const _PedidoDetalleSheet({required this.pedido, required this.onEstadoCambiado});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#${pedido.numeroPedido ?? '---'}',
                    style: const TextStyle(
                      color: Color(0xFFFF6B00),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pedido.clienteNombre,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        pedido.clienteTelefono,
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                Text(
                  pedido.estadoDisplay,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          // Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('🍗 Productos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...pedido.items.map((item) => _buildItemRow(item, currencyFormat)),
                const SizedBox(height: 20),
                // Totales
                _buildTotalRow('Subtotal', currencyFormat.format(pedido.subtotal)),
                if (pedido.costoDelivery > 0)
                  _buildTotalRow('Delivery', currencyFormat.format(pedido.costoDelivery)),
                if (pedido.descuento > 0)
                  _buildTotalRow('Descuento', '-${currencyFormat.format(pedido.descuento)}', color: Colors.green),
                const Divider(color: Colors.white24),
                _buildTotalRow('TOTAL', currencyFormat.format(pedido.total), isBold: true),
                const SizedBox(height: 20),
                // Info adicional
                if (pedido.esDelivery && pedido.direccionEntrega != null) ...[
                  const Text('📍 Dirección', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(pedido.direccionEntrega!, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  const SizedBox(height: 16),
                ],
                if (pedido.notasCliente != null && pedido.notasCliente!.isNotEmpty) ...[
                  const Text('📝 Notas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(pedido.notasCliente!, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                ],
              ],
            ),
          ),
          // Acciones
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D14),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildAccionButton(
                    context,
                    _getSiguienteEstado(pedido.estado),
                    _getColorSiguienteEstado(pedido.estado),
                    () => _cambiarEstado(context, _getSiguienteEstadoValue(pedido.estado)),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _llamarCliente(pedido.clienteTelefono),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(PollosPedidoDetalleModel item, NumberFormat format) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${item.cantidad}',
                style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productoNombre, style: const TextStyle(color: Colors.white)),
                if (item.notas != null && item.notas!.isNotEmpty)
                  Text(item.notas!, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          Text(format.format(item.subtotal), style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(isBold ? 1 : 0.7),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? (isBold ? const Color(0xFFFF6B00) : Colors.white),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionButton(BuildContext context, String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  String _getSiguienteEstado(String actual) {
    switch (actual) {
      case 'pendiente': return '✅ Confirmar';
      case 'confirmado': return '🍳 Preparando';
      case 'preparando': return '🔔 Marcar Listo';
      case 'listo': return pedido.esDelivery ? '🚗 En Camino' : '✔️ Entregar';
      case 'en_camino': return '✔️ Entregado';
      default: return 'Actualizar';
    }
  }

  String _getSiguienteEstadoValue(String actual) {
    switch (actual) {
      case 'pendiente': return 'confirmado';
      case 'confirmado': return 'preparando';
      case 'preparando': return 'listo';
      case 'listo': return pedido.esDelivery ? 'en_camino' : 'entregado';
      case 'en_camino': return 'entregado';
      default: return actual;
    }
  }

  Color _getColorSiguienteEstado(String actual) {
    switch (actual) {
      case 'pendiente': return const Color(0xFF3B82F6);
      case 'confirmado': return const Color(0xFFFF6B00);
      case 'preparando': return const Color(0xFF10B981);
      case 'listo': return pedido.esDelivery ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
      case 'en_camino': return const Color(0xFF10B981);
      default: return const Color(0xFF6B7280);
    }
  }

  Future<void> _cambiarEstado(BuildContext context, String nuevoEstado) async {
    try {
      final updates = <String, dynamic>{'estado': nuevoEstado};
      
      if (nuevoEstado == 'confirmado') {
        updates['hora_confirmacion'] = DateTime.now().toIso8601String();
        updates['tiempo_estimado_min'] = 20; // TODO: Hacer configurable
      } else if (nuevoEstado == 'listo') {
        updates['hora_listo'] = DateTime.now().toIso8601String();
      } else if (nuevoEstado == 'entregado') {
        updates['hora_entrega'] = DateTime.now().toIso8601String();
      }

      await AppSupabase.client
          .from('pollos_pedidos')
          .update(updates)
          .eq('id', pedido.id);

      onEstadoCambiado();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _llamarCliente(String telefono) {
    // TODO: Implementar llamada
  }
}
