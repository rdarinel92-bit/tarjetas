// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/pollos_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// PANTALLA DE MENÚ - POLLOS ASADOS
/// Gestión del catálogo de productos
/// ═══════════════════════════════════════════════════════════════════════════════
class PollosMenuScreen extends StatefulWidget {
  const PollosMenuScreen({super.key});

  @override
  State<PollosMenuScreen> createState() => _PollosMenuScreenState();
}

class _PollosMenuScreenState extends State<PollosMenuScreen> {
  bool _isLoading = true;
  List<PollosProductoModel> _productos = [];
  String _categoriaSeleccionada = 'todos';

  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _categorias = ['todos', 'pollos', 'paquetes', 'complementos', 'bebidas', 'extras'];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  List<PollosProductoModel> get _productosFiltrados {
    if (_categoriaSeleccionada == 'todos') return _productos;
    return _productos.where((p) => p.categoria == _categoriaSeleccionada).toList();
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppSupabase.client
          .from('pollos_productos')
          .select()
          .order('categoria')
          .order('orden_display');

      if (mounted) {
        setState(() {
          _productos = (res as List).map((e) => PollosProductoModel.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🍗 Menú',
      subtitle: '${_productos.where((p) => p.activo).length} productos activos',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarProductos,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : Column(
              children: [
                // Filtros por categoría
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categorias.length,
                    itemBuilder: (ctx, i) {
                      final cat = _categorias[i];
                      final isSelected = _categoriaSeleccionada == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(_getCategoriaLabel(cat)),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: const Color(0xFF1A1A2E),
                          selectedColor: const Color(0xFFFF6B00),
                          checkmarkColor: Colors.white,
                          onSelected: (_) {
                            setState(() => _categoriaSeleccionada = cat);
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Lista de productos
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarProductos,
                    color: const Color(0xFFFF6B00),
                    child: _productosFiltrados.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _productosFiltrados.length,
                            itemBuilder: (ctx, i) => _buildProductoCard(_productosFiltrados[i]),
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioProducto(null),
        backgroundColor: const Color(0xFFFF6B00),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Sin productos', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _mostrarFormularioProducto(null),
            icon: const Icon(Icons.add),
            label: const Text('Agregar producto'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoCard(PollosProductoModel producto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: producto.activo ? Colors.transparent : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarFormularioProducto(producto),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Emoji/Imagen
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getEmoji(producto.categoria),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              producto.nombre,
                              style: TextStyle(
                                color: producto.activo ? Colors.white : Colors.white54,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!producto.activo)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('INACTIVO', style: TextStyle(color: Colors.red, fontSize: 9)),
                            ),
                        ],
                      ),
                      if (producto.descripcion != null && producto.descripcion!.isNotEmpty)
                        Text(
                          producto.descripcion!,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getCategoriaLabel(producto.categoria),
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Precio
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(producto.precio),
                      style: const TextStyle(
                        color: Color(0xFFFF6B00),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Switch(
                      value: producto.activo,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (v) => _toggleActivo(producto, v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoriaLabel(String categoria) {
    switch (categoria) {
      case 'todos': return '📋 Todos';
      case 'pollos': return '🍗 Pollos';
      case 'paquetes': return '📦 Paquetes';
      case 'complementos': return '🥗 Complementos';
      case 'bebidas': return '🥤 Bebidas';
      case 'extras': return '➕ Extras';
      default: return categoria;
    }
  }

  String _getEmoji(String categoria) {
    switch (categoria) {
      case 'pollos': return '🍗';
      case 'paquetes': return '📦';
      case 'complementos': return '🥗';
      case 'bebidas': return '🥤';
      case 'extras': return '🌶️';
      default: return '🍴';
    }
  }

  Future<void> _toggleActivo(PollosProductoModel producto, bool activo) async {
    try {
      await AppSupabase.client
          .from('pollos_productos')
          .update({'activo': activo})
          .eq('id', producto.id);

      await _cargarProductos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarFormularioProducto(PollosProductoModel? producto) {
    final isEditing = producto != null;
    final nombreCtrl = TextEditingController(text: producto?.nombre ?? '');
    final descripcionCtrl = TextEditingController(text: producto?.descripcion ?? '');
    final precioCtrl = TextEditingController(text: producto?.precio.toString() ?? '');
    String categoria = producto?.categoria ?? 'pollos';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      isEditing ? '✏️ Editar Producto' : '➕ Nuevo Producto',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (isEditing)
                      IconButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmarEliminar(producto);
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildTextField(nombreCtrl, 'Nombre del producto', Icons.restaurant),
                    const SizedBox(height: 16),
                    _buildTextField(descripcionCtrl, 'Descripción (opcional)', Icons.description, maxLines: 2),
                    const SizedBox(height: 16),
                    _buildTextField(precioCtrl, 'Precio', Icons.attach_money, isNumber: true),
                    const SizedBox(height: 16),
                    const Text('Categoría', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['pollos', 'paquetes', 'complementos', 'bebidas', 'extras'].map((cat) {
                        final selected = categoria == cat;
                        return ChoiceChip(
                          label: Text(_getCategoriaLabel(cat)),
                          selected: selected,
                          selectedColor: const Color(0xFFFF6B00),
                          labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                          backgroundColor: Colors.white.withOpacity(0.1),
                          onSelected: (_) => setModalState(() => categoria = cat),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D14),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.white24),
                        ),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final nombre = nombreCtrl.text.trim();
                          final precio = double.tryParse(precioCtrl.text) ?? 0;

                          if (nombre.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('El nombre es requerido')),
                            );
                            return;
                          }

                          if (precio <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('El precio debe ser mayor a 0')),
                            );
                            return;
                          }

                          try {
                            final data = {
                              'nombre': nombre,
                              'descripcion': descripcionCtrl.text.trim().isEmpty ? null : descripcionCtrl.text.trim(),
                              'precio': precio,
                              'categoria': categoria,
                            };

                            if (isEditing) {
                              await AppSupabase.client
                                  .from('pollos_productos')
                                  .update(data)
                                  .eq('id', producto.id);
                            } else {
                              data['activo'] = true;
                              await AppSupabase.client
                                  .from('pollos_productos')
                                  .insert(data);
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            await _cargarProductos();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing ? 'Producto actualizado' : 'Producto creado'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          isEditing ? 'Guardar Cambios' : 'Crear Producto',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFFFF6B00)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B00)),
        ),
      ),
    );
  }

  void _confirmarEliminar(PollosProductoModel producto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚠️ Eliminar Producto', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de eliminar "${producto.nombre}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AppSupabase.client
                    .from('pollos_productos')
                    .delete()
                    .eq('id', producto.id);
                await _cargarProductos();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
