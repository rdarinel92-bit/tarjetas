// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRODUCTOS PURIFICADORA - Gestión de Productos (Garrafones, etc.)
// Robert Darin Platform v10.22
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';

class PurificadoraProductosScreen extends StatefulWidget {
  final String negocioId;
  const PurificadoraProductosScreen({super.key, this.negocioId = ''});

  @override
  State<PurificadoraProductosScreen> createState() => _PurificadoraProductosScreenState();
}

class _PurificadoraProductosScreenState extends State<PurificadoraProductosScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _productos = [];
  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  String _filtroTipo = 'todos';

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    try {
      var query = AppSupabase.client
          .from('purificadora_productos')
          .select()
          .eq('negocio_id', widget.negocioId);
      
      if (_filtroTipo != 'todos') {
        query = query.eq('tipo', _filtroTipo);
      }
      
      final res = await query.order('nombre');
      
      if (mounted) {
        setState(() {
          _productos = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando productos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Productos',
      subtitle: 'Gestión de productos purificadora',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.white),
          onPressed: _mostrarFormularioProducto,
        ),
      ],
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
                : _productos.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _cargarProductos,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _productos.length,
                          itemBuilder: (context, i) => _buildProductoCard(_productos[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1A1A2E),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFiltroChip('todos', 'Todos'),
            const SizedBox(width: 8),
            _buildFiltroChip('garrafon', 'Garrafones'),
            const SizedBox(width: 8),
            _buildFiltroChip('botella', 'Botellas'),
            const SizedBox(width: 8),
            _buildFiltroChip('dispensador', 'Dispensadores'),
            const SizedBox(width: 8),
            _buildFiltroChip('accesorio', 'Accesorios'),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String tipo, String label) {
    final isSelected = _filtroTipo == tipo;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _filtroTipo = tipo);
        _cargarProductos();
      },
      backgroundColor: const Color(0xFF0D0D14),
      selectedColor: const Color(0xFF0EA5E9).withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey[400],
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey[700]!,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.water_drop_outlined, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Sin productos registrados',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _mostrarFormularioProducto,
            icon: const Icon(Icons.add),
            label: const Text('Agregar Producto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> producto) {
    final tipo = producto['tipo'] ?? 'garrafon';
    final activo = producto['activo'] ?? true;
    
    IconData tipoIcon;
    Color tipoColor;
    switch (tipo) {
      case 'garrafon':
        tipoIcon = Icons.water_drop;
        tipoColor = const Color(0xFF0EA5E9);
        break;
      case 'botella':
        tipoIcon = Icons.local_drink;
        tipoColor = const Color(0xFF10B981);
        break;
      case 'dispensador':
        tipoIcon = Icons.coffee_maker;
        tipoColor = const Color(0xFF8B5CF6);
        break;
      default:
        tipoIcon = Icons.shopping_bag;
        tipoColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activo ? tipoColor.withOpacity(0.3) : Colors.grey[700]!,
        ),
      ),
      child: InkWell(
        onTap: () => _mostrarFormularioProducto(producto: producto),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tipoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tipoIcon, color: tipoColor, size: 28),
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
                            producto['nombre'] ?? 'Sin nombre',
                            style: TextStyle(
                              color: activo ? Colors.white : Colors.grey[500],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!activo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'INACTIVO',
                              style: TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_capitalize(tipo)} • ${producto['capacidad_litros'] ?? '-'} L',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPrecioTag('Venta', producto['precio_venta'], tipoColor),
                        if (producto['precio_mayoreo'] != null) ...[
                          const SizedBox(width: 12),
                          _buildPrecioTag('Mayoreo', producto['precio_mayoreo'], const Color(0xFF10B981)),
                        ],
                        if (producto['deposito'] != null && (producto['deposito'] ?? 0) > 0) ...[
                          const SizedBox(width: 12),
                          _buildPrecioTag('Depósito', producto['deposito'], const Color(0xFFF59E0B)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${producto['stock'] ?? 0}',
                    style: TextStyle(
                      color: (producto['stock'] ?? 0) > 10 
                          ? const Color(0xFF10B981) 
                          : const Color(0xFFF59E0B),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Stock',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrecioTag(String label, dynamic precio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        Text(
          _formatCurrency.format(precio ?? 0),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _mostrarFormularioProducto({Map<String, dynamic>? producto}) {
    final isEdit = producto != null;
    final nombreCtrl = TextEditingController(text: producto?['nombre'] ?? '');
    final codigoCtrl = TextEditingController(text: producto?['codigo'] ?? '');
    final descripcionCtrl = TextEditingController(text: producto?['descripcion'] ?? '');
    final capacidadCtrl = TextEditingController(text: producto?['capacidad_litros']?.toString() ?? '');
    final precioVentaCtrl = TextEditingController(text: producto?['precio_venta']?.toString() ?? '');
    final precioMayoreoCtrl = TextEditingController(text: producto?['precio_mayoreo']?.toString() ?? '');
    final depositoCtrl = TextEditingController(text: producto?['deposito']?.toString() ?? '0');
    final stockCtrl = TextEditingController(text: producto?['stock']?.toString() ?? '0');
    String tipoSeleccionado = producto?['tipo'] ?? 'garrafon';
    bool activo = producto?['activo'] ?? true;

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
                  isEdit ? 'Editar Producto' : 'Nuevo Producto',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(nombreCtrl, 'Nombre del producto *', Icons.water_drop),
                const SizedBox(height: 12),
                _buildTextField(codigoCtrl, 'Código (opcional)', Icons.qr_code),
                const SizedBox(height: 12),
                const Text('Tipo de Producto', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tipoSeleccionado,
                  dropdownColor: const Color(0xFF1A1A2E),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0D0D14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'garrafon', child: Text('Garrafón', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'botella', child: Text('Botella', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'dispensador', child: Text('Dispensador', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'accesorio', child: Text('Accesorio', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) => setModalState(() => tipoSeleccionado = v ?? 'garrafon'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField(capacidadCtrl, 'Litros', Icons.straighten, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(stockCtrl, 'Stock', Icons.inventory, isNumber: true)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField(precioVentaCtrl, 'Precio Venta *', Icons.attach_money, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(precioMayoreoCtrl, 'Precio Mayoreo', Icons.attach_money, isNumber: true)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(depositoCtrl, 'Depósito (garrafón)', Icons.account_balance_wallet, isNumber: true),
                const SizedBox(height: 12),
                _buildTextField(descripcionCtrl, 'Descripción', Icons.description, maxLines: 2),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: activo,
                  onChanged: (v) => setModalState(() => activo = v),
                  title: const Text('Producto Activo', style: TextStyle(color: Colors.white)),
                  activeColor: const Color(0xFF10B981),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isEdit)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _eliminarProducto(producto['id']),
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
                        onPressed: () => _guardarProducto(
                          id: producto?['id'],
                          nombre: nombreCtrl.text,
                          codigo: codigoCtrl.text,
                          descripcion: descripcionCtrl.text,
                          tipo: tipoSeleccionado,
                          capacidad: double.tryParse(capacidadCtrl.text),
                          precioVenta: double.tryParse(precioVentaCtrl.text) ?? 0,
                          precioMayoreo: double.tryParse(precioMayoreoCtrl.text),
                          deposito: double.tryParse(depositoCtrl.text) ?? 0,
                          stock: int.tryParse(stockCtrl.text) ?? 0,
                          activo: activo,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
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

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, 
      {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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

  Future<void> _guardarProducto({
    String? id,
    required String nombre,
    String? codigo,
    String? descripcion,
    required String tipo,
    double? capacidad,
    required double precioVenta,
    double? precioMayoreo,
    required double deposito,
    required int stock,
    required bool activo,
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
        'codigo': codigo?.isNotEmpty == true ? codigo : null,
        'descripcion': descripcion?.isNotEmpty == true ? descripcion : null,
        'tipo': tipo,
        'capacidad_litros': capacidad,
        'precio_venta': precioVenta,
        'precio_mayoreo': precioMayoreo,
        'deposito': deposito,
        'stock': stock,
        'activo': activo,
      };

      if (id != null) {
        await AppSupabase.client.from('purificadora_productos').update(data).eq('id', id);
      } else {
        await AppSupabase.client.from('purificadora_productos').insert(data);
      }

      if (mounted) {
        Navigator.pop(context);
        _cargarProductos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? 'Producto actualizado' : 'Producto creado'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando producto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarProducto(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Eliminar Producto', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de eliminar este producto?', 
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
        await AppSupabase.client.from('purificadora_productos').delete().eq('id', id);
        if (mounted) {
          Navigator.pop(context);
          _cargarProductos();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto eliminado'), backgroundColor: Color(0xFF10B981)),
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
