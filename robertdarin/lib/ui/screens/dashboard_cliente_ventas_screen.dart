// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD CLIENTE VENTAS - Portal para Clientes de Catálogo/Tienda
// Robert Darin Platform v10.22
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class DashboardClienteVentasScreen extends StatefulWidget {
  const DashboardClienteVentasScreen({super.key});

  @override
  State<DashboardClienteVentasScreen> createState() => _DashboardClienteVentasScreenState();
}

class _DashboardClienteVentasScreenState extends State<DashboardClienteVentasScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _pedidosActivos = [];
  List<Map<String, dynamic>> _historialPedidos = [];
  List<Map<String, dynamic>> _productosDestacados = [];
  List<Map<String, dynamic>> _categorias = [];
  Map<String, dynamic> _stats = {};
  int _selectedTab = 0;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _formatDate = DateFormat('dd/MM/yyyy');
  
  // Carrito temporal
  List<Map<String, dynamic>> _carrito = [];

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

      // Buscar cliente por auth_uid o email
      var clienteRes = await AppSupabase.client
          .from('ventas_clientes')
          .select('*')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (clienteRes == null) {
        clienteRes = await AppSupabase.client
            .from('ventas_clientes')
            .select('*')
            .eq('email', user.email ?? '')
            .maybeSingle();
        
        if (clienteRes != null) {
          // Vincular auth_uid
          await AppSupabase.client
              .from('ventas_clientes')
              .update({'auth_uid': user.id})
              .eq('id', clienteRes['id']);
        }
      }

      _cliente = clienteRes;

      if (_cliente != null) {
        await Future.wait([
          _cargarPedidosActivos(),
          _cargarHistorial(),
          _cargarProductosDestacados(),
          _cargarCategorias(),
          _cargarEstadisticas(),
        ]);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error cargando datos cliente ventas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPedidosActivos() async {
    if (_cliente == null) return;
    
    final res = await AppSupabase.client
        .from('ventas_pedidos')
        .select('''
          *,
          vendedor:ventas_vendedores(nombre, telefono)
        ''')
        .eq('cliente_id', _cliente!['id'])
        .inFilter('estado', ['pendiente', 'confirmado', 'preparando', 'enviado'])
        .order('created_at', ascending: false);
    
    _pedidosActivos = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarHistorial() async {
    if (_cliente == null) return;
    
    final res = await AppSupabase.client
        .from('ventas_pedidos')
        .select('*')
        .eq('cliente_id', _cliente!['id'])
        .inFilter('estado', ['entregado', 'completado'])
        .order('created_at', ascending: false)
        .limit(20);
    
    _historialPedidos = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarProductosDestacados() async {
    // Preparado para filtrar por negocio en futuras versiones
    // ignore: unused_local_variable
    final negocioId = _cliente?['negocio_id'];
    
    final res = await AppSupabase.client
        .from('ventas_productos')
        .select('*, categoria:ventas_categorias(nombre)')
        .eq('activo', true)
        .eq('destacado', true)
        .order('nombre')
        .limit(10);
    
    _productosDestacados = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarCategorias() async {
    final res = await AppSupabase.client
        .from('ventas_categorias')
        .select('*')
        .eq('activo', true)
        .order('orden');
    
    _categorias = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarEstadisticas() async {
    if (_cliente == null) return;
    
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);

    final pedidosMes = await AppSupabase.client
        .from('ventas_pedidos')
        .select('id, total, estado')
        .eq('cliente_id', _cliente!['id'])
        .gte('created_at', inicioMes.toIso8601String());

    double gastadoMes = 0;
    int pedidosCompletados = 0;
    for (var p in pedidosMes) {
      if (p['estado'] == 'entregado' || p['estado'] == 'completado') {
        gastadoMes += (p['total'] ?? 0).toDouble();
        pedidosCompletados++;
      }
    }

    _stats = {
      'pedidos_mes': pedidosMes.length,
      'pedidos_completados': pedidosCompletados,
      'gastado_mes': gastadoMes,
      'saldo_pendiente': _cliente!['saldo_pendiente'] ?? 0,
      'puntos': _cliente!['puntos'] ?? 0,
      'limite_credito': _cliente!['limite_credito'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.purpleAccent),
              const SizedBox(height: 16),
              Text(
                'Cargando tu tienda...',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    if (_cliente == null) {
      return _buildNoClienteView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _cargarDatos,
          child: CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                      _buildStatsCards(),
                      const SizedBox(height: 24),
                      if (_pedidosActivos.isNotEmpty) ...[
                        _buildSectionTitle('Mis Pedidos Activos', Icons.local_shipping),
                        const SizedBox(height: 12),
                        ..._pedidosActivos.map((p) => _buildPedidoCard(p)),
                        const SizedBox(height: 24),
                      ],
                      if (_productosDestacados.isNotEmpty) ...[
                        _buildSectionTitle('Productos Destacados', Icons.star),
                        const SizedBox(height: 12),
                        _buildProductosGrid(),
                        const SizedBox(height: 24),
                      ],
                      if (_categorias.isNotEmpty) ...[
                        _buildSectionTitle('Categorías', Icons.category),
                        const SizedBox(height: 12),
                        _buildCategoriasHorizontal(),
                        const SizedBox(height: 24),
                      ],
                      if (_historialPedidos.isNotEmpty) ...[
                        _buildSectionTitle('Historial de Compras', Icons.history),
                        const SizedBox(height: 12),
                        ..._historialPedidos.take(5).map((p) => _buildHistorialCard(p)),
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
      floatingActionButton: _carrito.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _verCarrito,
              backgroundColor: Colors.purpleAccent,
              icon: Badge(
                label: Text('${_carrito.length}'),
                child: const Icon(Icons.shopping_cart),
              ),
              label: Text(_formatCurrency.format(_calcularTotalCarrito())),
            )
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildNoClienteView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mi Tienda'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 80, color: Colors.purpleAccent),
              const SizedBox(height: 24),
              const Text(
                '¡Bienvenido!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Aún no tienes un perfil de cliente registrado.\nContacta al vendedor para registrarte y comenzar a comprar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _cargarDatos(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/chat'),
                    icon: const Icon(Icons.chat),
                    label: const Text('Contactar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purpleAccent,
                      side: const BorderSide(color: Colors.purpleAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 200,
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
                          _cliente!['nombre']?[0]?.toUpperCase() ?? '?',
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
                              '¡Hola, ${_cliente!['nombre']}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_stats['puntos'] ?? 0} puntos',
                                        style: const TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _cliente!['tipo'] ?? 'Cliente',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Resumen financiero
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeaderStat('Compras', _formatCurrency.format(_stats['gastado_mes'] ?? 0), 'este mes'),
                        Container(width: 1, height: 40, color: Colors.white30),
                        _buildHeaderStat('Saldo', _formatCurrency.format(_stats['saldo_pendiente'] ?? 0), 'pendiente'),
                        Container(width: 1, height: 40, color: Colors.white30),
                        _buildHeaderStat('Crédito', _formatCurrency.format(_stats['limite_credito'] ?? 0), 'disponible'),
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
          icon: const Icon(Icons.search),
          onPressed: _buscarProductos,
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.pushNamed(context, '/notificaciones'),
        ),
      ],
    );
  }

  Widget _buildHeaderStat(String label, String value, String subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10),
        ),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Nuevo\nPedido',
            Icons.add_shopping_cart,
            Colors.green,
            _nuevoPedido,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            'Ver\nCatálogo',
            Icons.menu_book,
            Colors.blue,
            _verCatalogo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            'Mis\nPedidos',
            Icons.receipt_long,
            Colors.orange,
            () => setState(() => _selectedTab = 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            'Mi\nCuenta',
            Icons.account_balance_wallet,
            Colors.purple,
            _verCuenta,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '📦 Activos',
            '${_pedidosActivos.length}',
            Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            '✅ Completados',
            '${_stats['pedidos_completados'] ?? 0}',
            Colors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            '⭐ Puntos',
            '${_stats['puntos'] ?? 0}',
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.purpleAccent, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final vendedor = pedido['vendedor'];
    final estado = pedido['estado'] ?? 'pendiente';
    final total = pedido['total'] ?? 0;
    final fecha = pedido['created_at'] != null 
        ? DateTime.parse(pedido['created_at']) 
        : DateTime.now();

    Color estadoColor;
    IconData estadoIcon;
    String estadoTexto;
    
    switch (estado) {
      case 'pendiente':
        estadoColor = Colors.grey;
        estadoIcon = Icons.hourglass_empty;
        estadoTexto = 'Pendiente';
        break;
      case 'confirmado':
        estadoColor = Colors.blue;
        estadoIcon = Icons.check_circle;
        estadoTexto = 'Confirmado';
        break;
      case 'preparando':
        estadoColor = Colors.orange;
        estadoIcon = Icons.inventory;
        estadoTexto = 'Preparando';
        break;
      case 'enviado':
        estadoColor = Colors.purple;
        estadoIcon = Icons.local_shipping;
        estadoTexto = 'En Camino';
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.receipt;
        estadoTexto = estado;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(estadoIcon, color: estadoColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #${pedido['numero_pedido'] ?? pedido['id'].toString().substring(0, 8)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _formatDate.format(fecha),
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      estadoTexto,
                      style: TextStyle(color: estadoColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency.format(total),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (vendedor != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Vendedor: ${vendedor['nombre'] ?? 'Sin asignar'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                if (vendedor['telefono'] != null)
                  GestureDetector(
                    onTap: () => _llamarVendedor(vendedor['telefono']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone, color: Colors.greenAccent, size: 14),
                          SizedBox(width: 4),
                          Text('Llamar', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductosGrid() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _productosDestacados.length,
        itemBuilder: (context, index) {
          final producto = _productosDestacados[index];
          return _buildProductoCard(producto);
        },
      ),
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> producto) {
    final precio = producto['precio_venta'] ?? 0;
    final enCarrito = _carrito.any((p) => p['id'] == producto['id']);

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: enCarrito ? Border.all(color: Colors.purpleAccent, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Center(
              child: producto['imagen_url'] != null
                  ? Image.network(producto['imagen_url'], fit: BoxFit.cover)
                  : const Icon(Icons.inventory_2, color: Colors.purple, size: 40),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['nombre'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency.format(precio),
                  style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _agregarAlCarrito(producto),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: enCarrito ? Colors.red : Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      enCarrito ? 'Quitar' : 'Agregar',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriasHorizontal() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categorias.length,
        itemBuilder: (context, index) {
          final categoria = _categorias[index];
          return _buildCategoriaChip(categoria);
        },
      ),
    );
  }

  Widget _buildCategoriaChip(Map<String, dynamic> categoria) {
    final colores = [Colors.purple, Colors.blue, Colors.orange, Colors.teal, Colors.pink];
    final color = colores[_categorias.indexOf(categoria) % colores.length];

    return GestureDetector(
      onTap: () => _verCategoria(categoria),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              categoria['nombre'] ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorialCard(Map<String, dynamic> pedido) {
    final fecha = pedido['created_at'] != null 
        ? DateTime.parse(pedido['created_at']) 
        : DateTime.now();
    final total = pedido['total'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido #${pedido['numero_pedido'] ?? pedido['id'].toString().substring(0, 8)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatDate.format(fecha),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
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

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Inicio', _selectedTab == 0, () => setState(() => _selectedTab = 0)),
              _buildNavItem(Icons.menu_book, 'Catálogo', _selectedTab == 1, _verCatalogo),
              _buildNavItem(Icons.receipt_long, 'Pedidos', _selectedTab == 2, () => setState(() => _selectedTab = 2)),
              _buildNavItem(Icons.favorite, 'Favoritos', _selectedTab == 3, () => setState(() => _selectedTab = 3)),
              _buildNavItem(Icons.person, 'Perfil', _selectedTab == 4, _verPerfil),
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
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.purpleAccent : Colors.white54,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE ACCIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  double _calcularTotalCarrito() {
    double total = 0;
    for (var p in _carrito) {
      total += (p['precio_venta'] ?? 0).toDouble() * (p['cantidad'] ?? 1);
    }
    return total;
  }

  void _agregarAlCarrito(Map<String, dynamic> producto) {
    setState(() {
      final existe = _carrito.indexWhere((p) => p['id'] == producto['id']);
      if (existe >= 0) {
        _carrito.removeAt(existe);
      } else {
        _carrito.add({...producto, 'cantidad': 1});
      }
    });
  }

  void _verCarrito() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.purpleAccent),
                const SizedBox(width: 12),
                const Text(
                  'Mi Carrito',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => _carrito.clear());
                    Navigator.pop(context);
                  },
                  child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            ..._carrito.map((p) => ListTile(
              leading: const Icon(Icons.inventory_2, color: Colors.purple),
              title: Text(p['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
              subtitle: Text(_formatCurrency.format(p['precio_venta'] ?? 0), style: const TextStyle(color: Colors.purpleAccent)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() => _carrito.removeWhere((item) => item['id'] == p['id']));
                  Navigator.pop(context);
                  _verCarrito();
                },
              ),
            )),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 16)),
                Text(
                  _formatCurrency.format(_calcularTotalCarrito()),
                  style: const TextStyle(color: Colors.purpleAccent, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmarPedido,
                icon: const Icon(Icons.check),
                label: const Text('Confirmar Pedido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarPedido() async {
    if (_carrito.isEmpty) return;
    Navigator.pop(context);

    try {
      final total = _calcularTotalCarrito();
      
      // Crear pedido
      final pedidoRes = await AppSupabase.client
          .from('ventas_pedidos')
          .insert({
            'negocio_id': _cliente!['negocio_id'],
            'cliente_id': _cliente!['id'],
            'estado': 'pendiente',
            'tipo_venta': 'app',
            'subtotal': total,
            'total': total,
          })
          .select()
          .single();

      // Crear detalle
      for (var p in _carrito) {
        await AppSupabase.client.from('ventas_pedidos_detalle').insert({
          'pedido_id': pedidoRes['id'],
          'producto_id': p['id'],
          'cantidad': p['cantidad'] ?? 1,
          'precio_unitario': p['precio_venta'],
          'subtotal': (p['precio_venta'] ?? 0) * (p['cantidad'] ?? 1),
        });
      }

      setState(() => _carrito.clear());
      await _cargarDatos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido realizado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creando pedido: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _nuevoPedido() {
    _verCatalogo();
  }

  void _verCatalogo() {
    // Mostrar catálogo completo
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.menu_book, color: Colors.purpleAccent),
                  const SizedBox(width: 12),
                  const Text(
                    'Catálogo de Productos',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _productosDestacados.length,
                itemBuilder: (context, index) => _buildProductoCard(_productosDestacados[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verCuenta() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.purpleAccent),
                SizedBox(width: 12),
                Text('Mi Cuenta', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            _buildCuentaItem('Saldo Pendiente', _formatCurrency.format(_stats['saldo_pendiente'] ?? 0), Colors.orange),
            _buildCuentaItem('Límite de Crédito', _formatCurrency.format(_stats['limite_credito'] ?? 0), Colors.blue),
            _buildCuentaItem('Puntos Acumulados', '${_stats['puntos'] ?? 0}', Colors.amber),
            _buildCuentaItem('Total Compras (Mes)', _formatCurrency.format(_stats['gastado_mes'] ?? 0), Colors.green),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCuentaItem(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.8))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  void _buscarProductos() {
    // TODO: Implementar búsqueda
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Búsqueda próximamente')),
    );
  }

  void _verCategoria(Map<String, dynamic> categoria) {
    // TODO: Mostrar productos de categoría
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Categoría: ${categoria['nombre']}')),
    );
  }

  void _llamarVendedor(String telefono) {
    // TODO: Implementar llamada
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Llamando a $telefono...')),
    );
  }

  void _verPerfil() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.purple.withOpacity(0.2),
              child: Text(
                _cliente!['nombre']?[0]?.toUpperCase() ?? '?',
                style: const TextStyle(color: Colors.purple, fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _cliente!['nombre'] ?? 'Cliente',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              _cliente!['email'] ?? '',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: Text(_cliente!['telefono'] ?? 'Sin teléfono', style: const TextStyle(color: Colors.white)),
              subtitle: const Text('Teléfono', style: TextStyle(color: Colors.white38)),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.blue),
              title: Text(_cliente!['direccion'] ?? 'Sin dirección', style: const TextStyle(color: Colors.white)),
              subtitle: const Text('Dirección', style: TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cerrarSesion() {
    Navigator.pop(context);
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
