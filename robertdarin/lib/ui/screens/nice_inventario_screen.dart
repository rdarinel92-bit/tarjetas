import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// NICE INVENTARIO VENDEDORA SCREEN V10.22
/// ═══════════════════════════════════════════════════════════════════════════════
/// Gestión del inventario personal de vendedoras Nice Joyería.
/// Muestra productos asignados, consignados y vendidos por vendedora.
/// Permite traspasos entre vendedoras y devoluciones a almacén central.
/// ═══════════════════════════════════════════════════════════════════════════════

class NiceInventarioScreen extends StatefulWidget {
  const NiceInventarioScreen({super.key});

  @override
  State<NiceInventarioScreen> createState() => _NiceInventarioScreenState();
}

class _NiceInventarioScreenState extends State<NiceInventarioScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _inventario = [];
  List<dynamic> _vendedoras = [];
  String _filtroVendedora = 'todas';
  String _filtroEstado = 'todos';
  late TabController _tabController;

  int get _totalPiezas => _inventarioFiltrado.fold(0, (sum, i) => sum + (i['cantidad'] ?? 0) as int);
  double get _totalValor => _inventarioFiltrado.fold(0.0, (sum, i) => sum + ((i['cantidad'] ?? 0) * (i['producto']?['precio_venta'] ?? 0)).toDouble());

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
      setState(() => _isLoading = true);
      
      // Cargar vendedoras
      final vendedoras = await AppSupabase.client
          .from('nice_vendedoras')
          .select('id, nombre, codigo')
          .eq('activa', true)
          .order('nombre');
      
      // Cargar inventario con productos y vendedoras
      final inventario = await AppSupabase.client
          .from('nice_inventario_vendedora')
          .select('''
            *,
            vendedora:nice_vendedoras(id, nombre, codigo),
            producto:nice_productos(id, nombre, sku, precio_venta, categoria_id, imagen_url)
          ''')
          .order('updated_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _vendedoras = vendedoras;
          _inventario = inventario;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _inventarioFiltrado {
    return _inventario.where((i) {
      if (_filtroVendedora != 'todas' && i['vendedora_id'] != _filtroVendedora) return false;
      if (_filtroEstado != 'todos' && i['estado'] != _filtroEstado) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Inventario Nice',
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () => _mostrarAsignarProducto(),
          tooltip: 'Asignar producto',
        ),
      ],
      body: Column(
        children: [
          _buildResumen(),
          _buildFiltros(),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListaInventario('todos'),
                _buildListaInventario('consignado'),
                _buildListaInventario('vendido'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.inventory_2, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  _formatNumber(_totalPiezas.toDouble()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Piezas en Inventario',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 70,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.diamond, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  '\$${_formatNumber(_totalValor)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Valor Total',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Filtro por vendedora
            _buildDropdownFiltro(
              'Vendedora',
              _filtroVendedora,
              [
                const DropdownMenuItem(value: 'todas', child: Text('Todas')),
                ..._vendedoras.map((v) => DropdownMenuItem(
                  value: v['id'],
                  child: Text(v['nombre'] ?? ''),
                )),
              ],
              (value) => setState(() => _filtroVendedora = value ?? 'todas'),
            ),
            const SizedBox(width: 12),
            // Botón refrescar
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF00D9FF)),
              onPressed: _cargarDatos,
              tooltip: 'Refrescar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFiltro(String label, String value, List<DropdownMenuItem<String>> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          dropdownColor: const Color(0xFF1A1A2E),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFEC4899)),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        tabs: const [
          Tab(text: 'Todo'),
          Tab(text: 'Consignado'),
          Tab(text: 'Vendido'),
        ],
      ),
    );
  }

  Widget _buildListaInventario(String filtro) {
    final items = filtro == 'todos' 
        ? _inventarioFiltrado 
        : _inventarioFiltrado.where((i) => i['estado'] == filtro).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)));
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 80, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Sin inventario',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18),
            ),
            Text(
              'Asigna productos a vendedoras',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _mostrarAsignarProducto(),
              icon: const Icon(Icons.add),
              label: const Text('Asignar Producto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: const Color(0xFFEC4899),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildInventarioCard(item);
        },
      ),
    );
  }

  Widget _buildInventarioCard(Map<String, dynamic> item) {
    final producto = item['producto'];
    final vendedora = item['vendedora'];
    final cantidad = item['cantidad'] ?? 0;
    final estado = item['estado'] ?? 'consignado';
    final precioVenta = (producto?['precio_venta'] ?? 0).toDouble();
    final valorTotal = cantidad * precioVenta;
    // ignore: unused_local_variable
    final fechaAsignacion = DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now();

    Color estadoColor;
    IconData estadoIcon;
    switch (estado) {
      case 'consignado':
        estadoColor = const Color(0xFF00D9FF);
        estadoIcon = Icons.inventory;
        break;
      case 'vendido':
        estadoColor = const Color(0xFF10B981);
        estadoIcon = Icons.sell;
        break;
      case 'devuelto':
        estadoColor = const Color(0xFFFBBF24);
        estadoIcon = Icons.undo;
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estadoColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalles(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Imagen del producto
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                    image: producto?['imagen_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(producto['imagen_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: producto?['imagen_url'] == null
                      ? Icon(Icons.diamond, color: estadoColor, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto?['nombre'] ?? 'Sin producto',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${producto?['sku'] ?? 'N/A'}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.white.withValues(alpha: 0.5), size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              vendedora?['nombre'] ?? 'Sin asignar',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Cantidad, valor y estado
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(estadoIcon, color: estadoColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            estado.toUpperCase(),
                            style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$cantidad pzas',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${_formatNumber(valorTotal)}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
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

  void _mostrarDetalles(Map<String, dynamic> item) {
    final producto = item['producto'];
    final vendedora = item['vendedora'];
    final cantidad = item['cantidad'] ?? 0;
    final estado = item['estado'] ?? 'consignado';
    final precioVenta = (producto?['precio_venta'] ?? 0).toDouble();
    final valorTotal = cantidad * precioVenta;
    final fechaAsignacion = DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header con imagen
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      image: producto?['imagen_url'] != null
                          ? DecorationImage(
                              image: NetworkImage(producto['imagen_url']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: producto?['imagen_url'] == null
                        ? const Icon(Icons.diamond, color: Colors.white, size: 40)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto?['nombre'] ?? 'Sin producto',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'SKU: ${producto?['sku'] ?? 'N/A'}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Detalles
              _buildDetalleRow('Vendedora', vendedora?['nombre'] ?? 'Sin asignar', Icons.person),
              _buildDetalleRow('Código', vendedora?['codigo'] ?? 'N/A', Icons.badge),
              _buildDetalleRow('Cantidad', '$cantidad piezas', Icons.inventory_2),
              _buildDetalleRow('Precio Unitario', '\$${_formatNumber(precioVenta)}', Icons.attach_money),
              _buildDetalleRow('Valor Total', '\$${_formatNumber(valorTotal)}', Icons.account_balance_wallet),
              _buildDetalleRow('Estado', estado.toUpperCase(), Icons.info),
              _buildDetalleRow('Asignado', DateFormat('dd/MM/yyyy').format(fechaAsignacion), Icons.calendar_today),
              const SizedBox(height: 24),
              // Acciones
              if (estado == 'consignado') ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _mostrarTraspasar(item);
                        },
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Traspasar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00D9FF),
                          side: const BorderSide(color: Color(0xFF00D9FF)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _marcarVendido(item);
                        },
                        icon: const Icon(Icons.sell),
                        label: const Text('Vender'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _devolverAlmacen(item);
                    },
                    icon: const Icon(Icons.undo),
                    label: const Text('Devolver a Almacén'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFBBF24),
                      side: const BorderSide(color: Color(0xFFFBBF24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFEC4899), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarAsignarProducto() {
    String? vendedoraSeleccionada;
    String? productoSeleccionado;
    final cantidadController = TextEditingController(text: '1');
    List<dynamic> productos = [];
    bool cargandoProductos = true;

    // Cargar productos
    AppSupabase.client
        .from('nice_productos')
        .select('id, nombre, sku, precio_venta')
        .eq('activo', true)
        .order('nombre')
        .then((res) {
          productos = res;
          cargandoProductos = false;
        });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Asignar Producto a Vendedora',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // Vendedora
              const Text('Vendedora *', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: vendedoraSeleccionada,
                    hint: const Text('Selecciona vendedora', style: TextStyle(color: Colors.white54)),
                    isExpanded: true,
                    items: _vendedoras.map((v) => DropdownMenuItem(
                      value: v['id'].toString(),
                      child: Text(v['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                    )).toList(),
                    onChanged: (value) => setModalState(() => vendedoraSeleccionada = value),
                    dropdownColor: const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Producto
              const Text('Producto *', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: cargandoProductos
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFFEC4899))),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: productoSeleccionado,
                          hint: const Text('Selecciona producto', style: TextStyle(color: Colors.white54)),
                          isExpanded: true,
                          items: productos.map((p) => DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text('${p['nombre']} (${p['sku']})', style: const TextStyle(color: Colors.white)),
                          )).toList(),
                          onChanged: (value) => setModalState(() => productoSeleccionado = value),
                          dropdownColor: const Color(0xFF1A1A2E),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              // Cantidad
              TextField(
                controller: cantidadController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.numbers, color: Color(0xFFEC4899)),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (vendedoraSeleccionada == null || productoSeleccionado == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Selecciona vendedora y producto'),
                              backgroundColor: Color(0xFFEF4444),
                            ),
                          );
                          return;
                        }

                        try {
                          await AppSupabase.client.from('nice_inventario_vendedora').insert({
                            'vendedora_id': vendedoraSeleccionada,
                            'producto_id': productoSeleccionado,
                            'cantidad': int.tryParse(cantidadController.text) ?? 1,
                            'estado': 'consignado',
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            _cargarDatos();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Producto asignado correctamente'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Asignar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarTraspasar(Map<String, dynamic> item) {
    String? nuevaVendedora;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Traspasar a otra vendedora', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: nuevaVendedora,
                decoration: InputDecoration(
                  labelText: 'Nueva Vendedora',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                dropdownColor: const Color(0xFF1A1A2E),
                items: _vendedoras
                    .where((v) => v['id'] != item['vendedora_id'])
                    .map((v) => DropdownMenuItem(
                          value: v['id'].toString(),
                          child: Text(v['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => nuevaVendedora = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nuevaVendedora == null) return;
                try {
                  await AppSupabase.client
                      .from('nice_inventario_vendedora')
                      .update({'vendedora_id': nuevaVendedora})
                      .eq('id', item['id']);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _cargarDatos();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Traspaso realizado'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                } catch (e) {
                  debugPrint('Error: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Traspasar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _marcarVendido(Map<String, dynamic> item) async {
    try {
      await AppSupabase.client
          .from('nice_inventario_vendedora')
          .update({'estado': 'vendido', 'fecha_venta': DateTime.now().toIso8601String()})
          .eq('id', item['id']);
      
      _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcado como vendido'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _devolverAlmacen(Map<String, dynamic> item) async {
    try {
      await AppSupabase.client
          .from('nice_inventario_vendedora')
          .update({'estado': 'devuelto', 'fecha_devolucion': DateTime.now().toIso8601String()})
          .eq('id', item['id']);
      
      _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devuelto a almacén'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  String _formatNumber(num number) {
    return number.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
