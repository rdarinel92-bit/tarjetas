// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD VENDEDORA NICE - Acceso Personal para Consultoras
// Robert Darin Platform v10.20
// ═══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: unused_import
import '../components/premium_scaffold.dart';
// ignore: unused_import
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
// Pantallas NICE para navegación
import 'nice_pedidos_screen.dart';
import 'nice_clientes_screen.dart';
import 'nice_productos_screen.dart';
import 'nice_comisiones_screen.dart';
import 'nice_vendedoras_screen.dart';

class DashboardVendedoraNiceScreen extends StatefulWidget {
  const DashboardVendedoraNiceScreen({super.key});

  @override
  State<DashboardVendedoraNiceScreen> createState() => _DashboardVendedoraNiceScreenState();
}

class _DashboardVendedoraNiceScreenState extends State<DashboardVendedoraNiceScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _vendedora;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pedidosRecientes = [];
  List<Map<String, dynamic>> _comisionesRecientes = [];
  List<Map<String, dynamic>> _miEquipo = [];
  
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

      // Buscar la vendedora asociada a este usuario
      final vendedoraRes = await AppSupabase.client
          .from('nice_vendedoras')
          .select('''
            *,
            nivel:nice_niveles(nombre, color, comision_ventas, comision_equipo_n1)
          ''')
          .eq('auth_uid', user.id)
          .eq('activo', true)
          .maybeSingle();

      if (vendedoraRes == null) {
        // Intentar buscar por email
        final vendedoraByEmail = await AppSupabase.client
            .from('nice_vendedoras')
            .select('''
              *,
              nivel:nice_niveles(nombre, color, comision_ventas, comision_equipo_n1)
            ''')
            .eq('email', user.email ?? '')
            .eq('activo', true)
            .maybeSingle();
        
        if (vendedoraByEmail != null) {
          _vendedora = vendedoraByEmail;
          // Vincular auth_uid si no está vinculado
          await AppSupabase.client
              .from('nice_vendedoras')
              .update({'auth_uid': user.id})
              .eq('id', vendedoraByEmail['id']);
        }
      } else {
        _vendedora = vendedoraRes;
      }

      if (_vendedora != null) {
        await Future.wait([
          _cargarEstadisticas(),
          _cargarPedidosRecientes(),
          _cargarComisiones(),
          _cargarMiEquipo(),
        ]);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error cargando datos vendedora: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarEstadisticas() async {
    if (_vendedora == null) return;
    
    final vendedoraId = _vendedora!['id'];
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);

    // Ventas del mes
    final ventasMes = await AppSupabase.client
        .from('nice_pedidos')
        .select('total')
        .eq('vendedora_id', vendedoraId)
        .gte('fecha_pedido', inicioMes.toIso8601String())
        .neq('estado', 'cancelado');

    double totalVentasMes = 0;
    for (var p in ventasMes) {
      totalVentasMes += (p['total'] ?? 0).toDouble();
    }

    // Pedidos pendientes
    final pendientes = await AppSupabase.client
        .from('nice_pedidos')
        .select('id')
        .eq('vendedora_id', vendedoraId)
        .inFilter('estado', ['pendiente', 'confirmado', 'en_preparacion']);

    // Clientes
    final clientes = await AppSupabase.client
        .from('nice_clientes')
        .select('id')
        .eq('vendedora_id', vendedoraId)
        .eq('activo', true);

    // Comisiones del mes
    final comisionesMes = await AppSupabase.client
        .from('nice_comisiones')
        .select('monto')
        .eq('vendedora_id', vendedoraId)
        .gte('created_at', inicioMes.toIso8601String())
        .eq('estado', 'pagada');

    double totalComisionesMes = 0;
    for (var c in comisionesMes) {
      totalComisionesMes += (c['monto'] ?? 0).toDouble();
    }

    // Comisiones pendientes
    final comisionesPendientes = await AppSupabase.client
        .from('nice_comisiones')
        .select('monto')
        .eq('vendedora_id', vendedoraId)
        .eq('estado', 'pendiente');

    double totalComisionesPendientes = 0;
    for (var c in comisionesPendientes) {
      totalComisionesPendientes += (c['monto'] ?? 0).toDouble();
    }

    _stats = {
      'ventas_mes': totalVentasMes,
      'pedidos_pendientes': pendientes.length,
      'total_clientes': clientes.length,
      'comisiones_mes': totalComisionesMes,
      'comisiones_pendientes': totalComisionesPendientes,
      'puntos': _vendedora!['puntos_acumulados'] ?? 0,
    };
  }

  Future<void> _cargarPedidosRecientes() async {
    if (_vendedora == null) return;
    
    final res = await AppSupabase.client
        .from('nice_pedidos')
        .select('''
          id, folio_pedido, total, ganancia_vendedora, estado, fecha_pedido,
          cliente:nice_clientes(nombre, apellidos)
        ''')
        .eq('vendedora_id', _vendedora!['id'])
        .order('fecha_pedido', ascending: false)
        .limit(5);

    _pedidosRecientes = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarComisiones() async {
    if (_vendedora == null) return;

    final res = await AppSupabase.client
        .from('nice_comisiones')
        .select('id, tipo, monto, porcentaje, estado, created_at')
        .eq('vendedora_id', _vendedora!['id'])
        .order('created_at', ascending: false)
        .limit(5);

    _comisionesRecientes = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarMiEquipo() async {
    if (_vendedora == null) return;

    final res = await AppSupabase.client
        .from('nice_vendedoras')
        .select('''
          id, codigo_vendedora, nombre, apellidos, ventas_mes,
          nivel:nice_niveles(nombre, color)
        ''')
        .eq('patrocinadora_id', _vendedora!['id'])
        .eq('activo', true)
        .order('ventas_mes', ascending: false)
        .limit(10);

    _miEquipo = List<Map<String, dynamic>>.from(res);
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
              const CircularProgressIndicator(color: Colors.pinkAccent),
              const SizedBox(height: 16),
              Text(
                'Cargando tu información...',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    if (_vendedora == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'No se encontró tu perfil de vendedora',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Contacta a tu patrocinadora o al administrador',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _cargarDatos(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final nivel = _vendedora!['nivel'];
    Color nivelColor;
    try {
      nivelColor = Color(int.parse((nivel?['color'] ?? '#E91E63').replaceAll('#', '0xFF')));
    } catch (_) {
      nivelColor = Colors.pinkAccent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Header con info de vendedora
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: const Color(0xFF0D0D14),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
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
                                radius: 35,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Text(
                                  _vendedora!['nombre']?[0]?.toUpperCase() ?? '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '¡Hola, ${_vendedora!['nombre']}!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _vendedora!['codigo_vendedora'] ?? '',
                                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                    ),
                                  ],
                                ),
                              ),
                              // Badge de nivel
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, color: nivelColor, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      nivel?['nombre'] ?? 'Inicio',
                                      style: TextStyle(
                                        color: nivelColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Comisión actual
                          Text(
                            'Tu comisión: ${nivel?['comision_ventas'] ?? 25}%',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                          if ((nivel?['comision_equipo_n1'] ?? 0) > 0)
                            Text(
                              '+ ${nivel?['comision_equipo_n1']}% de tu equipo',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
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
            // Stats principales
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(
                          '💰 Ventas del Mes',
                          _formatCurrency.format(_stats['ventas_mes'] ?? 0),
                          Colors.green,
                        ),
                        _buildStatCard(
                          '✨ Comisiones Ganadas',
                          _formatCurrency.format(_stats['comisiones_mes'] ?? 0),
                          Colors.purple,
                        ),
                        _buildStatCard(
                          '⏳ Por Cobrar',
                          _formatCurrency.format(_stats['comisiones_pendientes'] ?? 0),
                          Colors.orange,
                        ),
                        _buildStatCard(
                          '👥 Mis Clientes',
                          '${_stats['total_clientes'] ?? 0}',
                          Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Acciones rápidas
                    const Text(
                      'Acciones Rápidas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            Icons.add_shopping_cart,
                            'Nuevo Pedido',
                            Colors.pinkAccent,
                            () => _irANuevoPedido(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            Icons.person_add,
                            'Nueva Cliente',
                            Colors.purple,
                            () => _irANuevaCliente(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            Icons.menu_book,
                            'Catálogo',
                            Colors.blue,
                            () => _irACatalogo(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Pedidos recientes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mis Pedidos Recientes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _irAMisPedidos(),
                          child: const Text('Ver todos'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_pedidosRecientes.isEmpty)
                      _buildEmptyState('No tienes pedidos aún', Icons.shopping_bag_outlined)
                    else
                      ...List.generate(
                        _pedidosRecientes.length.clamp(0, 3),
                        (index) => _buildPedidoItem(_pedidosRecientes[index]),
                      ),
                    const SizedBox(height: 24),
                    // Mi equipo
                    if (_miEquipo.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mi Equipo (${_miEquipo.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _irAMiEquipo(),
                            child: const Text('Ver todo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _miEquipo.length.clamp(0, 3),
                        (index) => _buildEquipoItem(_miEquipo[index]),
                      ),
                    ],
                    // Comisiones
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mis Comisiones',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _irAMisComisiones(),
                          child: const Text('Ver todas'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_comisionesRecientes.isEmpty)
                      _buildEmptyState('Sin comisiones aún', Icons.monetization_on_outlined)
                    else
                      ...List.generate(
                        _comisionesRecientes.length.clamp(0, 3),
                        (index) => _buildComisionItem(_comisionesRecientes[index]),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, 'Inicio', true, () {}),
                _buildNavItem(Icons.shopping_bag, 'Pedidos', false, () => _irAMisPedidos()),
                _buildNavItem(Icons.people, 'Clientes', false, () => _irAMisClientes()),
                _buildNavItem(Icons.account_tree, 'Equipo', false, () => _irAMiEquipo()),
                _buildNavItem(Icons.person, 'Perfil', false, () => _irAMiPerfil()),
              ],
            ),
          ),
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
          Text(
            title,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

  Widget _buildPedidoItem(Map<String, dynamic> pedido) {
    final cliente = pedido['cliente'];
    final nombreCliente = cliente != null
        ? '${cliente['nombre']} ${cliente['apellidos'] ?? ''}'
        : 'Sin cliente';
    
    Color estadoColor;
    switch (pedido['estado']) {
      case 'pendiente':
        estadoColor = Colors.orange;
        break;
      case 'confirmado':
      case 'en_preparacion':
        estadoColor = Colors.blue;
        break;
      case 'entregado':
        estadoColor = Colors.green;
        break;
      case 'cancelado':
        estadoColor = Colors.red;
        break;
      default:
        estadoColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.receipt, color: estadoColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pedido['folio_pedido'] ?? 'Sin folio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  nombreCliente,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency.format(pedido['total'] ?? 0),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '+${_formatCurrency.format(pedido['ganancia_vendedora'] ?? 0)}',
                style: const TextStyle(color: Colors.purpleAccent, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipoItem(Map<String, dynamic> miembro) {
    final nivel = miembro['nivel'];
    Color nivelColor;
    try {
      nivelColor = Color(int.parse((nivel?['color'] ?? '#666666').replaceAll('#', '0xFF')));
    } catch (_) {
      nivelColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: nivelColor.withOpacity(0.2),
            child: Text(
              miembro['nombre']?[0]?.toUpperCase() ?? '?',
              style: TextStyle(color: nivelColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${miembro['nombre']} ${miembro['apellidos'] ?? ''}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Text(
                      miembro['codigo_vendedora'] ?? '',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: nivelColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        nivel?['nombre'] ?? 'Inicio',
                        style: TextStyle(color: nivelColor, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency.format(miembro['ventas_mes'] ?? 0),
            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildComisionItem(Map<String, dynamic> comision) {
    final esPagada = comision['estado'] == 'pagada';
    
    String tipoTexto;
    switch (comision['tipo']) {
      case 'venta':
        tipoTexto = 'Comisión por venta';
        break;
      case 'equipo_n1':
        tipoTexto = 'Comisión equipo N1';
        break;
      case 'equipo_n2':
        tipoTexto = 'Comisión equipo N2';
        break;
      case 'equipo_n3':
        tipoTexto = 'Comisión equipo N3';
        break;
      default:
        tipoTexto = 'Comisión';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: esPagada
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              esPagada ? Icons.check_circle : Icons.hourglass_empty,
              color: esPagada ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipoTexto,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${comision['porcentaje'] ?? 0}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency.format(comision['monto'] ?? 0),
                style: TextStyle(
                  color: esPagada ? Colors.greenAccent : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                esPagada ? 'Pagada' : 'Pendiente',
                style: TextStyle(
                  color: esPagada ? Colors.green : Colors.orange,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.pinkAccent : Colors.white54,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.pinkAccent : Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _irANuevoPedido() {
    if (_vendedora == null) return;
    final negocioId = _vendedora!['negocio_id'];
    if (negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el negocio asociado')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NicePedidosScreen(negocioId: negocioId),
      ),
    );
  }

  void _irANuevaCliente() {
    if (_vendedora == null) return;
    final negocioId = _vendedora!['negocio_id'];
    if (negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el negocio asociado')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NiceClientesScreen(negocioId: negocioId),
      ),
    );
  }

  void _irACatalogo() {
    if (_vendedora == null) return;
    final negocioId = _vendedora!['negocio_id'];
    if (negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el negocio asociado')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NiceProductosScreen(negocioId: negocioId),
      ),
    );
  }

  void _irAMisPedidos() {
    if (_vendedora == null) return;
    final negocioId = _vendedora!['negocio_id'];
    if (negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el negocio asociado')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NicePedidosScreen(negocioId: negocioId),
      ),
    );
  }

  void _irAMisClientes() {
    if (_vendedora == null) return;
    final negocioId = _vendedora!['negocio_id'];
    if (negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el negocio asociado')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NiceClientesScreen(negocioId: negocioId),
      ),
    );
  }

  void _irAMiEquipo() {
    if (_vendedora == null) return;
    final negocioId = _vendedora!['negocio_id'];
    if (negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el negocio asociado')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NiceVendedorasScreen(negocioId: negocioId),
      ),
    );
  }

  void _irAMisComisiones() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NiceComisionesScreen(),
      ),
    );
  }

  void _irAMiPerfil() {
    _mostrarMiPerfil();
  }

  void _mostrarMiPerfil() {
    if (_vendedora == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.pinkAccent.withOpacity(0.2),
              child: Text(
                (_vendedora!['nombre'] ?? 'V')[0].toUpperCase(),
                style: const TextStyle(fontSize: 32, color: Colors.pinkAccent),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_vendedora!['nombre'] ?? ''} ${_vendedora!['apellidos'] ?? ''}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Código: ${_vendedora!['codigo_vendedora'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            if (_vendedora!['nivel'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Nivel: ${_vendedora!['nivel']['nombre'] ?? 'Inicio'}',
                  style: const TextStyle(color: Colors.pinkAccent, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatPerfil('Puntos', '${_vendedora!['puntos_acumulados'] ?? 0}'),
                _buildStatPerfil('Clientes', '${_stats['total_clientes'] ?? 0}'),
                _buildStatPerfil('Equipo', '${_miEquipo.length}'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPerfil(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Deseas cerrar tu sesión?',
          style: TextStyle(color: Colors.white70),
        ),
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
