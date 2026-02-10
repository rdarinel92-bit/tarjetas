// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE TAREAS CLIMAS - V1.0
/// ═══════════════════════════════════════════════════════════════════════════════
/// Sistema de tareas para coordinar trabajo de técnicos:
/// - Asignación de tareas a técnicos
/// - Seguimiento de checklist
/// - Priorización de trabajos
/// - Fechas límite y recordatorios
/// ═══════════════════════════════════════════════════════════════════════════════

class ClimasTareasScreen extends StatefulWidget {
  const ClimasTareasScreen({super.key});

  @override
  State<ClimasTareasScreen> createState() => _ClimasTareasScreenState();
}

class _ClimasTareasScreenState extends State<ClimasTareasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _tareasPendientes = [];
  List<Map<String, dynamic>> _tareasEnProceso = [];
  List<Map<String, dynamic>> _tareasCompletadas = [];
  List<Map<String, dynamic>> _tecnicos = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar técnicos
      try {
        final tecnicosRes = await AppSupabase.client
            .from('climas_tecnicos')
            .select()
            .eq('activo', true)
            .order('nombre');
        _tecnicos = List<Map<String, dynamic>>.from(tecnicosRes);
      } catch (_) {}

      // Cargar órdenes por estado (usamos órdenes como tareas)
      try {
        final pendientesRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('*, climas_clientes(nombre, telefono, direccion), climas_tecnicos(nombre)')
            .inFilter('estado', ['pendiente', 'asignada'])
            .order('fecha_programada');
        _tareasPendientes = List<Map<String, dynamic>>.from(pendientesRes);
      } catch (_) {}

      try {
        final enProcesoRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('*, climas_clientes(nombre, telefono, direccion), climas_tecnicos(nombre)')
            .eq('estado', 'en_proceso')
            .order('fecha_inicio', ascending: false);
        _tareasEnProceso = List<Map<String, dynamic>>.from(enProcesoRes);
      } catch (_) {}

      try {
        final completadasRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('*, climas_clientes(nombre), climas_tecnicos(nombre)')
            .eq('estado', 'completada')
            .order('fecha_fin', ascending: false)
            .limit(20);
        _tareasCompletadas = List<Map<String, dynamic>>.from(completadasRes);
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '📋 Tareas',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
        ),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: _mostrarFiltros,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildResumen(),
                _buildTabs(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaTareas(_tareasPendientes, 'pendiente'),
                      _buildListaTareas(_tareasEnProceso, 'en_proceso'),
                      _buildListaTareas(_tareasCompletadas, 'completada'),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.climasOrdenNueva),
        backgroundColor: const Color(0xFF00D9FF),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nueva Tarea', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildResumen() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildResumenItem('Pendientes', '${_tareasPendientes.length}', const Color(0xFFF59E0B)),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          _buildResumenItem('En Proceso', '${_tareasEnProceso.length}', const Color(0xFF3B82F6)),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          _buildResumenItem('Completadas', '${_tareasCompletadas.length}', const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
        ],
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
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(text: 'Pendientes (${_tareasPendientes.length})'),
          Tab(text: 'En Proceso (${_tareasEnProceso.length})'),
          Tab(text: 'Completadas'),
        ],
      ),
    );
  }

  Widget _buildListaTareas(List<Map<String, dynamic>> tareas, String tipo) {
    if (tareas.isEmpty) {
      return _buildEmptyState(tipo);
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tareas.length,
        itemBuilder: (context, index) => _buildTareaCard(tareas[index], tipo),
      ),
    );
  }

  Widget _buildTareaCard(Map<String, dynamic> tarea, String tipo) {
    final cliente = tarea['climas_clientes'] ?? {};
    final tecnico = tarea['climas_tecnicos'] ?? {};
    final fecha = DateTime.tryParse(tarea['fecha_programada'] ?? '');
    final tipoServicio = tarea['tipo_servicio'] ?? 'mantenimiento';
    final prioridad = tarea['prioridad'] ?? 'normal';
    final estado = tarea['estado'] ?? 'pendiente';
    
    final estadoColor = _getEstadoColor(estado);
    final prioridadColor = _getPrioridadColor(prioridad);
    final esUrgente = prioridad == 'urgente' || prioridad == 'alta';
    
    // Calcular si está atrasada
    final hoy = DateTime.now();
    final atrasada = fecha != null && fecha.isBefore(hoy) && estado != 'completada';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: atrasada 
              ? const Color(0xFFEF4444).withOpacity(0.7) 
              : esUrgente 
                  ? prioridadColor.withOpacity(0.5) 
                  : estadoColor.withOpacity(0.3),
          width: atrasada || esUrgente ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Tipo de servicio
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getTipoLabel(tipoServicio),
                    style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                // Prioridad
                if (esUrgente)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: prioridadColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.priority_high, color: Colors.white, size: 12),
                        Text(prioridad.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                if (atrasada) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, color: Colors.white, size: 12),
                        Text(' ATRASADA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // Folio
                Text(
                  tarea['folio'] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
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
                // Cliente
                Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF00D9FF), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cliente['nombre'] ?? 'Sin cliente',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Dirección
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white.withOpacity(0.5), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cliente['direccion'] ?? tarea['direccion_servicio'] ?? 'Sin dirección',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Fecha y técnico
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.5), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : 'Sin fecha',
                      style: TextStyle(
                        color: atrasada ? const Color(0xFFEF4444) : Colors.white.withOpacity(0.7),
                        fontWeight: atrasada ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.engineering, color: Colors.white.withOpacity(0.5), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      tecnico['nombre'] ?? 'Sin asignar',
                      style: TextStyle(
                        color: tecnico['nombre'] != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                // Descripción
                if (tarea['descripcion_problema'] != null && tarea['descripcion_problema'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tarea['descripcion_problema'],
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                // Acciones
                if (tipo != 'completada') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (tecnico['nombre'] == null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _asignarTecnico(tarea),
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text('Asignar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00D9FF),
                              side: const BorderSide(color: Color(0xFF00D9FF)),
                            ),
                          ),
                        )
                      else if (estado == 'pendiente' || estado == 'asignada')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _cambiarEstado(tarea, 'en_proceso'),
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('Iniciar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        )
                      else if (estado == 'en_proceso')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _cambiarEstado(tarea, 'completada'),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Completar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _editarTarea(tarea),
                        icon: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                        tooltip: 'Editar',
                      ),
                      IconButton(
                        onPressed: () => _reprogramar(tarea),
                        icon: const Icon(Icons.schedule, color: Color(0xFFF59E0B)),
                        tooltip: 'Reprogramar',
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

  Widget _buildEmptyState(String tipo) {
    IconData icon;
    String titulo;
    String subtitulo;

    switch (tipo) {
      case 'pendiente':
        icon = Icons.pending_actions;
        titulo = 'Sin tareas pendientes';
        subtitulo = '¡Excelente! Todo está al día';
        break;
      case 'en_proceso':
        icon = Icons.autorenew;
        titulo = 'Sin tareas en proceso';
        subtitulo = 'Los técnicos están libres';
        break;
      default:
        icon = Icons.check_circle;
        titulo = 'Sin tareas completadas';
        subtitulo = 'Aún no hay historial';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 4),
          Text(subtitulo, style: TextStyle(color: Colors.white.withOpacity(0.5))),
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

  Color _getPrioridadColor(String prioridad) {
    switch (prioridad) {
      case 'urgente': return const Color(0xFFEF4444);
      case 'alta': return const Color(0xFFF59E0B);
      case 'normal': return const Color(0xFF3B82F6);
      case 'baja': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'instalacion': return 'INSTALACIÓN';
      case 'mantenimiento': return 'MANTENIMIENTO';
      case 'reparacion': return 'REPARACIÓN';
      case 'emergencia': return 'EMERGENCIA';
      case 'garantia': return 'GARANTÍA';
      default: return tipo.toUpperCase();
    }
  }

  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtrar por', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Técnico', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: true,
                  onSelected: (v) {},
                  selectedColor: const Color(0xFF00D9FF),
                  backgroundColor: const Color(0xFF1A1A2E),
                  labelStyle: const TextStyle(color: Colors.black),
                ),
                ..._tecnicos.take(5).map((t) => FilterChip(
                  label: Text(t['nombre'] ?? ''),
                  selected: false,
                  onSelected: (v) {},
                  backgroundColor: const Color(0xFF1A1A2E),
                  labelStyle: const TextStyle(color: Colors.white70),
                )),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Prioridad', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(label: const Text('Todas'), selected: true, onSelected: (v) {}, selectedColor: const Color(0xFF00D9FF), labelStyle: const TextStyle(color: Colors.black)),
                FilterChip(label: const Text('Urgente'), selected: false, onSelected: (v) {}, backgroundColor: const Color(0xFFEF4444).withOpacity(0.3), labelStyle: const TextStyle(color: Color(0xFFEF4444))),
                FilterChip(label: const Text('Alta'), selected: false, onSelected: (v) {}, backgroundColor: const Color(0xFFF59E0B).withOpacity(0.3), labelStyle: const TextStyle(color: Color(0xFFF59E0B))),
                FilterChip(label: const Text('Normal'), selected: false, onSelected: (v) {}, backgroundColor: const Color(0xFF1A1A2E), labelStyle: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF), foregroundColor: Colors.black),
                child: const Text('Aplicar Filtros'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _asignarTecnico(Map<String, dynamic> tarea) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D14),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Asignar Técnico', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._tecnicos.map((t) => ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF00D9FF).withOpacity(0.2),
                child: Text(
                  t['nombre']?.toString().substring(0, 1).toUpperCase() ?? 'T',
                  style: const TextStyle(color: Color(0xFF00D9FF)),
                ),
              ),
              title: Text(t['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
              subtitle: Text(t['especialidad'] ?? 'General', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              onTap: () async {
                try {
                  await AppSupabase.client
                      .from('climas_ordenes_servicio')
                      .update({
                        'tecnico_id': t['id'],
                        'estado': 'asignada',
                        'updated_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', tarea['id']);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Asignado a ${t['nombre']}'), backgroundColor: const Color(0xFF10B981)),
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
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(Map<String, dynamic> tarea, String nuevoEstado) async {
    try {
      final updates = <String, dynamic>{
        'estado': nuevoEstado,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nuevoEstado == 'en_proceso') {
        updates['fecha_inicio'] = DateTime.now().toIso8601String();
      } else if (nuevoEstado == 'completada') {
        updates['fecha_fin'] = DateTime.now().toIso8601String();
      }

      await AppSupabase.client
          .from('climas_ordenes_servicio')
          .update(updates)
          .eq('id', tarea['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tarea ${nuevoEstado == 'en_proceso' ? 'iniciada' : 'completada'}'),
            backgroundColor: const Color(0xFF10B981),
          ),
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

  void _editarTarea(Map<String, dynamic> tarea) {
    Navigator.pushNamed(context, AppRoutes.climasOrdenEditar, arguments: tarea['id']);
  }

  void _reprogramar(Map<String, dynamic> tarea) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF00D9FF))),
          child: child!,
        );
      },
    );

    if (fecha != null) {
      final hora = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF00D9FF))),
            child: child!,
          );
        },
      );

      if (hora != null && mounted) {
        try {
          final nuevaFecha = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
          await AppSupabase.client
              .from('climas_ordenes_servicio')
              .update({
                'fecha_programada': nuevaFecha.toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', tarea['id']);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Reprogramada para ${DateFormat('dd/MM/yyyy HH:mm').format(nuevaFecha)}'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _cargarDatos();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
