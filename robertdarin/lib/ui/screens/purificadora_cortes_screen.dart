// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// CORTES DIARIOS PURIFICADORA - Robert Darin Platform v10.18
/// Control de caja diaria: Apertura, cierre, ventas, gastos
/// ═══════════════════════════════════════════════════════════════════════════════
class PurificadoraCortesScreen extends StatefulWidget {
  const PurificadoraCortesScreen({super.key});

  @override
  State<PurificadoraCortesScreen> createState() => _PurificadoraCortesScreenState();
}

class _PurificadoraCortesScreenState extends State<PurificadoraCortesScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  bool _isLoading = true;
  DateTime _fechaSeleccionada = DateTime.now();

  Map<String, dynamic>? _corteActual;
  List<Map<String, dynamic>> _entregas = [];
  List<Map<String, dynamic>> _gastos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);

      // Obtener corte del día
      final corteRes = await AppSupabase.client
          .from('purificadora_cortes')
          .select()
          .eq('fecha', fechaStr)
          .maybeSingle();
      _corteActual = corteRes;

      // Obtener entregas del día
      final entregasRes = await AppSupabase.client
          .from('purificadora_entregas')
          .select('*, purificadora_clientes(nombre)')
          .eq('fecha_entrega', fechaStr)
          .eq('estado', 'entregada');
      _entregas = List<Map<String, dynamic>>.from(entregasRes);

      // Obtener gastos del día
      final gastosRes = await AppSupabase.client
          .from('purificadora_gastos')
          .select()
          .eq('fecha', fechaStr);
      _gastos = List<Map<String, dynamic>>.from(gastosRes);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalVentas => _entregas.fold<double>(0, (sum, e) => sum + (e['monto_cobrado'] ?? 0).toDouble());
  double get _totalGastos => _gastos.fold<double>(0, (sum, g) => sum + (g['monto'] ?? 0).toDouble());
  int get _totalGarrafones => _entregas.fold<int>(0, (sum, e) => sum + ((e['cantidad_garrafones'] ?? 0) as int));

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '💰 Corte de Caja',
      actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos)],
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSelectorFecha(),
          const SizedBox(height: 16),
          _buildEstadoCorte(),
          const SizedBox(height: 16),
          _buildResumen(),
          const SizedBox(height: 16),
          _buildSeccionVentas(),
          const SizedBox(height: 16),
          _buildSeccionGastos(),
          const SizedBox(height: 16),
          _buildAcciones(),
        ],
      ),
    );
  }

  Widget _buildSelectorFecha() {
    return Container(
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
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _fechaSeleccionada = picked);
                _cargarDatos();
              }
            },
            child: Text(
              DateFormat('EEEE, dd MMMM yyyy', 'es_MX').format(_fechaSeleccionada),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _fechaSeleccionada.isBefore(DateTime.now())
                ? () {
                    setState(() => _fechaSeleccionada = _fechaSeleccionada.add(const Duration(days: 1)));
                    _cargarDatos();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoCorte() {
    final estaAbierto = _corteActual != null && _corteActual!['estado'] == 'abierto';
    final estaCerrado = _corteActual != null && _corteActual!['estado'] == 'cerrado';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: estaAbierto
            ? const Color(0xFF10B981).withOpacity(0.1)
            : (estaCerrado ? const Color(0xFF3B82F6).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: estaAbierto
              ? const Color(0xFF10B981).withOpacity(0.3)
              : (estaCerrado ? const Color(0xFF3B82F6).withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            estaAbierto ? Icons.lock_open : (estaCerrado ? Icons.lock : Icons.schedule),
            color: estaAbierto ? const Color(0xFF10B981) : (estaCerrado ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B)),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estaAbierto ? 'CAJA ABIERTA' : (estaCerrado ? 'CAJA CERRADA' : 'SIN APERTURA'),
                  style: TextStyle(
                    color: estaAbierto ? const Color(0xFF10B981) : (estaCerrado ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B)),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (_corteActual != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Fondo inicial: ${_currencyFormat.format(_corteActual!['fondo_inicial'] ?? 0)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final fondoInicial = (_corteActual?['fondo_inicial'] ?? 0).toDouble();
    final totalCaja = fondoInicial + _totalVentas - _totalGastos;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 RESUMEN DEL DÍA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildResumenCard('🛢️ Garrafones', _totalGarrafones.toString(), const Color(0xFF00D9FF))),
              const SizedBox(width: 12),
              Expanded(child: _buildResumenCard('📋 Entregas', _entregas.length.toString(), const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 12),
          _buildResumenLinea('Fondo Inicial', fondoInicial, Colors.white70),
          _buildResumenLinea('+ Ventas', _totalVentas, const Color(0xFF10B981)),
          _buildResumenLinea('- Gastos', _totalGastos, const Color(0xFFEF4444)),
          const Divider(color: Colors.white24),
          _buildResumenLinea('= TOTAL EN CAJA', totalCaja, const Color(0xFF00D9FF), isBold: true),
        ],
      ),
    );
  }

  Widget _buildResumenCard(String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResumenLinea(String label, double monto, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(_currencyFormat.format(monto), style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14)),
        ],
      ),
    );
  }

  Widget _buildSeccionVentas() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('💵 VENTAS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(_currencyFormat.format(_totalVentas), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (_entregas.isEmpty)
            Center(child: Text('Sin ventas registradas', style: TextStyle(color: Colors.white.withOpacity(0.5))))
          else
            ...(_entregas.take(5).map((e) => _buildVentaItem(e))),
          if (_entregas.length > 5)
            Center(
              child: TextButton(
                onPressed: () {}, // Mostrar todas
                child: Text('Ver todas (${_entregas.length})', style: const TextStyle(color: Color(0xFF00D9FF))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVentaItem(Map<String, dynamic> entrega) {
    final cliente = entrega['purificadora_clientes'] ?? {};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(cliente['nombre'] ?? 'Cliente', style: const TextStyle(color: Colors.white))),
          Text('${entrega['cantidad_garrafones']} 🛢️', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          const SizedBox(width: 12),
          Text(_currencyFormat.format(entrega['monto_cobrado'] ?? 0), style: const TextStyle(color: Color(0xFF10B981))),
        ],
      ),
    );
  }

  Widget _buildSeccionGastos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📤 GASTOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text(_currencyFormat.format(_totalGastos), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF00D9FF), size: 24),
                    onPressed: _corteActual != null && _corteActual!['estado'] == 'abierto' ? _agregarGasto : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_gastos.isEmpty)
            Center(child: Text('Sin gastos registrados', style: TextStyle(color: Colors.white.withOpacity(0.5))))
          else
            ...(_gastos.map((g) => _buildGastoItem(g))),
        ],
      ),
    );
  }

  Widget _buildGastoItem(Map<String, dynamic> gasto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.remove_circle, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(gasto['concepto'] ?? '', style: const TextStyle(color: Colors.white))),
          Text(_currencyFormat.format(gasto['monto'] ?? 0), style: const TextStyle(color: Color(0xFFEF4444))),
        ],
      ),
    );
  }

  Widget _buildAcciones() {
    final estaAbierto = _corteActual != null && _corteActual!['estado'] == 'abierto';
    final estaCerrado = _corteActual != null && _corteActual!['estado'] == 'cerrado';
    final esHoy = DateUtils.isSameDay(_fechaSeleccionada, DateTime.now());

    if (!esHoy) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (_corteActual == null)
          ElevatedButton.icon(
            onPressed: _abrirCaja,
            icon: const Icon(Icons.lock_open, color: Colors.black),
            label: const Text('ABRIR CAJA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), minimumSize: const Size(double.infinity, 56)),
          ),
        if (estaAbierto)
          ElevatedButton.icon(
            onPressed: _cerrarCaja,
            icon: const Icon(Icons.lock, color: Colors.white),
            label: const Text('CERRAR CAJA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), minimumSize: const Size(double.infinity, 56)),
          ),
        if (estaCerrado)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Corte cerrado', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                      Text('Cierre: ${_currencyFormat.format(_corteActual!['monto_cierre'] ?? 0)}', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _abrirCaja() {
    final fondoCtrl = TextEditingController(text: '500');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Abrir Caja', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: fondoCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Fondo inicial',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            prefixText: '\$ ',
            filled: true,
            fillColor: const Color(0xFF0D0D14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await AppSupabase.client.from('purificadora_cortes').insert({
                'fecha': DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
                'fondo_inicial': double.tryParse(fondoCtrl.text) ?? 500,
                'estado': 'abierto',
              });
              if (mounted) {
                Navigator.pop(context);
                _cargarDatos();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Caja abierta'), backgroundColor: Colors.green));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }

  void _cerrarCaja() {
    final fondoInicial = (_corteActual?['fondo_inicial'] ?? 0).toDouble();
    final totalCaja = fondoInicial + _totalVentas - _totalGastos;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Cerrar Caja', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResumenLinea('Fondo Inicial', fondoInicial, Colors.white70),
            _buildResumenLinea('+ Ventas', _totalVentas, const Color(0xFF10B981)),
            _buildResumenLinea('- Gastos', _totalGastos, const Color(0xFFEF4444)),
            const Divider(color: Colors.white24),
            _buildResumenLinea('TOTAL EN CAJA', totalCaja, const Color(0xFF00D9FF), isBold: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await AppSupabase.client.from('purificadora_cortes').update({
                'monto_cierre': totalCaja,
                'total_ventas': _totalVentas,
                'total_gastos': _totalGastos,
                'total_garrafones': _totalGarrafones,
                'estado': 'cerrado',
              }).eq('id', _corteActual!['id']);
              if (mounted) {
                Navigator.pop(context);
                _cargarDatos();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Caja cerrada'), backgroundColor: Colors.green));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Cerrar Caja'),
          ),
        ],
      ),
    );
  }

  void _agregarGasto() {
    final conceptoCtrl = TextEditingController();
    final montoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Agregar Gasto', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: conceptoCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Concepto',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (conceptoCtrl.text.trim().isEmpty || montoCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos'), backgroundColor: Colors.orange));
                return;
              }
              await AppSupabase.client.from('purificadora_gastos').insert({
                'corte_id': _corteActual!['id'],
                'fecha': DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
                'concepto': conceptoCtrl.text.trim(),
                'monto': double.tryParse(montoCtrl.text) ?? 0,
              });
              if (mounted) {
                Navigator.pop(context);
                _cargarDatos();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Gasto agregado'), backgroundColor: Colors.green));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF)),
            child: const Text('Agregar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
