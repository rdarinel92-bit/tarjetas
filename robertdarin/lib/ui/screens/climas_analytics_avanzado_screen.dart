// ═══════════════════════════════════════════════════════════════════════════════
// CLIMAS ANALYTICS AVANZADO - V10.55
// Dashboard completo de métricas, predicciones y comparativas
// Para Superadmin: visión total del negocio de aires acondicionados
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

class ClimasAnalyticsAvanzadoScreen extends StatefulWidget {
  final String? negocioId;
  
  const ClimasAnalyticsAvanzadoScreen({super.key, this.negocioId});

  @override
  State<ClimasAnalyticsAvanzadoScreen> createState() => _ClimasAnalyticsAvanzadoScreenState();
}

class _ClimasAnalyticsAvanzadoScreenState extends State<ClimasAnalyticsAvanzadoScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  bool _isLoading = true;
  String _periodoSeleccionado = '30d';
  
  // KPIs Principales
  int _totalOrdenes = 0;
  int _ordenesCompletadas = 0;
  int _ordenesPendientes = 0;
  int _ordenesCanceladas = 0;
  double _ingresosTotales = 0;
  double _ticketPromedio = 0;
  double _tasaCompletacion = 0;
  double _tiempoPromedioServicio = 0; // en horas
  
  // Datos para gráficas
  List<Map<String, dynamic>> _ordenesPorDia = [];
  List<Map<String, dynamic>> _ingresosPorDia = [];
  List<Map<String, dynamic>> _ordenesPorTipo = [];
  List<Map<String, dynamic>> _rendimientoTecnicos = [];
  List<Map<String, dynamic>> _equiposMasAtendidos = [];
  List<Map<String, dynamic>> _clientesTop = [];
  List<Map<String, dynamic>> _proximosMantenimientos = [];
  List<Map<String, dynamic>> _garantiasPorVencer = [];
  
  // Comparativas
  double _variacionIngresosMes = 0;
  double _variacionOrdenesMes = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final ahora = DateTime.now();
      final dias = _periodoSeleccionado == '7d' ? 7 
                 : _periodoSeleccionado == '30d' ? 30 
                 : _periodoSeleccionado == '90d' ? 90 : 365;
      final fechaInicio = ahora.subtract(Duration(days: dias));
      
      // Cargar órdenes
      var query = AppSupabase.client
          .from('climas_ordenes_servicio')
          .select('*, climas_clientes(nombre), climas_tecnicos(nombre), climas_equipos(modelo, marca)')
          .gte('created_at', fechaInicio.toIso8601String());
      
      if (widget.negocioId != null) {
        query = query.eq('negocio_id', widget.negocioId!);
      }
      
      final ordenes = await query.order('created_at', ascending: false);
      final listaOrdenes = List<Map<String, dynamic>>.from(ordenes);
      
      // Calcular KPIs
      _totalOrdenes = listaOrdenes.length;
      _ordenesCompletadas = listaOrdenes.where((o) => o['estado'] == 'completada').length;
      _ordenesPendientes = listaOrdenes.where((o) => o['estado'] == 'pendiente').length;
      _ordenesCanceladas = listaOrdenes.where((o) => o['estado'] == 'cancelada').length;
      
      _ingresosTotales = listaOrdenes.fold(0.0, (sum, o) => 
          sum + (double.tryParse(o['total']?.toString() ?? '0') ?? 0));
      
      _ticketPromedio = _ordenesCompletadas > 0 ? _ingresosTotales / _ordenesCompletadas : 0;
      _tasaCompletacion = _totalOrdenes > 0 ? (_ordenesCompletadas / _totalOrdenes * 100) : 0;
      
      // Tiempo promedio de servicio (basado en diferencia entre fecha_inicio y fecha_fin)
      final ordenesConTiempo = listaOrdenes.where((o) => 
          o['fecha_inicio'] != null && o['fecha_fin'] != null).toList();
      if (ordenesConTiempo.isNotEmpty) {
        double totalHoras = 0;
        for (final o in ordenesConTiempo) {
          final inicio = DateTime.tryParse(o['fecha_inicio'] ?? '');
          final fin = DateTime.tryParse(o['fecha_fin'] ?? '');
          if (inicio != null && fin != null) {
            totalHoras += fin.difference(inicio).inMinutes / 60;
          }
        }
        _tiempoPromedioServicio = totalHoras / ordenesConTiempo.length;
      }
      
      // Órdenes por día
      _ordenesPorDia = _agruparPorDia(listaOrdenes, dias);
      
      // Ingresos por día
      _ingresosPorDia = _agruparIngresosPorDia(listaOrdenes, dias);
      
      // Órdenes por tipo de servicio
      _ordenesPorTipo = _agruparPorTipo(listaOrdenes);
      
      // Rendimiento de técnicos
      await _cargarRendimientoTecnicos(fechaInicio);
      
      // Equipos más atendidos
      _equiposMasAtendidos = _agruparPorEquipo(listaOrdenes);
      
      // Top clientes
      _clientesTop = _agruparPorCliente(listaOrdenes);
      
      // Próximos mantenimientos
      await _cargarProximosMantenimientos();
      
      // Garantías por vencer
      await _cargarGarantiasPorVencer();
      
      // Calcular variaciones mes anterior
      await _calcularVariaciones();
      
    } catch (e) {
      debugPrint('Error cargando analytics: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _agruparPorDia(List<Map<String, dynamic>> ordenes, int dias) {
    final Map<String, int> porDia = {};
    final ahora = DateTime.now();
    
    // Inicializar todos los días
    for (int i = dias - 1; i >= 0; i--) {
      final fecha = ahora.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(fecha);
      porDia[key] = 0;
    }
    
    // Contar órdenes
    for (final o in ordenes) {
      final fecha = o['created_at']?.toString().split('T')[0];
      if (fecha != null && porDia.containsKey(fecha)) {
        porDia[fecha] = (porDia[fecha] ?? 0) + 1;
      }
    }
    
    final resultado = <Map<String, dynamic>>[];
    porDia.forEach((key, value) {
      resultado.add({
        'fecha': key,
        'label': DateFormat('dd/MM').format(DateTime.parse(key)),
        'cantidad': value,
      });
    });
    return resultado;
  }

  List<Map<String, dynamic>> _agruparIngresosPorDia(List<Map<String, dynamic>> ordenes, int dias) {
    final Map<String, double> porDia = {};
    final ahora = DateTime.now();
    
    for (int i = dias - 1; i >= 0; i--) {
      final fecha = ahora.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(fecha);
      porDia[key] = 0;
    }
    
    for (final o in ordenes) {
      if (o['estado'] == 'completada') {
        final fecha = o['created_at']?.toString().split('T')[0];
        final monto = double.tryParse(o['total']?.toString() ?? '0') ?? 0;
        if (fecha != null && porDia.containsKey(fecha)) {
          porDia[fecha] = (porDia[fecha] ?? 0) + monto;
        }
      }
    }
    
    final resultado = <Map<String, dynamic>>[];
    porDia.forEach((key, value) {
      resultado.add({
        'fecha': key,
        'label': DateFormat('dd/MM').format(DateTime.parse(key)),
        'monto': value,
      });
    });
    return resultado;
  }

  List<Map<String, dynamic>> _agruparPorTipo(List<Map<String, dynamic>> ordenes) {
    final Map<String, int> porTipo = {};
    
    for (final o in ordenes) {
      final tipo = o['tipo_servicio']?.toString() ?? 'otro';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;
    }
    
    final colores = <String, Color>{
      'instalacion': Colors.blue,
      'mantenimiento': Colors.green,
      'reparacion': Colors.orange,
      'emergencia': Colors.red,
      'garantia': Colors.purple,
      'otro': Colors.grey,
    };
    
    final resultado = <Map<String, dynamic>>[];
    porTipo.forEach((key, value) {
      resultado.add({
        'tipo': key,
        'cantidad': value,
        'color': colores[key] ?? Colors.grey,
        'porcentaje': _totalOrdenes > 0 ? (value / _totalOrdenes * 100) : 0,
      });
    });
    resultado.sort((a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int));
    return resultado;
  }

  Future<void> _cargarRendimientoTecnicos(DateTime fechaInicio) async {
    try {
      // Obtener todos los técnicos
      var tecnicosQuery = AppSupabase.client
          .from('climas_tecnicos')
          .select('id, nombre, foto_url');
      
      if (widget.negocioId != null) {
        tecnicosQuery = tecnicosQuery.eq('negocio_id', widget.negocioId!);
      }
      
      final tecnicos = await tecnicosQuery;
      
      // Para cada técnico, calcular métricas
      _rendimientoTecnicos = [];
      for (final t in tecnicos) {
        var ordenesQuery = AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('estado, total, created_at')
            .eq('tecnico_id', t['id'])
            .gte('created_at', fechaInicio.toIso8601String());
        
        final ordenesT = await ordenesQuery;
        final listaOrdenesT = List<Map<String, dynamic>>.from(ordenesT);
        
        final completadas = listaOrdenesT.where((o) => o['estado'] == 'completada').length;
        final total = listaOrdenesT.length;
        final ingresos = listaOrdenesT
            .where((o) => o['estado'] == 'completada')
            .fold(0.0, (sum, o) => sum + (double.tryParse(o['total']?.toString() ?? '0') ?? 0));
        
        _rendimientoTecnicos.add({
          'id': t['id'],
          'nombre': t['nombre'] ?? 'Sin nombre',
          'foto_url': t['foto_url'],
          'ordenes_total': total,
          'ordenes_completadas': completadas,
          'tasa_completacion': total > 0 ? (completadas / total * 100) : 0,
          'ingresos': ingresos,
        });
      }
      
      _rendimientoTecnicos.sort((a, b) => 
          (b['ordenes_completadas'] as int).compareTo(a['ordenes_completadas'] as int));
      
    } catch (e) {
      debugPrint('Error cargando rendimiento técnicos: $e');
    }
  }

  List<Map<String, dynamic>> _agruparPorEquipo(List<Map<String, dynamic>> ordenes) {
    final Map<String, Map<String, dynamic>> porEquipo = {};
    
    for (final o in ordenes) {
      final equipo = o['climas_equipos'];
      if (equipo != null) {
        final key = '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''}'.trim();
        if (key.isNotEmpty) {
          if (!porEquipo.containsKey(key)) {
            porEquipo[key] = {
              'equipo': key,
              'cantidad': 0,
              'ingresos': 0.0,
            };
          }
          porEquipo[key]!['cantidad'] = (porEquipo[key]!['cantidad'] as int) + 1;
          porEquipo[key]!['ingresos'] = (porEquipo[key]!['ingresos'] as double) + 
              (double.tryParse(o['total']?.toString() ?? '0') ?? 0);
        }
      }
    }
    
    final resultado = porEquipo.values.toList();
    resultado.sort((a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int));
    return resultado.take(10).toList();
  }

  List<Map<String, dynamic>> _agruparPorCliente(List<Map<String, dynamic>> ordenes) {
    final Map<String, Map<String, dynamic>> porCliente = {};
    
    for (final o in ordenes) {
      final clienteId = o['cliente_id']?.toString();
      final clienteNombre = o['climas_clientes']?['nombre'] ?? 'Sin cliente';
      
      if (clienteId != null) {
        if (!porCliente.containsKey(clienteId)) {
          porCliente[clienteId] = {
            'id': clienteId,
            'nombre': clienteNombre,
            'ordenes': 0,
            'ingresos': 0.0,
          };
        }
        porCliente[clienteId]!['ordenes'] = (porCliente[clienteId]!['ordenes'] as int) + 1;
        if (o['estado'] == 'completada') {
          porCliente[clienteId]!['ingresos'] = (porCliente[clienteId]!['ingresos'] as double) + 
              (double.tryParse(o['total']?.toString() ?? '0') ?? 0);
        }
      }
    }
    
    final resultado = porCliente.values.toList();
    resultado.sort((a, b) => (b['ingresos'] as double).compareTo(a['ingresos'] as double));
    return resultado.take(10).toList();
  }

  Future<void> _cargarProximosMantenimientos() async {
    try {
      final hoy = DateTime.now();
      final en30Dias = hoy.add(const Duration(days: 30));
      
      var query = AppSupabase.client
          .from('climas_equipos')
          .select('*, climas_clientes(nombre, telefono)')
          .lte('proximo_mantenimiento', en30Dias.toIso8601String())
          .gte('proximo_mantenimiento', hoy.toIso8601String());
      
      if (widget.negocioId != null) {
        query = query.eq('negocio_id', widget.negocioId!);
      }
      
      final resultado = await query.order('proximo_mantenimiento').limit(20);
      _proximosMantenimientos = List<Map<String, dynamic>>.from(resultado);
    } catch (e) {
      debugPrint('Error cargando mantenimientos: $e');
    }
  }

  Future<void> _cargarGarantiasPorVencer() async {
    try {
      final hoy = DateTime.now();
      final en60Dias = hoy.add(const Duration(days: 60));
      
      var query = AppSupabase.client
          .from('climas_equipos')
          .select('*, climas_clientes(nombre, telefono)')
          .lte('garantia_hasta', en60Dias.toIso8601String())
          .gte('garantia_hasta', hoy.toIso8601String());
      
      if (widget.negocioId != null) {
        query = query.eq('negocio_id', widget.negocioId!);
      }
      
      final resultado = await query.order('garantia_hasta').limit(20);
      _garantiasPorVencer = List<Map<String, dynamic>>.from(resultado);
    } catch (e) {
      debugPrint('Error cargando garantías: $e');
    }
  }

  Future<void> _calcularVariaciones() async {
    try {
      final ahora = DateTime.now();
      final inicioMesActual = DateTime(ahora.year, ahora.month, 1);
      final inicioMesAnterior = DateTime(ahora.year, ahora.month - 1, 1);
      final finMesAnterior = inicioMesActual.subtract(const Duration(days: 1));
      
      // Órdenes mes actual
      var queryActual = AppSupabase.client
          .from('climas_ordenes_servicio')
          .select('total, estado')
          .gte('created_at', inicioMesActual.toIso8601String());
      
      if (widget.negocioId != null) {
        queryActual = queryActual.eq('negocio_id', widget.negocioId!);
      }
      
      final ordenesActual = await queryActual;
      final ingresosActual = (ordenesActual as List)
          .where((o) => o['estado'] == 'completada')
          .fold(0.0, (sum, o) => sum + (double.tryParse(o['total']?.toString() ?? '0') ?? 0));
      
      // Órdenes mes anterior
      var queryAnterior = AppSupabase.client
          .from('climas_ordenes_servicio')
          .select('total, estado')
          .gte('created_at', inicioMesAnterior.toIso8601String())
          .lte('created_at', finMesAnterior.toIso8601String());
      
      if (widget.negocioId != null) {
        queryAnterior = queryAnterior.eq('negocio_id', widget.negocioId!);
      }
      
      final ordenesAnterior = await queryAnterior;
      final ingresosAnterior = (ordenesAnterior as List)
          .where((o) => o['estado'] == 'completada')
          .fold(0.0, (sum, o) => sum + (double.tryParse(o['total']?.toString() ?? '0') ?? 0));
      
      _variacionOrdenesMes = ordenesAnterior.isNotEmpty 
          ? ((ordenesActual.length - ordenesAnterior.length) / ordenesAnterior.length * 100)
          : 0;
      
      _variacionIngresosMes = ingresosAnterior > 0
          ? ((ingresosActual - ingresosAnterior) / ingresosAnterior * 100)
          : 0;
          
    } catch (e) {
      debugPrint('Error calculando variaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Analytics Climas',
      actions: [
        // Selector de período
        PopupMenuButton<String>(
          icon: const Icon(Icons.calendar_today, color: Colors.white),
          onSelected: (value) {
            setState(() => _periodoSeleccionado = value);
            _cargarDatos();
          },
          itemBuilder: (context) => [
            _buildPeriodoItem('7d', '7 días'),
            _buildPeriodoItem('30d', '30 días'),
            _buildPeriodoItem('90d', '3 meses'),
            _buildPeriodoItem('365d', '1 año'),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : Column(
              children: [
                // Tabs
                Container(
                  color: const Color(0xFF0D0D14),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.cyan,
                    labelColor: Colors.cyan,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Resumen'),
                      Tab(icon: Icon(Icons.engineering, size: 20), text: 'Técnicos'),
                      Tab(icon: Icon(Icons.people, size: 20), text: 'Clientes'),
                      Tab(icon: Icon(Icons.warning, size: 20), text: 'Alertas'),
                    ],
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResumenTab(),
                      _buildTecnicosTab(),
                      _buildClientesTab(),
                      _buildAlertasTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PopupMenuItem<String> _buildPeriodoItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_periodoSeleccionado == value)
            const Icon(Icons.check, color: Colors.cyan, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildResumenTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPIs principales
            _buildKPIsGrid(),
            const SizedBox(height: 20),
            
            // Gráfica de órdenes por día
            _buildGraficaOrdenesDia(),
            const SizedBox(height: 20),
            
            // Gráfica de ingresos
            _buildGraficaIngresos(),
            const SizedBox(height: 20),
            
            // Distribución por tipo de servicio
            _buildDistribucionTipos(),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKPICard(
              'Órdenes Totales',
              _totalOrdenes.toString(),
              Icons.assignment,
              Colors.blue,
              variacion: _variacionOrdenesMes,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard(
              'Completadas',
              _ordenesCompletadas.toString(),
              Icons.check_circle,
              Colors.green,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard(
              'Ingresos',
              _currencyFormat.format(_ingresosTotales),
              Icons.attach_money,
              Colors.amber,
              variacion: _variacionIngresosMes,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard(
              'Ticket Promedio',
              _currencyFormat.format(_ticketPromedio),
              Icons.receipt_long,
              Colors.purple,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard(
              'Tasa Éxito',
              '${_tasaCompletacion.toStringAsFixed(1)}%',
              Icons.trending_up,
              _tasaCompletacion >= 80 ? Colors.green : Colors.orange,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard(
              'Tiempo Prom.',
              '${_tiempoPromedioServicio.toStringAsFixed(1)}h',
              Icons.timer,
              Colors.cyan,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String titulo, String valor, IconData icono, Color color, {double? variacion}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              if (variacion != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: variacion >= 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        variacion >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: variacion >= 0 ? Colors.green : Colors.red,
                      ),
                      Text(
                        '${variacion.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: variacion >= 0 ? Colors.green : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficaOrdenesDia() {
    if (_ordenesPorDia.isEmpty) return const SizedBox.shrink();
    
    final maxY = _ordenesPorDia.fold<double>(0, (max, e) {
      final val = (e['cantidad'] as int).toDouble();
      return val > max ? val : max;
    }) * 1.2;
    
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 Órdenes por Día',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white10,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (_ordenesPorDia.length / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _ordenesPorDia.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _ordenesPorDia[idx]['label'] ?? '',
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_ordenesPorDia.length - 1).toDouble(),
                minY: 0,
                maxY: maxY > 0 ? maxY : 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: _ordenesPorDia.asMap().entries.map((e) =>
                        FlSpot(e.key.toDouble(), (e.value['cantidad'] as int).toDouble())
                    ).toList(),
                    isCurved: true,
                    color: Colors.cyan,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.cyan.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficaIngresos() {
    if (_ingresosPorDia.isEmpty) return const SizedBox.shrink();
    
    final maxY = _ingresosPorDia.fold<double>(0, (max, e) {
      final val = (e['monto'] as double);
      return val > max ? val : max;
    }) * 1.2;
    
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 Ingresos por Día',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY : 1000,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        _currencyFormat.format(rod.toY),
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _ingresosPorDia.length && idx % 5 == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _ingresosPorDia[idx]['label'] ?? '',
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _ingresosPorDia.asMap().entries.map((e) =>
                    BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value['monto'] as double,
                          color: Colors.amber,
                          width: _ingresosPorDia.length > 30 ? 4 : 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    )
                ).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistribucionTipos() {
    if (_ordenesPorTipo.isEmpty) return const SizedBox.shrink();
    
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔧 Distribución por Tipo de Servicio',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Pie chart
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: _ordenesPorTipo.map((t) => PieChartSectionData(
                      value: (t['cantidad'] as int).toDouble(),
                      color: t['color'] as Color,
                      radius: 30,
                      showTitle: false,
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Leyenda
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _ordenesPorTipo.take(6).map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: t['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatearTipo(t['tipo'] as String),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        Text(
                          '${t['cantidad']} (${(t['porcentaje'] as double).toStringAsFixed(0)}%)',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatearTipo(String tipo) {
    final nombres = {
      'instalacion': 'Instalación',
      'mantenimiento': 'Mantenimiento',
      'reparacion': 'Reparación',
      'emergencia': 'Emergencia',
      'garantia': 'Garantía',
      'otro': 'Otro',
    };
    return nombres[tipo] ?? tipo;
  }

  Widget _buildTecnicosTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👷 Rendimiento de Técnicos',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (_rendimientoTecnicos.isEmpty)
              _buildEmptyState('No hay técnicos registrados')
            else
              ..._rendimientoTecnicos.asMap().entries.map((e) => 
                  _buildTecnicoCard(e.value, e.key + 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildTecnicoCard(Map<String, dynamic> tecnico, int posicion) {
    final tasa = tecnico['tasa_completacion'] as double;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: posicion <= 3 
            ? Border.all(color: posicion == 1 ? Colors.amber : posicion == 2 ? Colors.grey : Colors.brown, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Posición
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: posicion == 1 ? Colors.amber 
                   : posicion == 2 ? Colors.grey 
                   : posicion == 3 ? Colors.brown 
                   : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$posicion',
                style: TextStyle(
                  color: posicion <= 3 ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Info técnico
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tecnico['nombre'] ?? 'Sin nombre',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildMiniStat(Icons.assignment, '${tecnico['ordenes_total']}', Colors.blue),
                    const SizedBox(width: 12),
                    _buildMiniStat(Icons.check, '${tecnico['ordenes_completadas']}', Colors.green),
                    const SizedBox(width: 12),
                    _buildMiniStat(Icons.attach_money, _currencyFormat.format(tecnico['ingresos']), Colors.amber),
                  ],
                ),
              ],
            ),
          ),
          
          // Tasa de completación
          Column(
            children: [
              Text(
                '${tasa.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: tasa >= 80 ? Colors.green : tasa >= 60 ? Colors.orange : Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Éxito',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icono, String valor, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 12, color: color),
        const SizedBox(width: 4),
        Text(valor, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  Widget _buildClientesTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🏆 Top Clientes',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (_clientesTop.isEmpty)
              _buildEmptyState('No hay datos de clientes')
            else
              ..._clientesTop.asMap().entries.map((e) => 
                  _buildClienteCard(e.value, e.key + 1)),
            
            const SizedBox(height: 24),
            
            // Equipos más atendidos
            const Text(
              '🔧 Equipos Más Atendidos',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (_equiposMasAtendidos.isEmpty)
              _buildEmptyState('No hay datos de equipos')
            else
              ..._equiposMasAtendidos.map((e) => _buildEquipoCard(e)),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> cliente, int posicion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: posicion <= 3 ? Colors.amber.withOpacity(0.2) : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$posicion',
                style: TextStyle(
                  color: posicion <= 3 ? Colors.amber : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente['nombre'] ?? 'Sin nombre',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${cliente['ordenes']} órdenes',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(cliente['ingresos']),
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipoCard(Map<String, dynamic> equipo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.ac_unit, color: Colors.cyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              equipo['equipo'] ?? 'Sin nombre',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${equipo['cantidad']} servicios',
                style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                _currencyFormat.format(equipo['ingresos']),
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertasTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mantenimientos próximos
            _buildSeccionAlertas(
              '🔔 Mantenimientos Próximos (30 días)',
              _proximosMantenimientos,
              Icons.build,
              Colors.orange,
              'proximo_mantenimiento',
            ),
            
            const SizedBox(height: 24),
            
            // Garantías por vencer
            _buildSeccionAlertas(
              '⚠️ Garantías por Vencer (60 días)',
              _garantiasPorVencer,
              Icons.security,
              Colors.red,
              'garantia_hasta',
            ),
            
            const SizedBox(height: 24),
            
            // Órdenes pendientes
            _buildAlertaPendientes(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionAlertas(
    String titulo, 
    List<Map<String, dynamic>> items, 
    IconData icono, 
    Color color,
    String campoFecha,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (items.isEmpty)
          _buildEmptyState('No hay alertas pendientes')
        else
          ...items.take(10).map((item) => _buildAlertaItem(item, color, campoFecha)),
      ],
    );
  }

  Widget _buildAlertaItem(Map<String, dynamic> item, Color color, String campoFecha) {
    final cliente = item['climas_clientes'];
    final fecha = DateTime.tryParse(item[campoFecha] ?? '');
    final diasRestantes = fecha != null ? fecha.difference(DateTime.now()).inDays : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: diasRestantes <= 7 ? color.withOpacity(0.5) : Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.ac_unit, color: Colors.cyan, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['marca'] ?? ''} ${item['modelo'] ?? ''}'.trim(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                ),
                if (cliente != null)
                  Text(
                    '${cliente['nombre']}',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: diasRestantes <= 7 ? color.withOpacity(0.2) : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  diasRestantes <= 0 ? 'HOY' : '$diasRestantes días',
                  style: TextStyle(
                    color: diasRestantes <= 7 ? color : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              if (cliente?['telefono'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    cliente['telefono'],
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaPendientes() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.2), Colors.purple.withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pending_actions, color: Colors.orange, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Órdenes Pendientes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Requieren atención inmediata',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '$_ordenesPendientes',
                style: const TextStyle(color: Colors.orange, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                'pendientes',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          mensaje,
          style: TextStyle(color: Colors.white.withOpacity(0.4)),
        ),
      ),
    );
  }
}
