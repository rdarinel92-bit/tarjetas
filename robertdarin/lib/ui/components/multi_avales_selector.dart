// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/models/aval_model.dart';

/// Widget para seleccionar múltiples avales para un préstamo o tanda
/// Soporta límite configurable desde configuracion_global
class MultiAvalesSelector extends StatefulWidget {
  final String? prestamoId;
  final String? tandaId;
  final List<String> avalesSeleccionadosIds;
  final Function(List<String>) onAvalesChanged;
  final int? maxAvales; // Si es null, usa el default de config

  const MultiAvalesSelector({
    super.key,
    this.prestamoId,
    this.tandaId,
    required this.avalesSeleccionadosIds,
    required this.onAvalesChanged,
    this.maxAvales,
  });

  @override
  State<MultiAvalesSelector> createState() => _MultiAvalesSelectorState();
}

class _MultiAvalesSelectorState extends State<MultiAvalesSelector> {
  List<AvalModel> _todosAvales = [];
  List<String> _seleccionados = [];
  bool _cargando = true;
  int _maxAvalesPermitidos = 3;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _seleccionados = List.from(widget.avalesSeleccionadosIds);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // Cargar configuración de máximo de avales
      final config = await AppSupabase.client
          .from('configuracion_global')
          .select()
          .maybeSingle();

      if (widget.maxAvales != null) {
        _maxAvalesPermitidos = widget.maxAvales!;
      } else if (widget.prestamoId != null) {
        _maxAvalesPermitidos = config?['max_avales_prestamo'] ?? 3;
      } else if (widget.tandaId != null) {
        _maxAvalesPermitidos = config?['max_avales_tanda'] ?? 2;
      }

      // Cargar todos los avales activos
      final avalesData = await AppSupabase.client
          .from('avales')
          .select()
          .eq('estado', 'activo')
          .order('nombre_completo');

      setState(() {
        _todosAvales =
            (avalesData as List).map((a) => AvalModel.fromMap(a)).toList();
        _cargando = false;
      });
    } catch (e) {
      debugPrint("Error cargando avales: $e");
      setState(() => _cargando = false);
    }
  }

  void _toggleAval(String avalId) {
    setState(() {
      if (_seleccionados.contains(avalId)) {
        _seleccionados.remove(avalId);
      } else if (_seleccionados.length < _maxAvalesPermitidos) {
        _seleccionados.add(avalId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Máximo $_maxAvalesPermitidos avales permitidos"),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
      widget.onAvalesChanged(_seleccionados);
    });
  }

  List<AvalModel> get _avalesFiltrados {
    if (_busqueda.isEmpty) return _todosAvales;
    final query = _busqueda.toLowerCase();
    return _todosAvales.where((a) {
      return a.nombre.toLowerCase().contains(query) ||
          a.telefono.toLowerCase().contains(query) ||
          a.email.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.purpleAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Avales / Fiadores",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _seleccionados.length >= _maxAvalesPermitidos
                        ? Colors.greenAccent.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${_seleccionados.length} / $_maxAvalesPermitidos",
                    style: TextStyle(
                      color: _seleccionados.length >= _maxAvalesPermitidos
                          ? Colors.greenAccent
                          : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Buscar aval por nombre, teléfono...",
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              ),
            ),
          ),

          // Avales seleccionados (chips)
          if (_seleccionados.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _seleccionados.map((id) {
                  final aval = _todosAvales.firstWhere(
                    (a) => a.id == id,
                    orElse: () => AvalModel(id: id, nombre: 'Aval', email: '', telefono: '', direccion: '', relacion: '', clienteId: ''),
                  );
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.purpleAccent,
                      child: Text(
                        aval.nombre.isNotEmpty ? aval.nombre[0].toUpperCase() : 'A',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    label: Text(aval.nombre,
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                    deleteIcon: const Icon(Icons.close,
                        size: 16, color: Colors.white54),
                    onDeleted: () => _toggleAval(id),
                  );
                }).toList(),
              ),
            ),

          const Divider(color: Colors.white12, height: 20),

          // Lista de avales disponibles
          _cargando
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _avalesFiltrados.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text("No hay avales disponibles",
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _avalesFiltrados.length,
                      itemBuilder: (context, index) {
                        final aval = _avalesFiltrados[index];
                        final seleccionado = _seleccionados.contains(aval.id);

                        return ListTile(
                          onTap: () => _toggleAval(aval.id),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: seleccionado
                                    ? Colors.purpleAccent
                                    : Colors.white.withOpacity(0.1),
                                child: Text(
                                  aval.nombre.isNotEmpty ? aval.nombre[0].toUpperCase() : 'A',
                                  style: TextStyle(
                                    color: seleccionado
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (seleccionado)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check,
                                        size: 10, color: Colors.black),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            aval.nombre,
                            style: TextStyle(
                              color:
                                  seleccionado ? Colors.white : Colors.white70,
                              fontWeight: seleccionado
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            "${aval.telefono.isNotEmpty ? aval.telefono : 'Sin teléfono'} • ${aval.relacion.isNotEmpty ? aval.relacion : 'Fiador'}",
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                          trailing: seleccionado
                              ? const Icon(Icons.check_circle,
                                  color: Colors.greenAccent)
                              : Icon(
                                  _seleccionados.length >= _maxAvalesPermitidos
                                      ? Icons.block
                                      : Icons.add_circle_outline,
                                  color: _seleccionados.length >=
                                          _maxAvalesPermitidos
                                      ? Colors.white24
                                      : Colors.white38,
                                ),
                        );
                      },
                    ),

          // Botón para agregar nuevo aval
          Padding(
            padding: const EdgeInsets.all(10),
            child: OutlinedButton.icon(
              onPressed: () => _mostrarFormularioNuevoAval(),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text("Agregar Nuevo Aval"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purpleAccent,
                side: const BorderSide(color: Colors.purpleAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarFormularioNuevoAval() {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final emailController = TextEditingController();
    final direccionController = TextEditingController();
    String tipoRelacion = 'familiar';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Agregar Nuevo Aval",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: nombreController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Nombre Completo *"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Teléfono *"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Email"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: direccionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Dirección"),
                ),
                const SizedBox(height: 12),
                const Text("Relación con el cliente:",
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['familiar', 'amigo', 'conocido', 'laboral', 'otro']
                      .map((t) {
                    return ChoiceChip(
                      label: Text(t[0].toUpperCase() + t.substring(1)),
                      selected: tipoRelacion == t,
                      selectedColor: Colors.purpleAccent,
                      onSelected: (s) => setDialogState(() => tipoRelacion = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancelar"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nombreController.text.isEmpty ||
                              telefonoController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Nombre y teléfono son requeridos"),
                                  backgroundColor: Colors.red),
                            );
                            return;
                          }

                          try {
                            final nuevoAval = await AppSupabase.client
                                .from('avales')
                                .insert({
                                  'nombre_completo': nombreController.text,
                                  'telefono': telefonoController.text,
                                  'email': emailController.text.isNotEmpty
                                      ? emailController.text
                                      : null,
                                  'direccion':
                                      direccionController.text.isNotEmpty
                                          ? direccionController.text
                                          : null,
                                  'tipo_relacion': tipoRelacion,
                                  'estado': 'activo',
                                })
                                .select()
                                .single();

                            Navigator.pop(context);
                            await _cargarDatos();

                            // Auto-seleccionar el nuevo aval
                            if (_seleccionados.length < _maxAvalesPermitidos) {
                              _toggleAval(nuevoAval['id']);
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent),
                        child: const Text("Guardar"),
                      ),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}

/// Servicio para gestionar relación préstamo/tanda con múltiples avales
class MultiAvalesService {
  static final _client = AppSupabase.client;

  /// Guardar avales para un préstamo
  static Future<void> guardarAvalesPrestamo(
      String prestamoId, List<String> avalIds) async {
    // Eliminar relaciones anteriores
    await _client
        .from('prestamos_avales')
        .delete()
        .eq('prestamo_id', prestamoId);

    // Crear nuevas relaciones
    if (avalIds.isNotEmpty) {
      final inserts = avalIds
          .asMap()
          .entries
          .map((e) => {
                'prestamo_id': prestamoId,
                'aval_id': e.value,
                'orden': e.key + 1,
              })
          .toList();

      await _client.from('prestamos_avales').insert(inserts);
    }
  }

  /// Guardar avales para una tanda
  static Future<void> guardarAvalesTanda(
      String tandaId, List<String> avalIds) async {
    await _client.from('tandas_avales').delete().eq('tanda_id', tandaId);

    if (avalIds.isNotEmpty) {
      final inserts = avalIds
          .asMap()
          .entries
          .map((e) => {
                'tanda_id': tandaId,
                'aval_id': e.value,
                'orden': e.key + 1,
              })
          .toList();

      await _client.from('tandas_avales').insert(inserts);
    }
  }

  /// Obtener avales de un préstamo
  static Future<List<AvalModel>> obtenerAvalesPrestamo(
      String prestamoId) async {
    final result = await _client
        .from('prestamos_avales')
        .select('aval_id, orden, avales(*)')
        .eq('prestamo_id', prestamoId)
        .order('orden');

    return (result as List)
        .where((r) => r['avales'] != null)
        .map((r) => AvalModel.fromMap(r['avales']))
        .toList();
  }

  /// Obtener avales de una tanda
  static Future<List<AvalModel>> obtenerAvalesTanda(String tandaId) async {
    final result = await _client
        .from('tandas_avales')
        .select('aval_id, orden, avales(*)')
        .eq('tanda_id', tandaId)
        .order('orden');

    return (result as List)
        .where((r) => r['avales'] != null)
        .map((r) => AvalModel.fromMap(r['avales']))
        .toList();
  }

  /// Obtener IDs de avales de un préstamo
  static Future<List<String>> obtenerAvalIdsPrestamo(String prestamoId) async {
    final result = await _client
        .from('prestamos_avales')
        .select('aval_id')
        .eq('prestamo_id', prestamoId)
        .order('orden');

    return (result as List).map((r) => r['aval_id'] as String).toList();
  }

  /// Obtener IDs de avales de una tanda
  static Future<List<String>> obtenerAvalIdsTanda(String tandaId) async {
    final result = await _client
        .from('tandas_avales')
        .select('aval_id')
        .eq('tanda_id', tandaId)
        .order('orden');

    return (result as List).map((r) => r['aval_id'] as String).toList();
  }
}
