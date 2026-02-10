// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA NIVELES NICE - Gestión de Niveles MLM para Vendedoras
// Robert Darin Platform v10.22
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';

class NiceNivelesScreen extends StatefulWidget {
  final String negocioId;
  const NiceNivelesScreen({super.key, this.negocioId = ''});

  @override
  State<NiceNivelesScreen> createState() => _NiceNivelesScreenState();
}

class _NiceNivelesScreenState extends State<NiceNivelesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _niveles = [];
  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  final List<Map<String, dynamic>> _nivelesPreset = [
    {'codigo': 'bronce', 'nombre': 'Bronce', 'color': '#CD7F32', 'comision': 15.0, 'descuento': 20.0},
    {'codigo': 'plata', 'nombre': 'Plata', 'color': '#C0C0C0', 'comision': 20.0, 'descuento': 25.0},
    {'codigo': 'oro', 'nombre': 'Oro', 'color': '#FFD700', 'comision': 25.0, 'descuento': 30.0},
    {'codigo': 'platino', 'nombre': 'Platino', 'color': '#E5E4E2', 'comision': 30.0, 'descuento': 35.0},
    {'codigo': 'diamante', 'nombre': 'Diamante', 'color': '#B9F2FF', 'comision': 35.0, 'descuento': 40.0},
  ];

  @override
  void initState() {
    super.initState();
    _cargarNiveles();
  }

  Future<void> _cargarNiveles() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppSupabase.client
          .from('nice_niveles')
          .select()
          .eq('negocio_id', widget.negocioId)
          .order('orden');
      
      if (mounted) {
        setState(() {
          _niveles = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando niveles: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return const Color(0xFFCD7F32);
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFCD7F32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Niveles MLM',
      subtitle: 'Configura los niveles de vendedoras',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.white),
          onPressed: _mostrarFormularioNivel,
        ),
        if (_niveles.isEmpty)
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            onPressed: _crearNivelesDefault,
            tooltip: 'Crear niveles predeterminados',
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : _niveles.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _cargarNiveles,
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _niveles.length,
                    onReorder: _reordenarNiveles,
                    itemBuilder: (context, i) => _buildNivelCard(_niveles[i], i),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.military_tech, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Sin niveles configurados',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Los niveles definen comisiones y beneficios',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _crearNivelesDefault,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Crear Predeterminados'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _mostrarFormularioNivel,
                icon: const Icon(Icons.add),
                label: const Text('Crear Manual'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD700),
                  side: const BorderSide(color: Color(0xFFFFD700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNivelCard(Map<String, dynamic> nivel, int index) {
    final color = _parseColor(nivel['color']);
    final activo = nivel['activo'] ?? true;

    return Container(
      key: ValueKey(nivel['id']),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activo ? color.withOpacity(0.5) : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _mostrarFormularioNivel(nivel: nivel),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.military_tech, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          nivel['nombre'] ?? 'Sin nombre',
                          style: TextStyle(
                            color: activo ? Colors.white : Colors.grey[500],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!activo) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('INACTIVO', 
                                style: TextStyle(color: Colors.grey, fontSize: 9)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildBeneficioChip(
                          'Comisión ${nivel['comision_ventas'] ?? 0}%',
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        _buildBeneficioChip(
                          'Dto ${nivel['descuento_porcentaje'] ?? 0}%',
                          const Color(0xFF8B5CF6),
                        ),
                        if ((nivel['comision_equipo'] ?? 0) > 0) ...[
                          const SizedBox(width: 8),
                          _buildBeneficioChip(
                            'Equipo ${nivel['comision_equipo']}%',
                            const Color(0xFFF59E0B),
                          ),
                        ],
                      ],
                    ),
                    if ((nivel['ventas_minimas_mes'] ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Meta: ${_formatCurrency.format(nivel['ventas_minimas_mes'])} /mes',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
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

  Widget _buildBeneficioChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _reordenarNiveles(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex--;
    
    setState(() {
      final item = _niveles.removeAt(oldIndex);
      _niveles.insert(newIndex, item);
    });

    try {
      for (int i = 0; i < _niveles.length; i++) {
        await AppSupabase.client
            .from('nice_niveles')
            .update({'orden': i})
            .eq('id', _niveles[i]['id']);
      }
    } catch (e) {
      debugPrint('Error reordenando: $e');
    }
  }

  Future<void> _crearNivelesDefault() async {
    try {
      for (int i = 0; i < _nivelesPreset.length; i++) {
        final preset = _nivelesPreset[i];
        await AppSupabase.client.from('nice_niveles').insert({
          'negocio_id': widget.negocioId,
          'codigo': preset['codigo'],
          'nombre': preset['nombre'],
          'color': preset['color'],
          'comision_ventas': preset['comision'],
          'descuento_porcentaje': preset['descuento'],
          'comision_equipo': i >= 2 ? (i * 2).toDouble() : 0,
          'ventas_minimas_mes': i * 2000.0,
          'bono_reclutamiento': i >= 3 ? (i * 100).toDouble() : 0,
          'orden': i,
          'activo': true,
        });
      }
      
      if (mounted) {
        _cargarNiveles();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Niveles creados exitosamente'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creando niveles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarFormularioNivel({Map<String, dynamic>? nivel}) {
    final isEdit = nivel != null;
    final codigoCtrl = TextEditingController(text: nivel?['codigo'] ?? '');
    final nombreCtrl = TextEditingController(text: nivel?['nombre'] ?? '');
    final comisionVentasCtrl = TextEditingController(text: nivel?['comision_ventas']?.toString() ?? '20');
    final comisionEquipoCtrl = TextEditingController(text: nivel?['comision_equipo']?.toString() ?? '0');
    final descuentoCtrl = TextEditingController(text: nivel?['descuento_porcentaje']?.toString() ?? '25');
    final ventasMinimasCtrl = TextEditingController(text: nivel?['ventas_minimas_mes']?.toString() ?? '0');
    final bonoReclutamientoCtrl = TextEditingController(text: nivel?['bono_reclutamiento']?.toString() ?? '0');
    String colorSeleccionado = nivel?['color'] ?? '#CD7F32';
    bool activo = nivel?['activo'] ?? true;

    final colores = ['#CD7F32', '#C0C0C0', '#FFD700', '#E5E4E2', '#B9F2FF', '#E91E63', '#9C27B0'];

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
                  isEdit ? 'Editar Nivel' : 'Nuevo Nivel',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(codigoCtrl, 'Código', Icons.code),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(nombreCtrl, 'Nombre *', Icons.military_tech),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Color del Nivel', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: colores.map((c) {
                    final isSelected = colorSeleccionado == c;
                    final color = _parseColor(c);
                    return InkWell(
                      onTap: () => setModalState(() => colorSeleccionado = c),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Comisiones y Descuentos', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(comisionVentasCtrl, 'Comisión %', Icons.percent, isNumber: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(descuentoCtrl, 'Descuento %', Icons.discount, isNumber: true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(comisionEquipoCtrl, 'Comisión Equipo %', Icons.groups, isNumber: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(bonoReclutamientoCtrl, 'Bono Reclut.', Icons.person_add, isNumber: true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(ventasMinimasCtrl, 'Ventas Mínimas Mes (\$)', Icons.trending_up, isNumber: true),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: activo,
                  onChanged: (v) => setModalState(() => activo = v),
                  title: const Text('Nivel Activo', style: TextStyle(color: Colors.white)),
                  activeColor: const Color(0xFF10B981),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isEdit)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _eliminarNivel(nivel['id']),
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
                        onPressed: () => _guardarNivel(
                          id: nivel?['id'],
                          codigo: codigoCtrl.text,
                          nombre: nombreCtrl.text,
                          color: colorSeleccionado,
                          comisionVentas: double.tryParse(comisionVentasCtrl.text) ?? 20,
                          comisionEquipo: double.tryParse(comisionEquipoCtrl.text) ?? 0,
                          descuento: double.tryParse(descuentoCtrl.text) ?? 25,
                          ventasMinimas: double.tryParse(ventasMinimasCtrl.text) ?? 0,
                          bonoReclutamiento: double.tryParse(bonoReclutamientoCtrl.text) ?? 0,
                          activo: activo,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isEdit ? 'Actualizar' : 'Guardar',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Future<void> _guardarNivel({
    String? id,
    required String codigo,
    required String nombre,
    required String color,
    required double comisionVentas,
    required double comisionEquipo,
    required double descuento,
    required double ventasMinimas,
    required double bonoReclutamiento,
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
        'codigo': codigo.isNotEmpty ? codigo.toLowerCase() : nombre.toLowerCase().replaceAll(' ', '_'),
        'nombre': nombre,
        'color': color,
        'comision_ventas': comisionVentas,
        'comision_equipo': comisionEquipo,
        'descuento_porcentaje': descuento,
        'ventas_minimas_mes': ventasMinimas,
        'bono_reclutamiento': bonoReclutamiento,
        'activo': activo,
        'orden': id == null ? _niveles.length : null,
      };
      data.removeWhere((k, v) => v == null);

      if (id != null) {
        await AppSupabase.client.from('nice_niveles').update(data).eq('id', id);
      } else {
        await AppSupabase.client.from('nice_niveles').insert(data);
      }

      if (mounted) {
        Navigator.pop(context);
        _cargarNiveles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? 'Nivel actualizado' : 'Nivel creado'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando nivel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarNivel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Eliminar Nivel', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro? Las vendedoras de este nivel quedarán sin nivel asignado.',
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
        await AppSupabase.client.from('nice_niveles').delete().eq('id', id);
        if (mounted) {
          Navigator.pop(context);
          _cargarNiveles();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nivel eliminado'), backgroundColor: Color(0xFF10B981)),
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
