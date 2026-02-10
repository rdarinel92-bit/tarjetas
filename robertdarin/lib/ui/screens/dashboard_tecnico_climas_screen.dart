// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD TÉCNICO DE CLIMAS - Panel de Trabajo para Técnicos
// Robert Darin Platform v10.22 - VERSIÓN MEJORADA CON FUNCIONALIDADES COMPLETAS
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class DashboardTecnicoClimasScreen extends StatefulWidget {
  const DashboardTecnicoClimasScreen({super.key});

  @override
  State<DashboardTecnicoClimasScreen> createState() => _DashboardTecnicoClimasScreenState();
}

class _DashboardTecnicoClimasScreenState extends State<DashboardTecnicoClimasScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _tecnico;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _serviciosHoy = [];
  List<Map<String, dynamic>> _serviciosPendientes = [];
  List<Map<String, dynamic>> _historialServicios = [];
  List<Map<String, dynamic>> _serviciosSemana = [];
  int _selectedNavIndex = 0;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _formatDate = DateFormat('dd/MM/yyyy');
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

      // Buscar técnico por auth_uid
      final tecnicoRes = await AppSupabase.client
          .from('climas_tecnicos')
          .select('*')
          .eq('auth_uid', user.id)
          .eq('activo', true)
          .maybeSingle();

      if (tecnicoRes == null) {
        // Intentar buscar por email
        final tecnicoByEmail = await AppSupabase.client
            .from('climas_tecnicos')
            .select('*')
            .eq('email', user.email ?? '')
            .eq('activo', true)
            .maybeSingle();
        
        if (tecnicoByEmail != null) {
          _tecnico = tecnicoByEmail;
          // Vincular auth_uid
          await AppSupabase.client
              .from('climas_tecnicos')
              .update({'auth_uid': user.id})
              .eq('id', tecnicoByEmail['id']);
        }
      } else {
        _tecnico = tecnicoRes;
      }

      if (_tecnico != null) {
        await Future.wait([
          _cargarEstadisticas(),
          _cargarServiciosHoy(),
          _cargarServiciosPendientes(),
          _cargarHistorialServicios(),
          _cargarServiciosSemana(),
        ]);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error cargando datos técnico: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarEstadisticas() async {
    if (_tecnico == null) return;
    
    final tecnicoId = _tecnico!['id'];
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);

    // Servicios del mes
    final serviciosMes = await AppSupabase.client
        .from('climas_ordenes_servicio')
        .select('id, total, estado')
        .eq('tecnico_id', tecnicoId)
        .gte('fecha_programada', inicioMes.toIso8601String());

    int completados = 0;
    double totalGanado = 0;
    for (var s in serviciosMes) {
      if (s['estado'] == 'completado') {
        completados++;
        totalGanado += (s['total'] ?? 0).toDouble() * ((_tecnico!['comision_servicio'] ?? 10) / 100);
      }
    }

    _stats = {
      'servicios_hoy': _serviciosHoy.length,
      'servicios_mes': serviciosMes.length,
      'completados_mes': completados,
      'ganado_mes': totalGanado,
      'calificacion': _tecnico!['calificacion_promedio'] ?? 5.0,
    };
  }

  Future<void> _cargarServiciosHoy() async {
    if (_tecnico == null) return;
    
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final manana = hoy.add(const Duration(days: 1));

    final res = await AppSupabase.client
        .from('climas_ordenes_servicio')
        .select('''
          *,
          cliente:climas_clientes(nombre, telefono, direccion)
        ''')
        .eq('tecnico_id', _tecnico!['id'])
        .gte('fecha_programada', hoy.toIso8601String())
        .lt('fecha_programada', manana.toIso8601String())
        .order('fecha_programada');

    _serviciosHoy = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarServiciosPendientes() async {
    if (_tecnico == null) return;

    final res = await AppSupabase.client
        .from('climas_ordenes_servicio')
        .select('''
          *,
          cliente:climas_clientes(nombre, telefono, direccion)
        ''')
        .eq('tecnico_id', _tecnico!['id'])
        .inFilter('estado', ['asignado', 'en_camino', 'en_proceso'])
        .order('fecha_programada')
        .limit(10);

    _serviciosPendientes = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarHistorialServicios() async {
    if (_tecnico == null) return;

    final res = await AppSupabase.client
        .from('climas_ordenes_servicio')
        .select('''
          *,
          cliente:climas_clientes(nombre, telefono, direccion)
        ''')
        .eq('tecnico_id', _tecnico!['id'])
        .eq('estado', 'completado')
        .order('fecha_programada', ascending: false)
        .limit(20);

    _historialServicios = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarServiciosSemana() async {
    if (_tecnico == null) return;
    
    final now = DateTime.now();
    final inicioSemana = now.subtract(Duration(days: now.weekday - 1));
    final finSemana = inicioSemana.add(const Duration(days: 7));

    final res = await AppSupabase.client
        .from('climas_ordenes_servicio')
        .select('''
          *,
          cliente:climas_clientes(nombre, telefono, direccion)
        ''')
        .eq('tecnico_id', _tecnico!['id'])
        .gte('fecha_programada', inicioSemana.toIso8601String())
        .lt('fecha_programada', finSemana.toIso8601String())
        .order('fecha_programada');

    _serviciosSemana = List<Map<String, dynamic>>.from(res);
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
              const CircularProgressIndicator(color: Colors.cyanAccent),
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

    if (_tecnico == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.engineering, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'No se encontró tu perfil de técnico',
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
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
                      colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
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
                                  _tecnico!['nombre']?[0]?.toUpperCase() ?? '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
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
                                      '¡Hola, ${_tecnico!['nombre']}!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _tecnico!['codigo'] ?? 'Técnico',
                                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                    ),
                                  ],
                                ),
                              ),
                              // Estado disponible
                              Switch(
                                value: _tecnico!['disponible'] ?? false,
                                onChanged: (v) => _toggleDisponibilidad(v),
                                activeColor: Colors.greenAccent,
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '${(_stats['calificacion'] ?? 5.0).toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${_stats['servicios_mes'] ?? 0} servicios este mes',
                                style: TextStyle(color: Colors.white.withOpacity(0.8)),
                              ),
                            ],
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
                    // Stats
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(
                          '📅 Servicios Hoy',
                          '${_stats['servicios_hoy'] ?? 0}',
                          Colors.blue,
                        ),
                        _buildStatCard(
                          '✅ Completados',
                          '${_stats['completados_mes'] ?? 0}',
                          Colors.green,
                        ),
                        _buildStatCard(
                          '💰 Ganado (Mes)',
                          _formatCurrency.format(_stats['ganado_mes'] ?? 0),
                          Colors.purple,
                        ),
                        _buildStatCard(
                          '⭐ Calificación',
                          '${(_stats['calificacion'] ?? 5.0).toStringAsFixed(1)}/5',
                          Colors.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Servicios de hoy
                    const Text(
                      'Servicios de Hoy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_serviciosHoy.isEmpty)
                      _buildEmptyState('No tienes servicios programados hoy', Icons.event_busy)
                    else
                      ...List.generate(
                        _serviciosHoy.length,
                        (index) => _buildServicioCard(_serviciosHoy[index], esHoy: true),
                      ),
                    const SizedBox(height: 24),
                    // Servicios pendientes
                    if (_serviciosPendientes.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Servicios Pendientes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Ver todos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _serviciosPendientes.length.clamp(0, 5),
                        (index) => _buildServicioCard(_serviciosPendientes[index]),
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
                _buildNavItem(Icons.home, 'Inicio', _selectedNavIndex == 0, () => setState(() => _selectedNavIndex = 0)),
                _buildNavItem(Icons.calendar_today, 'Agenda', _selectedNavIndex == 1, () {
                  setState(() => _selectedNavIndex = 1);
                  _verAgenda();
                }),
                _buildNavItem(Icons.build, 'Servicios', _selectedNavIndex == 2, () => setState(() => _selectedNavIndex = 2)),
                _buildNavItem(Icons.history, 'Historial', _selectedNavIndex == 3, () {
                  setState(() => _selectedNavIndex = 3);
                  _verHistorial();
                }),
                _buildNavItem(Icons.chat, 'Soporte', _selectedNavIndex == 4, () {
                  setState(() => _selectedNavIndex = 4);
                  Navigator.pushNamed(context, '/chat');
                }),
                _buildNavItem(Icons.person, 'Perfil', _selectedNavIndex == 5, () {
                  setState(() => _selectedNavIndex = 5);
                  _verPerfil();
                }),
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
          Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
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

  Widget _buildServicioCard(Map<String, dynamic> servicio, {bool esHoy = false}) {
    final cliente = servicio['cliente'];
    final nombreCliente = cliente?['nombre'] ?? 'Sin nombre';
    final direccion = cliente?['direccion'] ?? 'Sin dirección';
    final estado = servicio['estado'] ?? 'pendiente';
    final tipoServicio = servicio['tipo_servicio'] ?? 'Servicio';
    
    Color estadoColor;
    switch (estado) {
      case 'asignado':
        estadoColor = Colors.orange;
        break;
      case 'en_camino':
        estadoColor = Colors.blue;
        break;
      case 'en_proceso':
        estadoColor = Colors.purple;
        break;
      case 'completado':
        estadoColor = Colors.green;
        break;
      default:
        estadoColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: esHoy ? Border.all(color: Colors.cyanAccent.withOpacity(0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tipoServicio,
                  style: TextStyle(color: estadoColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  estado.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: estadoColor, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nombreCliente,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  direccion,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (servicio['fecha_programada'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.cyanAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  _formatTime.format(DateTime.parse(servicio['fecha_programada'])),
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
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
                child: ElevatedButton.icon(
                  onPressed: () => _cambiarEstadoServicio(servicio),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text(_getBotonAccion(estado)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: estadoColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getBotonAccion(String estado) {
    switch (estado) {
      case 'asignado':
        return 'En Camino';
      case 'en_camino':
        return 'Llegué';
      case 'en_proceso':
        return 'Completar';
      default:
        return 'Iniciar';
    }
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? Colors.cyanAccent : Colors.white54, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: isActive ? Colors.cyanAccent : Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _toggleDisponibilidad(bool value) async {
    try {
      await AppSupabase.client
          .from('climas_tecnicos')
          .update({'disponible': value})
          .eq('id', _tecnico!['id']);
      
      setState(() {
        _tecnico!['disponible'] = value;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '¡Ahora estás disponible!' : 'Ahora estás no disponible'),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('Error cambiando disponibilidad: $e');
    }
  }

  void _cambiarEstadoServicio(Map<String, dynamic> servicio) async {
    String nuevoEstado;
    switch (servicio['estado']) {
      case 'asignado':
        nuevoEstado = 'en_camino';
        break;
      case 'en_camino':
        nuevoEstado = 'en_proceso';
        break;
      case 'en_proceso':
        // Mostrar diálogo para completar con detalles
        _mostrarDialogoCompletarServicio(servicio);
        return;
      default:
        return;
    }

    try {
      await AppSupabase.client
          .from('climas_ordenes_servicio')
          .update({
            'estado': nuevoEstado,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', servicio['id']);

      await _cargarDatos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estado actualizado: ${nuevoEstado.replaceAll('_', ' ')}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error cambiando estado: $e');
    }
  }

  void _mostrarDialogoCompletarServicio(Map<String, dynamic> servicio) {
    final diagnosticoController = TextEditingController(text: servicio['diagnostico'] ?? '');
    final trabajoController = TextEditingController(text: servicio['trabajo_realizado'] ?? '');
    final materialesController = TextEditingController();
    final costoMaterialesController = TextEditingController(text: '0');
    final costoManoObraController = TextEditingController(text: '0');
    String metodoPago = 'efectivo';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Completar Servicio',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Diagnóstico
                TextField(
                  controller: diagnosticoController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Diagnóstico',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Trabajo realizado
                TextField(
                  controller: trabajoController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Trabajo Realizado *',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Materiales utilizados
                TextField(
                  controller: materialesController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Materiales Utilizados',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Costos
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costoMaterialesController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Costo Materiales',
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(color: Colors.greenAccent),
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: costoManoObraController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Mano de Obra',
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(color: Colors.greenAccent),
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Método de pago
                const Text('Método de Pago', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Efectivo'),
                      selected: metodoPago == 'efectivo',
                      selectedColor: Colors.greenAccent,
                      onSelected: (s) => setSheetState(() => metodoPago = 'efectivo'),
                    ),
                    ChoiceChip(
                      label: const Text('Tarjeta'),
                      selected: metodoPago == 'tarjeta',
                      selectedColor: Colors.greenAccent,
                      onSelected: (s) => setSheetState(() => metodoPago = 'tarjeta'),
                    ),
                    ChoiceChip(
                      label: const Text('Transferencia'),
                      selected: metodoPago == 'transferencia',
                      selectedColor: Colors.greenAccent,
                      onSelected: (s) => setSheetState(() => metodoPago = 'transferencia'),
                    ),
                    ChoiceChip(
                      label: const Text('Pendiente'),
                      selected: metodoPago == 'pendiente',
                      selectedColor: Colors.orange,
                      onSelected: (s) => setSheetState(() => metodoPago = 'pendiente'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Botón completar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (trabajoController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ingresa el trabajo realizado'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      try {
                        final costoMateriales = double.tryParse(costoMaterialesController.text) ?? 0;
                        final costoManoObra = double.tryParse(costoManoObraController.text) ?? 0;
                        final total = costoMateriales + costoManoObra;

                        await AppSupabase.client
                            .from('climas_ordenes_servicio')
                            .update({
                              'estado': 'completado',
                              'diagnostico': diagnosticoController.text,
                              'trabajo_realizado': trabajoController.text,
                              'materiales_utilizados': materialesController.text,
                              'costo_materiales': costoMateriales,
                              'costo_mano_obra': costoManoObra,
                              'total': total,
                              'metodo_pago': metodoPago,
                              'pagado': metodoPago != 'pendiente',
                              'fecha_completado': DateTime.now().toIso8601String(),
                              'updated_at': DateTime.now().toIso8601String(),
                            })
                            .eq('id', servicio['id']);

                        Navigator.pop(context);
                        await _cargarDatos();
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('¡Servicio completado exitosamente!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Error completando servicio: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('COMPLETAR SERVICIO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _verAgenda() {
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
                  const Icon(Icons.calendar_today, color: Colors.cyanAccent),
                  const SizedBox(width: 12),
                  const Text(
                    'Mi Agenda de la Semana',
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
              child: _serviciosSemana.isEmpty
                  ? const Center(
                      child: Text(
                        'No tienes servicios esta semana',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _serviciosSemana.length,
                      itemBuilder: (context, index) {
                        final servicio = _serviciosSemana[index];
                        return _buildServicioAgendaCard(servicio);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicioAgendaCard(Map<String, dynamic> servicio) {
    final cliente = servicio['cliente'];
    final fecha = servicio['fecha_programada'] != null 
        ? DateTime.parse(servicio['fecha_programada'])
        : DateTime.now();
    final estado = servicio['estado'] ?? 'pendiente';

    Color estadoColor;
    switch (estado) {
      case 'completado': estadoColor = Colors.green; break;
      case 'en_proceso': estadoColor = Colors.purple; break;
      case 'en_camino': estadoColor = Colors.blue; break;
      default: estadoColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(fecha),
                  style: TextStyle(color: estadoColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('MMM').format(fecha).toUpperCase(),
                  style: TextStyle(color: estadoColor, fontSize: 10),
                ),
              ],
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
                  '${servicio['tipo_servicio'] ?? 'Servicio'} - ${_formatTime.format(fecha)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  cliente?['direccion'] ?? '',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              estado.replaceAll('_', ' '),
              style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _verHistorial() {
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
                  const Icon(Icons.history, color: Colors.cyanAccent),
                  const SizedBox(width: 12),
                  const Text(
                    'Historial de Servicios',
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
              child: _historialServicios.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay servicios completados',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _historialServicios.length,
                      itemBuilder: (context, index) {
                        final servicio = _historialServicios[index];
                        return _buildHistorialCard(servicio);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorialCard(Map<String, dynamic> servicio) {
    final cliente = servicio['cliente'];
    final fecha = servicio['fecha_programada'] != null 
        ? DateTime.parse(servicio['fecha_programada'])
        : DateTime.now();
    final total = servicio['total'] ?? 0;

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
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle, color: Colors.green),
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
                  '${servicio['tipo_servicio'] ?? 'Servicio'} - ${_formatDate.format(fecha)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
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
              backgroundColor: Colors.cyanAccent.withOpacity(0.2),
              child: Text(
                _tecnico!['nombre']?[0]?.toUpperCase() ?? '?',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tecnico!['nombre'] ?? 'Técnico',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              _tecnico!['codigo'] ?? '',
              style: const TextStyle(color: Colors.cyanAccent),
            ),
            const SizedBox(height: 20),
            
            // Especialidades
            if (_tecnico!['especialidades'] != null && (_tecnico!['especialidades'] as List).isNotEmpty) ...[
              const Text('Especialidades', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (_tecnico!['especialidades'] as List).map<Widget>((e) => Chip(
                  label: Text(e.toString(), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Info
            _buildPerfilItem(Icons.phone, _tecnico!['telefono'] ?? 'Sin teléfono'),
            _buildPerfilItem(Icons.email, _tecnico!['email'] ?? 'Sin email'),
            _buildPerfilItem(Icons.star, 'Calificación: ${(_tecnico!['calificacion_promedio'] ?? 5.0).toStringAsFixed(1)}/5'),
            _buildPerfilItem(Icons.money, 'Comisión: ${_tecnico!['comision_servicio'] ?? 10}%'),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cerrarSesion,
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
