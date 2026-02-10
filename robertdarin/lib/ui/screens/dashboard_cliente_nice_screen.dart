// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD CLIENTE NICE - Portal para Clientes de Joyería MLM
// Robert Darin Platform v10.22
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class DashboardClienteNiceScreen extends StatefulWidget {
  const DashboardClienteNiceScreen({super.key});

  @override
  State<DashboardClienteNiceScreen> createState() => _DashboardClienteNiceScreenState();
}

class _DashboardClienteNiceScreenState extends State<DashboardClienteNiceScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _cliente;
  Map<String, dynamic>? _vendedora;
  List<Map<String, dynamic>> _pedidosActivos = [];
  List<Map<String, dynamic>> _historialPedidos = [];
  List<Map<String, dynamic>> _productosDestacados = [];
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _carrito = [];
  int _selectedNavIndex = 0;
  
  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _formatDate = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Buscar cliente por auth_uid o email
      var clienteRes = await AppSupabase.client
          .from('nice_clientes')
          .select('*, vendedora:nice_vendedoras(id, nombre, telefono, whatsapp)')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (clienteRes == null) {
        clienteRes = await AppSupabase.client
            .from('nice_clientes')
            .select('*, vendedora:nice_vendedoras(id, nombre, telefono, whatsapp)')
            .eq('email', user.email ?? '')
            .maybeSingle();
        
        if (clienteRes != null) {
          await AppSupabase.client
              .from('nice_clientes')
              .update({'auth_uid': user.id})
              .eq('id', clienteRes['id']);
        }
      }

      _cliente = clienteRes;
      _vendedora = clienteRes?['vendedora'];

      if (_cliente != null) {
        await Future.wait([
          _cargarPedidos(),
          _cargarProductos(),
          _cargarCategorias(),
        ]);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando datos cliente nice: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPedidos() async {
    if (_cliente == null) return;
    
    // Pedidos activos
    final activos = await AppSupabase.client
        .from('nice_pedidos')
        .select('*, items:nice_pedido_items(*, producto:nice_productos(nombre, imagen_url))')
        .eq('cliente_id', _cliente!['id'])
        .inFilter('estado', ['pendiente', 'confirmado', 'en_proceso', 'enviado'])
        .order('created_at', ascending: false);
    
    _pedidosActivos = List<Map<String, dynamic>>.from(activos);
    
    // Historial
    final historial = await AppSupabase.client
        .from('nice_pedidos')
        .select('*')
        .eq('cliente_id', _cliente!['id'])
        .eq('estado', 'entregado')
        .order('created_at', ascending: false)
        .limit(10);
    
    _historialPedidos = List<Map<String, dynamic>>.from(historial);
  }

  Future<void> _cargarProductos() async {
    final res = await AppSupabase.client
        .from('nice_productos')
        .select('*, categoria:nice_categorias(nombre)')
        .eq('activo', true)
        .eq('destacado', true)
        .order('nombre')
        .limit(12);
    
    _productosDestacados = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarCategorias() async {
    final res = await AppSupabase.client
        .from('nice_categorias')
        .select('*')
        .eq('activa', true)
        .order('nombre');
    
    _categorias = List<Map<String, dynamic>>.from(res);
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.pink.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(color: Colors.pinkAccent),
              ),
              const SizedBox(height: 20),
              const Text('Cargando tu perfil...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    if (_cliente == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Nice Joyería', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond_outlined, color: Colors.pinkAccent, size: 64),
              const SizedBox(height: 16),
              const Text('No encontramos tu perfil', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('Contacta a tu vendedora para registrarte', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: Colors.pinkAccent,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: const Color(0xFF0D0D14),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.pink.shade800,
                        Colors.purple.shade900,
                      ],
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
                                radius: 30,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Text(
                                  _cliente?['nombre']?[0]?.toUpperCase() ?? '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '¡Hola, ${_cliente?['nombre']?.split(' ')[0] ?? 'Cliente'}!',
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    if (_vendedora != null)
                                      Text(
                                        'Tu asesora: ${_vendedora!['nombre']}',
                                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                      ),
                                  ],
                                ),
                              ),
                              // Logo Nice
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.diamond, color: Colors.white, size: 28),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Stats rápidas
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildHeaderStat('Pedidos', '${_pedidosActivos.length}', 'activos'),
                                Container(width: 1, height: 35, color: Colors.white30),
                                _buildHeaderStat('Carrito', '${_carrito.length}', 'items'),
                                Container(width: 1, height: 35, color: Colors.white30),
                                _buildHeaderStat('Puntos', '${_cliente?['puntos'] ?? 0}', 'acumulados'),
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
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_bag_outlined),
                      onPressed: () => _verCarrito(),
                    ),
                    if (_carrito.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                          child: Text('${_carrito.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                  ],
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
                    // Contactar vendedora
                    if (_vendedora != null)
                      GestureDetector(
                        onTap: () => _contactarVendedora(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.pink.shade600, Colors.purple.shade600],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.chat, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('¿Necesitas ayuda?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    Text('Contacta a ${_vendedora!['nombre']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Pedidos activos
                    if (_pedidosActivos.isNotEmpty) ...[
                      const Text('Tus Pedidos Activos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _pedidosActivos.length,
                        (index) => _buildPedidoCard(_pedidosActivos[index]),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Categorías
                    const Text('Categorías', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categorias.length,
                        itemBuilder: (context, idx) {
                          final cat = _categorias[idx];
                          return GestureDetector(
                            onTap: () => _verCategoria(cat),
                            child: Container(
                              width: 90,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.pink.withOpacity(0.3),
                                    Colors.purple.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_getCategoriaIcon(cat['nombre']), color: Colors.pinkAccent, size: 28),
                                  const SizedBox(height: 8),
                                  Text(cat['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 11), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Productos destacados
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Productos Destacados', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => _verCatalogo(),
                          child: const Text('Ver todo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _productosDestacados.length,
                      itemBuilder: (context, idx) => _buildProductoCard(_productosDestacados[idx]),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeaderStat(String label, String value, String sublabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
      ],
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final estado = pedido['estado'] ?? 'pendiente';
    final color = _getEstadoColor(estado);
    final items = pedido['items'] as List? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pedido #${pedido['id']?.toString().substring(0, 8) ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(estado.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${items.length} productos • ${_formatCurrency.format(pedido['total'] ?? 0)}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          if (pedido['created_at'] != null) ...[
            const SizedBox(height: 4),
            Text('Fecha: ${_formatDate.format(DateTime.parse(pedido['created_at']))}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> producto) {
    return GestureDetector(
      onTap: () => _verDetalleProducto(producto),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: producto['imagen_url'] != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(producto['imagen_url'], fit: BoxFit.cover, width: double.infinity, height: 120),
                      )
                    : const Icon(Icons.diamond, color: Colors.pinkAccent, size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(producto['categoria']?['nombre'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatCurrency.format(producto['precio'] ?? 0), style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      GestureDetector(
                        onTap: () => _agregarAlCarrito(producto),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add_shopping_cart, color: Colors.pinkAccent, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Inicio', _selectedNavIndex == 0, () => setState(() => _selectedNavIndex = 0)),
              _buildNavItem(Icons.grid_view, 'Catálogo', _selectedNavIndex == 1, _verCatalogo),
              _buildNavItem(Icons.shopping_bag, 'Carrito', _selectedNavIndex == 2, _verCarrito),
              _buildNavItem(Icons.chat, 'Chat', _selectedNavIndex == 3, () => Navigator.pushNamed(context, '/chat')),
              _buildNavItem(Icons.person, 'Cuenta', _selectedNavIndex == 4, _verCuenta),
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
          Icon(icon, color: isActive ? Colors.pinkAccent : Colors.white54, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? Colors.pinkAccent : Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente': return Colors.orange;
      case 'confirmado': return Colors.blue;
      case 'en_proceso': return Colors.purple;
      case 'enviado': return Colors.cyan;
      case 'entregado': return Colors.green;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getCategoriaIcon(String? nombre) {
    switch (nombre?.toLowerCase()) {
      case 'anillos': return Icons.circle_outlined;
      case 'collares': return Icons.link;
      case 'aretes': return Icons.earbuds;
      case 'pulseras': return Icons.watch;
      case 'relojes': return Icons.watch_later;
      default: return Icons.diamond;
    }
  }

  void _contactarVendedora() {
    if (_vendedora == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.pinkAccent.withOpacity(0.2),
              child: Text(_vendedora!['nombre']?[0]?.toUpperCase() ?? 'V', style: const TextStyle(color: Colors.pinkAccent, fontSize: 28)),
            ),
            const SizedBox(height: 16),
            Text(_vendedora!['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Tu asesora de belleza', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildContactOption(Icons.chat, 'Chat App', Colors.blue, () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/chat');
                }),
                _buildContactOption(Icons.phone, 'Llamar', Colors.green, () {}),
                _buildContactOption(Icons.message, 'WhatsApp', Colors.green.shade600, () {}),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  void _verCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
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
                  gradient: LinearGradient(colors: [Colors.pink.shade700, Colors.purple.shade800]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    const Text('Mi Carrito', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${_carrito.length} items', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Expanded(
                child: _carrito.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined, color: Colors.white24, size: 64),
                            const SizedBox(height: 16),
                            const Text('Tu carrito está vacío', style: TextStyle(color: Colors.white54)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _verCatalogo();
                              },
                              child: const Text('Ver catálogo'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _carrito.length,
                        itemBuilder: (context, idx) {
                          final item = _carrito[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.pink.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.diamond, color: Colors.pinkAccent),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                                      Text(_formatCurrency.format(item['precio'] ?? 0), style: const TextStyle(color: Colors.pinkAccent)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() => _carrito.removeAt(idx));
                                    Navigator.pop(context);
                                    _verCarrito();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_carrito.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 16)),
                            Text(
                              _formatCurrency.format(_carrito.fold(0.0, (sum, item) => sum + (item['precio'] ?? 0))),
                              style: const TextStyle(color: Colors.pinkAccent, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _confirmarPedido(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Confirmar Pedido', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _verCatalogo() {
    // Navegar al catálogo completo
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abriendo catálogo completo...'), backgroundColor: Colors.pinkAccent),
    );
  }

  void _verCategoria(Map<String, dynamic> categoria) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Categoría: ${categoria['nombre']}'), backgroundColor: Colors.pinkAccent),
    );
  }

  void _verDetalleProducto(Map<String, dynamic> producto) {
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
            Center(
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: Colors.pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: producto['imagen_url'] != null
                    ? Image.network(producto['imagen_url'], fit: BoxFit.cover)
                    : const Icon(Icons.diamond, color: Colors.pinkAccent, size: 50),
              ),
            ),
            const SizedBox(height: 16),
            Text(producto['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(producto['descripcion'] ?? 'Sin descripción', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatCurrency.format(producto['precio'] ?? 0), style: const TextStyle(color: Colors.pinkAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () {
                    _agregarAlCarrito(producto);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Agregar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _agregarAlCarrito(Map<String, dynamic> producto) {
    setState(() {
      _carrito.add({
        'id': producto['id'],
        'nombre': producto['nombre'],
        'precio': producto['precio'],
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${producto['nombre']} agregado al carrito'), backgroundColor: Colors.green),
    );
  }

  void _confirmarPedido() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmar Pedido', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total: ${_formatCurrency.format(_carrito.fold(0.0, (sum, item) => sum + (item['precio'] ?? 0)))}', style: const TextStyle(color: Colors.pinkAccent, fontSize: 20)),
            const SizedBox(height: 8),
            const Text('Tu vendedora recibirá el pedido y te contactará para coordinar el pago y entrega.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                final total = _carrito.fold(0.0, (sum, item) => sum + (item['precio'] ?? 0));
                
                // Crear pedido
                final pedido = await AppSupabase.client.from('nice_pedidos').insert({
                  'cliente_id': _cliente!['id'],
                  'vendedora_id': _vendedora?['id'],
                  'total': total,
                  'estado': 'pendiente',
                }).select().single();
                
                // Crear items
                for (var item in _carrito) {
                  await AppSupabase.client.from('nice_pedido_items').insert({
                    'pedido_id': pedido['id'],
                    'producto_id': item['id'],
                    'cantidad': 1,
                    'precio_unitario': item['precio'],
                  });
                }
                
                setState(() => _carrito.clear());
                if (mounted) {
                  Navigator.pop(context); // Cerrar dialog
                  Navigator.pop(context); // Cerrar carrito
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Pedido enviado a tu vendedora'), backgroundColor: Colors.green),
                  );
                  _cargarDatos();
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _verCuenta() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
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
                child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                  child: Text(_cliente?['nombre']?[0]?.toUpperCase() ?? '?', style: const TextStyle(color: Colors.pinkAccent, fontSize: 36, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(_cliente?['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
              Center(child: Text(_cliente?['email'] ?? '', style: const TextStyle(color: Colors.white54))),
              const SizedBox(height: 24),
              _buildCuentaItem(Icons.phone, 'Teléfono', _cliente?['telefono'] ?? 'No registrado'),
              _buildCuentaItem(Icons.location_on, 'Dirección', _cliente?['direccion'] ?? 'No registrada'),
              _buildCuentaItem(Icons.star, 'Puntos', '${_cliente?['puntos'] ?? 0} puntos'),
              _buildCuentaItem(Icons.shopping_bag, 'Total Pedidos', '${_historialPedidos.length + _pedidosActivos.length}'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
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

  Widget _buildCuentaItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.pinkAccent, size: 20),
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
}
