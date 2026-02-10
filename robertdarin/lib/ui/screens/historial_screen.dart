// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _movimientos = [];
  String _filtroTipo = 'todos';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      dynamic query = AppSupabase.client
          .from('inventario_movimientos')
          .select('*, inventario(nombre, sku)');
      
      if (_filtroTipo != 'todos') {
        query = query.eq('tipo', _filtroTipo);
      }
      
      query = query.order('created_at', ascending: false);
      final res = await query.limit(100);
      
      if (mounted) {
        setState(() {
          _movimientos = List<Map<String, dynamic>>.from(res);
          if (_fechaInicio != null || _fechaFin != null) {
            _movimientos = _movimientos.where((m) {
              final fecha = DateTime.tryParse(m['created_at'] ?? '');
              if (fecha == null) return true;
              if (_fechaInicio != null && fecha.isBefore(_fechaInicio!)) return false;
              if (_fechaFin != null && fecha.isAfter(_fechaFin!.add(const Duration(days: 1)))) return false;
              return true;
            }).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando historial: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Historial de Movimientos",
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos),
      ],
      body: Column(
        children: [
          _buildStats(),
          _buildFiltros(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildListaMovimientos(),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final entradas = _movimientos.where((m) => m['tipo'] == 'entrada').fold<int>(0, (sum, m) => sum + ((m['cantidad'] ?? 0) as num).toInt());
    final salidas = _movimientos.where((m) => m['tipo'] == 'salida').fold<int>(0, (sum, m) => sum + ((m['cantidad'] ?? 0) as num).toInt());
    
    return PremiumCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Movimientos", _movimientos.length.toString(), Icons.swap_vert),
          _buildStatItem("Entradas", "+$entradas", Icons.add_circle, Colors.green),
          _buildStatItem("Salidas", "-$salidas", Icons.remove_circle, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.blueAccent, size: 28),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filtroTipo,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos los tipos')),
                    DropdownMenuItem(value: 'entrada', child: Text('Solo entradas')),
                    DropdownMenuItem(value: 'salida', child: Text('Solo salidas')),
                  ],
                  onChanged: (v) { setState(() => _filtroTipo = v ?? 'todos'); _cargarDatos(); },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.date_range, color: _fechaInicio != null ? Colors.cyan : Colors.white54),
            onPressed: _seleccionarFechas,
          ),
          if (_fechaInicio != null)
            IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () { setState(() { _fechaInicio = null; _fechaFin = null; }); _cargarDatos(); }),
        ],
      ),
    );
  }

  Future<void> _seleccionarFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fechaInicio != null ? DateTimeRange(start: _fechaInicio!, end: _fechaFin ?? DateTime.now()) : null,
    );
    if (rango != null) {
      setState(() {
        _fechaInicio = rango.start;
        _fechaFin = rango.end;
      });
      _cargarDatos();
    }
  }

  Widget _buildListaMovimientos() {
    if (_movimientos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: Colors.white24),
            SizedBox(height: 15),
            Text("No hay movimientos", style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    // Agrupar por fecha
    final Map<String, List<Map<String, dynamic>>> gruposPorFecha = {};
    for (var mov in _movimientos) {
      final fecha = DateTime.tryParse(mov['created_at'] ?? '') ?? DateTime.now();
      final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);
      gruposPorFecha.putIfAbsent(fechaStr, () => []).add(mov);
    }

    final fechasOrdenadas = gruposPorFecha.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: fechasOrdenadas.length,
      itemBuilder: (context, index) {
        final fechaStr = fechasOrdenadas[index];
        final movsDia = gruposPorFecha[fechaStr]!;
        final fecha = DateTime.parse(fechaStr);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.white38),
                  const SizedBox(width: 8),
                  Text(DateFormat('EEEE, d MMMM yyyy', 'es').format(fecha), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('${movsDia.length}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ),
                ],
              ),
            ),
            ...movsDia.map((mov) {
              final esEntrada = mov['tipo'] == 'entrada';
              final hora = DateTime.tryParse(mov['created_at'] ?? '') ?? DateTime.now();
              
              return Card(
                color: const Color(0xFF1A1A2E),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (esEntrada ? Colors.green : Colors.red).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(esEntrada ? Icons.arrow_downward : Icons.arrow_upward, color: esEntrada ? Colors.green : Colors.red),
                  ),
                  title: Text(mov['inventario']?['nombre'] ?? 'Producto', style: const TextStyle(color: Colors.white)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mov['motivo'] != null) Text(mov['motivo'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      Text(DateFormat('HH:mm').format(hora), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: (esEntrada ? Colors.green : Colors.red).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text('${esEntrada ? '+' : '-'}${mov['cantidad']}', style: TextStyle(color: esEntrada ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
