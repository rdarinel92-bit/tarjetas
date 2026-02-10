// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA RUTAS PURIFICADORA - Gestión de Rutas de Entrega
// Robert Darin Platform v10.22
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';

class PurificadoraRutasScreen extends StatefulWidget {
  final String negocioId;
  const PurificadoraRutasScreen({super.key, this.negocioId = ''});

  @override
  State<PurificadoraRutasScreen> createState() => _PurificadoraRutasScreenState();
}

class _PurificadoraRutasScreenState extends State<PurificadoraRutasScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rutas = [];
  List<Map<String, dynamic>> _repartidores = [];
  String? _filtroRepartidor;
  String? _filtroDia;

  final List<String> _diasSemana = [
    'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar repartidores
      final repartidoresRes = await AppSupabase.client
          .from('purificadora_repartidores')
          .select('id, nombre')
          .eq('negocio_id', widget.negocioId)
          .eq('activo', true)
          .order('nombre');
      
      // Cargar rutas
      var query = AppSupabase.client
          .from('purificadora_rutas')
          .select('*, purificadora_repartidores(nombre, telefono)')
          .eq('negocio_id', widget.negocioId);
      
      if (_filtroRepartidor != null) {
        query = query.eq('repartidor_id', _filtroRepartidor!);
      }
      if (_filtroDia != null) {
        query = query.eq('dia_semana', _filtroDia!);
      }
      
      final rutasRes = await query.order('dia_semana');
      
      if (mounted) {
        setState(() {
          _repartidores = List<Map<String, dynamic>>.from(repartidoresRes);
          _rutas = List<Map<String, dynamic>>.from(rutasRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando rutas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Rutas de Entrega',
      subtitle: 'Gestión de rutas y zonas',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.white),
          onPressed: _mostrarFormularioRuta,
        ),
      ],
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                : _rutas.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _cargarDatos,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _rutas.length,
                          itemBuilder: (context, i) => _buildRutaCard(_rutas[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _filtroDia,
              dropdownColor: const Color(0xFF1A1A2E),
              decoration: InputDecoration(
                labelText: 'Día',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(color: Colors.white))),
                ..._diasSemana.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(_capitalize(d), style: const TextStyle(color: Colors.white)),
                )),
              ],
              onChanged: (v) {
                setState(() => _filtroDia = v);
                _cargarDatos();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _filtroRepartidor,
              dropdownColor: const Color(0xFF1A1A2E),
              decoration: InputDecoration(
                labelText: 'Repartidor',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(color: Colors.white))),
                ..._repartidores.map((r) => DropdownMenuItem(
                  value: r['id'] as String,
                  child: Text(r['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                )),
              ],
              onChanged: (v) {
                setState(() => _filtroRepartidor = v);
                _cargarDatos();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Sin rutas configuradas',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea rutas para organizar las entregas',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _mostrarFormularioRuta,
            icon: const Icon(Icons.add),
            label: const Text('Crear Ruta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRutaCard(Map<String, dynamic> ruta) {
    final activa = ruta['activa'] ?? true;
    final dia = ruta['dia_semana'] ?? '';
    final repartidor = ruta['purificadora_repartidores'];
    final ordenParadas = ruta['orden_paradas'] as List? ?? [];
    
    Color diaColor;
    switch (dia) {
      case 'lunes':
        diaColor = const Color(0xFF0EA5E9);
        break;
      case 'martes':
        diaColor = const Color(0xFF10B981);
        break;
      case 'miercoles':
        diaColor = const Color(0xFF8B5CF6);
        break;
      case 'jueves':
        diaColor = const Color(0xFFF59E0B);
        break;
      case 'viernes':
        diaColor = const Color(0xFFEF4444);
        break;
      case 'sabado':
        diaColor = const Color(0xFFEC4899);
        break;
      default:
        diaColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activa ? diaColor.withOpacity(0.3) : Colors.grey[700]!,
        ),
      ),
      child: InkWell(
        onTap: () => _mostrarFormularioRuta(ruta: ruta),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: diaColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _capitalize(dia),
                      style: TextStyle(
                        color: diaColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ruta['nombre'] ?? 'Sin nombre',
                      style: TextStyle(
                        color: activa ? Colors.white : Colors.grey[500],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!activa)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'INACTIVA',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ),
                ],
              ),
              if (ruta['descripcion'] != null && ruta['descripcion'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ruta['descripcion'],
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (repartidor != null) ...[
                    Icon(Icons.person, color: Colors.grey[500], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      repartidor['nombre'] ?? 'Sin asignar',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.location_on, color: Colors.grey[500], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    ruta['zona'] ?? 'Sin zona',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stop_circle, color: Color(0xFF0EA5E9), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${ordenParadas.length} paradas',
                          style: const TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _mostrarFormularioRuta({Map<String, dynamic>? ruta}) {
    final isEdit = ruta != null;
    final nombreCtrl = TextEditingController(text: ruta?['nombre'] ?? '');
    final descripcionCtrl = TextEditingController(text: ruta?['descripcion'] ?? '');
    final zonaCtrl = TextEditingController(text: ruta?['zona'] ?? '');
    String diaSeleccionado = ruta?['dia_semana'] ?? 'lunes';
    String? repartidorSeleccionado = ruta?['repartidor_id'];
    bool activa = ruta?['activa'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEdit ? 'Editar Ruta' : 'Nueva Ruta',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(nombreCtrl, 'Nombre de la ruta *', Icons.route),
                const SizedBox(height: 12),
                _buildTextField(zonaCtrl, 'Zona / Colonia', Icons.location_on),
                const SizedBox(height: 12),
                const Text('Día de la Semana', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: diaSeleccionado,
                  dropdownColor: const Color(0xFF1A1A2E),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0D0D14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _diasSemana.map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(_capitalize(d), style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (v) => setModalState(() => diaSeleccionado = v ?? 'lunes'),
                ),
                const SizedBox(height: 12),
                const Text('Repartidor Asignado', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: repartidorSeleccionado,
                  dropdownColor: const Color(0xFF1A1A2E),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0D0D14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  hint: const Text('Seleccionar repartidor', style: TextStyle(color: Colors.grey)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin asignar', style: TextStyle(color: Colors.grey))),
                    ..._repartidores.map((r) => DropdownMenuItem(
                      value: r['id'] as String,
                      child: Text(r['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                    )),
                  ],
                  onChanged: (v) => setModalState(() => repartidorSeleccionado = v),
                ),
                const SizedBox(height: 12),
                _buildTextField(descripcionCtrl, 'Descripción (opcional)', Icons.description, maxLines: 2),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: activa,
                  onChanged: (v) => setModalState(() => activa = v),
                  title: const Text('Ruta Activa', style: TextStyle(color: Colors.white)),
                  activeColor: const Color(0xFF10B981),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isEdit)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _eliminarRuta(ruta['id']),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Eliminar'),
                        ),
                      ),
                    if (isEdit) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _guardarRuta(
                          id: ruta?['id'],
                          nombre: nombreCtrl.text,
                          descripcion: descripcionCtrl.text,
                          zona: zonaCtrl.text,
                          diaSemana: diaSeleccionado,
                          repartidorId: repartidorSeleccionado,
                          activa: activa,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isEdit ? 'Actualizar' : 'Guardar',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _guardarRuta({
    String? id,
    required String nombre,
    String? descripcion,
    String? zona,
    required String diaSemana,
    String? repartidorId,
    required bool activa,
  }) async {
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es requerido'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final data = {
        'negocio_id': widget.negocioId,
        'nombre': nombre,
        'descripcion': descripcion?.isNotEmpty == true ? descripcion : null,
        'zona': zona?.isNotEmpty == true ? zona : null,
        'dia_semana': diaSemana,
        'repartidor_id': repartidorId,
        'activa': activa,
      };

      if (id != null) {
        await AppSupabase.client.from('purificadora_rutas').update(data).eq('id', id);
      } else {
        await AppSupabase.client.from('purificadora_rutas').insert(data);
      }

      if (mounted) {
        Navigator.pop(context);
        _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? 'Ruta actualizada' : 'Ruta creada'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando ruta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarRuta(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Eliminar Ruta', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de eliminar esta ruta?', 
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AppSupabase.client.from('purificadora_rutas').delete().eq('id', id);
        if (mounted) {
          Navigator.pop(context);
          _cargarDatos();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ruta eliminada'), backgroundColor: Color(0xFF10B981)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
