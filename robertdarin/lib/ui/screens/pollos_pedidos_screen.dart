// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/pollos_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// PANTALLA DE PEDIDOS - POLLOS ASADOS
/// Lista y gestión de todos los pedidos
/// ═══════════════════════════════════════════════════════════════════════════════
class PollosPedidosScreen extends StatefulWidget {
  const PollosPedidosScreen({super.key});

  @override
  State<PollosPedidosScreen> createState() => _PollosPedidosScreenState();
}

class _PollosPedidosScreenState extends State<PollosPedidosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<PollosPedidoModel> _todosPedidos = [];
  String _filtroActual = 'activos';

  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0: _filtroActual = 'activos'; break;
            case 1: _filtroActual = 'pendientes'; break;
            case 2: _filtroActual = 'preparando'; break;
            case 3: _filtroActual = 'completados'; break;
          }
        });
      }
    });
    _cargarPedidos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<PollosPedidoModel> get _pedidosFiltrados {
    switch (_filtroActual) {
      case 'activos':
        return _todosPedidos.where((p) => p.estaActivo).toList();
      case 'pendientes':
        return _todosPedidos.where((p) => p.estado == 'pendiente').toList();
      case 'preparando':
        return _todosPedidos.where((p) => ['confirmado', 'preparando', 'listo', 'en_camino'].contains(p.estado)).toList();
      case 'completados':
        return _todosPedidos.where((p) => p.estado == 'entregado' || p.estado == 'cancelado').toList();
      default:
        return _todosPedidos;
    }
  }

  Future<void> _cargarPedidos() async {
    setState(() => _isLoading = true);
    try {
      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

      final res = await AppSupabase.client
          .from('pollos_pedidos')
          .select('*, pollos_pedido_detalle(*)')
          .gte('hora_pedido', inicioHoy.toIso8601String())
          .order('hora_pedido', ascending: false);

      if (mounted) {
        setState(() {
          _todosPedidos = (res as List).map((e) => PollosPedidoModel.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '📋 Pedidos',
      subtitle: 'Gestión de pedidos del día',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarPedidos,
        ),
      ],
      body: Column(
        children: [
          // Tabs
          Container(
            color: const Color(0xFF0D0D14),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF6B00),
              labelColor: const Color(0xFFFF6B00),
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: 'Activos (${_todosPedidos.where((p) => p.estaActivo).length})'),
                Tab(text: 'Nuevos (${_todosPedidos.where((p) => p.estado == 'pendiente').length})'),
                Tab(text: 'En Proceso'),
                Tab(text: 'Historial'),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : RefreshIndicator(
                    onRefresh: _cargarPedidos,
                    color: const Color(0xFFFF6B00),
                    child: _pedidosFiltrados.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pedidosFiltrados.length,
                            itemBuilder: (ctx, i) => _buildPedidoCard(_pedidosFiltrados[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🍗', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            _filtroActual == 'pendientes'
                ? 'Sin pedidos pendientes'
                : _filtroActual == 'completados'
                    ? 'Sin pedidos completados hoy'
                    : 'Sin pedidos en esta categoría',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Desliza hacia abajo para actualizar',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
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
        border: Border(
          left: BorderSide(color: colorEstado, width: 4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarAcciones(pedido),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${pedido.numeroPedido ?? '---'}',
                        style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hora,
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pedido.estadoDisplay,
                        style: TextStyle(color: colorEstado, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Cliente info
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pedido.clienteNombre,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      _currencyFormat.format(pedido.total),
                      style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Tipo entrega y items
                Row(
                  children: [
                    Icon(
                      pedido.esDelivery ? Icons.delivery_dining : Icons.store,
                      color: Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pedido.tipoEntregaDisplay,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${pedido.items.length} producto${pedido.items.length != 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                  ],
                ),
                // Items resumidos
                if (pedido.items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: pedido.items.take(3).map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.cantidad}x ${item.productoNombre}',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                  if (pedido.items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${pedido.items.length - 3} más...',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                      ),
                    ),
                ],
                // Acciones rápidas (solo para pedidos activos)
                if (pedido.estaActivo) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAccionRapida(
                          _getSiguienteAccion(pedido.estado),
                          colorEstado,
                          () => _cambiarEstado(pedido, _getSiguienteEstado(pedido)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildIconButton(Icons.phone, const Color(0xFF10B981), () => _llamar(pedido.clienteTelefono)),
                      const SizedBox(width: 8),
                      _buildIconButton(Icons.more_vert, Colors.white38, () => _mostrarAcciones(pedido)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccionRapida(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
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

  String _getSiguienteAccion(String estado) {
    switch (estado) {
      case 'pendiente': return '✅ Confirmar';
      case 'confirmado': return '🍳 Preparar';
      case 'preparando': return '🔔 Listo';
      case 'listo': return '✔️ Entregar';
      case 'en_camino': return '✔️ Entregado';
      default: return 'Actualizar';
    }
  }

  String _getSiguienteEstado(PollosPedidoModel pedido) {
    switch (pedido.estado) {
      case 'pendiente': return 'confirmado';
      case 'confirmado': return 'preparando';
      case 'preparando': return 'listo';
      case 'listo': return pedido.esDelivery ? 'en_camino' : 'entregado';
      case 'en_camino': return 'entregado';
      default: return pedido.estado;
    }
  }

  Future<void> _cambiarEstado(PollosPedidoModel pedido, String nuevoEstado) async {
    try {
      final updates = <String, dynamic>{'estado': nuevoEstado};

      if (nuevoEstado == 'confirmado') {
        updates['hora_confirmacion'] = DateTime.now().toIso8601String();
        updates['tiempo_estimado_min'] = 20;
      } else if (nuevoEstado == 'listo') {
        updates['hora_listo'] = DateTime.now().toIso8601String();
      } else if (nuevoEstado == 'entregado') {
        updates['hora_entrega'] = DateTime.now().toIso8601String();
      }

      await AppSupabase.client
          .from('pollos_pedidos')
          .update(updates)
          .eq('id', pedido.id);

      await _cargarPedidos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido #${pedido.numeroPedido} actualizado'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _llamar(String telefono) {
    // TODO: Implementar llamada
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Llamar a $telefono'), backgroundColor: Colors.blue),
    );
  }

  void _mostrarAcciones(PollosPedidoModel pedido) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(
              'Pedido #${pedido.numeroPedido}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildOpcion(Icons.visibility, 'Ver detalle', () {
              Navigator.pop(ctx);
              // TODO: Navegar a detalle
            }),
            _buildOpcion(Icons.edit, 'Editar pedido', () {
              Navigator.pop(ctx);
              // TODO: Editar
            }),
            _buildOpcion(Icons.print, 'Imprimir ticket', () {
              Navigator.pop(ctx);
              // TODO: Imprimir
            }),
            if (pedido.estaActivo)
              _buildOpcion(Icons.cancel, 'Cancelar pedido', () {
                Navigator.pop(ctx);
                _confirmarCancelacion(pedido);
              }, color: Colors.red),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOpcion(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(label, style: TextStyle(color: color ?? Colors.white)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _confirmarCancelacion(PollosPedidoModel pedido) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚠️ Cancelar Pedido', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de cancelar el pedido #${pedido.numeroPedido}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cambiarEstado(pedido, 'cancelado');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
