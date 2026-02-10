// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD VENDEDOR VENTAS - Panel para Vendedores de Catálogo
// Robert Darin Platform v10.22 - VERSIÓN MEJORADA CON FUNCIONALIDADES COMPLETAS
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class DashboardVendedorVentasScreen extends StatefulWidget {
  const DashboardVendedorVentasScreen({super.key});

  @override
  State<DashboardVendedorVentasScreen> createState() => _DashboardVendedorVentasScreenState();
}

class _DashboardVendedorVentasScreenState extends State<DashboardVendedorVentasScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _vendedor;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pedidosActivos = [];
  List<Map<String, dynamic>> _ultimosClientes = [];
  List<Map<String, dynamic>> _productosDisponibles = [];
  int _selectedNavIndex = 0;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  // ignore: unused_field
  final _formatDate = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _cargarDatos();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Buscar vendedor por auth_uid
      var vendedorRes = await AppSupabase.client
          .from('ventas_vendedores')
          .select('*')
          .eq('auth_uid', user.id)
          .eq('activo', true)
          .maybeSingle();

      if (vendedorRes == null) {
        // Buscar por email
        vendedorRes = await AppSupabase.client
            .from('ventas_vendedores')
            .select('*')
            .eq('email', user.email ?? '')
            .eq('activo', true)
            .maybeSingle();
        
        if (vendedorRes != null) {
          await AppSupabase.client
              .from('ventas_vendedores')
              .update({'auth_uid': user.id})
              .eq('id', vendedorRes['id']);
        }
      }

      _vendedor = vendedorRes;

      if (_vendedor != null) {
        await Future.wait([
          _cargarEstadisticas(),
          _cargarPedidosActivos(),
          _cargarUltimosClientes(),
          _cargarProductos(),
        ]);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error cargando datos vendedor: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarProductos() async {
    final res = await AppSupabase.client
        .from('ventas_productos')
        .select('*, categoria:ventas_categorias(nombre)')
        .eq('activo', true)
        .order('nombre')
        .limit(50);
    
    _productosDisponibles = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarEstadisticas() async {
    if (_vendedor == null) return;
    
    final vendedorId = _vendedor!['id'];
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final inicioSemana = now.subtract(Duration(days: now.weekday - 1));

    // Pedidos del mes
    final pedidosMes = await AppSupabase.client
        .from('ventas_pedidos')
        .select('id, total, estado')
        .eq('vendedor_id', vendedorId)
        .gte('created_at', inicioMes.toIso8601String());

    // Pedidos de la semana
    final pedidosSemana = await AppSupabase.client
        .from('ventas_pedidos')
        .select('id, total, estado')
        .eq('vendedor_id', vendedorId)
        .gte('created_at', inicioSemana.toIso8601String());

    double ventasMes = 0;
    double ventasSemana = 0;
    int pedidosCompletados = 0;
    
    for (var p in pedidosMes) {
      if (p['estado'] == 'entregado' || p['estado'] == 'completado') {
        ventasMes += (p['total'] ?? 0).toDouble();
        pedidosCompletados++;
      }
    }
    
    for (var p in pedidosSemana) {
      if (p['estado'] == 'entregado' || p['estado'] == 'completado') {
        ventasSemana += (p['total'] ?? 0).toDouble();
      }
    }

    final comision = (_vendedor!['comision'] ?? 10).toDouble();
    
    _stats = {
      'ventas_mes': ventasMes,
      'ventas_semana': ventasSemana,
      'comision_mes': ventasMes * (comision / 100),
      'pedidos_mes': pedidosMes.length,
      'pedidos_completados': pedidosCompletados,
      'clientes_activos': _ultimosClientes.length,
    };
  }

  Future<void> _cargarPedidosActivos() async {
    if (_vendedor == null) return;

    final res = await AppSupabase.client
        .from('ventas_pedidos')
        .select('''
          *,
          cliente:ventas_clientes(nombre, telefono)
        ''')
        .eq('vendedor_id', _vendedor!['id'])
        .inFilter('estado', ['pendiente', 'confirmado', 'preparando', 'enviado'])
        .order('created_at', ascending: false)
        .limit(10);

    _pedidosActivos = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarUltimosClientes() async {
    if (_vendedor == null) return;

    final res = await AppSupabase.client
        .from('ventas_clientes')
        .select('*')
        .eq('vendedor_id', _vendedor!['id'])
        .order('created_at', ascending: false)
        .limit(5);

    _ultimosClientes = List<Map<String, dynamic>>.from(res);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent),
        ),
      );
    }

    if (_vendedor == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'No se encontró tu perfil de vendedor',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Contacta al administrador',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _cargarDatos(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _cargarDatos,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: const Color(0xFF0D0D14),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  child: Text(
                                    _vendedor!['nombre']?[0]?.toUpperCase() ?? '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '¡Hola, ${_vendedor!['nombre']}!',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _vendedor!['codigo'] ?? 'Vendedor',
                                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Resumen
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildHeaderStat('Ventas Mes', _formatCurrency.format(_stats['ventas_mes'] ?? 0)),
                                  Container(width: 1, height: 30, color: Colors.white30),
                                  _buildHeaderStat('Comisión', _formatCurrency.format(_stats['comision_mes'] ?? 0)),
                                  Container(width: 1, height: 30, color: Colors.white30),
                                  _buildHeaderStat('Pedidos', '${_stats['pedidos_mes'] ?? 0}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.pushNamed(context, '/notificaciones'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => _cerrarSesion(),
                  ),
                ],
              ),
              // Contenido
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Acciones rápidas
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'Nuevo Pedido',
                              Icons.add_shopping_cart,
                              Colors.green,
                              () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              'Catálogo',
                              Icons.menu_book,
                              Colors.blue,
                              () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              'Clientes',
                              Icons.people,
                              Colors.orange,
                              () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Stats
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _buildStatCard(
                            '📦 Pedidos Activos',
                            '${_pedidosActivos.length}',
                            Colors.orange,
                          ),
                          _buildStatCard(
                            '✅ Completados',
                            '${_stats['pedidos_completados'] ?? 0}',
                            Colors.green,
                          ),
                          _buildStatCard(
                            '📈 Semana',
                            _formatCurrency.format(_stats['ventas_semana'] ?? 0),
                            Colors.blue,
                          ),
                          _buildStatCard(
                            '👥 Clientes',
                            '${_ultimosClientes.length}',
                            Colors.purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Pedidos activos
                      if (_pedidosActivos.isNotEmpty) ...[
                        const Text(
                          'Pedidos Activos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(
                          _pedidosActivos.length.clamp(0, 5),
                          (index) => _buildPedidoCard(_pedidosActivos[index]),
                        ),
                      ] else
                        _buildEmptyState('No tienes pedidos activos', Icons.shopping_cart_outlined),
                      const SizedBox(height: 24),
                      // Últimos clientes
                      if (_ultimosClientes.isNotEmpty) ...[
                        const Text(
                          'Tus Últimos Clientes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(
                          _ultimosClientes.length,
                          (index) => _buildClienteCard(_ultimosClientes[index]),
                        ),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white38, size: 24),
          const SizedBox(width: 12),
          Text(message, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final cliente = pedido['cliente'];
    final nombreCliente = cliente?['nombre'] ?? 'Sin nombre';
    final estado = pedido['estado'] ?? 'pendiente';
    final total = pedido['total'] ?? 0;

    Color estadoColor;
    switch (estado) {
      case 'pendiente':
        estadoColor = Colors.grey;
        break;
      case 'confirmado':
        estadoColor = Colors.blue;
        break;
      case 'preparando':
        estadoColor = Colors.orange;
        break;
      case 'enviado':
        estadoColor = Colors.purple;
        break;
      default:
        estadoColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shopping_bag, color: estadoColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombreCliente, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(estado.toUpperCase(), style: TextStyle(color: estadoColor, fontSize: 11)),
              ],
            ),
          ),
          Text(
            _formatCurrency.format(total),
            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> cliente) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.purple.withOpacity(0.2),
            child: Text(
              cliente['nombre']?[0]?.toUpperCase() ?? '?',
              style: const TextStyle(color: Colors.purple),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cliente['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                Text(cliente['telefono'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.greenAccent, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Inicio', _selectedNavIndex == 0, () => setState(() => _selectedNavIndex = 0)),
              _buildNavItem(Icons.add_shopping_cart, 'Nuevo', _selectedNavIndex == 1, _nuevoPedido),
              _buildNavItem(Icons.chat, 'Chat', _selectedNavIndex == 2, () => Navigator.pushNamed(context, '/chat')),
              _buildNavItem(Icons.people, 'Clientes', _selectedNavIndex == 3, _verClientes),
              _buildNavItem(Icons.person, 'Perfil', _selectedNavIndex == 4, _verPerfil),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? Colors.purpleAccent : Colors.white54, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? Colors.purpleAccent : Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  // ============ NUEVOS MÉTODOS FUNCIONALES ============

  void _nuevoPedido() {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    List<Map<String, dynamic>> carrito = [];
    double totalPedido = 0;
    String? clienteSeleccionadoId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void actualizarTotal() {
            totalPedido = carrito.fold(0.0, (sum, item) {
              return sum + ((item['precio'] ?? 0) * (item['cantidad'] ?? 1));
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.95,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D14),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade700, Colors.purple.shade900],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('Nuevo Pedido', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatCurrency.format(totalPedido),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Seleccionar cliente existente o nuevo
                        const Text('Cliente', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        
                        // Dropdown de clientes existentes
                        if (_ultimosClientes.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.purple.withOpacity(0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: clienteSeleccionadoId,
                                hint: const Text('Seleccionar cliente existente', style: TextStyle(color: Colors.white38)),
                                dropdownColor: const Color(0xFF1A1A2E),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(value: 'nuevo', child: Text('+ Nuevo cliente', style: TextStyle(color: Colors.greenAccent))),
                                  ..._ultimosClientes.map((c) => DropdownMenuItem(
                                    value: c['id']?.toString(),
                                    child: Text(c['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                                  )),
                                ],
                                onChanged: (val) {
                                  setModalState(() {
                                    clienteSeleccionadoId = val;
                                    if (val != null && val != 'nuevo') {
                                      final cliente = _ultimosClientes.firstWhere((c) => c['id']?.toString() == val, orElse: () => {});
                                      nombreCtrl.text = cliente['nombre'] ?? '';
                                      telefonoCtrl.text = cliente['telefono'] ?? '';
                                      direccionCtrl.text = cliente['direccion'] ?? '';
                                    } else {
                                      nombreCtrl.clear();
                                      telefonoCtrl.clear();
                                      direccionCtrl.clear();
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Campos del cliente
                        _buildInputField(nombreCtrl, 'Nombre del cliente', Icons.person),
                        const SizedBox(height: 12),
                        _buildInputField(telefonoCtrl, 'Teléfono', Icons.phone),
                        const SizedBox(height: 12),
                        _buildInputField(direccionCtrl, 'Dirección de entrega', Icons.location_on),
                        
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 12),
                        
                        // Productos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Productos', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              onPressed: () => _agregarProductoAlCarrito(carrito, setModalState, actualizarTotal),
                              icon: const Icon(Icons.add, color: Colors.purpleAccent, size: 18),
                              label: const Text('Agregar', style: TextStyle(color: Colors.purpleAccent)),
                            ),
                          ],
                        ),
                        
                        if (carrito.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12, style: BorderStyle.solid),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.shopping_basket_outlined, color: Colors.white24, size: 40),
                                SizedBox(height: 8),
                                Text('Sin productos', style: TextStyle(color: Colors.white38)),
                                Text('Agrega productos al pedido', style: TextStyle(color: Colors.white24, fontSize: 12)),
                              ],
                            ),
                          )
                        else
                          ...carrito.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                        Text('${item['cantidad']} x ${_formatCurrency.format(item['precio'])}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Text(_formatCurrency.format((item['precio'] ?? 0) * (item['cantidad'] ?? 1)), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        carrito.removeAt(idx);
                                        actualizarTotal();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        
                        const SizedBox(height: 16),
                        _buildInputField(notasCtrl, 'Notas del pedido (opcional)', Icons.note),
                        
                        const SizedBox(height: 24),
                        
                        // Resumen
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple.withOpacity(0.2), Colors.purple.withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Productos:', style: TextStyle(color: Colors.white70)),
                                  Text('${carrito.length} items', style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(_formatCurrency.format(totalPedido), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        ElevatedButton(
                          onPressed: carrito.isEmpty ? null : () async {
                            if (nombreCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ingresa el nombre del cliente'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            
                            try {
                              // Crear o usar cliente
                              String clienteId;
                              if (clienteSeleccionadoId != null && clienteSeleccionadoId != 'nuevo') {
                                clienteId = clienteSeleccionadoId!;
                              } else {
                                final nuevoCliente = await AppSupabase.client.from('ventas_clientes').insert({
                                  'nombre': nombreCtrl.text.trim(),
                                  'telefono': telefonoCtrl.text.trim(),
                                  'direccion': direccionCtrl.text.trim(),
                                  'vendedor_id': _vendedor?['id'],
                                }).select().single();
                                clienteId = nuevoCliente['id'];
                              }
                              
                              // Crear pedido
                              final pedido = await AppSupabase.client.from('ventas_pedidos').insert({
                                'cliente_id': clienteId,
                                'vendedor_id': _vendedor?['id'],
                                'total': totalPedido,
                                'estado': 'pendiente',
                                'notas': notasCtrl.text.trim(),
                                'direccion_entrega': direccionCtrl.text.trim(),
                              }).select().single();
                              
                              // Crear items
                              for (var item in carrito) {
                                await AppSupabase.client.from('ventas_pedidos_items').insert({
                                  'pedido_id': pedido['id'],
                                  'producto_id': item['producto_id'],
                                  'cantidad': item['cantidad'],
                                  'precio_unitario': item['precio'],
                                  'subtotal': (item['precio'] ?? 0) * (item['cantidad'] ?? 1),
                                });
                              }
                              
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Pedido creado exitosamente'), backgroundColor: Colors.green),
                                );
                                _cargarDatos();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            disabledBackgroundColor: Colors.grey.shade700,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Crear Pedido', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildInputField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.purple.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.purple.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.purpleAccent),
        ),
      ),
    );
  }

  void _agregarProductoAlCarrito(List<Map<String, dynamic>> carrito, StateSetter setModalState, VoidCallback actualizarTotal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Seleccionar Producto', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_productosDisponibles.isEmpty)
                const Center(child: Text('No hay productos disponibles', style: TextStyle(color: Colors.white54)))
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: _productosDisponibles.length,
                    itemBuilder: (context, idx) {
                      final prod = _productosDisponibles[idx];
                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2, color: Colors.purpleAccent, size: 20),
                        ),
                        title: Text(prod['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(prod['categoria']?['nombre'] ?? 'Sin categoría', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        trailing: Text(_formatCurrency.format(prod['precio'] ?? 0), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          _seleccionarCantidad(prod, carrito, setModalState, actualizarTotal);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _seleccionarCantidad(Map<String, dynamic> producto, List<Map<String, dynamic>> carrito, StateSetter setModalState, VoidCallback actualizarTotal) {
    int cantidad = 1;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(producto['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Precio: ${_formatCurrency.format(producto['precio'] ?? 0)}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: cantidad > 1 ? () => setDialogState(() => cantidad--) : null,
                    icon: const Icon(Icons.remove_circle, color: Colors.purpleAccent),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$cantidad', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => setDialogState(() => cantidad++),
                    icon: const Icon(Icons.add_circle, color: Colors.purpleAccent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Subtotal: ${_formatCurrency.format((producto['precio'] ?? 0) * cantidad)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setModalState(() {
                  carrito.add({
                    'producto_id': producto['id'],
                    'nombre': producto['nombre'],
                    'precio': producto['precio'],
                    'cantidad': cantidad,
                  });
                  actualizarTotal();
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('Agregar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Ver catálogo de productos - disponible para uso futuro
  // ignore: unused_element
  void _verCatalogo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.purple.shade900]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    const Text('Catálogo de Productos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Text('${_productosDisponibles.length} productos', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _productosDisponibles.isEmpty
                    ? const Center(child: Text('No hay productos', style: TextStyle(color: Colors.white54)))
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _productosDisponibles.length,
                        itemBuilder: (context, idx) {
                          final prod = _productosDisponibles[idx];
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  ),
                                  child: Center(
                                    child: prod['imagen_url'] != null
                                        ? Image.network(prod['imagen_url'], fit: BoxFit.cover)
                                        : const Icon(Icons.inventory_2, color: Colors.purpleAccent, size: 40),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(prod['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(prod['categoria']?['nombre'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                      const SizedBox(height: 6),
                                      Text(_formatCurrency.format(prod['precio'] ?? 0), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verClientes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.purple.shade900]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    const Text('Mis Clientes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        _agregarNuevoCliente();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _cargarTodosClientes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                    }
                    final clientes = snapshot.data ?? [];
                    if (clientes.isEmpty) {
                      return const Center(child: Text('No tienes clientes registrados', style: TextStyle(color: Colors.white54)));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: clientes.length,
                      itemBuilder: (context, idx) {
                        final cliente = clientes[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.purple.withOpacity(0.2),
                                child: Text(cliente['nombre']?[0]?.toUpperCase() ?? '?', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cliente['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                    if (cliente['telefono'] != null)
                                      Text(cliente['telefono'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    if (cliente['direccion'] != null)
                                      Text(cliente['direccion'], style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Text('${cliente['total_pedidos'] ?? 0}', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const Text('pedidos', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _cargarTodosClientes() async {
    try {
      final res = await AppSupabase.client
          .from('ventas_clientes')
          .select('*, total_pedidos:ventas_pedidos(count)')
          .eq('vendedor_id', _vendedor?['id'] ?? '')
          .order('nombre');
      return List<Map<String, dynamic>>.from(res.map((c) {
        c['total_pedidos'] = c['total_pedidos']?[0]?['count'] ?? 0;
        return c;
      }));
    } catch (e) {
      return [];
    }
  }

  void _agregarNuevoCliente() {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Nuevo Cliente', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInputField(nombreCtrl, 'Nombre completo', Icons.person),
              const SizedBox(height: 12),
              _buildInputField(telefonoCtrl, 'Teléfono', Icons.phone),
              const SizedBox(height: 12),
              _buildInputField(emailCtrl, 'Email (opcional)', Icons.email),
              const SizedBox(height: 12),
              _buildInputField(direccionCtrl, 'Dirección', Icons.location_on),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es requerido')));
                return;
              }
              try {
                await AppSupabase.client.from('ventas_clientes').insert({
                  'nombre': nombreCtrl.text.trim(),
                  'telefono': telefonoCtrl.text.trim(),
                  'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  'direccion': direccionCtrl.text.trim(),
                  'vendedor_id': _vendedor?['id'],
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Cliente agregado'), backgroundColor: Colors.green));
                  _cargarDatos();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _verPerfil() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 50, height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              
              // Avatar y nombre
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.purple.withOpacity(0.3),
                  child: Text(
                    _vendedor?['nombre']?[0]?.toUpperCase() ?? 'V',
                    style: const TextStyle(color: Colors.purpleAccent, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(_vendedor?['nombre'] ?? 'Vendedor', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
              Center(child: Text(_vendedor?['email'] ?? '', style: const TextStyle(color: Colors.white54))),
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_vendedor?['activo'] == true ? '● Activo' : '○ Inactivo', style: TextStyle(color: _vendedor?['activo'] == true ? Colors.greenAccent : Colors.white54, fontSize: 12)),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Estadísticas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('${_pedidosActivos.length}', 'Activos'),
                  Container(width: 1, height: 40, color: Colors.white12),
                  _buildStatColumn('${_ultimosClientes.length}', 'Clientes'),
                  Container(width: 1, height: 40, color: Colors.white12),
                  _buildStatColumn(_formatCurrency.format(_stats['ventas_mes'] ?? 0), 'Ventas Mes'),
                ],
              ),
              
              const SizedBox(height: 30),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),
              
              // Info detallada
              _buildPerfilItem(Icons.phone, 'Teléfono', _vendedor?['telefono'] ?? 'No registrado'),
              _buildPerfilItem(Icons.location_on, 'Zona', _vendedor?['zona'] ?? 'No asignada'),
              _buildPerfilItem(Icons.percent, 'Comisión', '${_vendedor?['comision_porcentaje'] ?? 0}%'),
              _buildPerfilItem(Icons.calendar_today, 'Desde', _vendedor?['created_at'] != null ? DateTime.parse(_vendedor!['created_at']).toString().split(' ')[0] : '-'),
              
              const SizedBox(height: 20),
              
              ElevatedButton.icon(
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.purpleAccent, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildPerfilItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.purpleAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ============ FIN NUEVOS MÉTODOS ============

  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
        content: const Text('¿Deseas cerrar tu sesión?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
