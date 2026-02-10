// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE ÓRDENES CLIMAS - Robert Darin Platform v10.18
/// CRUD completo: Crear, listar, editar órdenes de servicio
/// ═══════════════════════════════════════════════════════════════════════════════
class ClimasOrdenesScreen extends StatefulWidget {
  final bool abrirNueva;
  final String? ordenId;

  const ClimasOrdenesScreen({
    super.key,
    this.abrirNueva = false,
    this.ordenId,
  });

  @override
  State<ClimasOrdenesScreen> createState() => _ClimasOrdenesScreenState();
}

class _ClimasOrdenesScreenState extends State<ClimasOrdenesScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  bool _isLoading = true;
  String _filtro = 'todas';
  bool _accionInicialEjecutada = false;
  
  List<Map<String, dynamic>> _ordenes = [];
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _tecnicos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final ordenesRes = await AppSupabase.client
          .from('climas_ordenes_servicio')
          .select('*, climas_clientes(nombre, telefono, direccion), climas_tecnicos(nombre)')
          .order('created_at', ascending: false);
      _ordenes = List<Map<String, dynamic>>.from(ordenesRes);

      final clientesRes = await AppSupabase.client.from('climas_clientes').select().eq('activo', true).order('nombre');
      _clientes = List<Map<String, dynamic>>.from(clientesRes);

      final tecnicosRes = await AppSupabase.client.from('climas_tecnicos').select().eq('activo', true).order('nombre');
      _tecnicos = List<Map<String, dynamic>>.from(tecnicosRes);

      if (mounted) setState(() => _isLoading = false);
      _ejecutarAccionInicial();
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _ejecutarAccionInicial() {
    if (_accionInicialEjecutada) return;
    _accionInicialEjecutada = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.ordenId != null) {
        Map<String, dynamic>? orden;
        for (final item in _ordenes) {
          if (item['id'] == widget.ordenId) {
            orden = item;
            break;
          }
        }
        if (orden != null) {
          _mostrarDetalleOrden(orden);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró la orden solicitada')),
          );
        }
        return;
      }

      if (widget.abrirNueva) {
        _mostrarNuevaOrden();
      }
    });
  }

  List<Map<String, dynamic>> get _ordenesFiltradas {
    if (_filtro == 'todas') return _ordenes;
    return _ordenes.where((o) => o['estado'] == _filtro).toList();
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return const Color(0xFFF59E0B);
      case 'en_progreso': return const Color(0xFF3B82F6);
      case 'completada': return const Color(0xFF10B981);
      case 'cancelada': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🔧 Órdenes de Servicio',
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFiltros(),
                Expanded(child: _buildLista()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarNuevaOrden(),
        backgroundColor: const Color(0xFF00D9FF),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nueva Orden', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChipFiltro('Todas', 'todas'),
            const SizedBox(width: 8),
            _buildChipFiltro('Pendientes', 'pendiente'),
            const SizedBox(width: 8),
            _buildChipFiltro('En Progreso', 'en_progreso'),
            const SizedBox(width: 8),
            _buildChipFiltro('Completadas', 'completada'),
          ],
        ),
      ),
    );
  }

  Widget _buildChipFiltro(String label, String valor) {
    final seleccionado = _filtro == valor;
    return FilterChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (v) => setState(() => _filtro = valor),
      selectedColor: const Color(0xFF00D9FF),
      backgroundColor: const Color(0xFF1A1A2E),
      labelStyle: TextStyle(color: seleccionado ? Colors.black : Colors.white),
    );
  }

  Widget _buildLista() {
    if (_ordenesFiltradas.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.assignment, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Sin órdenes', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _ordenesFiltradas.length,
        itemBuilder: (context, index) => _buildOrdenCard(_ordenesFiltradas[index]),
      ),
    );
  }

  Widget _buildOrdenCard(Map<String, dynamic> orden) {
    final cliente = orden['climas_clientes'] ?? {};
    final tecnico = orden['climas_tecnicos'] ?? {};
    final estado = orden['estado'] ?? 'pendiente';
    final tipo = orden['tipo_servicio'] ?? 'mantenimiento';
    final monto = (orden['costo_total'] ?? 0).toDouble();
    final fecha = orden['fecha_programada'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getEstadoColor(estado).withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getEstadoColor(estado).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            tipo == 'instalacion' ? Icons.build : (tipo == 'reparacion' ? Icons.handyman : Icons.ac_unit),
            color: _getEstadoColor(estado),
          ),
        ),
        title: Text(cliente['nombre'] ?? 'Cliente', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${tipo.toUpperCase()} • ${tecnico['nombre'] ?? 'Sin asignar'}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            if (fecha != null) ...[
              const SizedBox(height: 2),
              Text('📅 ${DateFormat('dd/MM/yyyy').format(DateTime.parse(fecha))}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_currencyFormat.format(monto), style: TextStyle(color: _getEstadoColor(estado), fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _getEstadoColor(estado).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(estado.toUpperCase(), style: TextStyle(color: _getEstadoColor(estado), fontSize: 9)),
            ),
          ],
        ),
        onTap: () => _mostrarDetalleOrden(orden),
      ),
    );
  }

  void _mostrarNuevaOrden() {
    String? clienteId, tecnicoId;
    String tipo = 'mantenimiento';
    final descripcionCtrl = TextEditingController();
    final costoCtrl = TextEditingController(text: '0');
    DateTime fechaProgramada = DateTime.now().add(const Duration(days: 1));

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
                const Text('Nueva Orden de Servicio', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                DropdownButtonFormField<String>(
                  value: clienteId,
                  dropdownColor: const Color(0xFF0D0D14),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Cliente'),
                  items: _clientes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['nombre'] ?? ''))).toList(),
                  onChanged: (v) => setModalState(() => clienteId = v),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: tecnicoId,
                  dropdownColor: const Color(0xFF0D0D14),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Técnico'),
                  items: _tecnicos.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['nombre'] ?? ''))).toList(),
                  onChanged: (v) => setModalState(() => tecnicoId = v),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: tipo,
                  dropdownColor: const Color(0xFF0D0D14),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Tipo de Servicio'),
                  items: const [
                    DropdownMenuItem(value: 'mantenimiento', child: Text('Mantenimiento')),
                    DropdownMenuItem(value: 'reparacion', child: Text('Reparación')),
                    DropdownMenuItem(value: 'instalacion', child: Text('Instalación')),
                  ],
                  onChanged: (v) => setModalState(() => tipo = v ?? 'mantenimiento'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descripcionCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Descripción'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: costoCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Costo Estimado').copyWith(prefixText: '\$ '),
                ),
                const SizedBox(height: 12),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha Programada', style: TextStyle(color: Colors.white)),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(fechaProgramada), style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.calendar_today, color: Colors.white70),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fechaProgramada,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setModalState(() => fechaProgramada = picked);
                  },
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () async {
                    if (clienteId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un cliente'), backgroundColor: Colors.orange));
                      return;
                    }
                    
                    await AppSupabase.client.from('climas_ordenes_servicio').insert({
                      'cliente_id': clienteId,
                      'tecnico_id': tecnicoId,
                      'tipo_servicio': tipo,
                      'descripcion': descripcionCtrl.text,
                      'costo_total': double.tryParse(costoCtrl.text) ?? 0,
                      'fecha_programada': fechaProgramada.toIso8601String().split('T')[0],
                      'estado': 'pendiente',
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _cargarDatos();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Orden creada'), backgroundColor: Colors.green));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF), minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Crear Orden', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleOrden(Map<String, dynamic> orden) {
    final cliente = orden['climas_clientes'] ?? {};
    final tecnico = orden['climas_tecnicos'] ?? {};
    final estado = orden['estado'] ?? 'pendiente';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Detalle de Orden', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _getEstadoColor(estado).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(estado.toUpperCase(), style: TextStyle(color: _getEstadoColor(estado), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetalleRow('Cliente', cliente['nombre'] ?? 'N/A'),
            _buildDetalleRow('Teléfono', cliente['telefono'] ?? 'N/A'),
            _buildDetalleRow('Dirección', cliente['direccion'] ?? 'N/A'),
            _buildDetalleRow('Técnico', tecnico['nombre'] ?? 'Sin asignar'),
            _buildDetalleRow('Tipo', (orden['tipo_servicio'] ?? '').toUpperCase()),
            _buildDetalleRow('Costo', _currencyFormat.format(orden['costo_total'] ?? 0)),
            _buildDetalleRow('Descripción', orden['descripcion'] ?? 'Sin descripción'),
            const SizedBox(height: 20),
            
            if (estado == 'pendiente')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _cambiarEstado(orden['id'], 'en_progreso'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                      child: const Text('Iniciar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _cambiarEstado(orden['id'], 'cancelada'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            
            if (estado == 'en_progreso')
              ElevatedButton(
                onPressed: () => _cambiarEstado(orden['id'], 'completada'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), minimumSize: const Size(double.infinity, 50)),
                child: const Text('Marcar Completada'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6)))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _cambiarEstado(String ordenId, String nuevoEstado) async {
    await AppSupabase.client.from('climas_ordenes_servicio').update({'estado': nuevoEstado}).eq('id', ordenId);
    if (mounted) {
      Navigator.pop(context);
      _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estado actualizado a $nuevoEstado'), backgroundColor: Colors.green));
    }
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
