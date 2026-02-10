// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE ENTREGAS PURIFICADORA - Robert Darin Platform v10.18
/// CRUD completo: Entregas, rutas, control diario
/// ═══════════════════════════════════════════════════════════════════════════════
class PurificadoraEntregasScreen extends StatefulWidget {
  final bool abrirNueva;

  const PurificadoraEntregasScreen({super.key, this.abrirNueva = false});

  @override
  State<PurificadoraEntregasScreen> createState() => _PurificadoraEntregasScreenState();
}

class _PurificadoraEntregasScreenState extends State<PurificadoraEntregasScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  bool _isLoading = true;
  bool _accionInicialEjecutada = false;
  DateTime _fechaSeleccionada = DateTime.now();
  String _filtroEstado = 'todos';

  List<Map<String, dynamic>> _entregas = [];
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _repartidores = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
      final entregasRes = await AppSupabase.client
          .from('purificadora_entregas')
          .select('*, purificadora_clientes(nombre, telefono, direccion), empleados(nombre)')
          .eq('fecha_entrega', fechaStr)
          .order('hora_programada');
      _entregas = List<Map<String, dynamic>>.from(entregasRes);

      final clientesRes = await AppSupabase.client.from('purificadora_clientes').select().eq('activo', true).order('nombre');
      _clientes = List<Map<String, dynamic>>.from(clientesRes);

      final repartidoresRes = await AppSupabase.client.from('empleados').select().eq('activo', true).order('nombre');
      _repartidores = List<Map<String, dynamic>>.from(repartidoresRes);

      if (mounted) {
        setState(() => _isLoading = false);
        _ejecutarAccionInicial();
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _ejecutarAccionInicial();
      }
    }
  }

  void _ejecutarAccionInicial() {
    if (_accionInicialEjecutada || !widget.abrirNueva) return;
    _accionInicialEjecutada = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mostrarNuevaEntrega();
    });
  }

  List<Map<String, dynamic>> get _entregasFiltradas {
    if (_filtroEstado == 'todos') return _entregas;
    return _entregas.where((e) => e['estado'] == _filtroEstado).toList();
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'programada': return const Color(0xFFF59E0B);
      case 'en_ruta': return const Color(0xFF3B82F6);
      case 'entregada': return const Color(0xFF10B981);
      case 'no_entregada': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🚰 Entregas del Día',
      actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos)],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSelectorFecha(),
                _buildStats(),
                _buildFiltros(),
                Expanded(child: _buildLista()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarNuevaEntrega(),
        backgroundColor: const Color(0xFF00D9FF),
        icon: const Icon(Icons.add_location_alt, color: Colors.black),
        label: const Text('Nueva Entrega', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSelectorFecha() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF667eea).withOpacity(0.3), const Color(0xFF764ba2).withOpacity(0.3)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () {
              setState(() => _fechaSeleccionada = _fechaSeleccionada.subtract(const Duration(days: 1)));
              _cargarDatos();
            },
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _fechaSeleccionada,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _fechaSeleccionada = picked);
                _cargarDatos();
              }
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, dd MMMM', 'es_MX').format(_fechaSeleccionada),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () {
              setState(() => _fechaSeleccionada = _fechaSeleccionada.add(const Duration(days: 1)));
              _cargarDatos();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final total = _entregas.length;
    final entregadas = _entregas.where((e) => e['estado'] == 'entregada').length;
    final pendientes = _entregas.where((e) => e['estado'] == 'programada' || e['estado'] == 'en_ruta').length;
    final garrafones = _entregas.fold<int>(0, (sum, e) => sum + ((e['cantidad_garrafones'] ?? 0) as int));
    final cobrado = _entregas.where((e) => e['estado'] == 'entregada').fold<double>(0, (sum, e) => sum + (e['monto_cobrado'] ?? 0).toDouble());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard('Total', total.toString(), const Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          _buildStatCard('Entregadas', entregadas.toString(), const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _buildStatCard('Pendientes', pendientes.toString(), const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _buildStatCard('🛢️', garrafones.toString(), const Color(0xFF00D9FF)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
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
            _buildChipFiltro('Todos', 'todos'),
            const SizedBox(width: 8),
            _buildChipFiltro('Programadas', 'programada'),
            const SizedBox(width: 8),
            _buildChipFiltro('En Ruta', 'en_ruta'),
            const SizedBox(width: 8),
            _buildChipFiltro('Entregadas', 'entregada'),
          ],
        ),
      ),
    );
  }

  Widget _buildChipFiltro(String label, String valor) {
    final seleccionado = _filtroEstado == valor;
    return FilterChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (v) => setState(() => _filtroEstado = valor),
      selectedColor: const Color(0xFF00D9FF),
      backgroundColor: const Color(0xFF1A1A2E),
      labelStyle: TextStyle(color: seleccionado ? Colors.black : Colors.white),
    );
  }

  Widget _buildLista() {
    if (_entregasFiltradas.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.local_shipping, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Sin entregas programadas', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _entregasFiltradas.length,
        itemBuilder: (context, index) => _buildEntregaCard(_entregasFiltradas[index]),
      ),
    );
  }

  Widget _buildEntregaCard(Map<String, dynamic> entrega) {
    final cliente = entrega['purificadora_clientes'] ?? {};
    final repartidor = entrega['empleados'] ?? {};
    final estado = entrega['estado'] ?? 'programada';
    final garrafones = entrega['cantidad_garrafones'] ?? 0;
    final hora = entrega['hora_programada'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: _getEstadoColor(estado), width: 4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _getEstadoColor(estado).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: Text('🛢️\n$garrafones', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        title: Row(
          children: [
            Expanded(child: Text(cliente['nombre'] ?? 'Cliente', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            if (hora.isNotEmpty) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('⏰ $hora', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📍 ${cliente['direccion'] ?? 'Sin dirección'}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            Text('🚐 ${repartidor['nombre'] ?? 'Sin asignar'}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _getEstadoColor(estado).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(estado.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: _getEstadoColor(estado), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        onTap: () => _mostrarDetalleEntrega(entrega),
      ),
    );
  }

  void _mostrarNuevaEntrega() {
    String? clienteId, repartidorId;
    final garrafonesCtrl = TextEditingController(text: '1');
    final precioCtrl = TextEditingController(text: '35');
    TimeOfDay horaProgramada = const TimeOfDay(hour: 9, minute: 0);
    final notasCtrl = TextEditingController();

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
                Text('Nueva Entrega - ${DateFormat('dd/MM/yyyy').format(_fechaSeleccionada)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                  value: repartidorId,
                  dropdownColor: const Color(0xFF0D0D14),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Repartidor'),
                  items: _repartidores.map((r) => DropdownMenuItem(value: r['id'] as String, child: Text(r['nombre'] ?? ''))).toList(),
                  onChanged: (v) => setModalState(() => repartidorId = v),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: TextField(controller: garrafonesCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Garrafones'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: precioCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Precio c/u').copyWith(prefixText: '\$ '))),
                  ],
                ),
                const SizedBox(height: 12),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora Programada', style: TextStyle(color: Colors.white)),
                  subtitle: Text('${horaProgramada.hour.toString().padLeft(2, '0')}:${horaProgramada.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.access_time, color: Colors.white70),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: horaProgramada);
                    if (picked != null) setModalState(() => horaProgramada = picked);
                  },
                ),
                const SizedBox(height: 12),

                TextField(controller: notasCtrl, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Notas')),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () async {
                    if (clienteId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un cliente'), backgroundColor: Colors.orange));
                      return;
                    }

                    final cantGarrafones = int.tryParse(garrafonesCtrl.text) ?? 1;
                    final precioUnitario = double.tryParse(precioCtrl.text) ?? 35;

                    await AppSupabase.client.from('purificadora_entregas').insert({
                      'cliente_id': clienteId,
                      'repartidor_id': repartidorId,
                      'fecha_entrega': DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
                      'hora_programada': '${horaProgramada.hour.toString().padLeft(2, '0')}:${horaProgramada.minute.toString().padLeft(2, '0')}',
                      'cantidad_garrafones': cantGarrafones,
                      'precio_unitario': precioUnitario,
                      'monto_total': cantGarrafones * precioUnitario,
                      'estado': 'programada',
                      'notas': notasCtrl.text.trim(),
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      _cargarDatos();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Entrega programada'), backgroundColor: Colors.green));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF), minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Programar Entrega', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleEntrega(Map<String, dynamic> entrega) {
    final cliente = entrega['purificadora_clientes'] ?? {};
    final repartidor = entrega['empleados'] ?? {};
    final estado = entrega['estado'] ?? 'programada';
    final garrafones = entrega['cantidad_garrafones'] ?? 0;
    final montoTotal = (entrega['monto_total'] ?? 0).toDouble();

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
                const Text('Detalle de Entrega', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _getEstadoColor(estado).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(estado.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: _getEstadoColor(estado), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetalleRow('Cliente', cliente['nombre'] ?? 'N/A'),
            _buildDetalleRow('Teléfono', cliente['telefono'] ?? 'N/A'),
            _buildDetalleRow('Dirección', cliente['direccion'] ?? 'N/A'),
            _buildDetalleRow('Repartidor', repartidor['nombre'] ?? 'Sin asignar'),
            _buildDetalleRow('Garrafones', garrafones.toString()),
            _buildDetalleRow('Total', _currencyFormat.format(montoTotal)),
            const SizedBox(height: 20),

            if (estado == 'programada')
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () => _cambiarEstado(entrega['id'], 'en_ruta'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)), child: const Text('En Ruta'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () => _cambiarEstado(entrega['id'], 'no_entregada'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('No Entregar'))),
                ],
              ),
            if (estado == 'en_ruta')
              ElevatedButton(
                onPressed: () => _marcarEntregada(entrega),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), minimumSize: const Size(double.infinity, 50)),
                child: const Text('✅ Marcar Entregada'),
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

  void _cambiarEstado(String entregaId, String nuevoEstado) async {
    await AppSupabase.client.from('purificadora_entregas').update({'estado': nuevoEstado}).eq('id', entregaId);
    if (mounted) {
      Navigator.pop(context);
      _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estado: $nuevoEstado'), backgroundColor: Colors.green));
    }
  }

  void _marcarEntregada(Map<String, dynamic> entrega) async {
    final montoTotal = (entrega['monto_total'] ?? 0).toDouble();
    
    await AppSupabase.client.from('purificadora_entregas').update({
      'estado': 'entregada',
      'monto_cobrado': montoTotal,
      'hora_entrega': DateFormat('HH:mm').format(DateTime.now()),
    }).eq('id', entrega['id']);

    if (mounted) {
      Navigator.pop(context);
      _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Entrega completada'), backgroundColor: Colors.green));
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
