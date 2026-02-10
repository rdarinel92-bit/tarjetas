// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE PEDIDOS VENTAS - Robert Darin Platform v10.18
/// CRUD completo: Crear, listar, editar pedidos y estado de entrega
/// ═══════════════════════════════════════════════════════════════════════════════
class VentasPedidosScreen extends StatefulWidget {
  final bool abrirNuevo;

  const VentasPedidosScreen({super.key, this.abrirNuevo = false});

  @override
  State<VentasPedidosScreen> createState() => _VentasPedidosScreenState();
}

class _VentasPedidosScreenState extends State<VentasPedidosScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  bool _isLoading = true;
  bool _accionInicialEjecutada = false;
  String _filtroEstado = 'todos';

  List<Map<String, dynamic>> _pedidos = [];
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _productos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final pedidosRes = await AppSupabase.client
          .from('ventas_pedidos')
          .select('*, ventas_clientes(nombre, telefono)')
          .order('created_at', ascending: false);
      _pedidos = List<Map<String, dynamic>>.from(pedidosRes);

      final clientesRes = await AppSupabase.client.from('ventas_clientes').select().eq('activo', true).order('nombre');
      _clientes = List<Map<String, dynamic>>.from(clientesRes);

      final productosRes = await AppSupabase.client.from('ventas_productos').select().eq('activo', true).order('nombre');
      _productos = List<Map<String, dynamic>>.from(productosRes);

      if (mounted) {
        setState(() => _isLoading = false);
        _ejecutarAccionInicial();
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _ejecutarAccionInicial();
      }
    }
  }

  void _ejecutarAccionInicial() {
    if (_accionInicialEjecutada || !widget.abrirNuevo) return;
    _accionInicialEjecutada = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mostrarNuevoPedido();
    });
  }

  List<Map<String, dynamic>> get _pedidosFiltrados {
    if (_filtroEstado == 'todos') return _pedidos;
    return _pedidos.where((p) => p['estado'] == _filtroEstado).toList();
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return const Color(0xFFF59E0B);
      case 'confirmado': return const Color(0xFF3B82F6);
      case 'en_camino': return const Color(0xFF8B5CF6);
      case 'entregado': return const Color(0xFF10B981);
      case 'cancelado': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'pendiente': return Icons.schedule;
      case 'confirmado': return Icons.check_circle;
      case 'en_camino': return Icons.local_shipping;
      case 'entregado': return Icons.done_all;
      case 'cancelado': return Icons.cancel;
      default: return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '📋 Pedidos Ventas',
      actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos)],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStats(),
                _buildFiltros(),
                Expanded(child: _buildLista()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarNuevoPedido(),
        backgroundColor: const Color(0xFF00D9FF),
        icon: const Icon(Icons.add_shopping_cart, color: Colors.black),
        label: const Text('Nuevo Pedido', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStats() {
    final pendientes = _pedidos.where((p) => p['estado'] == 'pendiente').length;
    final enCamino = _pedidos.where((p) => p['estado'] == 'en_camino').length;
    final hoy = _pedidos.where((p) {
      final fecha = DateTime.tryParse(p['created_at'] ?? '');
      return fecha != null && DateUtils.isSameDay(fecha, DateTime.now());
    }).length;
    final totalHoy = _pedidos.where((p) {
      final fecha = DateTime.tryParse(p['created_at'] ?? '');
      return fecha != null && DateUtils.isSameDay(fecha, DateTime.now());
    }).fold<double>(0, (sum, p) => sum + (p['total'] ?? 0).toDouble());

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard('Pendientes', pendientes.toString(), const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _buildStatCard('En Camino', enCamino.toString(), const Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          _buildStatCard('Hoy', hoy.toString(), const Color(0xFF00D9FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text('Venta Hoy', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                  Text(_currencyFormat.format(totalHoy), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChipFiltro('Todos', 'todos'),
            const SizedBox(width: 8),
            _buildChipFiltro('Pendientes', 'pendiente'),
            const SizedBox(width: 8),
            _buildChipFiltro('Confirmados', 'confirmado'),
            const SizedBox(width: 8),
            _buildChipFiltro('En Camino', 'en_camino'),
            const SizedBox(width: 8),
            _buildChipFiltro('Entregados', 'entregado'),
          ],
        ),
      ),
    );
  }

  Widget _buildChipFiltro(String label, String valor) {
    final seleccionado = _filtroEstado == valor;
    return FilterChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (v) => setState(() => _filtroEstado = valor),
      selectedColor: const Color(0xFF00D9FF),
      backgroundColor: const Color(0xFF1A1A2E),
      labelStyle: TextStyle(color: seleccionado ? Colors.black : Colors.white),
    );
  }

  Widget _buildLista() {
    if (_pedidosFiltrados.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Sin pedidos', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pedidosFiltrados.length,
        itemBuilder: (context, index) => _buildPedidoCard(_pedidosFiltrados[index]),
      ),
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final cliente = pedido['ventas_clientes'] ?? {};
    final estado = pedido['estado'] ?? 'pendiente';
    final total = (pedido['total'] ?? 0).toDouble();
    final fecha = DateTime.tryParse(pedido['created_at'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: _getEstadoColor(estado), width: 4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _getEstadoColor(estado).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: Icon(_getEstadoIcon(estado), color: _getEstadoColor(estado)),
        ),
        title: Row(
          children: [
            Expanded(child: Text(cliente['nombre'] ?? 'Cliente', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Text(_currencyFormat.format(total), style: TextStyle(color: _getEstadoColor(estado), fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📱 ${cliente['telefono'] ?? 'Sin teléfono'}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            if (fecha != null) Text('📅 ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _getEstadoColor(estado).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(estado.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: _getEstadoColor(estado), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        onTap: () => _mostrarDetallePedido(pedido),
      ),
    );
  }

  void _mostrarNuevoPedido() {
    String? clienteId;
    List<Map<String, dynamic>> lineas = [];
    final notasCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double calcularTotal() => lineas.fold<double>(0, (sum, l) => sum + ((l['precio'] ?? 0) * (l['cantidad'] ?? 1)));

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nuevo Pedido', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Seleccionar cliente
                  DropdownButtonFormField<String>(
                    value: clienteId,
                    dropdownColor: const Color(0xFF0D0D14),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Cliente'),
                    items: _clientes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['nombre'] ?? ''))).toList(),
                    onChanged: (v) => setModalState(() => clienteId = v),
                  ),
                  const SizedBox(height: 16),

                  // Productos agregados
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Productos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, color: Color(0xFF00D9FF)),
                        label: const Text('Agregar', style: TextStyle(color: Color(0xFF00D9FF))),
                        onPressed: () => _mostrarSelectorProducto(setModalState, lineas),
                      ),
                    ],
                  ),

                  if (lineas.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFF0D0D14), borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text('Agrega productos al pedido', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
                    )
                  else
                    ...lineas.asMap().entries.map((entry) {
                      final i = entry.key;
                      final linea = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF0D0D14), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(linea['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text('${linea['cantidad']} x ${_currencyFormat.format(linea['precio'])}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(_currencyFormat.format((linea['precio'] ?? 0) * (linea['cantidad'] ?? 1)), style: const TextStyle(color: Color(0xFF00D9FF), fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => setModalState(() => lineas.removeAt(i)),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 12),

                  // Total
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(_currencyFormat.format(calcularTotal()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(controller: notasCtrl, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Notas / Dirección de entrega')),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      if (clienteId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un cliente'), backgroundColor: Colors.orange));
                        return;
                      }
                      if (lineas.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto'), backgroundColor: Colors.orange));
                        return;
                      }

                      // Crear pedido
                      final pedidoRes = await AppSupabase.client.from('ventas_pedidos').insert({
                        'cliente_id': clienteId,
                        'total': calcularTotal(),
                        'estado': 'pendiente',
                        'notas': notasCtrl.text.trim(),
                      }).select().single();

                      // Crear líneas del pedido
                      for (var linea in lineas) {
                        await AppSupabase.client.from('ventas_pedido_lineas').insert({
                          'pedido_id': pedidoRes['id'],
                          'producto_id': linea['producto_id'],
                          'cantidad': linea['cantidad'],
                          'precio_unitario': linea['precio'],
                          'subtotal': (linea['precio'] ?? 0) * (linea['cantidad'] ?? 1),
                        });
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        _cargarDatos();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Pedido creado'), backgroundColor: Colors.green));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF), minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Crear Pedido', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _mostrarSelectorProducto(StateSetter setModalState, List<Map<String, dynamic>> lineas) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D14),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text('Seleccionar Producto', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _productos.length,
              itemBuilder: (context, index) {
                final producto = _productos[index];
                return ListTile(
                  leading: const Icon(Icons.shopping_bag, color: Color(0xFF00D9FF)),
                  title: Text(producto['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Stock: ${producto['stock'] ?? 0}', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  trailing: Text(_currencyFormat.format(producto['precio'] ?? 0), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  onTap: () {
                    lineas.add({
                      'producto_id': producto['id'],
                      'nombre': producto['nombre'],
                      'precio': producto['precio'] ?? 0,
                      'cantidad': 1,
                    });
                    setModalState(() {});
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetallePedido(Map<String, dynamic> pedido) {
    final cliente = pedido['ventas_clientes'] ?? {};
    final estado = pedido['estado'] ?? 'pendiente';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Detalle del Pedido', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _getEstadoColor(estado).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(estado.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: _getEstadoColor(estado), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetalleRow('Cliente', cliente['nombre'] ?? 'N/A'),
            _buildDetalleRow('Teléfono', cliente['telefono'] ?? 'N/A'),
            _buildDetalleRow('Total', _currencyFormat.format(pedido['total'] ?? 0)),
            _buildDetalleRow('Notas', pedido['notas'] ?? 'Sin notas'),
            const SizedBox(height: 20),

            // Acciones según estado
            if (estado == 'pendiente')
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () => _cambiarEstado(pedido['id'], 'confirmado'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)), child: const Text('Confirmar'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () => _cambiarEstado(pedido['id'], 'cancelado'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Cancelar'))),
                ],
              ),
            if (estado == 'confirmado')
              ElevatedButton(onPressed: () => _cambiarEstado(pedido['id'], 'en_camino'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), minimumSize: const Size(double.infinity, 50)), child: const Text('Marcar En Camino')),
            if (estado == 'en_camino')
              ElevatedButton(onPressed: () => _cambiarEstado(pedido['id'], 'entregado'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), minimumSize: const Size(double.infinity, 50)), child: const Text('Marcar Entregado')),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6)))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _cambiarEstado(String pedidoId, String nuevoEstado) async {
    await AppSupabase.client.from('ventas_pedidos').update({'estado': nuevoEstado}).eq('id', pedidoId);
    if (mounted) {
      Navigator.pop(context);
      _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estado actualizado a $nuevoEstado'), backgroundColor: Colors.green));
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: const Color(0xFF0D0D14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
