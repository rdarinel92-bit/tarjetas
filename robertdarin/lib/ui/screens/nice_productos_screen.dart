// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRODUCTOS - MÓDULO NICE
// Robert Darin Platform v10.20
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../services/nice_service.dart';
import '../../data/models/nice_models.dart';

class NiceProductosScreen extends StatefulWidget {
  final String negocioId;

  const NiceProductosScreen({super.key, required this.negocioId});

  @override
  State<NiceProductosScreen> createState() => _NiceProductosScreenState();
}

class _NiceProductosScreenState extends State<NiceProductosScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<NiceProducto> _productos = [];
  List<NiceCategoria> _categorias = [];
  List<NiceCatalogo> _catalogos = [];
  String _busqueda = '';
  String? _filtroCategoria;
  String? _filtroCatalogo;
  late TabController _tabController;

  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

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
    setState(() => _isLoading = true);
    try {
      _productos = await NiceService.getProductos(
        negocioId: widget.negocioId,
      );
      _categorias = await NiceService.getCategorias(negocioId: widget.negocioId);
      _catalogos = await NiceService.getCatalogos(widget.negocioId);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<NiceProducto> get _productosFiltrados {
    var lista = _productos;

    if (_filtroCategoria != null) {
      lista = lista.where((p) => p.categoriaId == _filtroCategoria).toList();
    }

    if (_filtroCatalogo != null) {
      lista = lista.where((p) => p.catalogoId == _filtroCatalogo).toList();
    }

    if (_busqueda.isNotEmpty) {
      final query = _busqueda.toLowerCase();
      lista = lista.where((p) =>
          p.nombre.toLowerCase().contains(query) ||
          p.codigoProducto.toLowerCase().contains(query) ||
          (p.descripcion?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Catálogo',
      subtitle: '${_productos.length} productos',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_box),
          onPressed: () => _mostrarFormularioProducto(),
          tooltip: 'Nuevo producto',
        ),
        IconButton(
          icon: const Icon(Icons.category),
          onPressed: () => _mostrarCategorias(),
          tooltip: 'Categorías',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : Column(
              children: [
                // Tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(text: 'Productos'),
                      Tab(text: 'Catálogos'),
                    ],
                  ),
                ),
                // Contenido
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProductosTab(),
                      _buildCatalogosTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductosTab() {
    return Column(
      children: [
        // Búsqueda y filtros
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: Colors.pinkAccent),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filtros por categoría
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFiltroChip('Todas', null),
                    ..._categorias.map((c) => _buildFiltroChip(c.nombre, c.id)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Grid de productos
        Expanded(
          child: _productosFiltrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No hay productos',
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _productosFiltrados.length,
                  itemBuilder: (context, index) {
                    final producto = _productosFiltrados[index];
                    return _buildProductoCard(producto);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String label, String? categoriaId) {
    final isSelected = _filtroCategoria == categoriaId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) => setState(() => _filtroCategoria = v ? categoriaId : null),
        selectedColor: Colors.pinkAccent,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 12,
        ),
        backgroundColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildProductoCard(NiceProducto producto) {
    final stockBajo = producto.stockActual < producto.stockMinimo;

    return GestureDetector(
      onTap: () => _mostrarDetalleProducto(producto),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: stockBajo
              ? Border.all(color: Colors.red.withOpacity(0.5), width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: producto.imagenUrl != null
                  ? ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        producto.imagenUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : Center(
                      child: Icon(
                        _getIconCategoria(producto.categoriaNombre),
                        size: 40,
                        color: Colors.pinkAccent.withOpacity(0.5),
                      ),
                    ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      producto.codigoProducto,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const Spacer(),
                    // Precios
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatCurrency.format(producto.precioPublico),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Costo: ${_formatCurrency.format(producto.precioBase)}',
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                        // Stock badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: stockBajo
                                ? Colors.red.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${producto.stockActual}',
                            style: TextStyle(
                              color: stockBajo ? Colors.red : Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconCategoria(String? categoria) {
    switch (categoria?.toLowerCase()) {
      case 'aretes':
        return Icons.earbuds;
      case 'collares':
        return Icons.circle_outlined;
      case 'pulseras':
        return Icons.watch;
      case 'anillos':
        return Icons.radio_button_unchecked;
      case 'aceites esenciales':
        return Icons.water_drop;
      case 'tés':
        return Icons.local_cafe;
      default:
        return Icons.diamond;
    }
  }

  Widget _buildCatalogosTab() {
    return _catalogos.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 64, color: Colors.white.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'No hay catálogos',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _mostrarFormularioCatalogo(),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear catálogo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _catalogos.length,
            itemBuilder: (context, index) {
              final catalogo = _catalogos[index];
              return _buildCatalogoCard(catalogo);
            },
          );
  }

  Widget _buildCatalogoCard(NiceCatalogo catalogo) {
    final esVigente = catalogo.fechaFin?.isAfter(DateTime.now()) ?? true;

    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book, color: Colors.pinkAccent, size: 30),
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
                          catalogo.nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: esVigente
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          esVigente ? 'Vigente' : 'Vencido',
                          style: TextStyle(
                            color: esVigente ? Colors.greenAccent : Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    catalogo.descripcion ?? 'Sin descripción',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${catalogo.fechaInicio != null ? DateFormat('dd/MM/yy').format(catalogo.fechaInicio!) : 'N/A'} - ${catalogo.fechaFin != null ? DateFormat('dd/MM/yy').format(catalogo.fechaFin!) : 'N/A'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white54),
              onPressed: () => _mostrarFormularioCatalogo(catalogo: catalogo),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalleProducto(NiceProducto producto) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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
              // Imagen
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: producto.imagenUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(producto.imagenUrl!, fit: BoxFit.contain),
                      )
                    : Icon(
                        _getIconCategoria(producto.categoriaNombre),
                        size: 60,
                        color: Colors.pinkAccent.withOpacity(0.5),
                      ),
              ),
              const SizedBox(height: 20),
              // Nombre y código
              Text(
                producto.nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    producto.codigoProducto,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      producto.categoriaNombre ?? 'Sin categoría',
                      style: const TextStyle(color: Colors.pinkAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (producto.descripcion != null) ...[
                const SizedBox(height: 12),
                Text(
                  producto.descripcion!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              const SizedBox(height: 24),
              // Precios
              Row(
                children: [
                  Expanded(
                    child: _buildInfoBox('Precio Base', _formatCurrency.format(producto.precioBase), Colors.blueAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoBox('Precio Público', _formatCurrency.format(producto.precioPublico), Colors.greenAccent),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoBox('Ganancia', _formatCurrency.format(producto.gananciaUnitaria), Colors.purpleAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoBox('% Ganancia', '${producto.porcentajeGanancia.toStringAsFixed(1)}%', Colors.amber),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Stock
              const Text(
                'Inventario',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoBox('Stock Actual', '${producto.stockActual}', 
                        producto.stockActual < producto.stockMinimo ? Colors.red : Colors.cyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoBox('Stock Mínimo', '${producto.stockMinimo}', Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Acciones
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarFormularioProducto(producto: producto);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _mostrarAjusteStock(producto),
                      icon: const Icon(Icons.inventory),
                      label: const Text('Ajustar Stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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

  Widget _buildInfoBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  void _mostrarAjusteStock(NiceProducto producto) {
    final cantidadController = TextEditingController();
    String tipo = 'entrada';
    String motivo = 'compra';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Ajustar Stock', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                producto.nombre,
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Stock actual: ${producto.stockActual}',
                style: const TextStyle(color: Colors.pinkAccent),
              ),
              const SizedBox(height: 16),
              // Tipo
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'entrada', label: Text('Entrada'), icon: Icon(Icons.add)),
                  ButtonSegment(value: 'salida', label: Text('Salida'), icon: Icon(Icons.remove)),
                ],
                selected: {tipo},
                onSelectionChanged: (v) => setDialogState(() => tipo = v.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cantidadController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: motivo,
                decoration: InputDecoration(
                  labelText: 'Motivo',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                items: tipo == 'entrada'
                    ? const [
                        DropdownMenuItem(value: 'compra', child: Text('Compra')),
                        DropdownMenuItem(value: 'devolucion', child: Text('Devolución')),
                        DropdownMenuItem(value: 'ajuste', child: Text('Ajuste')),
                      ]
                    : const [
                        DropdownMenuItem(value: 'venta', child: Text('Venta')),
                        DropdownMenuItem(value: 'merma', child: Text('Merma')),
                        DropdownMenuItem(value: 'ajuste', child: Text('Ajuste')),
                      ],
                onChanged: (v) => setDialogState(() => motivo = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cantidad = int.tryParse(cantidadController.text) ?? 0;
                if (cantidad <= 0) return;

                // Calcular nuevo stock
                final stockActual = producto.stock;
                final nuevoStock = tipo == 'entrada' 
                    ? stockActual + cantidad 
                    : stockActual - cantidad;

                final success = await NiceService.ajustarStock(
                  producto.id,
                  nuevoStock,
                  motivo: '${tipo == 'entrada' ? 'Entrada' : 'Salida'}: $motivo',
                );

                if (success && mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stock actualizado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFormularioProducto({NiceProducto? producto}) {
    final nombreController = TextEditingController(text: producto?.nombre);
    final codigoController = TextEditingController(text: producto?.codigoProducto);
    final descripcionController = TextEditingController(text: producto?.descripcion);
    final precioBaseController = TextEditingController(
        text: producto != null ? producto.precioBase.toString() : '');
    final precioPublicoController = TextEditingController(
        text: producto != null ? producto.precioPublico.toString() : '');
    final stockController = TextEditingController(
        text: producto != null ? producto.stockActual.toString() : '0');
    final stockMinController = TextEditingController(
        text: producto != null ? producto.stockMinimo.toString() : '5');
    String? categoriaSeleccionada = producto?.categoriaId;
    String? catalogoSeleccionado = producto?.catalogoId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                producto == null ? 'Nuevo Producto' : 'Editar Producto',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildTextField(nombreController, 'Nombre *', Icons.shopping_bag),
              _buildTextField(codigoController, 'Código', Icons.qr_code),
              _buildTextField(descripcionController, 'Descripción', Icons.description, maxLines: 2),
              Row(
                children: [
                  Expanded(child: _buildTextField(precioBaseController, 'Precio Base *', Icons.money, keyboard: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(precioPublicoController, 'Precio Público *', Icons.attach_money, keyboard: TextInputType.number)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(stockController, 'Stock', Icons.inventory, keyboard: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(stockMinController, 'Stock Mínimo', Icons.warning, keyboard: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              // Categoría
              DropdownButtonFormField<String>(
                value: categoriaSeleccionada,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.category, color: Colors.pinkAccent),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                items: _categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
                onChanged: (v) => categoriaSeleccionada = v,
              ),
              const SizedBox(height: 12),
              // Catálogo
              DropdownButtonFormField<String>(
                value: catalogoSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Catálogo',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.menu_book, color: Colors.pinkAccent),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin catálogo')),
                  ..._catalogos.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))),
                ],
                onChanged: (v) => catalogoSeleccionado = v,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nombreController.text.isEmpty ||
                        precioBaseController.text.isEmpty ||
                        precioPublicoController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Completa los campos requeridos')),
                      );
                      return;
                    }

                    final data = {
                      'nombre': nombreController.text,
                      'codigo_producto': codigoController.text.isEmpty ? null : codigoController.text,
                      'descripcion': descripcionController.text.isEmpty ? null : descripcionController.text,
                      'precio_vendedora': double.tryParse(precioBaseController.text) ?? 0,
                      'precio_catalogo': double.tryParse(precioPublicoController.text) ?? 0,
                      'stock': int.tryParse(stockController.text) ?? 0,
                      'stock_minimo': int.tryParse(stockMinController.text) ?? 5,
                      'categoria_id': categoriaSeleccionada,
                      'catalogo_id': catalogoSeleccionado,
                      'negocio_id': widget.negocioId,
                    };

                    bool success;
                    if (producto == null) {
                      final nuevo = NiceProducto(
                        id: '',
                        sku: data['sku'] as String? ?? '',
                        nombre: data['nombre'] as String,
                        descripcion: data['descripcion'] as String?,
                        precioVendedora: data['precio_vendedora'] as double,
                        precioCatalogo: data['precio_catalogo'] as double,
                        stock: data['stock'] as int,
                        stockMinimo: data['stock_minimo'] as int,
                        categoriaId: categoriaSeleccionada,
                        catalogoId: catalogoSeleccionado,
                        negocioId: widget.negocioId,
                      );
                      success = (await NiceService.crearProducto(nuevo)) != null;
                    } else {
                      success = await NiceService.actualizarProducto(producto.id, data);
                    }

                    if (success && mounted) {
                      Navigator.pop(context);
                      _cargarDatos();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(producto == null ? 'Producto creado' : 'Producto actualizado'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(producto == null ? 'Crear Producto' : 'Guardar Cambios'),
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
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.pinkAccent),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  void _mostrarCategorias() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Categorías',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.pinkAccent),
                  onPressed: () {
                    Navigator.pop(context);
                    _mostrarFormularioCategoria();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(
              _categorias.length,
              (index) {
                final cat = _categorias[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                    child: Icon(_getIconCategoria(cat.nombre), color: Colors.pinkAccent),
                  ),
                  title: Text(cat.nombre, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(cat.descripcion ?? '', style: const TextStyle(color: Colors.white54)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white54),
                    onPressed: () {
                      Navigator.pop(context);
                      _mostrarFormularioCategoria(categoria: cat);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFormularioCategoria({NiceCategoria? categoria}) {
    final nombreController = TextEditingController(text: categoria?.nombre);
    final descripcionController = TextEditingController(text: categoria?.descripcion);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          categoria == null ? 'Nueva Categoría' : 'Editar Categoría',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(nombreController, 'Nombre', Icons.category),
            _buildTextField(descripcionController, 'Descripción', Icons.description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.isEmpty) return;

              if (categoria == null) {
                final nueva = NiceCategoria(
                  id: '',
                  nombre: nombreController.text,
                  descripcion: descripcionController.text.isEmpty ? null : descripcionController.text,
                  negocioId: widget.negocioId,
                );
                await NiceService.crearCategoria(nueva);
              } else {
                await NiceService.actualizarCategoria(categoria.id, {
                  'nombre': nombreController.text,
                  'descripcion': descripcionController.text.isEmpty ? null : descripcionController.text,
                });
              }

              if (mounted) {
                Navigator.pop(context);
                _cargarDatos();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarFormularioCatalogo({NiceCatalogo? catalogo}) {
    final nombreController = TextEditingController(text: catalogo?.nombre);
    final descripcionController = TextEditingController(text: catalogo?.descripcion);
    DateTime fechaInicio = catalogo?.fechaInicio ?? DateTime.now();
    DateTime fechaFin = catalogo?.fechaFin ?? DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  catalogo == null ? 'Nuevo Catálogo' : 'Editar Catálogo',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildTextField(nombreController, 'Nombre *', Icons.menu_book),
                _buildTextField(descripcionController, 'Descripción', Icons.description, maxLines: 2),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fecha Inicio', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(fechaInicio),
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.calendar_today, color: Colors.pinkAccent),
                        onTap: () async {
                          final fecha = await showDatePicker(
                            context: context,
                            initialDate: fechaInicio,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (fecha != null) {
                            setSheetState(() => fechaInicio = fecha);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fecha Fin', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(fechaFin),
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.calendar_today, color: Colors.pinkAccent),
                        onTap: () async {
                          final fecha = await showDatePicker(
                            context: context,
                            initialDate: fechaFin,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (fecha != null) {
                            setSheetState(() => fechaFin = fecha);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nombreController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El nombre es requerido')),
                        );
                        return;
                      }

                      if (catalogo == null) {
                        final nuevo = NiceCatalogo(
                          id: '',
                          codigo: DateTime.now().millisecondsSinceEpoch.toString().substring(5),
                          nombre: nombreController.text,
                          descripcion: descripcionController.text.isEmpty ? null : descripcionController.text,
                          fechaInicio: fechaInicio,
                          fechaFin: fechaFin,
                          negocioId: widget.negocioId,
                        );
                        await NiceService.crearCatalogo(nuevo);
                      } else {
                        await NiceService.actualizarCatalogo(catalogo.id, {
                          'nombre': nombreController.text,
                          'descripcion': descripcionController.text.isEmpty ? null : descripcionController.text,
                          'fecha_inicio': fechaInicio.toIso8601String(),
                          'fecha_fin': fechaFin.toIso8601String(),
                        });
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        _cargarDatos();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(catalogo == null ? 'Catálogo creado' : 'Catálogo actualizado'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(catalogo == null ? 'Crear Catálogo' : 'Guardar Cambios'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
