// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// APP DEL TÉCNICO CLIMAS - V1.0
/// ═══════════════════════════════════════════════════════════════════════════════
/// Panel de campo para técnicos donde pueden:
/// - Ver órdenes asignadas del día
/// - Navegar con GPS al cliente
/// - Registrar entrada/salida
/// - Completar checklist de servicio
/// - Tomar fotos antes/después
/// - Capturar firma del cliente
/// - Reportar materiales usados
/// - Solicitar refacciones
/// - Reportar incidencias
/// ═══════════════════════════════════════════════════════════════════════════════

class ClimasTecnicoAppScreen extends StatefulWidget {
  final String? tecnicoId; // Opcional: si no se pasa, usa el usuario actual
  const ClimasTecnicoAppScreen({super.key, this.tecnicoId});

  @override
  State<ClimasTecnicoAppScreen> createState() => _ClimasTecnicoAppScreenState();
}

class _ClimasTecnicoAppScreenState extends State<ClimasTecnicoAppScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  late TabController _tabController;
  bool _isLoading = true;
  late String _tecnicoId;
  
  Map<String, dynamic>? _tecnico;
  List<Map<String, dynamic>> _ordenesHoy = [];
  List<Map<String, dynamic>> _ordenesPendientes = [];
  List<Map<String, dynamic>> _ordenesCompletadas = [];
  List<Map<String, dynamic>> _miInventario = [];
  List<Map<String, dynamic>> _misSolicitudesRefacciones = [];
  
  // Stats del día
  int _completadasHoy = 0;
  double _ingresoHoy = 0;
  int _pendientesHoy = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _inicializar();
  }

  Future<void> _inicializar() async {
    // Obtener tecnicoId del parámetro o buscar por usuario actual
    if (widget.tecnicoId != null) {
      _tecnicoId = widget.tecnicoId!;
    } else {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          final tecnico = await AppSupabase.client
              .from('climas_tecnicos')
              .select('id')
              .eq('auth_uid', userId)
              .maybeSingle();
          if (tecnico != null) {
            _tecnicoId = tecnico['id'];
          } else {
            _tecnicoId = userId; // Fallback
          }
        } catch (_) {
          _tecnicoId = userId;
        }
      } else {
        _tecnicoId = '';
      }
    }
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    if (_tecnicoId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      // Datos del técnico
      final tecnicoRes = await AppSupabase.client
          .from('climas_tecnicos')
          .select()
          .eq('id', _tecnicoId)
          .single();
      _tecnico = tecnicoRes;

      final hoy = DateTime.now().toIso8601String().split('T')[0];

      // Órdenes de hoy
      try {
        final ordenesRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('*, climas_clientes(nombre, telefono, direccion, whatsapp)')
            .eq('tecnico_id', _tecnicoId)
            .gte('fecha_programada', '${hoy}T00:00:00')
            .lte('fecha_programada', '${hoy}T23:59:59')
            .order('fecha_programada');
        _ordenesHoy = List<Map<String, dynamic>>.from(ordenesRes);
        
        _completadasHoy = _ordenesHoy.where((o) => o['estado'] == 'completada').length;
        _pendientesHoy = _ordenesHoy.where((o) => o['estado'] != 'completada' && o['estado'] != 'cancelada').length;
        _ingresoHoy = _ordenesHoy.where((o) => o['estado'] == 'completada').fold(0.0, (sum, o) => sum + (o['total'] ?? 0).toDouble());
      } catch (_) {}

      // Órdenes pendientes (futuras)
      try {
        final pendientesRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('*, climas_clientes(nombre, telefono, direccion)')
            .eq('tecnico_id', _tecnicoId)
            .inFilter('estado', ['pendiente', 'asignada'])
            .gt('fecha_programada', '${hoy}T23:59:59')
            .order('fecha_programada')
            .limit(20);
        _ordenesPendientes = List<Map<String, dynamic>>.from(pendientesRes);
      } catch (_) {}

      // Órdenes completadas recientes
      try {
        final completadasRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('*, climas_clientes(nombre)')
            .eq('tecnico_id', _tecnicoId)
            .eq('estado', 'completada')
            .order('fecha_fin', ascending: false)
            .limit(10);
        _ordenesCompletadas = List<Map<String, dynamic>>.from(completadasRes);
      } catch (_) {}

      // Mi inventario
      try {
        final invRes = await AppSupabase.client
            .from('climas_inventario_tecnico')
            .select('*, climas_productos(nombre, codigo)')
            .eq('tecnico_id', _tecnicoId);
        _miInventario = List<Map<String, dynamic>>.from(invRes);
      } catch (_) {}

      // Mis solicitudes de refacciones
      try {
        final solRes = await AppSupabase.client
            .from('climas_solicitudes_refacciones')
            .select()
            .eq('tecnico_id', _tecnicoId)
            .order('created_at', ascending: false)
            .limit(10);
        _misSolicitudesRefacciones = List<Map<String, dynamic>>.from(solRes);
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando datos técnico: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '👷 Mi Panel',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildResumenDia(),
                _buildTabs(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrdenesHoy(),
                      _buildOrdenesPendientes(),
                      _buildMiInventario(),
                      _buildMiPerfil(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumenDia() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0891B2).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  _tecnico?['nombre']?.toString().substring(0, 1).toUpperCase() ?? 'T',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Hola, ${_tecnico?['nombre']?.split(' ')[0] ?? 'Técnico'}!',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('EEEE dd MMMM', 'es').format(DateTime.now()),
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard('Pendientes', '$_pendientesHoy', Icons.pending_actions, const Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              _buildStatCard('Completadas', '$_completadasHoy', Icons.check_circle, const Color(0xFF10B981)),
              const SizedBox(width: 12),
              _buildStatCard('Ingresos', _currencyFormat.format(_ingresoHoy), Icons.attach_money, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF00D9FF),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: const [
          Tab(text: 'Hoy'),
          Tab(text: 'Próximas'),
          Tab(text: 'Inventario'),
          Tab(text: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildOrdenesHoy() {
    if (_ordenesHoy.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'Sin órdenes para hoy',
        subtitle: 'Revisa las próximas órdenes',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _ordenesHoy.length,
        itemBuilder: (context, index) => _buildOrdenCard(_ordenesHoy[index], esHoy: true),
      ),
    );
  }

  Widget _buildOrdenesPendientes() {
    if (_ordenesPendientes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_note,
        title: 'Sin órdenes pendientes',
        subtitle: 'No hay servicios programados',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _ordenesPendientes.length,
        itemBuilder: (context, index) => _buildOrdenCard(_ordenesPendientes[index], esHoy: false),
      ),
    );
  }

  Widget _buildOrdenCard(Map<String, dynamic> orden, {required bool esHoy}) {
    final cliente = orden['climas_clientes'] ?? {};
    final estado = orden['estado'] ?? 'pendiente';
    final estadoColor = _getEstadoColor(estado);
    final fecha = DateTime.tryParse(orden['fecha_programada'] ?? '');
    final tipo = orden['tipo_servicio'] ?? 'mantenimiento';
    final prioridad = orden['prioridad'] ?? 'normal';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: prioridad == 'urgente' || prioridad == 'alta'
              ? const Color(0xFFEF4444).withOpacity(0.5)
              : estadoColor.withOpacity(0.3),
          width: prioridad == 'urgente' ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header con estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getEstadoLabel(estado),
                    style: TextStyle(color: estadoColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tipo.toUpperCase(),
                    style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (prioridad == 'urgente' || prioridad == 'alta')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.priority_high, color: Colors.white, size: 12),
                        Text(
                          prioridad.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                if (fecha != null)
                  Text(
                    DateFormat('HH:mm').format(fecha),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
              ],
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Folio
                Text(
                  orden['folio'] ?? 'Sin folio',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                const SizedBox(height: 8),
                // Cliente
                Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF00D9FF), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cliente['nombre'] ?? 'Cliente',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    // Acciones rápidas
                    if (cliente['telefono'] != null)
                      IconButton(
                        icon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                        onPressed: () => _llamar(cliente['telefono']),
                        tooltip: 'Llamar',
                        iconSize: 20,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    if (cliente['whatsapp'] != null)
                      IconButton(
                        icon: const Icon(Icons.message, color: Color(0xFF25D366)),
                        onPressed: () => _abrirWhatsApp(cliente['whatsapp']),
                        tooltip: 'WhatsApp',
                        iconSize: 20,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Dirección
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white.withOpacity(0.5), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        orden['direccion_servicio'] ?? cliente['direccion'] ?? 'Sin dirección',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                        maxLines: 2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigation, color: Color(0xFF3B82F6)),
                      onPressed: () => _navegarGPS(orden['direccion_servicio'] ?? cliente['direccion']),
                      tooltip: 'Navegar',
                      iconSize: 20,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
                // Descripción del problema
                if (orden['descripcion_problema'] != null && orden['descripcion_problema'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            orden['descripcion_problema'],
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Acciones según estado
                if (esHoy && estado != 'completada' && estado != 'cancelada') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (estado == 'pendiente' || estado == 'asignada')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _iniciarServicio(orden),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Iniciar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (estado == 'en_proceso') ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _abrirDetalleOrden(orden),
                            icon: const Icon(Icons.checklist, size: 18),
                            label: const Text('Trabajar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _completarServicio(orden),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Completar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _reportarIncidencia(orden),
                        icon: const Icon(Icons.warning_amber, color: Color(0xFFF59E0B)),
                        tooltip: 'Reportar Problema',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiInventario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botón solicitar refacciones
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _solicitarRefacciones(),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Solicitar Refacciones'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Mi inventario
          const Text(
            'Mi Inventario',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_miInventario.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 50, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 10),
                    Text(
                      'Sin materiales asignados',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_miInventario.map((item) => _buildInventarioCard(item))),
          
          const SizedBox(height: 24),
          
          // Solicitudes pendientes
          if (_misSolicitudesRefacciones.isNotEmpty) ...[
            const Text(
              'Mis Solicitudes',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._misSolicitudesRefacciones.take(5).map((s) => _buildSolicitudRefaccionCard(s)),
          ],
        ],
      ),
    );
  }

  Widget _buildInventarioCard(Map<String, dynamic> item) {
    final producto = item['climas_productos'] ?? {};
    final cantidad = item['cantidad'] ?? 0;
    final minimo = item['cantidad_minima'] ?? 1;
    final stockBajo = cantidad <= minimo;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stockBajo ? const Color(0xFFEF4444).withOpacity(0.5) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: stockBajo 
                  ? const Color(0xFFEF4444).withOpacity(0.2) 
                  : const Color(0xFF00D9FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.build,
              color: stockBajo ? const Color(0xFFEF4444) : const Color(0xFF00D9FF),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['nombre'] ?? 'Producto',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  producto['codigo'] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$cantidad',
                style: TextStyle(
                  color: stockBajo ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Text(
                'Mín: $minimo',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudRefaccionCard(Map<String, dynamic> solicitud) {
    final estado = solicitud['estado'] ?? 'pendiente';
    final estadoColor = estado == 'aprobada' 
        ? const Color(0xFF10B981) 
        : estado == 'entregada'
            ? const Color(0xFF3B82F6)
            : estado == 'rechazada'
                ? const Color(0xFFEF4444)
                : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory, color: estadoColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitud de refacciones',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  solicitud['notas'] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              estado.toUpperCase(),
              style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiPerfil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Card de perfil
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF00D9FF).withOpacity(0.2),
                  child: Text(
                    _tecnico?['nombre']?.toString().substring(0, 1).toUpperCase() ?? 'T',
                    style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _tecnico?['nombre'] ?? 'Técnico',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _tecnico?['especialidad'] ?? 'General',
                    style: const TextStyle(color: Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 20),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPerfilStat('Nivel', _tecnico?['nivel'] ?? 'Jr'),
                    _buildPerfilStat('Comisión', '${_tecnico?['comision_porcentaje'] ?? 0}%'),
                    _buildPerfilStat('Activo', _tecnico?['activo'] == true ? 'Sí' : 'No'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Opciones
          _buildOpcionPerfil(Icons.school, 'Mis Certificaciones', () => _verCertificaciones()),
          _buildOpcionPerfil(Icons.bar_chart, 'Mis Métricas', () => _verMetricas()),
          _buildOpcionPerfil(Icons.map, 'Mis Zonas', () => _verZonas()),
          _buildOpcionPerfil(Icons.history, 'Historial Servicios', () {}),
          _buildOpcionPerfil(Icons.settings, 'Configuración', () {}),
        ],
      ),
    );
  }

  Widget _buildPerfilStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildOpcionPerfil(IconData icon, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00D9FF)),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return const Color(0xFFF59E0B);
      case 'asignada': return const Color(0xFF3B82F6);
      case 'en_proceso': return const Color(0xFF8B5CF6);
      case 'completada': return const Color(0xFF10B981);
      case 'cancelada': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'pendiente': return 'Pendiente';
      case 'asignada': return 'Asignada';
      case 'en_proceso': return 'En Proceso';
      case 'completada': return 'Completada';
      case 'cancelada': return 'Cancelada';
      default: return estado;
    }
  }

  Future<void> _llamar(String? telefono) async {
    if (telefono == null) return;
    final uri = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _abrirWhatsApp(String? numero) async {
    if (numero == null) return;
    final numeroLimpio = numero.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/52$numeroLimpio');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _navegarGPS(String? direccion) async {
    if (direccion == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(direccion)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _iniciarServicio(Map<String, dynamic> orden) async {
    try {
      await AppSupabase.client.from('climas_ordenes_servicio').update({
        'estado': 'en_proceso',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orden['id']);

      // Registrar entrada
      await AppSupabase.client.from('climas_registro_tiempo').insert({
        'orden_id': orden['id'],
        'tecnico_id': _tecnicoId,
        'tipo': 'entrada',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Servicio iniciado'), backgroundColor: Color(0xFF10B981)),
        );
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirDetalleOrden(Map<String, dynamic> orden) {
    Navigator.pushNamed(context, AppRoutes.climasTecnicoOrden, arguments: orden['id']);
  }

  Future<void> _completarServicio(Map<String, dynamic> orden) async {
    // Mostrar diálogo para completar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Completar Servicio', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de completar este servicio?\n\nAsegúrate de haber:\n• Completado el checklist\n• Tomado fotos\n• Capturado firma del cliente',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Completar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await AppSupabase.client.from('climas_ordenes_servicio').update({
        'estado': 'completada',
        'fecha_fin': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orden['id']);

      // Registrar salida
      await AppSupabase.client.from('climas_registro_tiempo').insert({
        'orden_id': orden['id'],
        'tecnico_id': _tecnicoId,
        'tipo': 'salida',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Servicio completado'), backgroundColor: Color(0xFF10B981)),
        );
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _reportarIncidencia(Map<String, dynamic> orden) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportarIncidenciaSheet(
        ordenId: orden['id'],
        tecnicoId: _tecnicoId,
        onReportada: _cargarDatos,
      ),
    );
  }

  void _solicitarRefacciones() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud de refacciones próximamente...'), backgroundColor: Color(0xFF3B82F6)),
    );
  }

  void _verCertificaciones() {
    Navigator.pushNamed(context, AppRoutes.climasTecnicoCertificaciones, arguments: _tecnicoId);
  }

  void _verMetricas() {
    Navigator.pushNamed(context, AppRoutes.climasTecnicoMetricas, arguments: _tecnicoId);
  }

  void _verZonas() {
    Navigator.pushNamed(context, AppRoutes.climasTecnicoZonas, arguments: _tecnicoId);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// SHEET REPORTAR INCIDENCIA
/// ═══════════════════════════════════════════════════════════════════════════════
class _ReportarIncidenciaSheet extends StatefulWidget {
  final String ordenId;
  final String tecnicoId;
  final VoidCallback onReportada;

  const _ReportarIncidenciaSheet({
    required this.ordenId,
    required this.tecnicoId,
    required this.onReportada,
  });

  @override
  State<_ReportarIncidenciaSheet> createState() => _ReportarIncidenciaSheetState();
}

class _ReportarIncidenciaSheetState extends State<_ReportarIncidenciaSheet> {
  final _descripcionController = TextEditingController();
  String _tipo = 'otro';
  String _gravedad = 'media';
  bool _guardando = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Color(0xFFF59E0B)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Reportar Incidencia', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipo de Incidencia', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChipTipo('Cliente Ausente', 'cliente_ausente'),
                      _buildChipTipo('Acceso Negado', 'acceso_negado'),
                      _buildChipTipo('Equipo Inaccesible', 'equipo_inaccesible'),
                      _buildChipTipo('Material Faltante', 'material_faltante'),
                      _buildChipTipo('Otro', 'otro'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Gravedad', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildChipGravedad('Baja', 'baja', Colors.green),
                      const SizedBox(width: 8),
                      _buildChipGravedad('Media', 'media', Colors.orange),
                      const SizedBox(width: 8),
                      _buildChipGravedad('Alta', 'alta', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Descripción *', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descripcionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Describe la incidencia...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _reportar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _guardando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Reportar Incidencia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipTipo(String label, String value) {
    final selected = _tipo == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _tipo = value),
      selectedColor: const Color(0xFFF59E0B),
      backgroundColor: const Color(0xFF1A1A2E),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70),
    );
  }

  Widget _buildChipGravedad(String label, String value, Color color) {
    final selected = _gravedad == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gravedad = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.3) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : Colors.transparent),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: selected ? color : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
      ),
    );
  }

  Future<void> _reportar() async {
    if (_descripcionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe la incidencia'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await AppSupabase.client.from('climas_incidencias').insert({
        'orden_id': widget.ordenId,
        'tecnico_id': widget.tecnicoId,
        'tipo': _tipo,
        'gravedad': _gravedad,
        'descripcion': _descripcionController.text.trim(),
        'estado': 'abierta',
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onReportada();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Incidencia reportada'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
