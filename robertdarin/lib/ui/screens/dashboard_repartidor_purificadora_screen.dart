// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD REPARTIDOR PURIFICADORA - Panel de Entregas y Rutas
// Robert Darin Platform v10.21
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class DashboardRepartidorPurificadoraScreen extends StatefulWidget {
  const DashboardRepartidorPurificadoraScreen({super.key});

  @override
  State<DashboardRepartidorPurificadoraScreen> createState() => _DashboardRepartidorPurificadoraScreenState();
}

class _DashboardRepartidorPurificadoraScreenState extends State<DashboardRepartidorPurificadoraScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _repartidor;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _entregasHoy = [];
  List<Map<String, dynamic>> _entregasPendientes = [];
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _formatDate = DateFormat('dd/MM/yyyy');
  // ignore: unused_field
  final _formatTime = DateFormat('HH:mm');

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

      // Buscar repartidor por auth_uid
      final repartidorRes = await AppSupabase.client
          .from('purificadora_repartidores')
          .select('*')
          .eq('auth_uid', user.id)
          .eq('activo', true)
          .maybeSingle();

      if (repartidorRes == null) {
        // Intentar buscar por email
        final repartidorByEmail = await AppSupabase.client
            .from('purificadora_repartidores')
            .select('*')
            .eq('email', user.email ?? '')
            .eq('activo', true)
            .maybeSingle();
        
        if (repartidorByEmail != null) {
          _repartidor = repartidorByEmail;
          // Vincular auth_uid
          await AppSupabase.client
              .from('purificadora_repartidores')
              .update({'auth_uid': user.id})
              .eq('id', repartidorByEmail['id']);
        }
      } else {
        _repartidor = repartidorRes;
      }

      if (_repartidor != null) {
        await Future.wait([
          _cargarEstadisticas(),
          _cargarEntregasHoy(),
          _cargarEntregasPendientes(),
        ]);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error cargando datos repartidor: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarEstadisticas() async {
    if (_repartidor == null) return;
    
    final repartidorId = _repartidor!['id'];
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);

    // Entregas del mes
    final entregasMes = await AppSupabase.client
        .from('purificadora_entregas')
        .select('id, total, estado, garrafones_entregados')
        .eq('repartidor_id', repartidorId)
        .gte('fecha_entrega', inicioMes.toIso8601String());

    int entregadas = 0;
    int garrafones = 0;
    double totalRecaudado = 0;
    for (var e in entregasMes) {
      if (e['estado'] == 'entregado') {
        entregadas++;
        garrafones += (e['garrafones_entregados'] ?? 0) as int;
        totalRecaudado += (e['total'] ?? 0).toDouble();
      }
    }

    final comision = (_repartidor!['comision_entrega'] ?? 5).toDouble();
    final ganado = totalRecaudado * (comision / 100);

    _stats = {
      'entregas_hoy': _entregasHoy.length,
      'entregas_mes': entregasMes.length,
      'entregadas_mes': entregadas,
      'garrafones_mes': garrafones,
      'ganado_mes': ganado,
      'recaudado_mes': totalRecaudado,
    };
  }

  Future<void> _cargarEntregasHoy() async {
    if (_repartidor == null) return;
    
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final manana = hoy.add(const Duration(days: 1));

    final res = await AppSupabase.client
        .from('purificadora_entregas')
        .select('''
          *,
          cliente:purificadora_clientes(nombre, telefono, direccion, referencias)
        ''')
        .eq('repartidor_id', _repartidor!['id'])
        .gte('fecha_entrega', hoy.toIso8601String())
        .lt('fecha_entrega', manana.toIso8601String())
        .order('orden_ruta');

    _entregasHoy = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarEntregasPendientes() async {
    if (_repartidor == null) return;

    final res = await AppSupabase.client
        .from('purificadora_entregas')
        .select('''
          *,
          cliente:purificadora_clientes(nombre, telefono, direccion, referencias)
        ''')
        .eq('repartidor_id', _repartidor!['id'])
        .inFilter('estado', ['pendiente', 'en_camino'])
        .order('fecha_entrega')
        .limit(15);

    _entregasPendientes = List<Map<String, dynamic>>.from(res);
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
              const CircularProgressIndicator(color: Colors.blueAccent),
              const SizedBox(height: 16),
              Text(
                'Cargando tu ruta...',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    if (_repartidor == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_shipping, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'No se encontró tu perfil de repartidor',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Contacta al administrador',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _cargarDatos(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
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
        child: CustomScrollView(
          slivers: [
            // Header con gradiente azul agua
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
                                radius: 30,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: const Icon(
                                  Icons.local_shipping,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '¡Hola, ${_repartidor!['nombre']}!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${_repartidor!['codigo'] ?? 'Repartidor'} • ${_repartidor!['vehiculo'] ?? ''}',
                                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                    ),
                                  ],
                                ),
                              ),
                              // Estado disponible
                              Switch(
                                value: _repartidor!['disponible'] ?? false,
                                onChanged: (v) => _toggleDisponibilidad(v),
                                activeColor: Colors.greenAccent,
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Resumen rápido
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildHeaderStat('Entregas Hoy', '${_entregasHoy.length}', Icons.delivery_dining),
                                Container(width: 1, height: 30, color: Colors.white30),
                                _buildHeaderStat('Garrafones', '${_stats['garrafones_mes'] ?? 0}', Icons.water_drop),
                                Container(width: 1, height: 30, color: Colors.white30),
                                _buildHeaderStat('Ganado', _formatCurrency.format(_stats['ganado_mes'] ?? 0), Icons.attach_money),
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
                    // Botón iniciar ruta
                    if (_entregasHoy.isNotEmpty && _entregasHoy.any((e) => e['estado'] == 'pendiente'))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        child: ElevatedButton.icon(
                          onPressed: () => _iniciarRuta(),
                          icon: const Icon(Icons.navigation, size: 24),
                          label: const Text('INICIAR RUTA DEL DÍA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
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
                          '📦 Pendientes',
                          '${_entregasPendientes.where((e) => e['estado'] == 'pendiente').length}',
                          Colors.orange,
                        ),
                        _buildStatCard(
                          '🚛 En Camino',
                          '${_entregasPendientes.where((e) => e['estado'] == 'en_camino').length}',
                          Colors.blue,
                        ),
                        _buildStatCard(
                          '✅ Entregadas (Mes)',
                          '${_stats['entregadas_mes'] ?? 0}',
                          Colors.green,
                        ),
                        _buildStatCard(
                          '💧 Garrafones (Mes)',
                          '${_stats['garrafones_mes'] ?? 0}',
                          Colors.cyan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Entregas de hoy
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ruta de Hoy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_entregasHoy.length} entregas',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_entregasHoy.isEmpty)
                      _buildEmptyState('No tienes entregas programadas hoy', Icons.local_shipping_outlined)
                    else
                      ...List.generate(
                        _entregasHoy.length,
                        (index) => _buildEntregaCard(_entregasHoy[index], index + 1),
                      ),
                    const SizedBox(height: 24),
                    // Entregas pendientes futuras
                    if (_entregasPendientes.isNotEmpty) ...[
                      const Text(
                        'Próximas Entregas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _entregasPendientes.length.clamp(0, 5),
                        (index) => _buildEntregaCard(_entregasPendientes[index], null),
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
                _buildNavItem(Icons.route, 'Ruta', false, _verRuta),
                _buildNavItem(Icons.chat, 'Chat', false, () => Navigator.pushNamed(context, '/chat')),
                _buildNavItem(Icons.water_drop, 'Inventario', false, _verInventario),
                _buildNavItem(Icons.person, 'Perfil', false, _verPerfil),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
      ],
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
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
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

  Widget _buildEntregaCard(Map<String, dynamic> entrega, int? numeroRuta) {
    final cliente = entrega['cliente'];
    final nombreCliente = cliente?['nombre'] ?? 'Sin nombre';
    final direccion = cliente?['direccion'] ?? 'Sin dirección';
    final referencias = cliente?['referencias'] ?? '';
    final estado = entrega['estado'] ?? 'pendiente';
    final garrafones = entrega['garrafones_solicitados'] ?? 0;
    
    Color estadoColor;
    IconData estadoIcon;
    switch (estado) {
      case 'pendiente':
        estadoColor = Colors.orange;
        estadoIcon = Icons.schedule;
        break;
      case 'en_camino':
        estadoColor = Colors.blue;
        estadoIcon = Icons.local_shipping;
        break;
      case 'entregado':
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle;
        break;
      case 'no_entregado':
        estadoColor = Colors.red;
        estadoIcon = Icons.cancel;
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: numeroRuta != null ? Border.all(color: Colors.blueAccent.withOpacity(0.3)) : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (numeroRuta != null)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$numeroRuta',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (numeroRuta != null) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nombreCliente,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(estadoIcon, color: estadoColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            estado.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white54, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        direccion,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (referencias.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          referencias,
                          style: const TextStyle(color: Colors.amber, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Garrafones
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.water_drop, color: Colors.cyan, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$garrafones garrafones',
                            style: const TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Total
                    Text(
                      _formatCurrency.format(entrega['total'] ?? 0),
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Acciones
          if (estado != 'entregado' && estado != 'no_entregado')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  if (cliente?['telefono'] != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.phone, size: 16),
                        label: const Text('Llamar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          side: const BorderSide(color: Colors.greenAccent),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('Navegar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _marcarEntregado(entrega),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Entregar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? Colors.blueAccent : Colors.white54, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: isActive ? Colors.blueAccent : Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _toggleDisponibilidad(bool value) async {
    try {
      await AppSupabase.client
          .from('purificadora_repartidores')
          .update({'disponible': value})
          .eq('id', _repartidor!['id']);
      
      setState(() {
        _repartidor!['disponible'] = value;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '¡Listo para repartir!' : 'Ahora estás no disponible'),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('Error cambiando disponibilidad: $e');
    }
  }

  void _iniciarRuta() async {
    try {
      // Marcar todas las entregas pendientes como en_camino
      for (var entrega in _entregasHoy.where((e) => e['estado'] == 'pendiente')) {
        await AppSupabase.client
            .from('purificadora_entregas')
            .update({
              'estado': 'en_camino',
              'hora_salida': DateTime.now().toIso8601String(),
            })
            .eq('id', entrega['id']);
      }

      await _cargarDatos();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Ruta iniciada! Buena suerte 🚛'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error iniciando ruta: $e');
    }
  }

  void _marcarEntregado(Map<String, dynamic> entrega) async {
    // Mostrar diálogo para confirmar entrega
    final garrafonesSolicitados = entrega['garrafones_solicitados'] ?? 0;
    int garrafonesEntregados = garrafonesSolicitados;
    int garrafonesRecogidos = 0;
    double totalCobrado = (entrega['total'] ?? 0).toDouble();
    bool efectivo = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Confirmar Entrega', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entrega['cliente']?['nombre'] ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                // Garrafones entregados
                Row(
                  children: [
                    const Expanded(child: Text('Garrafones entregados:', style: TextStyle(color: Colors.white))),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: garrafonesEntregados > 0 ? () => setDialogState(() => garrafonesEntregados--) : null,
                    ),
                    Text('$garrafonesEntregados', style: const TextStyle(color: Colors.cyan, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => setDialogState(() => garrafonesEntregados++),
                    ),
                  ],
                ),
                // Garrafones recogidos (vacíos)
                Row(
                  children: [
                    const Expanded(child: Text('Garrafones recogidos:', style: TextStyle(color: Colors.white))),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: garrafonesRecogidos > 0 ? () => setDialogState(() => garrafonesRecogidos--) : null,
                    ),
                    Text('$garrafonesRecogidos', style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => setDialogState(() => garrafonesRecogidos++),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Total
                Row(
                  children: [
                    const Text('Total cobrado: ', style: TextStyle(color: Colors.white)),
                    Expanded(
                      child: TextFormField(
                        initialValue: totalCobrado.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(color: Colors.greenAccent),
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => totalCobrado = double.tryParse(v) ?? totalCobrado,
                      ),
                    ),
                  ],
                ),
                // Método de pago
                Row(
                  children: [
                    const Text('Método: ', style: TextStyle(color: Colors.white)),
                    ChoiceChip(
                      label: const Text('Efectivo'),
                      selected: efectivo,
                      onSelected: (v) => setDialogState(() => efectivo = true),
                      selectedColor: Colors.green.withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Transfer'),
                      selected: !efectivo,
                      onSelected: (v) => setDialogState(() => efectivo = false),
                      selectedColor: Colors.blue.withOpacity(0.3),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                // Marcar como no entregado
                await AppSupabase.client
                    .from('purificadora_entregas')
                    .update({
                      'estado': 'no_entregado',
                      'hora_entrega': DateTime.now().toIso8601String(),
                      'notas': 'No se pudo entregar',
                    })
                    .eq('id', entrega['id']);
                Navigator.pop(context, true);
              },
              child: const Text('No Entregado', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                await AppSupabase.client
                    .from('purificadora_entregas')
                    .update({
                      'estado': 'entregado',
                      'hora_entrega': DateTime.now().toIso8601String(),
                      'garrafones_entregados': garrafonesEntregados,
                      'garrafones_recogidos': garrafonesRecogidos,
                      'total_cobrado': totalCobrado,
                      'metodo_pago': efectivo ? 'efectivo' : 'transferencia',
                    })
                    .eq('id', entrega['id']);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Entrega registrada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _verRuta() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.route, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  const Text(
                    'Mi Ruta del Día',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_entregasHoy.length} paradas',
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _entregasHoy.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay entregas programadas para hoy',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _entregasHoy.length,
                      itemBuilder: (context, index) {
                        final entrega = _entregasHoy[index];
                        return _buildRutaItem(entrega, index + 1);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRutaItem(Map<String, dynamic> entrega, int numero) {
    final cliente = entrega['cliente'];
    final estado = entrega['estado'] ?? 'pendiente';
    final completado = estado == 'entregado' || estado == 'no_entregado';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: completado ? Colors.green.withOpacity(0.1) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completado ? Colors.green.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: completado ? Colors.green : Colors.blueAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: completado
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '$numero',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente?['nombre'] ?? 'Sin nombre',
                  style: TextStyle(
                    color: completado ? Colors.white54 : Colors.white,
                    fontWeight: FontWeight.bold,
                    decoration: completado ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  cliente?['direccion'] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${entrega['garrafones_solicitados'] ?? 0}',
            style: TextStyle(
              color: completado ? Colors.green : Colors.cyan,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Icon(Icons.water_drop, color: Colors.cyan, size: 16),
        ],
      ),
    );
  }

  /// Historial de entregas - disponible para uso futuro
  // ignore: unused_element
  void _verHistorial() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FutureBuilder(
        future: _cargarHistorialEntregas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
            );
          }

          final historial = snapshot.data ?? [];

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      const Text(
                        'Historial de Entregas',
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
                  child: historial.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay entregas en el historial',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: historial.length,
                          itemBuilder: (context, index) {
                            final entrega = historial[index];
                            return _buildHistorialItem(entrega);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _cargarHistorialEntregas() async {
    if (_repartidor == null) return [];

    final res = await AppSupabase.client
        .from('purificadora_entregas')
        .select('''
          *,
          cliente:purificadora_clientes(nombre, direccion)
        ''')
        .eq('repartidor_id', _repartidor!['id'])
        .inFilter('estado', ['entregado', 'no_entregado'])
        .order('fecha_entrega', ascending: false)
        .limit(30);

    return List<Map<String, dynamic>>.from(res);
  }

  Widget _buildHistorialItem(Map<String, dynamic> entrega) {
    final cliente = entrega['cliente'];
    final fecha = entrega['fecha_entrega'] != null
        ? DateTime.parse(entrega['fecha_entrega'])
        : DateTime.now();
    final estado = entrega['estado'] ?? '';
    final entregado = estado == 'entregado';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: entregado ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              entregado ? Icons.check_circle : Icons.cancel,
              color: entregado ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente?['nombre'] ?? 'Sin nombre',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatDate.format(fecha),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entrega['garrafones_entregados'] ?? 0} garrafones',
                style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
              ),
              Text(
                _formatCurrency.format(entrega['total_cobrado'] ?? 0),
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _verInventario() {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.water_drop, color: Colors.blueAccent),
                SizedBox(width: 12),
                Text(
                  'Mi Inventario',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInventarioItem(
              'Garrafones Cargados',
              '${_repartidor?['garrafones_cargados'] ?? 0}',
              Icons.water_drop,
              Colors.cyan,
            ),
            _buildInventarioItem(
              'Garrafones Vacíos',
              '${_repartidor?['garrafones_vacios'] ?? 0}',
              Icons.water_drop_outlined,
              Colors.orange,
            ),
            _buildInventarioItem(
              'Efectivo en Mano',
              _formatCurrency.format(_repartidor?['efectivo_en_mano'] ?? 0),
              Icons.attach_money,
              Colors.green,
            ),
            _buildInventarioItem(
              'Entregas Hoy',
              '${_entregasHoy.where((e) => e['estado'] == 'entregado').length}/${_entregasHoy.length}',
              Icons.local_shipping,
              Colors.blue,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _reportarCorte,
                icon: const Icon(Icons.receipt_long),
                label: const Text('Reportar Corte de Caja'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventarioItem(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  void _reportarCorte() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de corte de caja próximamente'),
        backgroundColor: Colors.blueAccent,
      ),
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
              radius: 45,
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              child: const Icon(Icons.local_shipping, color: Colors.blueAccent, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              _repartidor!['nombre'] ?? 'Repartidor',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              _repartidor!['codigo'] ?? '',
              style: const TextStyle(color: Colors.blueAccent),
            ),
            if (_repartidor!['vehiculo'] != null) ...[
              const SizedBox(height: 8),
              Text(
                '🚛 ${_repartidor!['vehiculo']} - ${_repartidor!['placas'] ?? ''}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 20),
            _buildPerfilItem(Icons.phone, _repartidor!['telefono'] ?? 'Sin teléfono'),
            _buildPerfilItem(Icons.email, _repartidor!['email'] ?? 'Sin email'),
            _buildPerfilItem(Icons.money, 'Comisión: \$${_repartidor!['comision_garrrafon'] ?? 2}/garrafón'),
            _buildPerfilItem(Icons.delivery_dining, 'Entregas mes: ${_stats['entregadas_mes'] ?? 0}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _cerrarSesion();
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerfilItem(IconData icon, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

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
