// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PEDIDOS - MÓDULO NICE
// Robert Darin Platform v10.20
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../services/nice_service.dart';
import '../../data/models/nice_models.dart';

class NicePedidosScreen extends StatefulWidget {
  final String negocioId;

  const NicePedidosScreen({super.key, required this.negocioId});

  @override
  State<NicePedidosScreen> createState() => _NicePedidosScreenState();
}

class _NicePedidosScreenState extends State<NicePedidosScreen> {
  bool _isLoading = true;
  List<NicePedido> _pedidos = [];
  List<NiceVendedora> _vendedoras = [];
  List<NiceCliente> _clientes = [];
  List<NiceProducto> _productos = [];
  String _filtroEstado = 'todos';

  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _formatDate = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      _pedidos = await NiceService.getPedidos(negocioId: widget.negocioId);
      _vendedoras = await NiceService.getVendedoras(negocioId: widget.negocioId, soloActivas: true);
      _clientes = await NiceService.getClientes(negocioId: widget.negocioId, soloActivos: true);
      _productos = await NiceService.getProductos(negocioId: widget.negocioId, soloDisponibles: true);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<NicePedido> get _pedidosFiltrados {
    if (_filtroEstado == 'todos') return _pedidos;
    return _pedidos.where((p) => p.estado == _filtroEstado).toList();
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'confirmado':
        return Colors.blue;
      case 'en_preparacion':
        return Colors.purple;
      case 'enviado':
        return Colors.cyan;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Icons.hourglass_empty;
      case 'confirmado':
        return Icons.check_circle;
      case 'en_preparacion':
        return Icons.inventory;
      case 'enviado':
        return Icons.local_shipping;
      case 'entregado':
        return Icons.done_all;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getTextoEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'confirmado':
        return 'Confirmado';
      case 'en_preparacion':
        return 'En Preparación';
      case 'enviado':
        return 'Enviado';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Pedidos',
      subtitle: '${_pedidos.length} pedidos',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_shopping_cart),
          onPressed: () => _mostrarNuevoPedido(),
          tooltip: 'Nuevo pedido',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : Column(
              children: [
                // Stats rápidas
                Container(
                  height: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildStatCard(
                        'Pendientes',
                        _pedidos.where((p) => p.estado == 'pendiente').length.toString(),
                        Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'En Proceso',
                        _pedidos.where((p) => ['confirmado', 'en_preparacion', 'enviado'].contains(p.estado)).length.toString(),
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Hoy',
                        _formatCurrency.format(
                          _pedidos
                              .where((p) => p.fechaPedido.day == DateTime.now().day && p.estado != 'cancelado')
                              .fold<double>(0, (sum, p) => sum + p.total)
                        ),
                        Colors.green,
                      ),
                    ],
                  ),
                ),
                // Filtros por estado
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFiltroChip('Todos', 'todos'),
                      _buildFiltroChip('Pendientes', 'pendiente'),
                      _buildFiltroChip('Confirmados', 'confirmado'),
                      _buildFiltroChip('En Preparación', 'en_preparacion'),
                      _buildFiltroChip('Enviados', 'enviado'),
                      _buildFiltroChip('Entregados', 'entregado'),
                      _buildFiltroChip('Cancelados', 'cancelado'),
                    ],
                  ),
                ),
                // Lista de pedidos
                Expanded(
                  child: _pedidosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_bag_outlined,
                                  size: 64, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No hay pedidos',
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pedidosFiltrados.length,
                          itemBuilder: (context, index) {
                            final pedido = _pedidosFiltrados[index];
                            return _buildPedidoCard(pedido);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String label, String estado) {
    final isSelected = _filtroEstado == estado;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) => setState(() => _filtroEstado = estado),
        selectedColor: Colors.pinkAccent,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 12,
        ),
        backgroundColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildPedidoCard(NicePedido pedido) {
    final colorEstado = _getColorEstado(pedido.estado);

    return GestureDetector(
      onTap: () => _mostrarDetallePedido(pedido),
      child: PremiumCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Icono estado
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconEstado(pedido.estado),
                      color: colorEstado,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              pedido.folioPedido,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorEstado.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getTextoEstado(pedido.estado),
                                style: TextStyle(
                                  color: colorEstado,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pedido.clienteNombre ?? 'Cliente no especificado',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Vendedora: ${pedido.vendedoraNombre ?? "N/A"}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fecha',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      Text(
                        _formatDate.format(pedido.fechaPedido),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Productos',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      Text(
                        '${pedido.items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      Text(
                        _formatCurrency.format(pedido.total),
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetallePedido(NicePedido pedido) {
    final colorEstado = _getColorEstado(pedido.estado);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_getIconEstado(pedido.estado), color: colorEstado, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pedido.folioPedido,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorEstado.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getTextoEstado(pedido.estado),
                            style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatCurrency.format(pedido.total),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Info cliente y vendedora
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      Icons.person,
                      'Cliente',
                      pedido.clienteNombre ?? 'No especificado',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      Icons.badge,
                      'Vendedora',
                      pedido.vendedoraNombre ?? 'N/A',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                Icons.calendar_today,
                'Fecha del pedido',
                _formatDate.format(pedido.fechaPedido),
              ),
              if (pedido.fechaEntrega != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildInfoCard(
                    Icons.event_available,
                    'Fecha de entrega',
                    _formatDate.format(pedido.fechaEntrega!),
                  ),
                ),
              const SizedBox(height: 24),
              // Items del pedido
              const Text(
                'Productos',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (pedido.items.isNotEmpty)
                ...pedido.items.map((item) => _buildItemCard(item))
              else
                const Text('Sin productos', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              // Totales
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildTotalRow('Subtotal', pedido.subtotal),
                    if (pedido.descuento > 0)
                      _buildTotalRow('Descuento', -pedido.descuento, isDiscount: true),
                    const Divider(color: Colors.white24),
                    _buildTotalRow('TOTAL', pedido.total, isTotal: true),
                    _buildTotalRow('Ganancia', pedido.gananciaVendedora, isGanancia: true),
                  ],
                ),
              ),
              if (pedido.notas != null && pedido.notas!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notas',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    pedido.notas!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Acciones de estado
              if (pedido.estado != 'entregado' && pedido.estado != 'cancelado')
                _buildAccionesEstado(pedido),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.pinkAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(NicePedidoItem item) {
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.diamond, color: Colors.pinkAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productoNombre,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${item.cantidad} x ${_formatCurrency.format(item.precioUnitario)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency.format(item.subtotal),
            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isDiscount = false, bool isTotal = false, bool isGanancia = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.white : Colors.white70,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            _formatCurrency.format(value),
            style: TextStyle(
              color: isDiscount
                  ? Colors.red
                  : isGanancia
                      ? Colors.purpleAccent
                      : isTotal
                          ? Colors.greenAccent
                          : Colors.white,
              fontWeight: isTotal || isGanancia ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesEstado(NicePedido pedido) {
    String? siguienteEstado;
    String? textoBoton;
    Color? colorBoton;

    switch (pedido.estado) {
      case 'pendiente':
        siguienteEstado = 'confirmado';
        textoBoton = 'Confirmar Pedido';
        colorBoton = Colors.blue;
        break;
      case 'confirmado':
        siguienteEstado = 'en_preparacion';
        textoBoton = 'Iniciar Preparación';
        colorBoton = Colors.purple;
        break;
      case 'en_preparacion':
        siguienteEstado = 'enviado';
        textoBoton = 'Marcar como Enviado';
        colorBoton = Colors.cyan;
        break;
      case 'enviado':
        siguienteEstado = 'entregado';
        textoBoton = 'Marcar como Entregado';
        colorBoton = Colors.green;
        break;
    }

    return Column(
      children: [
        if (siguienteEstado != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _cambiarEstado(pedido, siguienteEstado!),
              icon: Icon(_getIconEstado(siguienteEstado)),
              label: Text(textoBoton!),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorBoton,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _cambiarEstado(pedido, 'cancelado'),
            icon: const Icon(Icons.cancel, color: Colors.red),
            label: const Text('Cancelar Pedido', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _cambiarEstado(NicePedido pedido, String nuevoEstado) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Cambiar estado a "${_getTextoEstado(nuevoEstado)}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado == 'cancelado' ? Colors.red : Colors.pinkAccent,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await NiceService.actualizarPedido(pedido.id, {'estado': nuevoEstado});
      if (success && mounted) {
        Navigator.pop(context);
        _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido actualizado a ${_getTextoEstado(nuevoEstado)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _mostrarNuevoPedido() {
    String? vendedoraSeleccionada;
    String? clienteSeleccionado;
    final List<Map<String, dynamic>> itemsTemp = [];
    final notasController = TextEditingController();
    double descuento = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          double subtotal = itemsTemp.fold(0, (sum, item) => 
              sum + (item['cantidad'] as int) * (item['precio_unitario'] as double));
          double ganancia = itemsTemp.fold(0, (sum, item) =>
              sum + (item['cantidad'] as int) * (item['ganancia'] as double));
          double total = subtotal - descuento;

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.7,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nuevo Pedido',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Vendedora
                  DropdownButtonFormField<String>(
                    value: vendedoraSeleccionada,
                    decoration: InputDecoration(
                      labelText: 'Vendedora *',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.badge, color: Colors.pinkAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: const TextStyle(color: Colors.white),
                    items: _vendedoras.map((v) => DropdownMenuItem(
                      value: v.id,
                      child: Text('${v.nombre} (${v.codigoVendedora})'),
                    )).toList(),
                    onChanged: (v) => setSheetState(() {
                      vendedoraSeleccionada = v;
                      // Filtrar clientes de esta vendedora
                    }),
                  ),
                  const SizedBox(height: 12),
                  // Cliente
                  DropdownButtonFormField<String>(
                    value: clienteSeleccionado,
                    decoration: InputDecoration(
                      labelText: 'Cliente',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.person, color: Colors.pinkAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sin cliente')),
                      ..._clientes
                          .where((c) => vendedoraSeleccionada == null || c.vendedoraId == vendedoraSeleccionada)
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.nombre} ${c.apellidos ?? ""}'),
                              )),
                    ],
                    onChanged: (v) => setSheetState(() => clienteSeleccionado = v),
                  ),
                  const SizedBox(height: 20),
                  // Productos agregados
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Productos',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _agregarProductoDialog(context, setSheetState, itemsTemp),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (itemsTemp.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Agrega productos al pedido',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    )
                  else
                    ...itemsTemp.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['nombre'] as String,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    '${item['cantidad']} x ${_formatCurrency.format(item['precio_unitario'])}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatCurrency.format((item['cantidad'] as int) * (item['precio_unitario'] as double)),
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => setSheetState(() => itemsTemp.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  // Descuento
                  TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Descuento',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.discount, color: Colors.pinkAccent),
                      prefixText: '\$ ',
                      prefixStyle: const TextStyle(color: Colors.white),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setSheetState(() => descuento = double.tryParse(v) ?? 0),
                  ),
                  const SizedBox(height: 12),
                  // Notas
                  TextField(
                    controller: notasController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Notas',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.note, color: Colors.pinkAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Totales
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        _buildTotalRow('Subtotal', subtotal),
                        if (descuento > 0)
                          _buildTotalRow('Descuento', -descuento, isDiscount: true),
                        const Divider(color: Colors.white24),
                        _buildTotalRow('TOTAL', total, isTotal: true),
                        _buildTotalRow('Ganancia', ganancia, isGanancia: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: itemsTemp.isEmpty || vendedoraSeleccionada == null
                          ? null
                          : () async {
                              // Preparar items para el servicio
                              final itemsParaServicio = itemsTemp.map((item) => {
                                'producto_id': item['producto_id'],
                                'nombre_producto': item['nombre_producto'] ?? 'Producto',
                                'cantidad': item['cantidad'],
                                'precio_unitario': item['precio_unitario'],
                                'precio_vendedora': item['precio_base'] ?? item['precio_unitario'],
                                'ganancia': ((item['precio_unitario'] as double) - (item['precio_base'] as double? ?? 0)),
                              }).toList();

                              final result = await NiceService.crearPedido(
                                negocioId: widget.negocioId,
                                vendedoraId: vendedoraSeleccionada!,
                                clienteId: clienteSeleccionado,
                                items: itemsParaServicio,
                                notas: notasController.text.isEmpty ? null : notasController.text,
                              );

                              if (result != null && mounted) {
                                Navigator.pop(context);
                                _cargarDatos();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Pedido ${result.folio} creado'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Crear Pedido', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _agregarProductoDialog(
    BuildContext parentContext,
    StateSetter setSheetState,
    List<Map<String, dynamic>> itemsTemp,
  ) {
    String? productoSeleccionado;
    int cantidad = 1;

    showDialog(
      context: parentContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final producto = productoSeleccionado != null
              ? _productos.firstWhere((p) => p.id == productoSeleccionado)
              : null;

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('Agregar Producto', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: productoSeleccionado,
                  decoration: InputDecoration(
                    labelText: 'Producto',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  items: _productos
                      .where((p) => p.stockActual > 0)
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.nombre} - ${_formatCurrency.format(p.precioPublico)}'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => productoSeleccionado = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.pinkAccent),
                      onPressed: cantidad > 1
                          ? () => setDialogState(() => cantidad--)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        '$cantidad',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.pinkAccent),
                      onPressed: producto != null && cantidad < producto.stockActual
                          ? () => setDialogState(() => cantidad++)
                          : null,
                    ),
                  ],
                ),
                if (producto != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Stock disponible: ${producto.stockActual}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  Text(
                    'Subtotal: ${_formatCurrency.format(producto.precioPublico * cantidad)}',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: producto == null
                    ? null
                    : () {
                        itemsTemp.add({
                          'producto_id': producto.id,
                          'nombre': producto.nombre,
                          'cantidad': cantidad,
                          'precio_unitario': producto.precioPublico,
                          'precio_base': producto.precioBase,
                          'ganancia': producto.gananciaUnitaria,
                        });
                        Navigator.pop(context);
                        setSheetState(() {});
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
