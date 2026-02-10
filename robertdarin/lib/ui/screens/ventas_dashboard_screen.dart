// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/ventas_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DASHBOARD MÓDULO VENTAS/CATÁLOGO - Robert Darin Platform
/// Gestión de productos, pedidos, inventario y apartados
/// ═══════════════════════════════════════════════════════════════════════════════
class VentasDashboardScreen extends StatefulWidget {
  const VentasDashboardScreen({super.key});
  @override
  State<VentasDashboardScreen> createState() => _VentasDashboardScreenState();
}

class _VentasDashboardScreenState extends State<VentasDashboardScreen> {
  bool _isLoading = true;
  int _clientesTotal = 0;
  int _productosTotal = 0;
  int _categoriasTotal = 0;
  int _pedidosHoy = 0;
  int _pedidosPendientes = 0;
  int _productosStockBajo = 0;
  double _ventasHoy = 0;
  double _ventasMes = 0;
  List<VentasPedidoModel> _pedidosRecientes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final clientesRes = await AppSupabase.client.from('ventas_clientes').select('id').eq('activo', true);
      final productosRes = await AppSupabase.client.from('ventas_productos').select('id, stock_actual, stock_minimo').eq('activo', true);
      final categoriasRes = await AppSupabase.client.from('ventas_categorias').select('id').eq('activo', true);
      
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final pedidosHoyRes = await AppSupabase.client
          .from('ventas_pedidos')
          .select('id, total')
          .gte('fecha_pedido', hoy);
      
      final pedidosPendientesRes = await AppSupabase.client
          .from('ventas_pedidos')
          .select('id')
          .inFilter('estado', ['pendiente', 'confirmado', 'preparando']);

      // Pedidos recientes
      final pedidosRes = await AppSupabase.client
          .from('ventas_pedidos')
          .select('*, ventas_clientes(nombre), ventas_vendedores(nombre)')
          .order('created_at', ascending: false)
          .limit(5);

      // Calcular stock bajo
      int stockBajo = 0;
      double ventasHoyTotal = 0;
      for (var p in (productosRes as List)) {
        if ((p['stock_actual'] ?? 0) <= (p['stock_minimo'] ?? 0)) stockBajo++;
      }
      for (var ped in (pedidosHoyRes as List)) {
        ventasHoyTotal += (ped['total'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _clientesTotal = (clientesRes as List).length;
          _productosTotal = (productosRes).length;
          _categoriasTotal = (categoriasRes as List).length;
          _pedidosHoy = (pedidosHoyRes).length;
          _pedidosPendientes = (pedidosPendientesRes as List).length;
          _productosStockBajo = stockBajo;
          _ventasHoy = ventasHoyTotal;
          _pedidosRecientes = (pedidosRes as List)
              .map((e) => VentasPedidoModel.fromMap(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos ventas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Módulo Ventas',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildResumenVentas(),
                    const SizedBox(height: 24),
                    _buildKPIs(),
                    const SizedBox(height: 24),
                    _buildAccionesRapidas(),
                    const SizedBox(height: 24),
                    _buildPedidosRecientes(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/ventas/pedidos/nuevo'),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
        label: const Text('Nueva Venta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ventas & Catálogo',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Productos, pedidos e inventario',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenVentas() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.today, color: Color(0xFF22C55E), size: 32),
                const SizedBox(height: 8),
                Text(
                  '\$${_ventasHoy.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF22C55E), fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text('Ventas Hoy', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white.withOpacity(0.1)),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.calendar_month, color: Color(0xFF00D9FF), size: 32),
                const SizedBox(height: 8),
                Text(
                  '\$${_ventasMes.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text('Ventas del Mes', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIs() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1,
      children: [
        _buildKPICard('Clientes', '$_clientesTotal', Icons.people, const Color(0xFF10B981)),
        _buildKPICard('Productos', '$_productosTotal', Icons.inventory_2, const Color(0xFF8B5CF6)),
        _buildKPICard('Categorías', '$_categoriasTotal', Icons.category, const Color(0xFFF59E0B)),
        _buildKPICard('Pedidos Hoy', '$_pedidosHoy', Icons.shopping_bag, const Color(0xFF00D9FF)),
        _buildKPICard('Pendientes', '$_pedidosPendientes', Icons.pending, const Color(0xFFEC4899)),
        _buildKPICard('Stock Bajo', '$_productosStockBajo', Icons.warning_amber, const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildKPICard(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(height: 8),
          Text(valor, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(titulo, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gestión', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildAccionBtn('Clientes', Icons.people, '/ventas/clientes', const Color(0xFF10B981))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Productos', Icons.inventory_2, '/ventas/productos', const Color(0xFF8B5CF6))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Categorías', Icons.category, '/ventas/categorias', const Color(0xFFF59E0B))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildAccionBtn('Pedidos', Icons.shopping_bag, '/ventas/pedidos', const Color(0xFF00D9FF))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Apartados', Icons.bookmark, '/ventas/apartados', const Color(0xFFEC4899))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Vendedores', Icons.badge, '/ventas/vendedores', const Color(0xFF22C55E))),
          ],
        ),
      ],
    );
  }

  Widget _buildAccionBtn(String titulo, IconData icono, String ruta, Color color) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, ruta),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(height: 8),
            Text(titulo, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidosRecientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Pedidos Recientes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/ventas/pedidos'),
              child: const Text('Ver todos', style: TextStyle(color: Color(0xFF8B5CF6))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pedidosRecientes.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('No hay pedidos registrados', style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          ...(_pedidosRecientes.map((pedido) => _buildPedidoCard(pedido))),
      ],
    );
  }

  Widget _buildPedidoCard(VentasPedidoModel pedido) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pedido.numeroPedido ?? '#${pedido.id.substring(0, 8)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  pedido.clienteNombre ?? 'Venta mostrador',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getColorEstado(pedido.estado).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pedido.estadoDisplay,
                  style: TextStyle(color: _getColorEstado(pedido.estado), fontSize: 11),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente': return const Color(0xFFFBBF24);
      case 'confirmado': return const Color(0xFF00D9FF);
      case 'preparando': return const Color(0xFF8B5CF6);
      case 'enviado': return const Color(0xFFEC4899);
      case 'entregado': return const Color(0xFF10B981);
      case 'cancelado': return const Color(0xFFEF4444);
      default: return Colors.white54;
    }
  }
}
