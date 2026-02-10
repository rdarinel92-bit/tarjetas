// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD CLIENTE PURIFICADORA - Portal para Clientes de Agua Purificada
// Robert Darin Platform v10.21
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class DashboardClientePurificadoraScreen extends StatefulWidget {
  const DashboardClientePurificadoraScreen({super.key});

  @override
  State<DashboardClientePurificadoraScreen> createState() => _DashboardClientePurificadoraScreenState();
}

class _DashboardClientePurificadoraScreenState extends State<DashboardClientePurificadoraScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _pedidosActivos = [];
  List<Map<String, dynamic>> _historialPedidos = [];
  Map<String, dynamic> _stats = {};
  
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
          .from('purificadora_clientes')
          .select('*')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (clienteRes == null) {
        clienteRes = await AppSupabase.client
            .from('purificadora_clientes')
            .select('*')
            .eq('email', user.email ?? '')
            .maybeSingle();
        
        if (clienteRes != null) {
          // Vincular auth_uid
          await AppSupabase.client
              .from('purificadora_clientes')
              .update({'auth_uid': user.id})
              .eq('id', clienteRes['id']);
        }
      }

      _cliente = clienteRes;

      if (_cliente != null) {
        await Future.wait([
          _cargarPedidosActivos(),
          _cargarHistorial(),
          _cargarEstadisticas(),
        ]);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando datos cliente purificadora: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPedidosActivos() async {
    if (_cliente == null) return;
    
    final res = await AppSupabase.client
        .from('purificadora_entregas')
        .select('''
          *,
          repartidor:purificadora_repartidores(nombre, telefono)
        ''')
        .eq('cliente_id', _cliente!['id'])
        .inFilter('estado', ['pendiente', 'programado', 'en_camino'])
        .order('fecha_entrega');
    
    _pedidosActivos = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarHistorial() async {
    if (_cliente == null) return;
    
    final res = await AppSupabase.client
        .from('purificadora_entregas')
        .select('*')
        .eq('cliente_id', _cliente!['id'])
        .eq('estado', 'entregado')
        .order('fecha_entrega', ascending: false)
        .limit(20);
    
    _historialPedidos = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarEstadisticas() async {
    if (_cliente == null) return;
    
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);

    final pedidosMes = await AppSupabase.client
        .from('purificadora_entregas')
        .select('id, garrafones_entregados, total')
        .eq('cliente_id', _cliente!['id'])
        .eq('estado', 'entregado')
        .gte('fecha_entrega', inicioMes.toIso8601String());

    int garrafones = 0;
    double gastado = 0;
    for (var p in pedidosMes) {
      garrafones += (p['garrafones_entregados'] ?? 0) as int;
      gastado += (p['total'] ?? 0).toDouble();
    }

    _stats = {
      'garrafones_mes': garrafones,
      'gastado_mes': gastado,
      'total_pedidos_mes': pedidosMes.length,
      'saldo': _cliente!['saldo'] ?? 0,
      'garrafones_prestados': _cliente!['garrafones_prestados'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    if (_cliente == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Mi Portal'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  'Bienvenido',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aún no tienes un perfil de cliente registrado.\nContacta a la purificadora para registrarte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _cargarDatos(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: CustomScrollView(
          slivers: [
            // Header
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
                      colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
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
                                child: const Icon(Icons.person, color: Colors.white, size: 30),
                              ),
                              const SizedBox(width: 12),
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
                                        const Icon(Icons.location_on, color: Colors.white70, size: 14),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _cliente!['direccion'] ?? 'Sin dirección',
                                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
                                _buildHeaderStat('Garrafones', '${_stats['garrafones_prestados'] ?? 0}', 'prestados'),
                                Container(width: 1, height: 40, color: Colors.white30),
                                _buildHeaderStat('Saldo', _formatCurrency.format(_stats['saldo'] ?? 0), (_stats['saldo'] ?? 0) < 0 ? 'a favor' : 'pendiente'),
                                Container(width: 1, height: 40, color: Colors.white30),
                                _buildHeaderStat('Este mes', '${_stats['garrafones_mes'] ?? 0}', 'garrafones'),
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
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => Navigator.pushNamed(context, '/chat'),
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
                    // Botón pedir agua
                    GestureDetector(
                      onTap: () => _pedirAgua(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.water_drop, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¿Necesitas agua?',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Pide garrafones ahora',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add_shopping_cart, color: Color(0xFF0072FF)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Pedidos activos
                    if (_pedidosActivos.isNotEmpty) ...[
                      const Text(
                        'Tus Pedidos Activos',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _pedidosActivos.length,
                        (index) => _buildPedidoActivoCard(_pedidosActivos[index]),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Opciones rápidas
                    Row(
                      children: [
                        Expanded(child: _buildQuickAction('Programar\nEntrega', Icons.calendar_today, Colors.purple, () => _pedirAgua())),
                        const SizedBox(width: 12),
                        Expanded(child: _buildQuickAction('Ver\nHistorial', Icons.history, Colors.teal, () {})),
                        const SizedBox(width: 12),
                        Expanded(child: _buildQuickAction('Mi\nCuenta', Icons.account_balance_wallet, Colors.orange, () => _verCuenta())),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Historial reciente
                    if (_historialPedidos.isNotEmpty) ...[
                      const Text(
                        'Entregas Recientes',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _historialPedidos.length.clamp(0, 5),
                        (index) => _buildHistorialCard(_historialPedidos[index]),
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeaderStat(String value, String label, String sublabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(value, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
        Text(sublabel, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
      ],
    );
  }

  Widget _buildPedidoActivoCard(Map<String, dynamic> pedido) {
    final estado = pedido['estado'] ?? 'pendiente';
    final repartidor = pedido['repartidor'];
    final garrafones = pedido['garrafones_solicitados'] ?? 0;
    
    Color estadoColor;
    IconData estadoIcon;
    String estadoTexto;
    
    switch (estado) {
      case 'pendiente':
        estadoColor = Colors.orange;
        estadoIcon = Icons.hourglass_empty;
        estadoTexto = 'Procesando pedido';
        break;
      case 'programado':
        estadoColor = Colors.blue;
        estadoIcon = Icons.schedule;
        estadoTexto = 'Programado';
        break;
      case 'en_camino':
        estadoColor = Colors.green;
        estadoIcon = Icons.local_shipping;
        estadoTexto = '¡En camino!';
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.help;
        estadoTexto = estado;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [estadoColor.withOpacity(0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withOpacity(0.5)),
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
                      estadoTexto,
                      style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '$garrafones garrafones',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatCurrency.format(pedido['total'] ?? 0),
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (pedido['fecha_entrega'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Entrega: ${_formatDate.format(DateTime.parse(pedido['fecha_entrega']))}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
          if (repartidor != null && estado == 'en_camino') ...[
            const Divider(color: Colors.white12, height: 24),
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(repartidor['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                      const Text('Tu repartidor', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                if (repartidor['telefono'] != null)
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.phone, color: Colors.greenAccent),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorialCard(Map<String, dynamic> pedido) {
    final fecha = pedido['fecha_entrega'] != null 
        ? _formatDate.format(DateTime.parse(pedido['fecha_entrega']))
        : '';
    final garrafones = pedido['garrafones_entregados'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
                Text('$garrafones garrafones', style: const TextStyle(color: Colors.white)),
                Text(fecha, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text(
            _formatCurrency.format(pedido['total_cobrado'] ?? pedido['total'] ?? 0),
            style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
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
              _buildNavItem(Icons.home, 'Inicio', true),
              _buildNavItem(Icons.water_drop, 'Pedir', false),
              _buildNavItem(Icons.history, 'Historial', false),
              _buildNavItem(Icons.person, 'Perfil', false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? Colors.blueAccent : Colors.white54, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? Colors.blueAccent : Colors.white54, fontSize: 10)),
      ],
    );
  }

  void _pedirAgua() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PedirAguaSheet(
        cliente: _cliente!,
        onPedido: () {
          Navigator.pop(context);
          _cargarDatos();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ ¡Pedido realizado! Te avisaremos cuando esté en camino.'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _verCuenta() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Mi Cuenta', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildCuentaRow('Garrafones prestados', '${_stats['garrafones_prestados'] ?? 0}', Colors.orange),
            _buildCuentaRow('Saldo', _formatCurrency.format(_stats['saldo'] ?? 0), (_stats['saldo'] ?? 0) < 0 ? Colors.green : Colors.orange),
            _buildCuentaRow('Garrafones este mes', '${_stats['garrafones_mes'] ?? 0}', Colors.blue),
            _buildCuentaRow('Total pagado este mes', _formatCurrency.format(_stats['gastado_mes'] ?? 0), Colors.purple),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCuentaRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET PARA PEDIR AGUA
// ═══════════════════════════════════════════════════════════════════════════════

class _PedirAguaSheet extends StatefulWidget {
  final Map<String, dynamic> cliente;
  final VoidCallback onPedido;

  const _PedirAguaSheet({required this.cliente, required this.onPedido});

  @override
  State<_PedirAguaSheet> createState() => _PedirAguaSheetState();
}

class _PedirAguaSheetState extends State<_PedirAguaSheet> {
  int _cantidad = 1;
  // ignore: unused_field
  DateTime? _fechaEntrega;
  String _horario = 'manana';
  String _notas = '';
  bool _enviando = false;
  double _precioPorGarrafon = 25.0; // Precio default

  @override
  void initState() {
    super.initState();
    _cargarPrecio();
  }

  Future<void> _cargarPrecio() async {
    try {
      // Intentar obtener precio del cliente o precio default
      final precioCliente = widget.cliente['precio_especial'];
      if (precioCliente != null) {
        _precioPorGarrafon = (precioCliente as num).toDouble();
      } else {
        // Buscar precio default de productos
        final producto = await AppSupabase.client
            .from('purificadora_productos')
            .select('precio')
            .eq('tipo', 'garrafon')
            .eq('activo', true)
            .maybeSingle();
        if (producto != null) {
          _precioPorGarrafon = (producto['precio'] as num).toDouble();
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error cargando precio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _cantidad * _precioPorGarrafon;
    final formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pedir Agua',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.cliente['direccion'] ?? 'Sin dirección',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Cantidad
            const Text('¿Cuántos garrafones?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                    icon: const Icon(Icons.remove_circle, size: 36),
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    children: [
                      Text(
                        '$_cantidad',
                        style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                      Text('garrafones', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                    ],
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: _cantidad < 20 ? () => setState(() => _cantidad++) : null,
                    icon: const Icon(Icons.add_circle, size: 36),
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Horario preferido
            const Text('Horario preferido', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildHorarioChip('manana', 'Mañana', '8am - 12pm')),
                const SizedBox(width: 8),
                Expanded(child: _buildHorarioChip('tarde', 'Tarde', '12pm - 6pm')),
              ],
            ),
            const SizedBox(height: 20),
            // Notas
            TextFormField(
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                hintText: 'Notas adicionales (opcional)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              ),
              onChanged: (v) => _notas = v,
            ),
            const SizedBox(height: 24),
            // Resumen y total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Precio por garrafón', style: TextStyle(color: Colors.white70)),
                      Text(formatCurrency.format(_precioPorGarrafon), style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cantidad', style: TextStyle(color: Colors.white70)),
                      Text('$_cantidad', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(formatCurrency.format(total), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Botón pedir
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enviando ? null : _realizarPedido,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _enviando 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmar Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHorarioChip(String value, String label, String sublabel) {
    final isSelected = _horario == value;
    return GestureDetector(
      onTap: () => setState(() => _horario = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white70, fontWeight: FontWeight.bold)),
            Text(sublabel, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Future<void> _realizarPedido() async {
    setState(() => _enviando = true);
    
    try {
      final total = _cantidad * _precioPorGarrafon;
      
      await AppSupabase.client.from('purificadora_entregas').insert({
        'cliente_id': widget.cliente['id'],
        'negocio_id': widget.cliente['negocio_id'],
        'garrafones_solicitados': _cantidad,
        'total': total,
        'horario_preferido': _horario,
        'notas': _notas,
        'estado': 'pendiente',
        'fecha_entrega': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      });

      widget.onPedido();
    } catch (e) {
      debugPrint('Error realizando pedido: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}
