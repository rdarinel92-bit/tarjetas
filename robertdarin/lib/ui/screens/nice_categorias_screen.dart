// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA CATEGORÍAS NICE - Gestión de Categorías de Joyería MLM
// Robert Darin Platform v10.22
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';

class NiceCategoriasScreen extends StatefulWidget {
  final String negocioId;
  const NiceCategoriasScreen({super.key, this.negocioId = ''});

  @override
  State<NiceCategoriasScreen> createState() => _NiceCategoriasScreenState();
}

class _NiceCategoriasScreenState extends State<NiceCategoriasScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _categorias = [];

  final List<Map<String, dynamic>> _iconosDisponibles = [
    {'icon': 'diamond', 'label': 'Diamante', 'iconData': Icons.diamond},
    {'icon': 'favorite', 'label': 'Corazón', 'iconData': Icons.favorite},
    {'icon': 'star', 'label': 'Estrella', 'iconData': Icons.star},
    {'icon': 'circle', 'label': 'Círculo', 'iconData': Icons.circle},
    {'icon': 'square', 'label': 'Cuadrado', 'iconData': Icons.square},
    {'icon': 'watch', 'label': 'Reloj', 'iconData': Icons.watch},
    {'icon': 'auto_awesome', 'label': 'Brillos', 'iconData': Icons.auto_awesome},
    {'icon': 'monetization_on', 'label': 'Moneda', 'iconData': Icons.monetization_on},
  ];

  final List<Map<String, dynamic>> _coloresDisponibles = [
    {'color': '#E91E63', 'label': 'Rosa'},
    {'color': '#9C27B0', 'label': 'Púrpura'},
    {'color': '#3F51B5', 'label': 'Índigo'},
    {'color': '#2196F3', 'label': 'Azul'},
    {'color': '#009688', 'label': 'Teal'},
    {'color': '#4CAF50', 'label': 'Verde'},
    {'color': '#FF9800', 'label': 'Naranja'},
    {'color': '#F44336', 'label': 'Rojo'},
    {'color': '#FFD700', 'label': 'Oro'},
    {'color': '#C0C0C0', 'label': 'Plata'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppSupabase.client
          .from('nice_categorias')
          .select()
          .eq('negocio_id', widget.negocioId)
          .order('orden');
      
      if (mounted) {
        setState(() {
          _categorias = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando categorías: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIconData(String? iconName) {
    final found = _iconosDisponibles.firstWhere(
      (i) => i['icon'] == iconName,
      orElse: () => _iconosDisponibles.first,
    );
    return found['iconData'] as IconData;
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return const Color(0xFFE91E63);
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFE91E63);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Categorías',
      subtitle: 'Organiza tus productos Nice',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.white),
          onPressed: _mostrarFormularioCategoria,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
          : _categorias.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _cargarCategorias,
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categorias.length,
                    onReorder: _reordenarCategorias,
                    itemBuilder: (context, i) => _buildCategoriaCard(_categorias[i], i),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Sin categorías',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea categorías para organizar tus productos',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _mostrarFormularioCategoria,
            icon: const Icon(Icons.add),
            label: const Text('Crear Categoría'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaCard(Map<String, dynamic> categoria, int index) {
    final color = _parseColor(categoria['color']);
    final activa = categoria['activa'] ?? true;

    return Container(
      key: ValueKey(categoria['id']),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activa ? color.withOpacity(0.4) : Colors.grey[700]!,
        ),
      ),
      child: InkWell(
        onTap: () => _mostrarFormularioCategoria(categoria: categoria),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getIconData(categoria['icono']),
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            categoria['nombre'] ?? 'Sin nombre',
                            style: TextStyle(
                              color: activa ? Colors.white : Colors.grey[500],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!activa)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    if (categoria['descripcion'] != null && categoria['descripcion'].isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        categoria['descripcion'],
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_handle, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reordenarCategorias(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex--;
    
    setState(() {
      final item = _categorias.removeAt(oldIndex);
      _categorias.insert(newIndex, item);
    });

    // Actualizar orden en base de datos
    try {
      for (int i = 0; i < _categorias.length; i++) {
        await AppSupabase.client
            .from('nice_categorias')
            .update({'orden': i})
            .eq('id', _categorias[i]['id']);
      }
    } catch (e) {
      debugPrint('Error reordenando: $e');
    }
  }

  void _mostrarFormularioCategoria({Map<String, dynamic>? categoria}) {
    final isEdit = categoria != null;
    final nombreCtrl = TextEditingController(text: categoria?['nombre'] ?? '');
    final descripcionCtrl = TextEditingController(text: categoria?['descripcion'] ?? '');
    String iconoSeleccionado = categoria?['icono'] ?? 'diamond';
    String colorSeleccionado = categoria?['color'] ?? '#E91E63';
    bool activa = categoria?['activa'] ?? true;

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
                  isEdit ? 'Editar Categoría' : 'Nueva Categoría',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Preview
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _parseColor(colorSeleccionado).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _parseColor(colorSeleccionado).withOpacity(0.4)),
                    ),
                    child: Icon(
                      _getIconData(iconoSeleccionado),
                      color: _parseColor(colorSeleccionado),
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nombreCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre de la categoría *',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.category, color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF0D0D14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.description, color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF0D0D14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Icono', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _iconosDisponibles.map((i) {
                    final isSelected = iconoSeleccionado == i['icon'];
                    return InkWell(
                      onTap: () => setModalState(() => iconoSeleccionado = i['icon'] as String),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? _parseColor(colorSeleccionado).withOpacity(0.2) 
                              : const Color(0xFF0D0D14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? _parseColor(colorSeleccionado) 
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          i['iconData'] as IconData,
                          color: isSelected 
                              ? _parseColor(colorSeleccionado) 
                              : Colors.grey[500],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _coloresDisponibles.map((c) {
                    final isSelected = colorSeleccionado == c['color'];
                    final color = _parseColor(c['color'] as String);
                    return InkWell(
                      onTap: () => setModalState(() => colorSeleccionado = c['color'] as String),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: activa,
                  onChanged: (v) => setModalState(() => activa = v),
                  title: const Text('Categoría Activa', style: TextStyle(color: Colors.white)),
                  activeColor: const Color(0xFF10B981),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isEdit)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _eliminarCategoria(categoria['id']),
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
                        onPressed: () => _guardarCategoria(
                          id: categoria?['id'],
                          nombre: nombreCtrl.text,
                          descripcion: descripcionCtrl.text,
                          icono: iconoSeleccionado,
                          color: colorSeleccionado,
                          activa: activa,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
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

  Future<void> _guardarCategoria({
    String? id,
    required String nombre,
    String? descripcion,
    required String icono,
    required String color,
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
        'icono': icono,
        'color': color,
        'activa': activa,
        'orden': id == null ? _categorias.length : null,
      };
      data.removeWhere((k, v) => v == null);

      if (id != null) {
        await AppSupabase.client.from('nice_categorias').update(data).eq('id', id);
      } else {
        await AppSupabase.client.from('nice_categorias').insert(data);
      }

      if (mounted) {
        Navigator.pop(context);
        _cargarCategorias();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? 'Categoría actualizada' : 'Categoría creada'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando categoría: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarCategoria(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Eliminar Categoría', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro? Los productos de esta categoría quedarán sin categoría.',
          style: TextStyle(color: Colors.white70),
        ),
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
        await AppSupabase.client.from('nice_categorias').delete().eq('id', id);
        if (mounted) {
          Navigator.pop(context);
          _cargarCategorias();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Categoría eliminada'), backgroundColor: Color(0xFF10B981)),
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
