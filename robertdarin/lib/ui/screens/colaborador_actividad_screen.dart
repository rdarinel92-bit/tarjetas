// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE ACTIVIDAD DEL COLABORADOR
// Historial de acciones y logs de auditoría
// Robert Darin Platform v10.16
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradorActividadScreen extends StatefulWidget {
  final String colaboradorId;
  
  const ColaboradorActividadScreen({super.key, required this.colaboradorId});
  
  @override
  State<ColaboradorActividadScreen> createState() => _ColaboradorActividadScreenState();
}

class _ColaboradorActividadScreenState extends State<ColaboradorActividadScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _actividades = [];
  Map<String, dynamic>? _colaborador;
  String _filtroTipo = 'todos';
  
  // ignore: unused_field
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar colaborador
      final colabRes = await AppSupabase.client
          .from('v_colaboradores_completos')
          .select()
          .eq('id', widget.colaboradorId)
          .single();
      
      _colaborador = colabRes;

      // Cargar actividades
      final actRes = await AppSupabase.client
          .from('colaborador_actividad')
          .select()
          .eq('colaborador_id', widget.colaboradorId)
          .order('created_at', ascending: false)
          .limit(100);
      
      _actividades = List<Map<String, dynamic>>.from(actRes);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar actividad: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _actividadesFiltradas {
    if (_filtroTipo == 'todos') return _actividades;
    return _actividades.where((a) => a['tipo_accion'] == _filtroTipo).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '📋 Actividad',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildFiltros(),
                Expanded(child: _buildListaActividades()),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getIniciales(_colaborador?['nombre'] ?? ''),
                style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _colaborador?['nombre'] ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  _colaborador?['tipo_nombre'] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_actividades.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              Text(
                'acciones',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    final tipos = ['todos', 'login', 'ver', 'crear', 'editar', 'eliminar', 'exportar'];
    
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tipos.length,
        itemBuilder: (context, index) {
          final tipo = tipos[index];
          final seleccionado = _filtroTipo == tipo;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_getNombreTipo(tipo)),
              selected: seleccionado,
              onSelected: (v) => setState(() => _filtroTipo = tipo),
              backgroundColor: const Color(0xFF1A1A2E),
              selectedColor: const Color(0xFF3B82F6).withOpacity(0.3),
              labelStyle: TextStyle(
                color: seleccionado ? const Color(0xFF3B82F6) : Colors.white70,
                fontSize: 12,
              ),
              checkmarkColor: const Color(0xFF3B82F6),
              side: BorderSide(
                color: seleccionado ? const Color(0xFF3B82F6) : Colors.transparent,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListaActividades() {
    final actividades = _actividadesFiltradas;
    
    if (actividades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              _filtroTipo == 'todos' 
                  ? 'Sin actividad registrada'
                  : 'Sin actividad de tipo "${_getNombreTipo(_filtroTipo)}"',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    // Agrupar por fecha
    final Map<String, List<Map<String, dynamic>>> agrupadas = {};
    for (var act in actividades) {
      final fecha = DateTime.tryParse(act['created_at'] ?? '');
      if (fecha != null) {
        final key = DateFormat('dd MMM yyyy', 'es').format(fecha);
        agrupadas[key] = [...(agrupadas[key] ?? []), act];
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agrupadas.length,
      itemBuilder: (context, index) {
        final fecha = agrupadas.keys.elementAt(index);
        final items = agrupadas[fecha]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Separador de fecha
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      fecha,
                      style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
            
            // Items de ese día
            ...items.map((act) => _buildActividadItem(act)),
          ],
        );
      },
    );
  }

  Widget _buildActividadItem(Map<String, dynamic> actividad) {
    final tipoAccion = actividad['tipo_accion'] ?? '';
    final modulo = actividad['modulo'] ?? '';
    final descripcion = actividad['descripcion'] ?? '';
    final createdAt = DateTime.tryParse(actividad['created_at'] ?? '');
    final detalles = actividad['detalles'] as Map<String, dynamic>? ?? {};
    
    final config = _getConfigAccion(tipoAccion);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: config.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(config.icono, color: config.color, size: 20),
        ),
        title: Text(
          descripcion.isNotEmpty ? descripcion : '${config.nombre} en $modulo',
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    config.nombre,
                    style: TextStyle(color: config.color, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                if (modulo.isNotEmpty)
                  Text(
                    modulo,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                  ),
              ],
            ),
            if (detalles.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _formatDetalles(detalles),
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: createdAt != null
            ? Text(
                DateFormat('HH:mm').format(createdAt),
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              )
            : null,
      ),
    );
  }

  String _getIniciales(String nombre) {
    final partes = nombre.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    } else if (partes.isNotEmpty) {
      return partes[0].substring(0, 2).toUpperCase();
    }
    return '?';
  }

  String _getNombreTipo(String tipo) {
    switch (tipo) {
      case 'todos': return 'Todos';
      case 'login': return 'Inicios sesión';
      case 'ver': return 'Visualizaciones';
      case 'crear': return 'Creaciones';
      case 'editar': return 'Ediciones';
      case 'eliminar': return 'Eliminaciones';
      case 'exportar': return 'Exportaciones';
      default: return tipo;
    }
  }

  _AccionConfig _getConfigAccion(String tipo) {
    switch (tipo) {
      case 'login':
        return _AccionConfig('Inicio sesión', Icons.login, const Color(0xFF3B82F6));
      case 'ver':
        return _AccionConfig('Ver', Icons.visibility, const Color(0xFF8B5CF6));
      case 'crear':
        return _AccionConfig('Crear', Icons.add_circle, const Color(0xFF10B981));
      case 'editar':
        return _AccionConfig('Editar', Icons.edit, const Color(0xFFF59E0B));
      case 'eliminar':
        return _AccionConfig('Eliminar', Icons.delete, const Color(0xFFEF4444));
      case 'exportar':
        return _AccionConfig('Exportar', Icons.download, const Color(0xFF06B6D4));
      default:
        return _AccionConfig(tipo, Icons.circle, Colors.grey);
    }
  }

  String _formatDetalles(Map<String, dynamic> detalles) {
    return detalles.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .take(3)
        .map((e) => '${e.key}: ${e.value}')
        .join(' • ');
  }
}

class _AccionConfig {
  final String nombre;
  final IconData icono;
  final Color color;

  _AccionConfig(this.nombre, this.icono, this.color);
}
