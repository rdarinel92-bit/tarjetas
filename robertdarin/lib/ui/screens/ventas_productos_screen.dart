// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE PRODUCTOS VENTAS - Robert Darin Platform v10.18
/// CRUD completo: productos, categorías, inventario
/// ═══════════════════════════════════════════════════════════════════════════════
class VentasProductosScreen extends StatefulWidget {
  const VentasProductosScreen({super.key});

  @override
  State<VentasProductosScreen> createState() => _VentasProductosScreenState();
}

class _VentasProductosScreenState extends State<VentasProductosScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _categorias = [];
  String? _categoriaFiltro;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final productosRes = await AppSupabase.client
          .from('ventas_productos')
          .select('*, ventas_categorias(nombre)')
          .order('nombre');
      _productos = List<Map<String, dynamic>>.from(productosRes);

      final categoriasRes = await AppSupabase.client.from('ventas_categorias').select().order('nombre');
      _categorias = List<Map<String, dynamic>>.from(categoriasRes);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _productosFiltrados {
    if (_categoriaFiltro == null) return _productos;
    return _productos.where((p) => p['categoria_id'] == _categoriaFiltro).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '📦 Productos & Categorías',
      actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos)],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF00D9FF),
                    labelColor: const Color(0xFF00D9FF),
                    unselectedLabelColor: Colors.white54,
                    tabs: const [Tab(text: 'Productos'), Tab(text: 'Categorías')],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildProductosTab(), _buildCategoriasTab()],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tabController.index == 0 ? _mostrarFormularioProducto() : _mostrarFormularioCategoria(),
        backgroundColor: const Color(0xFF00D9FF),
        icon: const Icon(Icons.add, color: Colors.black),
        label: Text(_tabController.index == 0 ? 'Nuevo Producto' : 'Nueva Categoría', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildProductosTab() {
    return Column(
      children: [
        // Filtro por categoría
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<String?>(
            value: _categoriaFiltro,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF0D0D14),
            hint: const Text('Todas las categorías', style: TextStyle(color: Colors.white70)),
            style: const TextStyle(color: Colors.white),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas las categorías')),
              ..._categorias.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['nombre'] ?? ''))),
            ],
            onChanged: (v) => setState(() => _categoriaFiltro = v),
          ),
        ),

        // Lista de productos
        Expanded(
          child: _productosFiltrados.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.inventory_2, size: 64, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text('Sin productos', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _productosFiltrados.length,
                  itemBuilder: (context, index) => _buildProductoCard(_productosFiltrados[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> producto) {
    final stock = producto['stock'] ?? 0;
    final stockBajo = stock < (producto['stock_minimo'] ?? 5);
    final categoria = producto['ventas_categorias']?['nombre'] ?? 'Sin categoría';
    final activo = producto['activo'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: stockBajo ? Colors.orange : const Color(0xFF10B981), width: 4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF00D9FF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.shopping_bag, color: Color(0xFF00D9FF)),
        ),
        title: Row(
          children: [
            Expanded(child: Text(producto['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            if (!activo) Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: const Text('INACTIVO', style: TextStyle(color: Colors.red, fontSize: 9)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📁 $categoria', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: stockBajo ? Colors.orange.withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('Stock: $stock', style: TextStyle(color: stockBajo ? Colors.orange : const Color(0xFF10B981), fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_currencyFormat.format(producto['precio'] ?? 0), style: const TextStyle(color: Color(0xFF00D9FF), fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Costo: ${_currencyFormat.format(producto['costo'] ?? 0)}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          ],
        ),
        onTap: () => _mostrarFormularioProducto(producto: producto),
      ),
    );
  }

  Widget _buildCategoriasTab() {
    if (_categorias.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.folder_open, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Sin categorías', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categorias.length,
      itemBuilder: (context, index) => _buildCategoriaCard(_categorias[index]),
    );
  }

  Widget _buildCategoriaCard(Map<String, dynamic> categoria) {
    final productosEnCategoria = _productos.where((p) => p['categoria_id'] == categoria['id']).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
          child: const Icon(Icons.folder, color: Color(0xFF8B5CF6)),
        ),
        title: Text(categoria['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(categoria['descripcion'] ?? 'Sin descripción', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF00D9FF).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: Text('$productosEnCategoria productos', style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 12)),
        ),
        onTap: () => _mostrarFormularioCategoria(categoria: categoria),
      ),
    );
  }

  void _mostrarFormularioProducto({Map<String, dynamic>? producto}) {
    final esEdicion = producto != null;
    final nombreCtrl = TextEditingController(text: producto?['nombre'] ?? '');
    final precioCtrl = TextEditingController(text: (producto?['precio'] ?? 0).toString());
    final costoCtrl = TextEditingController(text: (producto?['costo'] ?? 0).toString());
    final stockCtrl = TextEditingController(text: (producto?['stock'] ?? 0).toString());
    final stockMinCtrl = TextEditingController(text: (producto?['stock_minimo'] ?? 5).toString());
    final descripcionCtrl = TextEditingController(text: producto?['descripcion'] ?? '');
    String? categoriaId = producto?['categoria_id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(esEdicion ? 'Editar Producto' : 'Nuevo Producto', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                TextField(controller: nombreCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Nombre del producto')),
                const SizedBox(height: 12),

                DropdownButtonFormField<String?>(
                  value: categoriaId,
                  dropdownColor: const Color(0xFF0D0D14),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Categoría'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin categoría')),
                    ..._categorias.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['nombre'] ?? ''))),
                  ],
                  onChanged: (v) => setModalState(() => categoriaId = v),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: TextField(controller: precioCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Precio').copyWith(prefixText: '\$ '))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: costoCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Costo').copyWith(prefixText: '\$ '))),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Stock actual'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: stockMinCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Stock mínimo'))),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(controller: descripcionCtrl, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Descripción')),
                const SizedBox(height: 20),

                Row(
                  children: [
                    if (esEdicion) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await AppSupabase.client.from('ventas_productos').update({'activo': !(producto['activo'] ?? true)}).eq('id', producto['id']);
                            if (mounted) { Navigator.pop(context); _cargarDatos(); }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(0, 50)),
                          child: Text((producto['activo'] ?? true) ? 'Desactivar' : 'Activar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nombreCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa el nombre'), backgroundColor: Colors.orange));
                            return;
                          }

                          final data = {
                            'nombre': nombreCtrl.text.trim(),
                            'categoria_id': categoriaId,
                            'precio': double.tryParse(precioCtrl.text) ?? 0,
                            'costo': double.tryParse(costoCtrl.text) ?? 0,
                            'stock': int.tryParse(stockCtrl.text) ?? 0,
                            'stock_minimo': int.tryParse(stockMinCtrl.text) ?? 5,
                            'descripcion': descripcionCtrl.text.trim(),
                            'activo': true,
                          };

                          if (esEdicion) {
                            await AppSupabase.client.from('ventas_productos').update(data).eq('id', producto['id']);
                          } else {
                            await AppSupabase.client.from('ventas_productos').insert(data);
                          }

                          if (mounted) {
                            Navigator.pop(context);
                            _cargarDatos();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(esEdicion ? '✅ Producto actualizado' : '✅ Producto creado'), backgroundColor: Colors.green));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF), minimumSize: const Size(0, 50)),
                        child: Text(esEdicion ? 'Guardar Cambios' : 'Crear Producto', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  void _mostrarFormularioCategoria({Map<String, dynamic>? categoria}) {
    final esEdicion = categoria != null;
    final nombreCtrl = TextEditingController(text: categoria?['nombre'] ?? '');
    final descripcionCtrl = TextEditingController(text: categoria?['descripcion'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(esEdicion ? 'Editar Categoría' : 'Nueva Categoría', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            TextField(controller: nombreCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Nombre de categoría')),
            const SizedBox(height: 12),

            TextField(controller: descripcionCtrl, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Descripción')),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                if (nombreCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa el nombre'), backgroundColor: Colors.orange));
                  return;
                }

                final data = {'nombre': nombreCtrl.text.trim(), 'descripcion': descripcionCtrl.text.trim()};

                if (esEdicion) {
                  await AppSupabase.client.from('ventas_categorias').update(data).eq('id', categoria['id']);
                } else {
                  await AppSupabase.client.from('ventas_categorias').insert(data);
                }

                if (mounted) {
                  Navigator.pop(context);
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(esEdicion ? '✅ Categoría actualizada' : '✅ Categoría creada'), backgroundColor: Colors.green));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF), minimumSize: const Size(double.infinity, 50)),
              child: Text(esEdicion ? 'Guardar Cambios' : 'Crear Categoría', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: const Color(0xFF0D0D14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
