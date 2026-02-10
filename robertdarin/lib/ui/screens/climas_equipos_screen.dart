import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// CLIMAS EQUIPOS SCREEN V10.22
/// ═══════════════════════════════════════════════════════════════════════════════
/// Gestión de equipos de aire acondicionado y productos del módulo Climas.
/// CRUD completo: crear, editar, ver detalles, eliminar equipos.
/// Campos: nombre, marca, modelo, tipo, capacidad BTU, precio, stock.
/// ═══════════════════════════════════════════════════════════════════════════════

class ClimasEquiposScreen extends StatefulWidget {
  const ClimasEquiposScreen({super.key});

  @override
  State<ClimasEquiposScreen> createState() => _ClimasEquiposScreenState();
}

class _ClimasEquiposScreenState extends State<ClimasEquiposScreen> {
  bool _isLoading = true;
  List<dynamic> _equipos = [];
  String _filtroTipo = 'todos';
  String _busqueda = '';
  final TextEditingController _busquedaController = TextEditingController();
  String? _negocioId;

  @override
  void initState() {
    super.initState();
    _cargarEquipos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarEquipos() async {
    try {
      setState(() => _isLoading = true);
      if (_negocioId == null) {
        _negocioId = await _cargarNegocioActivoId();
      }
      var query = AppSupabase.client
          .from('climas_productos')
          .select();

      final negocioId = _negocioId;
      if (negocioId != null) {
        query = query.eq('negocio_id', negocioId);
      }
      
      if (_filtroTipo != 'todos') {
        query = query.eq('tipo', _filtroTipo);
      }
      
      final res = await query.order('nombre', ascending: true);
      
      if (mounted) {
        setState(() {
          _equipos = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando equipos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _cargarNegocioActivoId() async {
    try {
      final configRes = await AppSupabase.client
          .from('configuracion_global')
          .select('valor')
          .eq('clave', 'negocio_activo')
          .maybeSingle();
      if (configRes != null) {
        final valor = configRes['valor'];
        if (valor is Map && valor['id'] != null) {
          return valor['id'].toString();
        }
        if (valor is String && valor.isNotEmpty) {
          return valor;
        }
      }
    } catch (_) {}

    try {
      final negocio = await AppSupabase.client
          .from('negocios')
          .select('id')
          .limit(1)
          .maybeSingle();
      return negocio?['id'];
    } catch (_) {}

    return null;
  }

  List<dynamic> get _equiposFiltrados {
    if (_busqueda.isEmpty) return _equipos;
    return _equipos.where((e) {
      final nombre = (e['nombre'] ?? '').toString().toLowerCase();
      final marca = (e['marca'] ?? '').toString().toLowerCase();
      final modelo = (e['modelo'] ?? '').toString().toLowerCase();
      final search = _busqueda.toLowerCase();
      return nombre.contains(search) || marca.contains(search) || modelo.contains(search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Equipos de A/C',
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () => _mostrarFormulario(),
          tooltip: 'Agregar equipo',
        ),
      ],
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF)))
                : _equiposFiltrados.isEmpty
                    ? _buildEmptyState()
                    : _buildListaEquipos(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
      ),
      child: Column(
        children: [
          // Buscador
          TextField(
            controller: _busquedaController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, marca o modelo...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00D9FF)),
              filled: true,
              fillColor: const Color(0xFF16213E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _busquedaController.clear();
                        setState(() => _busqueda = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _busqueda = value),
          ),
          const SizedBox(height: 12),
          // Filtros por tipo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChipFiltro('Todos', 'todos'),
                _buildChipFiltro('Mini Split', 'mini_split'),
                _buildChipFiltro('Multi Split', 'multisplit'),
                _buildChipFiltro('Central', 'central'),
                _buildChipFiltro('Ventana', 'ventana'),
                _buildChipFiltro('Portátil', 'portatil'),
                _buildChipFiltro('Cassette', 'cassette'),
                _buildChipFiltro('Piso-Techo', 'piso_techo'),
                _buildChipFiltro('Paquete', 'paquete'),
                _buildChipFiltro('Industrial', 'industrial'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String label, String value) {
    final isSelected = _filtroTipo == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filtroTipo = value);
          _cargarEquipos();
        },
        backgroundColor: const Color(0xFF16213E),
        selectedColor: const Color(0xFF00D9FF).withValues(alpha: 0.3),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF00D9FF) : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF00D9FF) : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ac_unit, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Sin equipos registrados',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tu primer equipo de A/C',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _mostrarFormulario(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Equipo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaEquipos() {
    return RefreshIndicator(
      onRefresh: _cargarEquipos,
      color: const Color(0xFF00D9FF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _equiposFiltrados.length,
        itemBuilder: (context, index) {
          final equipo = _equiposFiltrados[index];
          return _buildEquipoCard(equipo);
        },
      ),
    );
  }

  Widget _buildEquipoCard(Map<String, dynamic> equipo) {
    final stock = equipo['stock'] ?? 0;
    final precio = (equipo['precio_venta'] ?? equipo['precio'] ?? 0).toDouble();
    final capacidadBtu = equipo['capacidad_btu'] ?? 0;
    final activo = equipo['activo'] ?? true;
    final imagenUrl = (equipo['imagen_url'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: activo
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [const Color(0xFF2D2D3A), const Color(0xFF1F1F2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activo ? const Color(0xFF00D9FF).withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalles(equipo),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono según tipo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00D9FF).withValues(alpha: 0.3),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imagenUrl.isNotEmpty
                      ? Image.network(
                          imagenUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            _getIconoTipo(equipo['tipo']),
                            color: const Color(0xFF00D9FF),
                            size: 30,
                          ),
                        )
                      : Icon(
                          _getIconoTipo(equipo['tipo']),
                          color: const Color(0xFF00D9FF),
                          size: 30,
                        ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipo['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''}'.trim(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Capacidad BTU
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_formatNumber(capacidadBtu)} BTU',
                              style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Stock
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: stock > 0
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Stock: $stock',
                              style: TextStyle(
                                color: stock > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Precio y acciones
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${_formatNumber(precio)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFFFBBF24), size: 20),
                          onPressed: () => _mostrarFormulario(equipo: equipo),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
                          onPressed: () => _confirmarEliminar(equipo),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      ],
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

  IconData _getIconoTipo(String? tipo) {
    switch (tipo) {
      case 'mini_split':
        return Icons.ac_unit;
      case 'multisplit':
        return Icons.device_hub;
      case 'central':
        return Icons.home_work;
      case 'ventana':
        return Icons.window;
      case 'portatil':
        return Icons.toys;
      case 'cassette':
        return Icons.view_module;
      case 'piso_techo':
        return Icons.unfold_more;
      case 'paquete':
        return Icons.all_inbox;
      case 'industrial':
        return Icons.factory;
      default:
        return Icons.ac_unit;
    }
  }

  String _formatNumber(num number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<String?> _subirFotoEquipo(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final name = file.name.isNotEmpty
          ? file.name
          : 'equipo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ext = name.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final fileName =
          'equipos/${_negocioId ?? 'global'}/${DateTime.now().millisecondsSinceEpoch}_$name';

      await AppSupabase.client.storage
          .from('climas_equipos')
          .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: mime));

      return AppSupabase.client.storage.from('climas_equipos').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error subiendo foto de equipo: $e');
      return null;
    }
  }

  void _mostrarDetalles(Map<String, dynamic> equipo) {
    final imagenUrl = (equipo['imagen_url'] ?? '').toString();
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
              // Handle
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
              // Header
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getIconoTipo(equipo['tipo']),
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipo['nombre'] ?? 'Sin nombre',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''}'.trim(),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (imagenUrl.isNotEmpty) ...[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imagenUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image, color: Colors.white54, size: 40),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Detalles
              _buildDetalleRow('Tipo', _getTipoLabel(equipo['tipo']), Icons.category),
              _buildDetalleRow('Capacidad', '${_formatNumber(equipo['capacidad_btu'] ?? 0)} BTU', Icons.speed),
              _buildDetalleRow('Precio venta', '\$${_formatNumber((equipo['precio_venta'] ?? equipo['precio'] ?? 0).toDouble())}', Icons.attach_money),
              _buildDetalleRow('Precio instalación', '\$${_formatNumber((equipo['precio_instalacion'] ?? 0).toDouble())}', Icons.construction),
              _buildDetalleRow('Costo', '\$${_formatNumber((equipo['costo'] ?? 0).toDouble())}', Icons.price_check),
              _buildDetalleRow('Stock', '${equipo['stock'] ?? 0} unidades', Icons.inventory_2),
              _buildDetalleRow('Stock mínimo', '${equipo['stock_minimo'] ?? 0}', Icons.warning_amber),
              if ((equipo['codigo'] ?? '').toString().isNotEmpty)
                _buildDetalleRow('Código', equipo['codigo'], Icons.qr_code),
              if ((equipo['categoria'] ?? '').toString().isNotEmpty)
                _buildDetalleRow('Categoría', equipo['categoria'], Icons.label),
              if ((equipo['subcategoria'] ?? '').toString().isNotEmpty)
                _buildDetalleRow('Subcategoría', equipo['subcategoria'], Icons.label_outline),
              if ((equipo['ubicacion_almacen'] ?? '').toString().isNotEmpty)
                _buildDetalleRow('Ubicación almacén', equipo['ubicacion_almacen'], Icons.location_on),
              if ((equipo['proveedor_principal'] ?? '').toString().isNotEmpty)
                _buildDetalleRow('Proveedor', equipo['proveedor_principal'], Icons.local_shipping),
              if (equipo['garantia_meses'] != null)
                _buildDetalleRow('Garantía', '${equipo['garantia_meses']} meses', Icons.verified),
              _buildDetalleRow('Estado', (equipo['activo'] ?? true) ? 'Activo' : 'Inactivo', Icons.toggle_on),
              if (equipo['descripcion'] != null && equipo['descripcion'].toString().isNotEmpty)
                _buildDetalleRow('Descripción', equipo['descripcion'], Icons.description),
              const SizedBox(height: 24),
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarFormulario(equipo: equipo);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFBBF24),
                        side: const BorderSide(color: Color(0xFFFBBF24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cerrar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16213E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  String _getTipoLabel(String? tipo) {
    switch (tipo) {
      case 'mini_split': return 'Mini Split';
      case 'multisplit': return 'Multi Split';
      case 'central': return 'Central';
      case 'ventana': return 'Ventana';
      case 'portatil': return 'Portátil';
      case 'cassette': return 'Cassette';
      case 'piso_techo': return 'Piso-Techo';
      case 'paquete': return 'Paquete';
      case 'industrial': return 'Industrial';
      default: return tipo ?? 'No especificado';
    }
  }

  Widget _buildDetalleRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF00D9FF), size: 20),
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

  void _mostrarFormulario({Map<String, dynamic>? equipo}) {
    final isEditing = equipo != null;
    final nombreController = TextEditingController(text: equipo?['nombre'] ?? '');
    final marcaController = TextEditingController(text: equipo?['marca'] ?? '');
    final modeloController = TextEditingController(text: equipo?['modelo'] ?? '');
    final codigoController = TextEditingController(text: equipo?['codigo'] ?? '');
    final categoriaController = TextEditingController(text: equipo?['categoria'] ?? '');
    final subcategoriaController = TextEditingController(text: equipo?['subcategoria'] ?? '');
    final capacidadController = TextEditingController(text: (equipo?['capacidad_btu'] ?? '').toString());
    final precioController = TextEditingController(text: (equipo?['precio_venta'] ?? equipo?['precio'] ?? '').toString());
    final precioInstalacionController = TextEditingController(text: (equipo?['precio_instalacion'] ?? '').toString());
    final costoController = TextEditingController(text: (equipo?['costo'] ?? '').toString());
    final stockController = TextEditingController(text: (equipo?['stock'] ?? '0').toString());
    final stockMinimoController = TextEditingController(text: (equipo?['stock_minimo'] ?? '5').toString());
    final garantiaController = TextEditingController(text: (equipo?['garantia_meses'] ?? '12').toString());
    final ubicacionController = TextEditingController(text: equipo?['ubicacion_almacen'] ?? '');
    final proveedorController = TextEditingController(text: equipo?['proveedor_principal'] ?? '');
    final descripcionController = TextEditingController(text: equipo?['descripcion'] ?? '');
    String tipoSeleccionado = equipo?['tipo'] ?? 'mini_split';
    bool activo = equipo?['activo'] ?? true;
    String? imagenUrl = equipo?['imagen_url'];
    XFile? imagenFile;
    bool subiendoImagen = false;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                Text(
                  isEditing ? 'Editar Equipo' : 'Nuevo Equipo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // Nombre
                _buildTextField('Nombre *', nombreController, Icons.ac_unit),
                const SizedBox(height: 16),
                // Marca y Modelo
                Row(
                  children: [
                    Expanded(child: _buildTextField('Marca', marcaController, Icons.branding_watermark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Modelo', modeloController, Icons.confirmation_number)),
                  ],
                ),
                const SizedBox(height: 16),
                // Código y Garantía
                Row(
                  children: [
                    Expanded(child: _buildTextField('Código', codigoController, Icons.qr_code)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Garantía (meses)', garantiaController, Icons.verified, isNumber: true)),
                  ],
                ),
                const SizedBox(height: 16),
                // Categoría y Subcategoría
                Row(
                  children: [
                    Expanded(child: _buildTextField('Categoría', categoriaController, Icons.label)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Subcategoría', subcategoriaController, Icons.label_outline)),
                  ],
                ),
                const SizedBox(height: 16),
                // Tipo
                Text('Tipo de Equipo', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTipoChip('Mini Split', 'mini_split', tipoSeleccionado, (v) => setModalState(() => tipoSeleccionado = v)),
                    _buildTipoChip('Multi Split', 'multisplit', tipoSeleccionado, (v) => setModalState(() => tipoSeleccionado = v)),
                    _buildTipoChip('Central', 'central', tipoSeleccionado, (v) => setModalState(() => tipoSeleccionado = v)),
                    _buildTipoChip('Ventana', 'ventana', tipoSeleccionado, (v) => setModalState(() => tipoSeleccionado = v)),
                    _buildTipoChip('Portátil', 'portatil', tipoSeleccionado, (v) => setModalState(() => tipoSeleccionado = v)),
                    _buildTipoChip('Cassette', 'cassette', tipoSeleccionado, (v) => setModalState(() => tipoSeleccionado = v)),
                    _buildTipoChip('Piso-Techo', 'piso_techo', tipoSeleccionado, (v) => setModalState(() => tipoSeleccionado = v)),
                    _buildTipoChip('Paquete', 'paquete', tipoSeleccionado, (v) => setModalState(() => tipoSeleccionado = v)),
                    _buildTipoChip('Industrial', 'industrial', tipoSeleccionado, (v) => setModalState(() => tipoSeleccionado = v)),
                  ],
                ),
                const SizedBox(height: 16),
                // Capacidad y precios
                Row(
                  children: [
                    Expanded(child: _buildTextField('BTU', capacidadController, Icons.speed, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Precio venta', precioController, Icons.attach_money, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Precio instalación', precioInstalacionController, Icons.construction, isNumber: true)),
                  ],
                ),
                const SizedBox(height: 16),
                // Stock y costos
                Row(
                  children: [
                    Expanded(child: _buildTextField('Stock', stockController, Icons.inventory, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Stock mínimo', stockMinimoController, Icons.warning_amber, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Costo', costoController, Icons.price_check, isNumber: true)),
                  ],
                ),
                const SizedBox(height: 16),
                // Ubicación y proveedor
                Row(
                  children: [
                    Expanded(child: _buildTextField('Ubicación almacén', ubicacionController, Icons.location_on)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Proveedor', proveedorController, Icons.local_shipping)),
                  ],
                ),
                const SizedBox(height: 16),
                // Foto del equipo
                Text('Foto del equipo', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (imagenFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(imagenFile!.path),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (imagenUrl != null && imagenUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imagenUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: Colors.white10,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, color: Colors.white54),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image, color: Colors.white54),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton.icon(
                            onPressed: subiendoImagen
                                ? null
                                : () async {
                                    final picker = ImagePicker();
                                    final file = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 80,
                                    );
                                    if (file != null) {
                                      setModalState(() => imagenFile = file);
                                    }
                                  },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Elegir foto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1A2E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (imagenFile != null || (imagenUrl != null && imagenUrl!.isNotEmpty))
                            TextButton(
                              onPressed: subiendoImagen
                                  ? null
                                  : () => setModalState(() {
                                        imagenFile = null;
                                        imagenUrl = null;
                                      }),
                              child: const Text('Quitar foto', style: TextStyle(color: Colors.redAccent)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Descripción
                _buildTextField('Descripción', descripcionController, Icons.description, maxLines: 3),
                const SizedBox(height: 16),
                // Activo
                SwitchListTile(
                  title: const Text('Equipo Activo', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    activo ? 'Visible en catálogo' : 'Oculto del catálogo',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  value: activo,
                  onChanged: (v) => setModalState(() => activo = v),
                  activeColor: const Color(0xFF10B981),
                  contentPadding: EdgeInsets.zero,
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
                          if (nombreController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('El nombre es requerido'), backgroundColor: Color(0xFFEF4444)),
                            );
                            return;
                          }

                          try {
                            if (imagenFile != null) {
                              setModalState(() => subiendoImagen = true);
                              final url = await _subirFotoEquipo(imagenFile!);
                              if (url != null) {
                                imagenUrl = url;
                              }
                              setModalState(() => subiendoImagen = false);
                            }

                            final data = {
                              'negocio_id': _negocioId ?? equipo?['negocio_id'],
                              'nombre': nombreController.text.trim(),
                              'marca': marcaController.text.trim(),
                              'modelo': modeloController.text.trim(),
                              'codigo': codigoController.text.trim().isEmpty ? null : codigoController.text.trim(),
                              'categoria': categoriaController.text.trim().isEmpty ? null : categoriaController.text.trim(),
                              'subcategoria': subcategoriaController.text.trim().isEmpty ? null : subcategoriaController.text.trim(),
                              'tipo': tipoSeleccionado,
                              'capacidad_btu': int.tryParse(capacidadController.text) ?? 0,
                              'precio_venta': double.tryParse(precioController.text) ?? 0,
                              'precio_instalacion': double.tryParse(precioInstalacionController.text) ?? 0,
                              'costo': double.tryParse(costoController.text) ?? 0,
                              'stock': int.tryParse(stockController.text) ?? 0,
                              'stock_minimo': int.tryParse(stockMinimoController.text) ?? 0,
                              'garantia_meses': int.tryParse(garantiaController.text) ?? 12,
                              'ubicacion_almacen': ubicacionController.text.trim().isEmpty ? null : ubicacionController.text.trim(),
                              'proveedor_principal': proveedorController.text.trim().isEmpty ? null : proveedorController.text.trim(),
                              'descripcion': descripcionController.text.trim(),
                              'imagen_url': imagenUrl,
                              'activo': activo,
                            };

                            if (isEditing) {
                              await AppSupabase.client
                                  .from('climas_productos')
                                  .update(data)
                                  .eq('id', equipo['id']);
                            } else {
                              await AppSupabase.client
                                  .from('climas_productos')
                                  .insert(data);
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              _cargarEquipos();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing ? 'Equipo actualizado' : 'Equipo creado'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error guardando equipo: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                              );
                            }
                          }
                        },
                        icon: Icon(isEditing ? Icons.save : Icons.add),
                        label: Text(isEditing ? 'Guardar' : 'Crear Equipo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D9FF),
                          foregroundColor: Colors.black,
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
      ),
    );
  }

  Widget _buildTipoChip(String label, String value, String selected, Function(String) onSelect) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (sel) => onSelect(value),
      backgroundColor: const Color(0xFF16213E),
      selectedColor: const Color(0xFF00D9FF).withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF00D9FF) : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? const Color(0xFF00D9FF) : Colors.transparent),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: const Color(0xFF00D9FF), size: 20),
        filled: true,
        fillColor: const Color(0xFF16213E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D9FF)),
        ),
      ),
    );
  }

  void _confirmarEliminar(Map<String, dynamic> equipo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar Equipo?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Se eliminará "${equipo['nombre']}" permanentemente.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AppSupabase.client
                    .from('climas_productos')
                    .delete()
                    .eq('id', equipo['id']);
                
                if (mounted) {
                  Navigator.pop(context);
                  _cargarEquipos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Equipo eliminado'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              } catch (e) {
                debugPrint('Error eliminando: $e');
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
