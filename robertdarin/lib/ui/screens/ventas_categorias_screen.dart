// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA CATEGORÍAS VENTAS - Gestión de Categorías de Productos
// Robert Darin Platform v10.22
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';

class VentasCategoriasScreen extends StatefulWidget {
  final String negocioId;
  const VentasCategoriasScreen({super.key, this.negocioId = ''});

  @override
  State<VentasCategoriasScreen> createState() => _VentasCategoriasScreenState();
}

class _VentasCategoriasScreenState extends State<VentasCategoriasScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _categorias = [];

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppSupabase.client
          .from('ventas_categorias')
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

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Categorías',
      subtitle: 'Organiza tus productos',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.white),
          onPressed: _mostrarFormularioCategoria,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
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
            'Crea categorías para organizar tu catálogo',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _mostrarFormularioCategoria,
            icon: const Icon(Icons.add),
            label: const Text('Crear Categoría'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaCard(Map<String, dynamic> categoria, int index) {
    final activa = categoria['activa'] ?? true;
    const color = Color(0xFF10B981);

    return Container(
      key: ValueKey(categoria['id']),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activa ? color.withOpacity(0.3) : Colors.grey[700]!,
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  image: categoria['imagen_url'] != null
                      ? DecorationImage(
                          image: NetworkImage(categoria['imagen_url']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: categoria['imagen_url'] == null
                    ? Icon(Icons.category, color: color, size: 28)
                    : null,
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

    try {
      for (int i = 0; i < _categorias.length; i++) {
        await AppSupabase.client
            .from('ventas_categorias')
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
    final imagenCtrl = TextEditingController(text: categoria?['imagen_url'] ?? '');
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
                const SizedBox(height: 12),
                TextField(
                  controller: imagenCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'URL de imagen (opcional)',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.image, color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF0D0D14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
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
                          imagenUrl: imagenCtrl.text,
                          activa: activa,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
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
    String? imagenUrl,
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
        'imagen_url': imagenUrl?.isNotEmpty == true ? imagenUrl : null,
        'activa': activa,
        'orden': id == null ? _categorias.length : null,
      };
      data.removeWhere((k, v) => v == null);

      if (id != null) {
        await AppSupabase.client.from('ventas_categorias').update(data).eq('id', id);
      } else {
        await AppSupabase.client.from('ventas_categorias').insert(data);
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
        await AppSupabase.client.from('ventas_categorias').delete().eq('id', id);
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
