// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _movimientos = [];
  final _currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
  String _filtroCategoria = 'todos';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final resProductos = await AppSupabase.client.from('inventario').select().order('nombre');
      final resMovimientos = await AppSupabase.client.from('inventario_movimientos').select('*, inventario(nombre)').order('created_at', ascending: false).limit(50);
      
      if (mounted) {
        setState(() {
          _productos = List<Map<String, dynamic>>.from(resProductos);
          _movimientos = List<Map<String, dynamic>>.from(resMovimientos);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando inventario: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Inventario",
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos),
        IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: _mostrarDialogoNuevoProducto),
      ],
      body: Column(
        children: [
          _buildStats(),
          Container(
            color: const Color(0xFF1A1A2E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.cyanAccent,
              tabs: [
                Tab(text: "Productos (${_productos.length})"),
                Tab(text: "Movimientos (${_movimientos.length})"),
                const Tab(text: "Bajo Stock"),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaProductos(),
                      _buildListaMovimientos(),
                      _buildProductosBajoStock(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final valorTotal = _productos.fold<double>(0, (sum, p) => sum + ((p['precio_unitario'] ?? 0) as num).toDouble() * ((p['cantidad'] ?? 0) as num).toDouble());
    final bajoStock = _productos.where((p) => ((p['cantidad'] ?? 0) as num) <= ((p['stock_minimo'] ?? 5) as num)).length;
    
    return PremiumCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Productos", _productos.length.toString(), Icons.inventory_2),
          _buildStatItem("Bajo Stock", bajoStock.toString(), Icons.warning_amber, Colors.orange),
          _buildStatItem("Valor", _currencyFormat.format(valorTotal), Icons.attach_money, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.cyanAccent, size: 28),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildListaProductos() {
    if (_productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2, size: 60, color: Colors.white24),
            const SizedBox(height: 15),
            const Text("No hay productos", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _mostrarDialogoNuevoProducto, icon: const Icon(Icons.add), label: const Text("Agregar Producto")),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _productos.length,
      itemBuilder: (context, index) {
        final prod = _productos[index];
        final cantidad = (prod['cantidad'] ?? 0) as num;
        final stockMin = (prod['stock_minimo'] ?? 5) as num;
        final bajStock = cantidad <= stockMin;
        
        return Card(
          color: const Color(0xFF1A1A2E),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: bajStock ? Colors.red.withOpacity(0.2) : Colors.cyan.withOpacity(0.2),
              child: Icon(Icons.inventory, color: bajStock ? Colors.red : Colors.cyan),
            ),
            title: Text(prod['nombre'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white)),
            subtitle: Text('${prod['categoria'] ?? 'Sin categoría'} • SKU: ${prod['sku'] ?? '-'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$cantidad unid.', style: TextStyle(color: bajStock ? Colors.red : Colors.white, fontWeight: FontWeight.bold)),
                Text(_currencyFormat.format((prod['precio_unitario'] ?? 0).toDouble()), style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ],
            ),
            onTap: () => _mostrarDetalleProducto(prod),
            onLongPress: () => _mostrarMenuProducto(prod),
          ),
        );
      },
    );
  }

  Widget _buildListaMovimientos() {
    if (_movimientos.isEmpty) return const Center(child: Text("No hay movimientos", style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _movimientos.length,
      itemBuilder: (context, index) {
        final mov = _movimientos[index];
        final esEntrada = mov['tipo'] == 'entrada';
        final fecha = DateTime.tryParse(mov['created_at'] ?? '') ?? DateTime.now();
        
        return Card(
          color: const Color(0xFF1A1A2E),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (esEntrada ? Colors.green : Colors.red).withOpacity(0.2),
              child: Icon(esEntrada ? Icons.add_circle : Icons.remove_circle, color: esEntrada ? Colors.green : Colors.red),
            ),
            title: Text(mov['inventario']?['nombre'] ?? 'Producto desconocido', style: const TextStyle(color: Colors.white)),
            subtitle: Text('${mov['motivo'] ?? mov['tipo']} • ${DateFormat('dd/MM HH:mm').format(fecha)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: Text('${esEntrada ? '+' : '-'}${mov['cantidad']}', style: TextStyle(color: esEntrada ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        );
      },
    );
  }

  Widget _buildProductosBajoStock() {
    final productosBajo = _productos.where((p) => ((p['cantidad'] ?? 0) as num) <= ((p['stock_minimo'] ?? 5) as num)).toList();
    
    if (productosBajo.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 60, color: Colors.green),
            SizedBox(height: 15),
            Text("¡Todo en orden!", style: TextStyle(color: Colors.white)),
            Text("No hay productos con bajo stock", style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: productosBajo.length,
      itemBuilder: (context, index) {
        final prod = productosBajo[index];
        return Card(
          color: Colors.red.withOpacity(0.1),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
            title: Text(prod['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
            subtitle: Text('Mínimo: ${prod['stock_minimo']} unidades', style: const TextStyle(color: Colors.white54)),
            trailing: Text('${prod['cantidad']} unid.', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
            onTap: () => _mostrarDialogoReabastecer(prod),
          ),
        );
      },
    );
  }

  void _mostrarDialogoNuevoProducto() {
    final nombreCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: '0');
    final precioCtrl = TextEditingController(text: '0');
    final stockMinCtrl = TextEditingController(text: '5');
    String categoria = 'general';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Nuevo Producto", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre del producto")),
              const SizedBox(height: 10),
              TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: "SKU / Código")),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: categoria,
                decoration: const InputDecoration(labelText: "Categoría"),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'refacciones', child: Text('Refacciones')),
                  DropdownMenuItem(value: 'herramientas', child: Text('Herramientas')),
                  DropdownMenuItem(value: 'consumibles', child: Text('Consumibles')),
                  DropdownMenuItem(value: 'equipos', child: Text('Equipos')),
                ],
                onChanged: (v) => categoria = v ?? 'general',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: cantidadCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cantidad"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: precioCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Precio", prefixText: "\$"))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: stockMinCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock mínimo")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.isEmpty) return;
              try {
                await AppSupabase.client.from('inventario').insert({
                  'nombre': nombreCtrl.text,
                  'sku': skuCtrl.text.isEmpty ? null : skuCtrl.text,
                  'categoria': categoria,
                  'cantidad': int.tryParse(cantidadCtrl.text) ?? 0,
                  'precio_unitario': double.tryParse(precioCtrl.text) ?? 0,
                  'stock_minimo': int.tryParse(stockMinCtrl.text) ?? 5,
                });
                Navigator.pop(context);
                _cargarDatos();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto agregado'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleProducto(Map<String, dynamic> prod) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prod['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(height: 25),
            _buildDetalleRow("SKU", prod['sku'] ?? '-'),
            _buildDetalleRow("Categoría", prod['categoria'] ?? '-'),
            _buildDetalleRow("Cantidad", "${prod['cantidad']} unidades"),
            _buildDetalleRow("Precio", _currencyFormat.format((prod['precio_unitario'] ?? 0).toDouble())),
            _buildDetalleRow("Stock Mínimo", "${prod['stock_minimo']} unidades"),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _registrarMovimiento(prod, 'entrada'); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), icon: const Icon(Icons.add), label: const Text("Entrada"))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _registrarMovimiento(prod, 'salida'); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), icon: const Icon(Icons.remove), label: const Text("Salida"))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white54)), Text(value, style: const TextStyle(color: Colors.white))]),
  );

  void _registrarMovimiento(Map<String, dynamic> prod, String tipo) {
    final cantidadCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text("Registrar ${tipo == 'entrada' ? 'Entrada' : 'Salida'}", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: cantidadCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cantidad")),
            const SizedBox(height: 10),
            TextField(controller: motivoCtrl, decoration: const InputDecoration(labelText: "Motivo (opcional)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tipo == 'entrada' ? Colors.green : Colors.red),
            onPressed: () async {
              final cantidad = int.tryParse(cantidadCtrl.text) ?? 0;
              if (cantidad <= 0) return;
              try {
                await AppSupabase.client.from('inventario_movimientos').insert({
                  'producto_id': prod['id'],
                  'tipo': tipo,
                  'cantidad': cantidad,
                  'motivo': motivoCtrl.text.isEmpty ? null : motivoCtrl.text,
                });
                final nuevaCantidad = tipo == 'entrada' ? (prod['cantidad'] as num) + cantidad : (prod['cantidad'] as num) - cantidad;
                await AppSupabase.client.from('inventario').update({'cantidad': nuevaCantidad}).eq('id', prod['id']);
                Navigator.pop(context);
                _cargarDatos();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text("Registrar"),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoReabastecer(Map<String, dynamic> prod) => _registrarMovimiento(prod, 'entrada');

  void _mostrarMenuProducto(Map<String, dynamic> prod) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.edit, color: Colors.cyan), title: const Text("Editar", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); /* TODO: editar */ }),
          ListTile(leading: const Icon(Icons.add_circle, color: Colors.green), title: const Text("Registrar entrada", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _registrarMovimiento(prod, 'entrada'); }),
          ListTile(leading: const Icon(Icons.remove_circle, color: Colors.red), title: const Text("Registrar salida", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _registrarMovimiento(prod, 'salida'); }),
          ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Eliminar", style: TextStyle(color: Colors.red)), onTap: () async {
            Navigator.pop(context);
            await AppSupabase.client.from('inventario').delete().eq('id', prod['id']);
            _cargarDatos();
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
