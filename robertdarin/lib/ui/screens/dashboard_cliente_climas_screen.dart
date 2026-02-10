// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD CLIENTE CLIMAS - Portal para Clientes de Aire Acondicionado
// Robert Darin Platform v10.21
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class DashboardClienteClimasScreen extends StatefulWidget {
  const DashboardClienteClimasScreen({super.key});

  @override
  State<DashboardClienteClimasScreen> createState() => _DashboardClienteClimasScreenState();
}

class _DashboardClienteClimasScreenState extends State<DashboardClienteClimasScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _equipos = [];
  List<Map<String, dynamic>> _serviciosActivos = [];
  List<Map<String, dynamic>> _historialServicios = [];
  
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
          .from('climas_clientes')
          .select('*')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (clienteRes == null) {
        clienteRes = await AppSupabase.client
            .from('climas_clientes')
            .select('*')
            .eq('email', user.email ?? '')
            .maybeSingle();
        
        if (clienteRes != null) {
          // Vincular auth_uid
          await AppSupabase.client
              .from('climas_clientes')
              .update({'auth_uid': user.id})
              .eq('id', clienteRes['id']);
        }
      }

      _cliente = clienteRes;

      if (_cliente != null) {
        await Future.wait([
          _cargarEquipos(),
          _cargarServicios(),
        ]);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando datos cliente climas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarEquipos() async {
    if (_cliente == null) return;
    
    final res = await AppSupabase.client
        .from('climas_equipos')
        .select('*')
        .eq('cliente_id', _cliente!['id'])
        .order('created_at', ascending: false);
    
    _equipos = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _cargarServicios() async {
    if (_cliente == null) return;
    
    // Servicios activos
    final activos = await AppSupabase.client
        .from('climas_ordenes_servicio')
        .select('''
          *,
          tecnico:climas_tecnicos(nombre, telefono)
        ''')
        .eq('cliente_id', _cliente!['id'])
        .inFilter('estado', ['pendiente', 'asignado', 'en_camino', 'en_proceso'])
        .order('fecha_programada');
    
    _serviciosActivos = List<Map<String, dynamic>>.from(activos);

    // Historial
    final historial = await AppSupabase.client
        .from('climas_ordenes_servicio')
        .select('''
          *,
          tecnico:climas_tecnicos(nombre)
        ''')
        .eq('cliente_id', _cliente!['id'])
        .inFilter('estado', ['completado', 'cancelado'])
        .order('fecha_programada', ascending: false)
        .limit(10);
    
    _historialServicios = List<Map<String, dynamic>>.from(historial);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
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
                const Icon(Icons.ac_unit, size: 64, color: Colors.cyanAccent),
                const SizedBox(height: 16),
                const Text(
                  'Bienvenido',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aún no tienes un perfil de cliente registrado.\nContacta a la empresa para registrarte.',
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
              expandedHeight: 160,
              pinned: true,
              backgroundColor: const Color(0xFF0D0D14),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00BCD4), Color(0xFF00838F)],
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
                                radius: 25,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: const Icon(Icons.person, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _cliente!['nombre'] ?? 'Cliente',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${_equipos.length} equipos registrados',
                                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              _buildHeaderChip(Icons.ac_unit, '${_equipos.length} Equipos'),
                              const SizedBox(width: 8),
                              _buildHeaderChip(Icons.build, '${_serviciosActivos.length} Servicios'),
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
                    // Acción rápida - Solicitar servicio
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.cyan.withOpacity(0.3), Colors.blue.withOpacity(0.2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.build_circle, color: Colors.cyanAccent, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '¿Necesitas servicio?',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Solicita mantenimiento o reparación',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _solicitarServicio(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Solicitar'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Servicios activos
                    if (_serviciosActivos.isNotEmpty) ...[
                      const Text(
                        'Servicios en Proceso',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _serviciosActivos.length,
                        (index) => _buildServicioActivoCard(_serviciosActivos[index]),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Mis equipos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mis Equipos',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_equipos.isEmpty)
                      _buildEmptyState('No tienes equipos registrados', Icons.ac_unit)
                    else
                      ...List.generate(
                        _equipos.length,
                        (index) => _buildEquipoCard(_equipos[index]),
                      ),
                    const SizedBox(height: 24),
                    // Historial
                    if (_historialServicios.isNotEmpty) ...[
                      const Text(
                        'Historial de Servicios',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _historialServicios.length,
                        (index) => _buildHistorialCard(_historialServicios[index]),
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

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildServicioActivoCard(Map<String, dynamic> servicio) {
    final estado = servicio['estado'] ?? 'pendiente';
    final tipoServicio = servicio['tipo_servicio'] ?? 'Servicio';
    final tecnico = servicio['tecnico'];
    
    Color estadoColor;
    String estadoTexto;
    double progreso;
    
    switch (estado) {
      case 'pendiente':
        estadoColor = Colors.grey;
        estadoTexto = 'Esperando asignación';
        progreso = 0.1;
        break;
      case 'asignado':
        estadoColor = Colors.orange;
        estadoTexto = 'Técnico asignado';
        progreso = 0.3;
        break;
      case 'en_camino':
        estadoColor = Colors.blue;
        estadoTexto = 'Técnico en camino';
        progreso = 0.5;
        break;
      case 'en_proceso':
        estadoColor = Colors.purple;
        estadoTexto = 'En servicio';
        progreso = 0.7;
        break;
      default:
        estadoColor = Colors.grey;
        estadoTexto = estado;
        progreso = 0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.build, color: estadoColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tipoServicio,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      estadoTexto,
                      style: TextStyle(color: estadoColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (tecnico != null)
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Llamar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progreso,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(estadoColor),
            ),
          ),
          if (servicio['fecha_programada'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Programado: ${_formatDate.format(DateTime.parse(servicio['fecha_programada']))}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
          if (tecnico != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.engineering, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Técnico: ${tecnico['nombre']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEquipoCard(Map<String, dynamic> equipo) {
    final marca = equipo['marca'] ?? '';
    final modelo = equipo['modelo'] ?? '';
    final ubicacion = equipo['ubicacion'] ?? '';
    final toneladas = equipo['toneladas']?.toString() ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.ac_unit, color: Colors.cyanAccent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$marca $modelo',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (ubicacion.isNotEmpty)
                  Text(ubicacion, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (toneladas.isNotEmpty)
                  Text('$toneladas TON', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            color: const Color(0xFF1A1A2E),
            onSelected: (value) {
              if (value == 'servicio') {
                _solicitarServicio(equipoId: equipo['id']);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'servicio', child: Text('Solicitar servicio', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'historial', child: Text('Ver historial', style: TextStyle(color: Colors.white))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialCard(Map<String, dynamic> servicio) {
    final tipoServicio = servicio['tipo_servicio'] ?? 'Servicio';
    final estado = servicio['estado'];
    final fecha = servicio['fecha_programada'] != null 
        ? _formatDate.format(DateTime.parse(servicio['fecha_programada']))
        : '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            estado == 'completado' ? Icons.check_circle : Icons.cancel,
            color: estado == 'completado' ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tipoServicio, style: const TextStyle(color: Colors.white70)),
                Text(fecha, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text(
            _formatCurrency.format(servicio['total'] ?? 0),
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
              _buildNavItem(Icons.ac_unit, 'Equipos', false),
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
        Icon(icon, color: isActive ? Colors.cyanAccent : Colors.white54, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? Colors.cyanAccent : Colors.white54, fontSize: 10)),
      ],
    );
  }

  void _solicitarServicio({String? equipoId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SolicitarServicioSheet(
        clienteId: _cliente!['id'],
        equipoId: equipoId,
        equipos: _equipos,
        onSolicitud: () {
          Navigator.pop(context);
          _cargarDatos();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Servicio solicitado. Te contactaremos pronto.'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET PARA SOLICITAR SERVICIO
// ═══════════════════════════════════════════════════════════════════════════════

class _SolicitarServicioSheet extends StatefulWidget {
  final String clienteId;
  final String? equipoId;
  final List<Map<String, dynamic>> equipos;
  final VoidCallback onSolicitud;

  const _SolicitarServicioSheet({
    required this.clienteId,
    this.equipoId,
    required this.equipos,
    required this.onSolicitud,
  });

  @override
  State<_SolicitarServicioSheet> createState() => _SolicitarServicioSheetState();
}

class _SolicitarServicioSheetState extends State<_SolicitarServicioSheet> {
  String? _equipoSeleccionado;
  String _tipoServicio = 'mantenimiento';
  String _descripcion = '';
  String _urgencia = 'normal';
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _equipoSeleccionado = widget.equipoId;
  }

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'Solicitar Servicio',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Equipo
            if (widget.equipos.isNotEmpty) ...[
              const Text('Equipo', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _equipoSeleccionado,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                hint: const Text('Selecciona un equipo', style: TextStyle(color: Colors.white54)),
                items: widget.equipos.map((e) => DropdownMenuItem(
                  value: e['id'] as String,
                  child: Text('${e['marca']} ${e['modelo']} - ${e['ubicacion'] ?? ''}'),
                )).toList(),
                onChanged: (v) => setState(() => _equipoSeleccionado = v),
              ),
              const SizedBox(height: 16),
            ],
            // Tipo de servicio
            const Text('Tipo de servicio', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildTipoChip('mantenimiento', 'Mantenimiento', Icons.build),
                _buildTipoChip('reparacion', 'Reparación', Icons.handyman),
                _buildTipoChip('instalacion', 'Instalación', Icons.settings),
                _buildTipoChip('revision', 'Revisión', Icons.search),
              ],
            ),
            const SizedBox(height: 16),
            // Urgencia
            const Text('Urgencia', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildUrgenciaChip('normal', 'Normal', Colors.green),
                const SizedBox(width: 8),
                _buildUrgenciaChip('urgente', 'Urgente', Colors.orange),
                const SizedBox(width: 8),
                _buildUrgenciaChip('emergencia', 'Emergencia', Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            // Descripción
            const Text('Describe el problema', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                hintText: 'Ej: El aire no enfría bien...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              ),
              onChanged: (v) => _descripcion = v,
            ),
            const SizedBox(height: 24),
            // Botón enviar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviarSolicitud,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _enviando 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enviar Solicitud', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoChip(String value, String label, IconData icon) {
    final isSelected = _tipoServicio == value;
    return FilterChip(
      selected: isSelected,
      onSelected: (v) => setState(() => _tipoServicio = value),
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white54),
      label: Text(label),
      selectedColor: Colors.cyanAccent,
      labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70),
      backgroundColor: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildUrgenciaChip(String value, String label, Color color) {
    final isSelected = _urgencia == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgencia = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.3) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : Colors.transparent),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: isSelected ? color : Colors.white54)),
          ),
        ),
      ),
    );
  }

  Future<void> _enviarSolicitud() async {
    if (_descripcion.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor describe el problema'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _enviando = true);
    
    try {
      await AppSupabase.client.from('climas_ordenes_servicio').insert({
        'cliente_id': widget.clienteId,
        'equipo_id': _equipoSeleccionado,
        'tipo_servicio': _tipoServicio,
        'descripcion': _descripcion,
        'urgencia': _urgencia,
        'estado': 'pendiente',
      });

      widget.onSolicitud();
    } catch (e) {
      debugPrint('Error enviando solicitud: $e');
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
